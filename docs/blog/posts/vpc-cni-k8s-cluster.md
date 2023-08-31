---
title: "VPC-CNI方案实现k8s集群内外互通"
author: Peter Liao
description: 之前的文章分析过 flannel 网络模型，诚然，Flannel 解决了 k8s 集群中容器间网络互通的问题，但对于如何解决集群内容器与集群外的虚拟机或者物理机直接互通的问题却无能为力...
categories: "CNI"
date: 2023-05-28 23:52:19
tags: 
  - 'CNI'
  - '网络'
  - 'go'
---

## VPC-CNI方案背景

之前的文章分析过 flannel 网络模型，诚然，Flannel 解决了 k8s 集群中容器间网络互通的问题，但对于如何解决集群内容器与集群外的虚拟机或者物理机直接互通的问题却无能为力。
其实，更确切说法是集群外服务无法直接 ping 通集群内容器ip。那么就意味着，在类似`dubbo`这种微服务发现和注册场景中，在网络层，k8s 集群外的consumer是无法直接连通集群内的provider的

!!! question "疑问"

    可能有人不禁要问，flannel 为什么对于这种场景无能为力？


这是因为，k8s 集群中容器的ip是由`flanneld`"另起炉灶"独立生成的，并不在vpc网段的范围内，导致集群外的服务器上的路由表缺失相应的路由条目将数据包转发到容器内。
聪明如你，马上想到"既然如此，那让容器分配的 ip 在 vpc 网段内，不就可以了吗?"

恭喜你，答对了！！！

vpc-cni 方案整体沿用的正是这样的思路:从 VPC 网段中分配 ip给容器。这样，集群内外就实现了无差别的网络直连互通；另外一个好处是，这种方案由于省却了 Flanneld 解封装 vxlan 数据包的步骤，网络性能毋庸置疑上会有显著提升。
在 k8s 的落地过程中，为了将业务系统平滑迁移到 k8s 中，尤其是建立在 RPC+ 注册中心的微服务架构上,就必须保持集群内外的直连互通，这种场景下，vpc-cni 方案无疑是首选。

## VPC-CNI原理

主要实现逻辑:

Worker节点启动的时候挂载多个虚拟网卡ENI(`Elastic Netowrk Interface`)

* 每个ENI都绑定了一个主IP(Primary ip) 和 多个 secondary ip
* `ipamd`(Local IP Address Manager)运行在每个 worker 节点上,将所有ENI的所有 secondary ip 加入到本地 ip 地址池中
* 当 cni 接受到创建 pod 事件请求时，就会通过 grpc 请求`ipamd`拿到 ip 并设置 pod 网络栈;反之，当接收到删除 pod 请求时就会通知`ipamd`释放 ip 并同时删除 pod 网络栈

![](https://cdn.jsdelivr.net/gh/hyperter96/hyperter96.github.io/img/vpc-cni1.png)

## CNI接口

遵守 k8S CNI 网络模型的接口规范,主要实现了`cmdAdd`、`cmdDel` 接口,分别处理 pod 网络的创建和销毁事件

### cmdAdd

  代码路径: `cmd/routed-eni-cni-plugin/cni.go`
  ```go
  func cmdAdd(args *skel.CmdArgs) error {
    return add(args, typeswrapper.New(), grpcwrapper.New(), rpcwrapper.New(), driver.New())
  }

  func add(args *skel.CmdArgs, cniTypes typeswrapper.CNITYPES, grpcClient grpcwrapper.GRPC,
    rpcClient rpcwrapper.RPC, driverClient driver.NetworkAPIs) error {
    
        conf, log, err := LoadNetConf(args.StdinData)
        ...
        // 解析 k8s 参数
        var k8sArgs K8sArgs
        if err := cniTypes.LoadArgs(args.Args, &k8sArgs); err != nil {
            log.Errorf("Failed to load k8s config from arg: %v", err)
            return errors.Wrap(err, "add cmd: failed to load k8s config from arg")
        }
        ...
        // 通过 grpc 发起请求到 ipamd server
        conn, err := grpcClient.Dial(ipamdAddress, grpc.WithInsecure())
        ...
        c := rpcClient.NewCNIBackendClient(conn)
        
            // 调用 ipamd 的 AddNetwork 接口获取 ip 地址
        r, err := c.AddNetwork(context.Background(),
            &pb.AddNetworkRequest{
                ClientVersion:              version,
                K8S_POD_NAME:               string(k8sArgs.K8S_POD_NAME),
                K8S_POD_NAMESPACE:          string(k8sArgs.K8S_POD_NAMESPACE),
                K8S_POD_INFRA_CONTAINER_ID: string(k8sArgs.K8S_POD_INFRA_CONTAINER_ID),
                Netns:                      args.Netns,
                ContainerID:                args.ContainerID,
                NetworkName:                conf.Name,
                IfName:                     args.IfName,
            })
        ...
        addr := &net.IPNet{
            IP:   net.ParseIP(r.IPv4Addr),
            Mask: net.IPv4Mask(255, 255, 255, 255),
        }
        ...
                    // 获取到 ip 后,调用 driver 模块配置 pod 的 network namespace
            err = driverClient.SetupNS(hostVethName, args.IfName, args.Netns, addr, int(r.DeviceNumber), r.VPCcidrs, r.UseExternalSNAT, mtu, log)
        }
        ...
        ips := []*current.IPConfig{
            {
                Version: "4",
                Address: *addr,
            },
        }
    
        result := &current.Result{
            IPs: ips,
        }
    
        return cniTypes.PrintResult(result, conf.CNIVersion)
  }

  ```
  总结:cni 通过 grpc 请求`ipamd`服务获取 ip,拿到 ip 后调用 driver 模块设置 pod 的网络环境。


### cmdDel

  释放 pod ip 并清理 pod 的网络环境

  ```go
  func cmdDel(args *skel.CmdArgs) error {
	return del(args, typeswrapper.New(), grpcwrapper.New(), rpcwrapper.New(), driver.New())
  }

  func del(args *skel.CmdArgs, cniTypes typeswrapper.CNITYPES, grpcClient grpcwrapper.GRPC, rpcClient rpcwrapper.RPC, 
  driverClient driver.NetworkAPIs) error {

	conf, log, err := LoadNetConf(args.StdinData)
    ...
	var k8sArgs K8sArgs
	if err := cniTypes.LoadArgs(args.Args, &k8sArgs); err != nil {
		log.Errorf("Failed to load k8s config from args: %v", err)
		return errors.Wrap(err, "del cmd: failed to load k8s config from args")
	}
	// 发起 grpc 请求通知 ipamd 释放 ip
	conn, err := grpcClient.Dial(ipamdAddress, grpc.WithInsecure())
	...
	c := rpcClient.NewCNIBackendClient(conn)

	r, err := c.DelNetwork(context.Background(), &pb.DelNetworkRequest{
		ClientVersion:              version,
		K8S_POD_NAME:               string(k8sArgs.K8S_POD_NAME),
		K8S_POD_NAMESPACE:          string(k8sArgs.K8S_POD_NAMESPACE),
		K8S_POD_INFRA_CONTAINER_ID: string(k8sArgs.K8S_POD_INFRA_CONTAINER_ID),
		NetworkName:                conf.Name,
		ContainerID:                args.ContainerID,
		IfName:                     args.IfName,
		Reason:                     "PodDeleted",
	})
	...
	deletedPodIP := net.ParseIP(r.IPv4Addr)
	if deletedPodIP != nil {
		addr := &net.IPNet{
			IP:   deletedPodIP,
			Mask: net.IPv4Mask(255, 255, 255, 255),
		}
		... 
		// 调用 driver 模块的 TearDownNS 接口删除清理 pod 网络栈
		err = driverClient.TeardownNS(addr, int(r.DeviceNumber), log)
          ...
	      return nil
	}
  }
  
  ```
  
## Driver

该模块主要提供创建和销毁 pod 网络栈的工具,driver 模块的主函数是`SetupNS`和`TeardownNS`

代码路径: `cmd/routed-eni-cni-plugin/driver.go`

代码逻辑：

![](https://cdn.jsdelivr.net/gh/hyperter96/hyperter96.github.io/img/vpc-cni2.png)

### SetupNS

  该函数主要功能是配置 pod 网络栈,包括准备 pod 的网络环境和策略路由的配置

  在 `aws-cni` 网络模型中，节点上的每一个`ENI`都会生成相应的路由表来转发`from-pod`的流量;通过策略路由方式，让`to-pod`的流量优先走主路由表，而对于`from-pod`的流量则走`ENI`对应的路由表，所以在配置 pod 网络环境中有配置策略路由的过程

  ```go
  func (os *linuxNetwork) SetupNS(hostVethName string, contVethName string, netnsPath string, addr *net.IPNet, deviceNumber int, vpcCIDRs []string, useExternalSNAT bool, mtu int, log logger.Logger) error {
    log.Debugf("SetupNS: hostVethName=%s, contVethName=%s, netnsPath=%s, deviceNumber=%d, mtu=%d", hostVethName, contVethName, netnsPath, deviceNumber, mtu)
    return setupNS(hostVethName, contVethName, netnsPath, addr, deviceNumber, vpcCIDRs, useExternalSNAT, os.netLink, os.ns, mtu, log, os.procSys)
  }

  func setupNS(hostVethName string, contVethName string, netnsPath string, addr *net.IPNet, deviceNumber int, vpcCIDRs []string, useExternalSNAT bool,
  netLink netlinkwrapper.NetLink, ns nswrapper.NS, mtu int, log logger.Logger, procSys procsyswrapper.ProcSys) error {

        // 调用 setupVeth 函数设置 pod 网络环境
        hostVeth, err := setupVeth(hostVethName, contVethName, netnsPath, addr, netLink, ns, mtu, procSys, log)
        ...
        addrHostAddr := &net.IPNet{
            IP:   addr.IP,
            Mask: net.CIDRMask(32, 32),
		}

        // 在节点上的主路由表添加到 pod 的路由 ip route add $ip dev veth-1 
        route := netlink.Route{
            LinkIndex: hostVeth.Attrs().Index,
            Scope:     netlink.SCOPE_LINK,
            Dst:       addrHostAddr,
		}
   
        // netlink 接口封装了 linux 的 "ip link"、"ip route"、 "ip rule"等命令
        if err := netLink.RouteReplace(&route); err != nil {
            return errors.Wrapf(err, "setupNS: unable to add or replace route entry for %s", route.Dst.IP.String())
        }
    
        // 使用 "ip rule" 命令添加 to-pod 策略路由  512: from all to 10.0.97.30 lookup main 
        err = addContainerRule(netLink, true, addr, mainRouteTable)
        ...
    
       // 通过ENI deviceNumber 判断是否 primary ENI, 0表示 Primary ENI
       // 如果 ENI 不是 primary ENI,则添加流量从 pod 出来的策略路由 
       //  1536: from 10.0.97.30 lookup eni-1 
        if deviceNumber > 0 {
            tableNumber := deviceNumber + 1
            err = addContainerRule(netLink, false, addr, tableNumber)
            ...
        }
        return nil
  }

  ```
  
  最终实现的效果：

  ```bash
  # ip rule list
  0:	from all lookup local
  512:	from all to 10.0.97.30 lookup main <---------- to Pod's traffic
  1025:	not from all to 10.0.0.0/16 lookup main
  1536:	from 10.0.97.30 lookup eni-1 <-------------- from Pod's traffic
  ```
  
### createVethPairContext

  `createVethPairContext` 结构体包含了创建`vethpair`所需参数，`run` 方法其实是`setupVeth`函数的具体实现，包含了创建`vethpair`,启用`vethpir`、配置 pod 网关、路由等步骤

  ```go
  func newCreateVethPairContext(contVethName string, hostVethName string, addr *net.IPNet, mtu int) *createVethPairContext {
    return &createVethPairContext{
          contVethName: contVethName,
          hostVethName: hostVethName,
          addr:         addr,
          netLink:      netlinkwrapper.NewNetLink(),
          ip:           ipwrapper.NewIP(),
          mtu:          mtu,
        }
  }

  func (createVethContext *createVethPairContext) run(hostNS ns.NetNS) error {
    veth := &netlink.Veth{
            LinkAttrs: netlink.LinkAttrs{
                Name:  createVethContext.contVethName,
                Flags: net.FlagUp,
                MTU:   createVethContext.mtu,
            },
            PeerName: createVethContext.hostVethName,
        }

	// 执行 ip link add 为 pod 创建 vethpair
    if err := createVethContext.netLink.LinkAdd(veth); err != nil {
        return err
    }

    hostVeth, err := createVethContext.netLink.LinkByName(createVethContext.hostVethName)
    ...
	// 执行 ip link set $link up 启用 vethpair 的主机端
    if err = createVethContext.netLink.LinkSetUp(hostVeth); err != nil {
        return errors.Wrapf(err, "setup NS network: failed to set link %q up", createVethContext.hostVethName)
    }

    contVeth, err := createVethContext.netLink.LinkByName(createVethContext.contVethName)
    if err != nil {
        return errors.Wrapf(err, "setup NS network: failed to find link %q", createVethContext.contVethName)
    }

    // 启用 pod 端的 vethpair
    if err = createVethContext.netLink.LinkSetUp(contVeth); err != nil {
        return errors.Wrapf(err, "setup NS network: failed to set link %q up", createVethContext.contVethName)
    }

	// 添加默认网关 169.254.1.1   route add default gw addr
    if err = createVethContext.netLink.RouteReplace(&netlink.Route{
        LinkIndex: contVeth.Attrs().Index,
        Scope:     netlink.SCOPE_LINK,
        Dst:       gwNet,
	}); err != nil {
        return errors.Wrap(err, "setup NS network: failed to add default gateway")
    }

	// 添加默认路由 效果 default via 169.254.1.1 dev eth0
    if err = createVethContext.ip.AddDefaultRoute(gwNet.IP, contVeth); err != nil {
        return errors.Wrap(err, "setup NS network: failed to add default route")
    }
    
	// 给网卡 eth0 添加 ip 地址 "ip addr add $ip dev eth0"
    if err = createVethContext.netLink.AddrAdd(contVeth, &netlink.Addr{IPNet: createVethContext.addr}); err != nil {
        return errors.Wrapf(err, "setup NS network: failed to add IP addr to %q", createVethContext.contVethName)
    }

    // 为默认网关添加 arp 静态条目
    neigh := &netlink.Neigh{
        LinkIndex:    contVeth.Attrs().Index,
        State:        netlink.NUD_PERMANENT,
        IP:           gwNet.IP,
        HardwareAddr: hostVeth.Attrs().HardwareAddr,
    }

    if err = createVethContext.netLink.NeighAdd(neigh); err != nil {
        return errors.Wrap(err, "setup NS network: failed to add static ARP")
    }
    
	// 将 vethpair 的一端移动到主机侧 network namespace 
    if err = createVethContext.netLink.LinkSetNsFd(hostVeth, int(hostNS.Fd())); err != nil {
        return errors.Wrap(err, "setup NS network: failed to move veth to host netns")
    }
    return nil
  }
  ```
  
### TeardownNS

  清理 pod 网络环境:

  ```go
  func (os *linuxNetwork) TeardownNS(addr *net.IPNet, deviceNumber int, log logger.Logger) error {
	log.Debugf("TeardownNS: addr %s, deviceNumber %d", addr.String(), deviceNumber)
	return tearDownNS(addr, deviceNumber, os.netLink, log)
  }

  func tearDownNS(addr *net.IPNet, deviceNumber int, netLink netlinkwrapper.NetLink, log logger.Logger) error {
	  ...
      // 删除 to-pod 方向的策略路由 执行 "ip rule del"
      toContainerRule := netLink.NewRule()
      toContainerRule.Dst = addr
      toContainerRule.Priority = toContainerRulePriority
      err := netLink.RuleDel(toContainerRule)
      ...
      // 判断 ENI 是否为 Primary ENI,如果是非 Primary,则同时删除 from-pod 的策略路由
      if deviceNumber > 0 {
      err := deleteRuleListBySrc(*addr)
      ...
      }
      addrHostAddr := &net.IPNet{
          IP:   addr.IP,
          Mask: net.CIDRMask(32, 32)
	  }
      ...
      return nil
  }

  ```
  
## IPAMD

`IPAMD`是本地 ip 地址池管理进程，以`daemonset`的方式运行在每个 worker 节点上,维护着节点上所有可用 ip 地址。

!!! question "疑问"

    那么,问题来了,ip 地址池中的数据是从哪里来的呢？

  
