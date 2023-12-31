# 网络概览

## 研发背景

随着云原生技术从应用侧向数据中心和基础设施下沉，越来越多的企业开始使用 Kubernetes 和 KubeVirt 来运行虚拟化工作负载，实现在统一的控制平面同时管理虚拟机和容器。然而一方面虚拟机的使用场景和习惯都和容器有着显著的差异，另一方面新兴的容器网络并没有专门对虚拟化场景进行设计，功能的完备性和性能都与传统虚拟化网络存在较大差距。网络问题成为了云原生虚拟化的瓶颈所在。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 网络开发策略

Kube-OVN 由于使用了在传统虚拟化网络中得到广泛使用的 OVN/OVS，在开源后得到了很多 KubeVirt 用户的关注，一部分前沿的 KubeVirt 用户根据自己的使用场景进一步完善了 Kube-OVN 的网络能力。

[cards cols="3" image-tags(./docs/assets/data/network/multi-tenancy.yaml)]
