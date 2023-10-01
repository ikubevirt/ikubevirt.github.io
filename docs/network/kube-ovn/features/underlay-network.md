默认情况下 Kube-OVN 的默认子网使用 Geneve 对跨主机流量进行封装，在基础设施之上抽象出一层虚拟的 Overlay 网络。

对于希望容器网络直接使用物理网络地址段情况，可以将 Kube-OVN 的默认子网工作在 Underlay 模式，可以直接给容器分配物理网络中的地址资源，达到更好的性能以及和物理网络的连通性。

![](../../../assets/images/vlan-topology.png){ loading=lazy }

## 功能限制

由于该模式下容器网络直接使用物理网络进行二层包转发，Overlay 模式下的 SNAT/EIP， 分布式网关/集中式网关等 L3 功能无法使用，VPC 级别的隔离也无法对 Underlay 子网生效。

## 和 Macvlan 相比较

Kube-OVN 的 Underlay 模式和 Macvlan 工作模式十分类似，在功能和性能上主要有以下几个区别：

1. 由于 Macvlan 的内核路径更短，并且不需要 OVS 对数据包进行处理，Macvlan 在吞吐量和延迟性能指标上表现会更好。
2. Kube-OVN 通过流表提供了 `arp-proxy` 功能，可以缓解大规模网络下的 arp 广播风暴风险。
3. 由于 Macvlan 工作在内核底层，会绕过宿主机的 netfilter，Service 和 NetworkPolicy 功能需要额外开发。Kube-OVN 通过 OVS 流表提供了 Service 和 NetworkPolicy 的能力。
4. Kube-OVN 的 Underlay 模式相比 Macvlan 额外提供了地址管理，固定 IP 和 QoS 等功能。

## 环境要求

在 Underlay 模式下，OVS 将会桥接一个节点网卡到 OVS 网桥，并将数据包直接通过该节点网卡对外发送，L2/L3 层面的转发能力需要依赖底层网络设备。 需要预先在底层网络设备配置对应的网关、Vlan 和安全策略等配置。

1. 对于 OpenStack 的 VM 环境，需要将对应网络端口的 `PortSecurity` 关闭。
2. 对于 VMware 的 vSwitch 网络，需要将 MAC Address Changes, Forged Transmits 和 Promiscuous Mode Operation 设置为 allow。
3. 对于 Hyper-V 虚拟化，需要开启虚拟机网卡高级功能中的 MAC Address Spoofing。
4. 公有云，例如 AWS、GCE、阿里云等由于不支持用户自定义 Mac 无法支持 Underlay 模式网络，在这种场景下如果想使用 Underlay 推荐使用对应公有云厂商提供的 VPC-CNI。
5. 桥接网卡不能为 Linux Bridge。

对于管理网和容器网使用同一个网卡的情况下，Kube-OVN 会将网卡的 Mac 地址、IP 地址、路由以及 MTU 将转移或复制至对应的 OVS Bridge， 以支持单网卡部署 Underlay 网络。OVS Bridge 名称格式为 `br-PROVIDER_NAME`，`PROVIDER_NAME` 为 Provider 网络名称（默认为 provider）。

## 部署时指定网络模式

该部署模式将默认子网设置为 Underlay 模式，所有未指定子网的 Pod 均会默认运行在 Underlay 网络中。

### 下载安装脚本

```bash
wget https://raw.githubusercontent.com/kubeovn/kube-ovn/release-1.12/dist/images/install.sh
```

### 修改脚本中相应配置

```bash
ENABLE_ARP_DETECT_IP_CONFLICT # 如有需要，可以选择关闭 vlan 网络 arp 冲突检测
NETWORK_TYPE                  # 设置为 vlan
VLAN_INTERFACE_NAME           # 设置为宿主机上承担容器流量的网卡，例如 eth1
VLAN_ID                       # 交换机所接受的 VLAN Tag，若设置为 0 则不做 VLAN 封装
POD_CIDR                      # 设置为物理网络 CIDR， 例如 192.168.1.0/24
POD_GATEWAY                   # 设置为物理网络网关，例如 192.168.1.1
EXCLUDE_IPS                   # 排除范围，避免容器网段和物理网络已用 IP 冲突，例如 192.168.1.1..192.168.1.100
ENABLE_LB                     # 如果 Underlay 子网需要使用 Service 需要设置为 true 
EXCHANGE_LINK_NAME            # 是否交换默认 provider-network 下 OVS 网桥和桥接网卡的名字，默认为 false
LS_DNAT_MOD_DL_DST            # DNAT 时是否对 MAC 地址进行转换，可加速 Service 的访问，默认为 true
```

### 运行安装脚本

```bash
bash install.sh
```

## 通过 CRD 动态创建 Underlay 网络

该方式可在安装后动态的创建某个 Underlay 子网供 Pod 使用。需要配置 `ProviderNetwork`，`Vlan` 和 `Subnet` 三种自定义资源。

### 创建 ProviderNetwork

`ProviderNetwork` 提供了主机网卡到物理网络映射的抽象，将同属一个网络的网卡进行统一管理， 并解决在复杂环境下同机器多网卡、网卡名不一致、对应 Underlay 网络不一致等情况下的配置问题。

创建如下 `ProviderNetwork` 并应用:

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: ProviderNetwork
metadata:
  name: net1
spec:
  defaultInterface: eth1
  customInterfaces:
    - interface: eth2
      nodes:
        - node1
  excludeNodes:
    - node2
```

!!! warning "注意"

    `ProviderNetwork` 资源名称的长度不得超过 12。

| 字段名称         | 用途描述                                                                                                                       | 备注                       |
|:-------------|:---------------------------------------------------------------------------------------------------------------------------|:-------------------------|
| `defaultInterface`     | `ProviderNetwork` 创建成功后，各节点（除 `excludeNodes` 外）中会创建名为 `br-net1`（格式为 `br-NAME`）的 OVS 网桥，并将指定的节点网卡桥接至此网桥。                              | 为默认使用的节点网卡名称                       |
| `customInterfaces`        | 可针对特定节点指定需要使用的网卡。	 | 可选项| 
| `excludeNodes` | 用于指定不桥接网卡的节点。该列表中的节点会被添加 `net1.provider-network.ovn.kubernetes.io/exclude=true` 标签。                       | 可选项                       |

其它节点会被添加如下标签:

| Key                | Value   | 描述                                    |
|:-------------------|:--------|:--------------------------------------|
| `net1.provider-network.ovn.kubernetes.io/ready` | `true`  | 节点中的桥接工作已完成，`ProviderNetwork` 在节点中可用  |
| `net1.provider-network.ovn.kubernetes.io/interface` | `eth1`	 | 节点中被桥接的网卡的名称                          | 
| `net1.provider-network.ovn.kubernetes.io/mtu`     | 1500    | 节点中被桥接的网卡的 MTU                        |

!!! warning "注意"

    如果节点网卡上已经配置了 IP，则 IP 地址和网卡上的路由会被转移至对应的 OVS 网桥。

### 创建 VLAN

`Vlan` 提供了将 Vlan Tag 和 `ProviderNetwork` 进行绑定的能力。

创建如下 VLAN 并应用：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vlan
metadata:
  name: vlan1
spec:
  id: 0
  provider: net1
```

| 字段名称           | 用途描述                                                                                                                       |
|:---------------|:---------------------------------------------------------------------------------------------------------------------------|
| `id`           | 为 VLAN ID/Tag，Kube-OVN 会对对该 Vlan 下的流量增加 `Vlan` 标签，为 0 时不增加任何标签。                             |
| `provider`     | 为需要使用的 `ProviderNetwork` 资源的名称。多个 VLAN 可以引用同一个 `ProviderNetwork`。	 |

### 创建子网

将 `Vlan` 和一个子网绑定，如下所示：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: subnet1
spec:
  protocol: IPv4
  cidrBlock: 172.17.0.0/16
  gateway: 172.17.0.1
  vlan: vlan1
```

将 `vlan` 的值指定为需要使用的 VLAN 名称即可。多个 `Subnet` 可以引用同一个 VLAN。

## 容器创建

可按正常容器创建方式进行创建，查看容器 IP 是否在规定范围内，以及容器是否可以和物理网络互通。

如有固定 IP 需求，可参考[静态IP地址](./fixed-ip-address.md)。

## 使用逻辑网关

对于物理网络不存在网关的情况，Kube-OVN 支持在 Underlay 模式的子网中配置使用逻辑网关。 若要使用此功能，设置子网的 `spec.logicalGateway` 为 `true` 即可：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: subnet1
spec:
  protocol: IPv4
  cidrBlock: 172.17.0.0/16
  gateway: 172.17.0.1
  vlan: vlan1
  logicalGateway: true
```

开启此功能后，Pod 不使用外部网关，而是使用 Kube-OVN 创建的逻辑路由器（Logical Router）对于跨网段通信进行转发。

## Underlay 和 Overlay 网络互通

如果一个集群同时存在 Underlay 和 Overlay 子网，默认情况下 Overlay 子网下的 Pod 可以通过网关以 NAT 的方式访问 Underlay 子网下的 Pod IP。 在 Underlay 子网的 Pod 看来 Overlay 子网的地址是一个外部的地址，需要通过底层物理设备去转发，但底层物理设备并不清楚 Overlay 子网的地址无法进行转发。 因此 Underlay 子网下的 Pod 无法通过 Pod IP 直接访问 Overlay 子网的 Pod。

如果需要 Underlay 和 Overlay 互通需要将子网的 `u2oInterconnection` 设置为 `true`，在这个情况下 Kube-OVN 会额外使用一个 Underlay IP 将 Underlay 子网 和 ovn-cluster 逻辑路由器连接，并设置对应的路由规则实现互通。 和逻辑网关不同，该方案只会连接 Kube-OVN 内部的 Underlay 和 Overlay 子网，其他访问外网的流量还是会通过物理网关进行转发。

### 指定逻辑网关IP

开启互通功能后，会随机从 subnet 内的取一个 IP 作为逻辑网关，如果需要指定 Underlay Subnet 的逻辑网关可以指定字段 `u2oInterconnectionIP`。

### 指定 Underlay Subnet 连接的自定义 VPC

默认情况下 Underlay Subnet 会和默认 VPC 上的 Overlay Subnet 互通，如果要指定和某个 VPC 互通，在 `u2oInterconnection` 设置为 `true` 后，指定 `subnet.spec.vpc` 字段为该 VPC 名字即可。

## 注意事项

如果您使用的节点网卡上配置有 IP 地址，且操作系统通过 Netplan 配置网络（如 Ubuntu），建议您将 Netplan 的 `renderer` 设置为 `NetworkManager`，并为节点网卡配置静态 IP 地址（关闭 DHCP）：

```yaml
network:
  renderer: NetworkManager
  ethernets:
    eth0:
      dhcp4: no
      addresses:
        - 172.16.143.129/24
  version: 2
```

如果您要修改网卡的 IP 或路由配置，需要在修改 `netplan` 配置后执行以下命令：

```bash
netplan generate

nmcli connection reload netplan-eth0
nmcli device set eth0 managed yes
```

执行以上命令后，Kube-OVN 会将网卡上的 IP 及路由重新转移至 OVS 网桥。

如果您使用的操作系统通过 NetworkManager 管理网络（如 CentOS），在修改网卡配置后需要执行以下命令：

```bash
nmcli connection reload eth0
nmcli device set eth0 managed yes
nmcli -t -f GENERAL.STATE device show eth0 | grep -qw unmanaged || nmcli device reapply eth0
```

!!! warning "注意"

    节点网卡配置的动态修改仅支持 IP 和路由，不支持 MAC 地址的修改。

