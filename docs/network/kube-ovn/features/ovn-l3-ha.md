
自定义 vpc 基于 ovn snat 后基于 `ecmp` 静态路由哈希到多个 `gw node ovnext0` 网卡出公网

- 支持基于 `bfd`的高可用
- 仅支持 `hash` 负载均衡

``` mermaid
graph LR

pod-->vpc-subnet-->vpc-->snat-->ecmp-->external-subnet-->gw-node1-ovnext0--> node1-external-switch
external-subnet-->gw-node2-ovnext0--> node2-external-switch
external-subnet-->gw-node3-ovnext0--> node3-external-switch
```

该功能的使用方式和[ovn-eip-fip-snat.md]() 基本一致，一致的部分包括 `install.sh` 的部署部分，`provider-network`，`vlan`，`subnet` 的准备部分。

至于不相同的部分，会在以下部分具体阐述，主要包括 `lsp` 类型的 `ovn-eip` 的创建，以及基于 vpc `enable_bfd` 自动维护 `bfd` 以及 `ecmp` 静态路由。

## 部署

准备 [underlay 公网网络](./underlay-network.md), 默认 [vpc 启用 eip_snat](./eip-snat.md)。

### 自定义 vpc 启用 eip snat fip 功能

以上部分和 [ovn-eip-fip-snat.md]() 完全一致，这些功能验证通过后，可以直接基于如下方式，将 vpc 切换到基于 `ecmp` 的 bfd 静态路由，当然也可以切回。

自定义 vpc 使用该功能之前，需要先提供好网关节点，至少需要提供 2 个以上网关节点，注意当前实现 `ovn-eip` 的名字必须和网关节点名保持一致，目前没有做该资源的自动化维护。

```yaml linenums="1" title="gw-node-eip.yaml"
---
kind: OvnEip
apiVersion: kubeovn.io/v1
metadata:
  name: pc-node-1
spec:
  externalSubnet: external204
  type: lsp

---
kind: OvnEip
apiVersion: kubeovn.io/v1
metadata:
  name: pc-node-2
spec:
  externalSubnet: external204
  type: lsp

---
kind: OvnEip
apiVersion: kubeovn.io/v1
metadata:
  name: pc-node-3
spec:
  externalSubnet: external204
  type: lsp
```

由于这个场景目前设计上是供 vpc `ecmp` 出公网使用，所以以上在没有 vpc 启用 `bfd` 的时候，即不存在带有 `enable bfd` 标签的 `lrp` 的 ovn eip 的时候，网关节点不会触发创建网关网卡，也无法成功启动对端 `bfd` 会话的监听。

## 自定义 vpc 启用 ecmp bfd L3 HA 公网功能

```yaml linenums="1" title="01-vpc-ecmp-enable-external-bfd.yml"
---
apiVersion: kubeovn.io/v1
kind: Vpc
metadata:
  name: vpc1
spec:
  namespaces:
  - vpc1
  enableExternal: true
  enableBfd: true # bfd 开关可以随意切换，开表示启用 bfd ecmp 路由
  #enableBfd: false 
---
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: vpc1-subnet1
spec:
  cidrBlock: 192.168.0.0/24
  default: false
  disableGatewayCheck: false
  disableInterConnection: true
  enableEcmp: true  # 只需开启 ecmp
  gatewayNode: ""
  gatewayType: distributed
  #gatewayType: centralized
  natOutgoing: false
  private: false
  protocol: IPv4
  provider: ovn
  vpc: vpc1
  namespaces:
  - vpc1
```

!!! warning "注意"

    1. 自定义 vpc 下的 `ecmp` 只用静态 `ecmp bfd` 路由，vpc `enableBfd` 和 `subnet enableEcmp` 同时开启的情况下才会生效，才会自动管理静态 `ecmp bfd` 路由。
    2. 上述配置关闭的情况下，会自动切回常规默认静态路由。
    3. 默认 vpc 无法使用该功能，仅支持自定义 vpc，默认 vpc 有更复杂的策略路由以及 snat 设计。
    4. 自定义 vpc 的 `subnet` 的 `enableEcmp` 仅使用静态路由，网关类型 `gatewayType` 没有作用。
    5. 当关闭 `EnableExternal` 时，vpc 内无法通外网。
    6. 当开启 `EnableExternal` 时，关闭 `EnableBfd` 时，会基于普通默认路由上外网，不具备高可用。

```bash
# 上述模板应用后 ovn 逻辑层应该可以看到如下资源
# 查看 vpc
# k get vpc
NAME          ENABLEEXTERNAL   ENABLEBFD   STANDBY   SUBNETS                                NAMESPACES
ovn-cluster   true                         true      ["external204","join","ovn-default"]
vpc1          true             true        true      ["vpc1-subnet1"]                       ["vpc1"]

# 默认 vpc 未支持 ENABLEBFD
# 自定义 vpc 已支持且已启用


# 1. 创建了 bfd 会话
# k ko nbctl list bfd
_uuid               : be7df545-2c4c-4751-878f-b3507987f050
detect_mult         : 3
dst_ip              : "10.5.204.121"
external_ids        : {}
logical_port        : vpc1-external204
min_rx              : 100
min_tx              : 100
options             : {}
status              : up

_uuid               : 684c4489-5b59-4693-8d8c-3beab93f8093
detect_mult         : 3
dst_ip              : "10.5.204.109"
external_ids        : {}
logical_port        : vpc1-external204
min_rx              : 100
min_tx              : 100
options             : {}
status              : up

_uuid               : f0f62077-2ae9-4e79-b4f8-a446ec6e784c
detect_mult         : 3
dst_ip              : "10.5.204.108"
external_ids        : {}
logical_port        : vpc1-external204
min_rx              : 100
min_tx              : 100
options             : {}
status              : up

### 注意所有 status 正常都应该是 up 的

# 2. 创建了基于 bfd 的静态路由
# k ko nbctl lr-route-list vpc1
IPv4 Routes
Route Table <main>:
           192.168.0.0/24              10.5.204.108 src-ip ecmp ecmp-symmetric-reply bfd
           192.168.0.0/24              10.5.204.109 src-ip ecmp ecmp-symmetric-reply bfd
           192.168.0.0/24              10.5.204.121 src-ip ecmp ecmp-symmetric-reply bfd

# 3. 静态路由详情
# k ko nbctl find Logical_Router_Static_Route  policy=src-ip options=ecmp_symmetric_reply="true"
_uuid               : 3aacb384-d5ee-4b14-aebf-59e8c11717ba
bfd                 : 684c4489-5b59-4693-8d8c-3beab93f8093
external_ids        : {}
ip_prefix           : "192.168.0.0/24"
nexthop             : "10.5.204.109"
options             : {ecmp_symmetric_reply="true"}
output_port         : []
policy              : src-ip
route_table         : ""

_uuid               : 18bcc585-bc05-430b-925b-ef673c8e1aef
bfd                 : f0f62077-2ae9-4e79-b4f8-a446ec6e784c
external_ids        : {}
ip_prefix           : "192.168.0.0/24"
nexthop             : "10.5.204.108"
options             : {ecmp_symmetric_reply="true"}
output_port         : []
policy              : src-ip
route_table         : ""

_uuid               : 7d0a4e6b-cde0-4110-8176-fbaf19738498
bfd                 : be7df545-2c4c-4751-878f-b3507987f050
external_ids        : {}
ip_prefix           : "192.168.0.0/24"
nexthop             : "10.5.204.121"
options             : {ecmp_symmetric_reply="true"}
output_port         : []
policy              : src-ip
route_table         : ""

```

```bash
# 同时在网关节点都应该具备以下资源

[root@pc-node-1 ~]# ip netns exec ovnext bash ip a
/usr/sbin/ip: /usr/sbin/ip: cannot execute binary file
[root@pc-node-1 ~]#
[root@pc-node-1 ~]# ip netns exec ovnext ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host
       valid_lft forever preferred_lft forever
1541: ovnext0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1400 qdisc noqueue state UNKNOWN group default qlen 1000
    link/ether 00:00:00:ab:bd:87 brd ff:ff:ff:ff:ff:ff
    inet 10.5.204.108/24 brd 10.5.204.255 scope global ovnext0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:feab:bd87/64 scope link
       valid_lft forever preferred_lft forever
[root@pc-node-1 ~]#
[root@pc-node-1 ~]# ip netns exec ovnext route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.5.204.254    0.0.0.0         UG    0      0        0 ovnext0
10.5.204.0      0.0.0.0         255.255.255.0   U     0      0        0 ovnext0

## 注意以上内容和一个 internal port unerlay 公网 pod 内部的 ns 大致是一致的，这里只是在网关节点上单独维护了一个 ns

[root@pc-node-1 ~]# ip netns exec ovnext bfdd-control status
There are 1 sessions:
Session 1
 id=1 local=10.5.204.108 (p) remote=10.5.204.122 state=Up

## 这里即是 lrp bfd 会话的另一端，也是 lrp ecmp 的下一跳的其中一个


[root@pc-node-1 ~]# ip netns exec ovnext ping -c1 223.5.5.5
PING 223.5.5.5 (223.5.5.5) 56(84) bytes of data.
64 bytes from 223.5.5.5: icmp_seq=1 ttl=115 time=21.6 ms

# 到公网没问题
```

可以在某一个网关节点的 `ovnext ns` 内抓到出去的包

```bash
# tcpdump -i ovnext0 host 223.5.5.5 -netvv
dropped privs to tcpdump
tcpdump: listening on ovnext0, link-type EN10MB (Ethernet), capture size 262144 bytes
^C
0 packets captured
0 packets received by filter
0 packets dropped by kernel
[root@pc-node-1 ~]# exit
[root@pc-node-1 ~]# ssh pc-node-2
Last login: Thu Feb 23 09:21:08 2023 from 10.5.32.51
[root@pc-node-2 ~]# ip netns exec ovnext bash
[root@pc-node-2 ~]# tcpdump -i ovnext0 host 223.5.5.5 -netvv
dropped privs to tcpdump
tcpdump: listening on ovnext0, link-type EN10MB (Ethernet), capture size 262144 bytes
^C
0 packets captured
0 packets received by filter
0 packets dropped by kernel
[root@pc-node-2 ~]# exit
[root@pc-node-2 ~]# logout
Connection to pc-node-2 closed.
[root@pc-node-1 ~]# ssh pc-node-3
Last login: Thu Feb 23 08:32:41 2023 from 10.5.32.51
[root@pc-node-3 ~]#  ip netns exec ovnext bash
[root@pc-node-3 ~]# tcpdump -i ovnext0 host 223.5.5.5 -netvv
dropped privs to tcpdump
tcpdump: listening on ovnext0, link-type EN10MB (Ethernet), capture size 262144 bytes
00:00:00:2d:f8:ce > 00:00:00:fd:b2:a4, ethertype IPv4 (0x0800), length 98: (tos 0x0, ttl 63, id 57978, offset 0, flags [DF], proto ICMP (1), length 84)
    10.5.204.102 > 223.5.5.5: ICMP echo request, id 22, seq 71, length 64
00:00:00:fd:b2:a4 > dc:ef:80:5a:44:1a, ethertype IPv4 (0x0800), length 98: (tos 0x0, ttl 62, id 57978, offset 0, flags [DF], proto ICMP (1), length 84)
    10.5.204.102 > 223.5.5.5: ICMP echo request, id 22, seq 71, length 64
^C
2 packets captured
2 packets received by filter
0 packets dropped by kernel
[root@pc-node-3 ~]#

# 可以在该节点 down 掉出去的网卡，然后看 pod 出去的包在网络中断中会出现几个包
# 一般都会看到丢 3 个包

```

## 关闭 bfd 模式

在某些场景下，可能想直接使用（集中式）单个网关直接出公网，这个时候和默认 vpc `enable_eip_snat` 的使用模式是一致的

```yaml linenums="1" title="01-vpc-ecmp-enable-external-bfd.yml"
kind: Vpc
apiVersion: kubeovn.io/v1
metadata:
  name: vpc2
spec:
  namespaces:
  - vpc2
  enableExternal: true
  #enableBfd: true
  enableBfd: false
```

```bash
## 将 bfd 功能直接禁用即可

# k ko nbctl lr-route-list vpc2
IPv4 Routes
Route Table <main>:
                0.0.0.0/0              10.5.204.254 dst-ip

# 应用后路由会切换回正常的默认静态路由
# 同时 nbctl list bfd  可以看到 lrp 关联的 bfd 会话已经移除
# 而且 ovnext ns 中的对端 bfd 会话也自动移除
# 该切换过程保持 vpc subnet 内保持 ping 未看到(秒级)丢包
# 再切换回去 也未看到(秒级)丢包
```