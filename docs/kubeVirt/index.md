# 快速了解 kubeVirt

## 研发背景

随着云时代的到来，各大企业纷纷将以往的传统业务转移至K8s集群通过容器化将业务逻辑跑起来，但同时背后的支持依然是靠着`Openstack`主打虚拟化，而近年`OpenStack`
的活跃度日趋下降，这也给各企业在虚拟机运行业务带来诸多不稳定性。

于是，后Kubernetes时代的虚拟机管理技术`kubeVirt`便逐渐崛起。`kubeVirt`是 Red Hat 开源的以容器方式运行虚拟机的项目，是基于kubernetes运行，利用k8s CRD为增加资源类型`VirtualMachineInstance（VMI）`，使用CRD的方式是由于`kubeVirt`对虚拟机的管理不局限于`pod`管理接口。通过CRD机制，`kubeVirt`可以自定义额外的操作，来调整常规容器中不可用的行为。`kubeVirt`可以使用容器的`image registry`去创建虚拟机并提供VM生命周期管理。

## kubeVirt的架构

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/kubeVirt-infra.png)

`kubeVirt`以CRD的形式将VM管理接口接入到kubernetes中，通过一个`pod`去使用`libvirtd`管理VM的方式，实现`pod`与VM的一一对应，做到如同容器一般去管理虚拟机，并且做到与容器一样的资源管理、调度规划、这一层整体与企业IAAS关系不大，也方便企业的接入，统一纳管。

- `virt-api` ：`kubeVirt`是以CRD形式去管理VM Pod，`virt-api`就是所有虚拟化操作的入口，这里面包括常规的CDR更新验证、以及`console、vm start、stop`等操作。
- `virt-controller` ：`virt-controller`会根据`vmi CRD`，生成对应的`virt-launcher Pod`，并且维护CRD的状态。与kubernetes api-server通讯监控VMI资源的创建删除等状态。
- `virt-handler` ：`virt-handler`会以`deamonset`形式部署在每一个节点上，负责监控节点上的每个虚拟机实例状态变化，一旦检测到状态的变化，会进行响应并且确保相应的操作能够达到所需（理想）的状态。`virt-handler`还会保持集群级别`VMI Spec`与相应`libvirt`域之间的同步；报告`libvirt`域状态和集群Spec的变化；调用以节点为中心的插件以满足`VMI Spec`定义的网络和存储要求。
- `virt-launcher` ：每个`virt-launcher pod`对应着一个`VMI`，kubelet只负责`virt-launcher pod`运行状态，不会去关心`VMI`创建情况。`virt-handler`会根据CRD参数配置去通知`virt-launcher`去使用本地的`libvirtd`实例来启动`VMI`，随着`Pod`的生命周期结束，`virt-lanuncher`也会去通知`VMI`去执行终止操作；其次在每个`virt-launcher pod`中还对应着一个`libvirtd`，`virt-launcher`通过`libvirtd`去管理VM的生命周期，这样做到去中心化，不再是以前的虚拟机那套做法，一个`libvirtd`去管理多个VM。
- `virtctl` ：`virtctl`是`kubeVirt`自带类似`kubectl`的命令行工具，它是越过`virt-launcher pod`这一层去直接管理VM虚拟机，可以控制VM的`start、stop、restart`。

## kubeVirt管理虚拟机机制

### 虚拟机镜像制作与管理

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/virt-image-construction-flow.png)

虚拟机镜像采用容器镜像形式存放在镜像仓库中。创建原理如上图所示，将Linux发行版本的镜像文件存放到基础镜像的`/disk`目录内，镜像格式支持`qcow2、raw、img`。通过`Dockerfile`文件将虚拟机镜像制作成容器镜像，然后分别推送到不同的`registry`镜像仓库中。客户在创建虚拟机时，根据配置的优先级策略拉取`registry`中的虚拟机容器镜像，如果其中一台`registry`故障，会另一台健康的`registry`拉取镜像。

### 虚拟机生命周期管理

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/virt-lifecycle.png)

`KubeVirt`虚拟机生命周期管理主要分为以下几种状态：

- 虚拟机创建：创建VM对象，并同步创建`DataVolume/PVC`，从`Harbor`镜像仓库中拉取系统模板镜像拷贝至目标调度主机，通过调度、IP分配后生成`VMI`以及管理VM的`Launcher Pod`从而启动供业务使用的VM。
- 虚拟机运行：运行状态下的VM 可以进行控制台管理、快照备份/恢复、热迁移、磁盘热挂载/热删除等操作，此外还可以进行重启、下电操作，提高VM安全的同时解决业务存储空间需求和主机异常`Hung`等问题。
- 虚拟机关机：关机状态下的VM可以进行快照备份/恢复、冷迁移、`CPU/MEM`规格变更、重命名以及磁盘挂载等操作，同时可通过重新启动进入运行状态，也可删除进行资源回收。
- 虚拟机删除：对虚机资源进行回收，但VM所属的磁盘数据仍将保留、具备恢复条件。