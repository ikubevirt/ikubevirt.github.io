# kubeVirt概览

## 研发背景

随着云时代的到来，各大企业纷纷将以往的传统业务转移至K8s集群通过容器化将业务逻辑跑起来，但同时背后的支持依然是靠着Openstack主打虚拟化，而近年OpenStack
的活跃度日趋下降，这也给各企业在虚拟机运行业务带来诸多不稳定性。

于是，后Kubernetes时代的虚拟机管理技术kubeVirt便逐渐崛起。kubeVirt是 Red Hat 开源的以容器方式运行虚拟机的项目，是基于kubernetes运行，利用k8s CRD为增加资源类型`VirtualMachineInstance（VMI）`，使用CRD的方式是由于kubeVirt对虚拟机的管理不局限于pod管理接口。通过CRD机制，kubeVirt可以自定义额外的操作，来调整常规容器中不可用的行为。kubeVirt可以使用容器的image registry去创建虚拟机并提供VM生命周期管理。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 快速了解

[cards cols="3" image-tags(./docs/assets/data/kubeVirt/kubeVirt.yaml)]

### 资源列表

kubeVirt资源分为以下几大类：

[cards cols="3" image-tags(./docs/assets/data/kubeVirt/vmi.yaml)]

### 特性功能

kubeVirt具备以下特性功能：

[cards cols="3" image-tags(./docs/assets/data/kubeVirt/features.yaml)]

### 源码分析

kubeVirt源码分析细分以下组件：

[cards cols="3" image-tags(./docs/assets/data/kubeVirt/virt-components.yaml)]
