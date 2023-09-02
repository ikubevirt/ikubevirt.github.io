
Kube-OVN 已经支持了 VPC 和 VPC 网关的实现，具体配置可以参考 [VPC 配置](./vpc.md)。

由于 VPC 网关的使用比较复杂，基于 VPC 网关的实现做了简化，支持在默认 VPC 下创建 LoadBalancer 类型的 Service，实现通过 LoadBalancerIP 来访问默认 VPC 下的 Service。

首先确认环境上满足以下条件：

1. 安装了 multus-cni 和 macvlan cni。
2. LoadBalancer Service 的支持，是对 VPC 网关代码进行简化实现的，仍然使用 `vpc-nat-gw` 的镜像，依赖 `macvlan` 提供多网卡功能支持。
3. 目前只支持在默认 VPC 配置，自定义 VPC 下的 LoadBalancer 支持可以参考 VPC 的文档 [VPC 配置](./vpc.md)。

## 默认 VPC LoadBalancer Service 配置步骤

### 开启特性开关

修改 `kube-system` namespace 下的 deployment `kube-ovn-controller`，在 `args` 中增加参数 `--enable-lb-svc=true`，开启功能开关，该参数默认为 `false`。

```yaml
containers:
- args:
  - /kube-ovn/start-controller.sh
  - --default-cidr=10.16.0.0/16
  - --default-gateway=10.16.0.1
  - --default-gateway-check=true
  - --enable-lb-svc=true                  // 参数设置为 true
```

### 创建 NetworkAttachmentDefinition CRD 资源

参考以下 yaml，创建 `net-attach-def` 资源:

```yaml linenums="1"
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: lb-svc-attachment
  namespace: kube-system
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth0",                         //物理网卡，根据实际情况配置
      "mode": "bridge"
    }'
```

默认情况下，通过物理网卡 `eth0` 来实现多网卡功能，如果需要使用其他物理网卡，可以通过修改 `master` 取值，指定使用的物理网卡名称。

### 创建 Subnet

创建的 Subnet，用于给 LoadBalancer Service 分配 LoadBalancerIP，该地址正常情况下在集群外应该可以访问到。可以配置 Underlay Subnet 用于地址分配。

参考以下 yaml，创建新子网：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: attach-subnet
spec:
  protocol: IPv4
  provider: lb-svc-attachment.kube-system    # provider 格式固定，由上一步创建的 net-attach-def 资源的 Name.Namespace 组成
  cidrBlock: 172.18.0.0/16
  gateway: 172.18.0.1
  excludeIps:
  - 172.18.0.0..172.18.0.10
```

`Subnet` 中 `provider` 参数以 `ovn` 或者以 `.ovn` 为后缀结束，表示该子网是由 Kube-OVN 管理使用，需要对应创建 `logical switch` 记录。

provider 非 ovn 或者非 `.ovn` 为后缀结束，则 Kube-OVN 只提供 IPAM 功能，记录 IP 地址分配情况，不对子网做业务逻辑处理。

### 创建 LoadBalancer Service

参考以下 yaml，创建 LoadBalancer Service：

```yaml linenums="1"
apiVersion: v1
kind: Service
metadata:
  annotations:
    lb-svc-attachment.kube-system.kubernetes.io/logical_switch: attach-subnet   #可选
    ovn.kubernetes.io/attachmentprovider: lb-svc-attachment.kube-system          #必须
  labels:
    app: dynamic
  name: test-service
  namespace: default
spec:
  loadBalancerIP: 172.18.0.18                                                   #可选
  ports:
    - name: test
      protocol: TCP
      port: 80
      targetPort: 80
  selector:
    app: dynamic
  sessionAffinity: None
  type: LoadBalancer
```

在 yaml 中，`annotation ovn.kubernetes.io/attachmentprovider` 为必填项，取值由第一步创建的 `net-attach-def` 资源的 Name.Namespace 组成。该 `annotation` 用于在创建 Pod 时，查找 `net-attach-def` 资源。

可以通过 `annotation` 指定多网卡地址分配使用的子网。`annotation key` 格式为 `net-attach-def` 资源的 `Name.Namespace.kubernetes.io/logical_switch`。该配置为可选选项，在没有指定 LoadBalancerIP 地址的情况下，将从该子网动态分配地址，填充到 LoadBalancerIP 字段。

如果需要静态配置 LoadBalancerIP 地址，可以配置 `spec.loadBalancerIP` 字段，该地址需要在指定子网的地址范围内。

在执行 yaml 创建 Service 后，在 Service 同 Namespace 下，可以看到 Pod 启动信息：

```bash
$ kubectl get pod
NAME                                      READY   STATUS    RESTARTS   AGE
lb-svc-test-service-6869d98dd8-cjvll      1/1     Running   0          107m
$ kubectl get svc
NAME              TYPE           CLUSTER-IP       EXTERNAL-IP   PORT(S)        AGE
test-service      LoadBalancer   10.109.201.193   172.18.0.18   80:30056/TCP   107m
```

指定 `service.spec.loadBalancerIP` 参数时，最终将该参数赋值给 `service external-ip` 字段。不指定的情况下，该参数为随机分配值。

查看测试 Pod 的 yaml 输出，存在多网卡分配的地址信息：

//// collapse-code
```bash
$ kubectl get pod -o yaml lb-svc-test-service-6869d98dd8-cjvll
apiVersion: v1
kind: Pod
metadata:
  annotations:
    k8s.v1.cni.cncf.io/network-status: |-
      [{
          "name": "kube-ovn",
          "ips": [
              "10.16.0.2"
          ],
          "default": true,
          "dns": {}
      },{
          "name": "default/test-service",
          "interface": "net1",
          "mac": "ba:85:f7:02:9f:42",
          "dns": {}
      }]
    k8s.v1.cni.cncf.io/networks: default/test-service
    k8s.v1.cni.cncf.io/networks-status: |-
      [{
          "name": "kube-ovn",
          "ips": [
              "10.16.0.2"
          ],
          "default": true,
          "dns": {}
      },{
          "name": "default/test-service",
          "interface": "net1",
          "mac": "ba:85:f7:02:9f:42",
          "dns": {}
      }]
    ovn.kubernetes.io/allocated: "true"
    ovn.kubernetes.io/cidr: 10.16.0.0/16
    ovn.kubernetes.io/gateway: 10.16.0.1
    ovn.kubernetes.io/ip_address: 10.16.0.2
    ovn.kubernetes.io/logical_router: ovn-cluster
    ovn.kubernetes.io/logical_switch: ovn-default
    ovn.kubernetes.io/mac_address: 00:00:00:45:F4:29
    ovn.kubernetes.io/pod_nic_type: veth-pair
    ovn.kubernetes.io/routed: "true"
    test-service.default.kubernetes.io/allocated: "true"
    test-service.default.kubernetes.io/cidr: 172.18.0.0/16
    test-service.default.kubernetes.io/gateway: 172.18.0.1
    test-service.default.kubernetes.io/ip_address: 172.18.0.18
    test-service.default.kubernetes.io/logical_switch: attach-subnet
    test-service.default.kubernetes.io/mac_address: 00:00:00:AF:AA:BF
    test-service.default.kubernetes.io/pod_nic_type: veth-pair
```
////

查看 Service 的信息：

//// collapse-code
```bash
# kubectl get svc -o yaml test-service
apiVersion: v1
kind: Service
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"v1","kind":"Service","metadata":{"annotations":{"test-service.default.kubernetes.io/logical_switch":"attach-subnet"},"labels":{"app":"dynamic"},"name":"test-service","namespace":"default"},"spec":{"ports":[{"name":"test","port":80,"protocol":"TCP","targetPort":80}],"selector":{"app":"dynamic"},"sessionAffinity":"None","type":"LoadBalancer"}}
    ovn.kubernetes.io/vpc: ovn-cluster
    test-service.default.kubernetes.io/logical_switch: attach-subnet
  creationTimestamp: "2022-06-15T09:01:58Z"
  labels:
    app: dynamic
  name: test-service
  namespace: default
  resourceVersion: "38485"
  uid: 161edee1-7f6e-40f5-9e09-5a52c44267d0
spec:
  allocateLoadBalancerNodePorts: true
  clusterIP: 10.109.201.193
  clusterIPs:
  - 10.109.201.193
  externalTrafficPolicy: Cluster
  internalTrafficPolicy: Cluster
  ipFamilies:
  - IPv4
  ipFamilyPolicy: SingleStack
  ports:
  - name: test
    nodePort: 30056
    port: 80
    protocol: TCP
    targetPort: 80
  selector:
    app: dynamic
  sessionAffinity: None
  type: LoadBalancer
status:
  loadBalancer:
    ingress:
    - ip: 172.18.0.18
```
////

## 测试 LoadBalancerIP访问

参考以下 yaml, 创建测试 Pod，作为 Service 的 Endpoints 提供服务:

```yaml linenums="1"
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: dynamic
  name: dynamic
  namespace: default
spec:
  replicas: 2
  selector:
    matchLabels:
      app: dynamic
  strategy:
    rollingUpdate:
      maxSurge: 25%
      maxUnavailable: 25%
    type: RollingUpdate
  template:
    metadata:
      creationTimestamp: null
      labels:
        app: dynamic
    spec:
      containers:
      - image: docker.io/library/nginx:alpine
        imagePullPolicy: IfNotPresent
        name: nginx
      dnsPolicy: ClusterFirst
      restartPolicy: Always
```

正常情况下，提供的子网地址，在集群外应该可以访问到。为了简单验证，在集群内访问 Service 的 `LoadBalancerIP:Port`，查看是否正常访问成功。

```html
$ curl 172.18.0.11:80
<html>
<head>
        <title>Hello World!</title>
        <link href='//fonts.googleapis.com/css?family=Open+Sans:400,700' rel='stylesheet' type='text/css'>
        <style>
        body {
                background-color: white;
                text-align: center;
                padding: 50px;
                font-family: "Open Sans","Helvetica Neue",Helvetica,Arial,sans-serif;
        }
        #logo {
                margin-bottom: 40px;
        }
        </style>
</head>
<body>
                <h1>Hello World!</h1>
                                <h3>Links found</h3>
        <h3>I am on  dynamic-7d8d7874f5-hsgc4</h3>
        <h3>Cookie                  =</h3>
                                        <b>KUBERNETES</b> listening in 443 available at tcp://10.96.0.1:443<br />
                                                <h3>my name is hanhouchao!</h3>
                        <h3> RequestURI='/'</h3>
</body>
</html>
```

进入 Service 创建的 Pod，查看网络的信息:

//// collapse-code
```bash
$ ip a
4: net1@if62: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default
    link/ether ba:85:f7:02:9f:42 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.18.0.18/16 scope global net1
       valid_lft forever preferred_lft forever
    inet6 fe80::b885:f7ff:fe02:9f42/64 scope link
       valid_lft forever preferred_lft forever
36: eth0@if37: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UP group default
    link/ether 00:00:00:45:f4:29 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 10.16.0.2/16 brd 10.16.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fe45:f429/64 scope link
       valid_lft forever preferred_lft forever

$ ip rule
0: from all lookup local
32764: from all iif eth0 lookup 100
32765: from all iif net1 lookup 100
32766: from all lookup main
32767: from all lookup default

$ ip route show table 100
default via 172.18.0.1 dev net1
10.109.201.193 via 10.16.0.1 dev eth0
172.18.0.0/16 dev net1 scope link

$ iptables -t nat -L -n -v
Chain PREROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 DNAT       tcp  --  *      *       0.0.0.0/0            172.18.0.18          tcp dpt:80 to:10.109.201.193:80

Chain INPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain OUTPUT (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination

Chain POSTROUTING (policy ACCEPT 0 packets, 0 bytes)
 pkts bytes target     prot opt in     out     source               destination
    0     0 MASQUERADE  all  --  *      *       0.0.0.0/0            10.109.201.193
```
////