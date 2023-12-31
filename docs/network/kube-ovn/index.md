# Kube-OVN 概览

Kube-OVN 是一款 CNCF 旗下的企业级云原生网络编排系统，将 SDN 的能力和云原生结合， 提供丰富的功能，极致的性能以及良好的可运维性。

## 技术架构

总体来看，Kube-OVN 作为 Kubernetes 和 OVN 之间的一个桥梁，将成熟的 SDN 和云原生相结合。 这意味着 Kube-OVN 不仅通过 OVN 实现了 Kubernetes 下的网络规范，例如 CNI，Service 和 Networkpolicy，还将大量的 SDN 领域能力带入云原生，例如逻辑交换机，逻辑路由器，VPC，网关，QoS，ACL 和流量镜像。

同时 Kube-OVN 还保持了良好的开放性可以和诸多技术方案集成，例如 Cilium，Submariner，Prometheus，KubeVirt 等等。

[cards cols="3" image-tags(./docs/assets/data/network/ovn-architecture.yaml)]

## 丰富的功能

如果你怀念 SDN 领域丰富的网络能力却在云原生领域苦苦追寻而不得，那么 Kube-OVN 将是你的最佳选择。

借助 OVS/OVN 在 SDN 领域成熟的能力，Kube-OVN 将网络虚拟化的丰富功能带入云原生领域。目前已支持[子网管理](./features/subnet.md)， [静态 IP 分配](./features/fixed-ip-address.md)，[分布式/集中式网关](./features/subnet.md/#overlay)，[Underlay/Overlay 混合网络](./features/underlay-network.md)， [VPC 多租户网络](./features/vpc.md)，[跨集群互联网络](./features/cluster-inter-connection.md)，[QoS 管理](./features/vpc-qos.md)， [多网卡管理](./features/manage-multiple-interface.md)，[ACL 网络控制](./features/subnet.md/#acl)，[自定义VPC负载均衡](./features/customize-vpc-load-balancing.md)，ARM 支持， Windows 支持等诸多功能。

部分特性功能如下:

[cards cols="3" image-tags(./docs/assets/data/network/kube-ovn-features.yaml)]

## 极致的性能

如果你担心容器网络会带来额外的性能损耗，那么来看一下 Kube-OVN 是如何极致的优化性能。

在数据平面，通过一系列对流表和内核的精心优化，并借助 eBPF、DPDK、智能网卡卸载等新兴技术， Kube-OVN 可以在延迟和吞吐量等方面的指标达到近似或超出宿主机网络性能的水平。在控制平面，通过对 OVN 上游流表的裁剪， 各种缓存技术的使用和调优，Kube-OVN 可以支持大规模上千节点和上万 Pod 的集群。

此外 Kube-OVN 还在不断优化 CPU 和内存等资源的使用量，以适应边缘等资源有限场景。

## 良好的可运维性

如果你对容器网络的运维心存忧虑，Kube-OVN 内置了大量的工具来帮助你简化运维操作。

Kube-OVN 提供了一键安装脚本，帮助用户迅速搭建生产就绪的容器网络。同时内置的丰富的监控指标和 Grafana 面板， 可帮助用户建立完善的监控体系。强大的命令行工具可以简化用户的日常运维操作。通过和 Cilium 结合，利用 eBPF 能力用户可以 增强对网络的可观测性。 此外[流量镜像](./devops/remote-port-mirroring.md)的能力可以方便用户自定义流量监控，并和传统的 NPM 系统对接。

[cards cols="3" image-tags(./docs/assets/data/network/ovn-devops.yaml)]