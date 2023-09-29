
Kube-OVN 的组件可以大致分为三类：

- 上游 OVN/OVS 组件。
- 核心控制器和 Agent。
- 监控，运维工具和扩展组件。

![](../../../assets/images/architecture.png){ loading=lazy }


## 上游 OVN/OVS 组件

该类型组件来自 OVN/OVS 社区，并针对 Kube-OVN 的使用场景做了特定修改。 OVN/OVS 本身是一套成熟的管理虚机和容器的 SDN 系统。Kube-OVN 使用 OVN 的北向接口创建和调整虚拟网络，并将其中的网络概念映射到 Kubernetes 之内。

所有 OVN/OVS 相关组件都已打包成对应镜像，并可在 Kubernetes 中运行。

### ovn-central
`ovn-central` Deployment 运行 OVN 的管理平面组件，包括 `ovn-nb`, `ovn-sb`, 和 `ovn-northd`。

`ovn-nb`： 保存虚拟网络配置，并提供 API 进行虚拟网络管理。`kube-ovn-controller` 将会主要和 `ovn-nb` 进行交互配置虚拟网络。
`ovn-sb`： 保存从 `ovn-nb` 的逻辑网络生成的逻辑流表，以及各个节点的实际物理网络状态。
`ovn-northd`：将 `ovn-nb` 的虚拟网络翻译成 `ovn-sb` 中的逻辑流表。

多个 `ovn-central` 实例会通过 Raft 协议同步数据保证高可用。

### ovs-ovn

`ovs-ovn` 以 `DaemonSet` 形式运行在每个节点，在 Pod 内运行了 `openvswitch`, `ovsdb`, 和 `ovn-controller`。这些组件作为 `ovn-central` 的 Agent 将逻辑流表翻译成真实的网络配置。

## 核心控制器和 Agent

该部分为 Kube-OVN 的核心组件，作为 OVN 和 Kubernetes 之间的一个桥梁，将两个系统打通并将网络概念进行相互转换。 大部分的核心功能都在该部分组件中实现。

### kube-ovn-controller

该组件为一个 `Deployment` 执行所有 Kubernetes 内资源到 OVN 资源的翻译工作，其作用相当于整个 Kube-OVN 系统的控制平面。 `kube-ovn-controller` 监听了所有和网络功能相关资源的事件，并根据资源变化情况更新 OVN 内的逻辑网络。主要监听的资源包括： `Pod`，`Service`，`Endpoint`，`Node`，`NetworkPolicy`，`VPC`，`Subnet`，`Vlan`，`ProviderNetwork`。

以 Pod 事件为例， `kube-ovn-controller` 监听到 Pod 创建事件后，通过内置的内存 IPAM 功能分配地址，并调用 `ovn-central` 创建 逻辑端口，静态路由和可能的 ACL 规则。接下来 `kube-ovn-controller` 将分配到的地址，和子网信息例如 CIDR，网关，路由等信息写会到 `Pod` 的 `annotation` 中。该 `annotation` 后续会被 `kube-ovn-cni` 读取用来配置本地网络。

### kube-ovn-cni

该组件为一个 `DaemonSet` 运行在每个节点上，实现 CNI 接口，并操作本地的 OVS 配置单机网络。

该 `DaemonSet` 会复制 kube-ovn 二进制文件到每台机器，作为 `kubelet` 和 `kube-ovn-cni` 之间的交互工具，将相应 CNI 请求 发送给 `kube-ovn-cni` 执行。该二进制文件默认会被复制到 `/opt/cni/bin` 目录下。

`kube-ovn-cni` 会配置具体的网络来执行相应流量操作，主要工作包括：

1. 配置 `ovn-controller` 和 `vswitchd`。
2. 处理 CNI `add/del` 请求：
    - 创建删除 `veth` 并和 OVS 端口绑定。
    - 配置 OVS 端口信息。
    - 更新宿主机的 `iptables/ipset/route` 等规则。
3. 动态更新容器 QoS.
4. 创建并配置 `ovn0` 网卡联通容器网络和主机网络。
5. 配置主机网卡来实现 `Vlan/Underlay/EIP` 等功能。
6. 动态配置集群互联网关。

## 监控，运维工具和扩展组件

该部分组件主要提供监控，诊断，运维操作以及和外部进行对接，对 Kube-OVN 的核心网络能力进行扩展，并简化日常运维操作。

### kube-ovn-speaker

该组件为一个 DaemonSet 运行在特定标签的节点上，对外发布容器网络的路由，使得外部可以直接通过 Pod IP 访问容器。

### kube-ovn-pinger

该组件为一个 DaemonSet 运行在每个节点上收集 OVS 运行信息，节点网络质量，网络延迟等信息，收集的监控指标可参考 Kube-OVN 监控指标。

### kube-ovn-monitor

该组件为一个 Deployment 收集 OVN 的运行信息，收集的监控指标可参考 Kube-OVN 监控指标。

### kubectl-ko

该组件为 kubectl 插件，可以快速运行常见运维操作。