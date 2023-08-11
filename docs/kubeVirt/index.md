# 快速了解 kubeVirt

## 研发背景

随着云时代的到来，各大企业纷纷将以往的传统业务转移至K8s集群通过容器化将业务逻辑跑起来，但同时背后的支持依然是靠着Openstack主打虚拟化，而近年OpenStack
的活跃度日趋下降，这也给各企业在虚拟机运行业务带来诸多不稳定性。

于是，后Kubernetes时代的虚拟机管理技术kubeVirt便逐渐崛起。kubeVirt是 Red Hat 开源的以容器方式运行虚拟机的项目，是基于kubernetes运行，利用k8s CRD为增加资源类型`VirtualMachineInstance（VMI）`，使用CRD的方式是由于kubeVirt对虚拟机的管理不局限于pod管理接口。通过CRD机制，kubeVirt可以自定义额外的操作，来调整常规容器中不可用的行为。kubeVirt可以使用容器的image registry去创建虚拟机并提供VM生命周期管理。

## kubeVirt的架构

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/kubeVirt-infra.png){ loading=lazy }

kubeVirt以CRD的形式将VM管理接口接入到kubernetes中，通过一个pod去使用libvirtd管理VM的方式，实现pod与VM的一一对应，做到如同容器一般去管理虚拟机，并且做到与容器一样的资源管理、调度规划、这一层整体与企业IAAS关系不大，也方便企业的接入，统一纳管。

- `virt-api`: kubeVirt是以CRD形式去管理VM Pod，`virt-api`就是所有虚拟化操作的入口，这里面包括常规的CDR更新验证、以及`console、vm start、stop`等操作。
- `virt-controller`
    - `virt-controller`会根据vmi CRD，生成对应的`virt-launcher` Pod，并且维护CRD的状态。
    - 与kubernetes api-server通讯监控VMI资源的创建删除等状态。
- `virt-handler`
    - `virt-handler`会以daemonset形式部署在每一个节点上，负责监控节点上的每个虚拟机实例状态变化，一旦检测到状态的变化，会进行响应并且确保相应的操作能够达到所需（理想）的状态。
    - `virt-handler`还会保持集群级别`VMI Spec`与相应libvirt域之间的同步；报告`libvirt`域状态和集群Spec的变化；调用以节点为中心的插件以满足VMI Spec定义的网络和存储要求。
- `virt-launcher`
    - 每个`virt-launcher` pod对应着一个VMI，kubelet只负责`virt-launcher` pod运行状态，不会去关心VMI创建情况。
    - `virt-handler`会根据CRD参数配置去通知`virt-launcher`去使用本地的`libvirtd`实例来启动VMI，随着Pod的生命周期结束，`virt-lanuncher`也会去通知VMI去执行终止操作；
    - 其次在每个`virt-launcher` pod中还对应着一个`libvirtd`，`virt-launcher`通过`libvirtd`去管理VM的生命周期，这样做到去中心化，不再是以前的虚拟机那套做法，一个`libvirtd`去管理多个VM。
- `virtctl`: kubeVirt自带类似`kubectl`的命令行工具，它是越过`virt-launcher` pod这一层去直接管理VM虚拟机，可以控制VM的`start、stop、restart`。

## kubeVirt管理虚拟机机制

### 虚拟机镜像制作与管理

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/virt-image-construction-flow.png){ loading=lazy }

虚拟机镜像采用容器镜像形式存放在镜像仓库中。创建原理如上图所示，将Linux发行版本的镜像文件存放到基础镜像的`/disk`目录内，镜像格式支持`qcow2、raw、img`。通过Dockerfile文件将虚拟机镜像制作成容器镜像，然后分别推送到不同的registry镜像仓库中。客户在创建虚拟机时，根据配置的优先级策略拉取registry中的虚拟机容器镜像，如果其中一台registry故障，会另一台健康的registry拉取镜像。

### 虚拟机生命周期管理

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/virt-lifecycle.png){ loading=lazy }

kubeVirt虚拟机生命周期管理主要分为以下几种状态：

- 虚拟机创建：创建VM对象，并同步创建`DataVolume/PVC`，从Harbor镜像仓库中拉取系统模板镜像拷贝至目标调度主机，通过调度、IP分配后生成VMI以及管理VM的Launcher Pod从而启动供业务使用的VM。
- 虚拟机运行：运行状态下的VM 可以进行控制台管理、快照备份/恢复、热迁移、磁盘热挂载/热删除等操作，此外还可以进行重启、下电操作，提高VM安全的同时解决业务存储空间需求和主机异常Hung等问题。
- 虚拟机关机：关机状态下的VM可以进行快照备份/恢复、冷迁移、`CPU/MEM`规格变更、重命名以及磁盘挂载等操作，同时可通过重新启动进入运行状态，也可删除进行资源回收。
- 虚拟机删除：对虚机资源进行回收，但VM所属的磁盘数据仍将保留、具备恢复条件。

#### 虚拟机创建

关于虚拟机的创建流程如下图：

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/virt-vm-start.png){ loading=lazy }