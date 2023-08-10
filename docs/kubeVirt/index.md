# 快速了解 kubeVirt

## 研发背景

随着云时代的到来，各大企业纷纷将以往的传统业务转移至K8s集群通过容器化将业务逻辑跑起来，但同时背后的支持依然是靠着`Openstack`主打虚拟化，而近年`OpenStack`
的活跃度日趋下降，这也给各企业在虚拟机运行业务带来诸多不稳定性。

于是，后Kubernetes时代的虚拟机管理技术`kubeVirt`便逐渐崛起。`kubeVirt`是 Red Hat 开源的以容器方式运行虚拟机的项目，是基于kubernetes运行，利用k8s CRD为增加资源类型`VirtualMachineInstance（VMI）`，使用CRD的方式是由于`kubeVirt`对虚拟机的管理不局限于`pod`管理接口。通过CRD机制，`kubeVirt`可以自定义额外的操作，来调整常规容器中不可用的行为。`kubeVirt`可以使用容器的`image registry`去创建虚拟机并提供VM生命周期管理。

## kubeVirt的架构

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/kubeVirt-infra.png)
