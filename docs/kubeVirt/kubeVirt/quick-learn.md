## kubeVirt的架构

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/kubeVirt-infra.png){ loading=lazy }

kubeVirt以CRD的形式将VM管理接口接入到kubernetes中，通过一个pod去使用libvirtd管理VM的方式，实现pod与VM的一一对应，做到如同容器一般去管理虚拟机，并且做到与容器一样的资源管理、调度规划、这一层整体与企业IAAS关系不大，也方便企业的接入，统一纳管。

| 组件                | 描述                                                                                                                                                                                                                                                                                                                                      |
|:------------------|:----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| `virt-api`        | kubeVirt是以CRD形式去管理VM Pod，`virt-api`就是所有虚拟化操作的入口，这里面包括常规的CDR更新验证、以及`console、vm start、stop`等操作。                                                                                                                                                                                                                                           |
| `virt-controller` | <li> `virt-controller`会根据vmi CRD，生成对应的`virt-launcher` Pod，并维护CRD的状态。<li> 与kubernetes api-server通讯监控VMI资源的创建删除等状态。                                                                                                                                                                                                                       |
| `virt-handler`    | <li> `virt-handler`会以daemonset形式部署在每一个节点上，负责监控节点上的每个虚拟机实例状态变化，一旦检测到状态的变化，会进行响应并且确保相应的操作能够达到所需（理想）的状态。<li> `virt-handler`还会保持集群级别`VMI Spec`与相应libvirt域之间的同步；报告`libvirt`域状态和集群Spec的变化；调用以节点为中心的插件以满足VMI Spec定义的网络和存储要求。                                                                                                                   |
| `virt-launcher`   | <li> 每个`virt-launcher` pod对应着一个VMI，kubelet只负责`virt-launcher` pod运行状态，不会去关心VMI创建情况。<li> `virt-handler`会根据CRD参数配置去通知`virt-launcher`去使用本地的`libvirtd`实例来启动VMI，随着Pod的生命周期结束，`virt-lanuncher`也会去通知VMI去执行终止操作；<li> 其次在每个`virt-launcher` pod中还对应着一个`libvirtd`，`virt-launcher`通过`libvirtd`去管理VM的生命周期，这样做到去中心化，不再是以前的虚拟机那套做法，一个`libvirtd`去管理多个VM。 |
| `virtctl`         | kubeVirt自带类似`kubectl`的命令行工具，它是越过`virt-launcher` pod这一层去直接管理VM虚拟机，可以控制VM的`start、stop、restart`。                                                                                                                                                                                                                                           |

## kubeVirt管理虚拟机机制

在讲解kubeVirt管理机制之前，我们先了解一下`libvirt`。

### libvirt

在云计算发展中，有两类虚拟化平台：

- openstack（iaas）：关注于资源的利用，虚拟机的计算，网络和存储
- kubernetes（paas）：关注容器的编排调度，自动化部署，发布管理

`libvirt`是一个虚拟化管理平台的软件集合。它提供统一的API，守护进程libvirtd和一个默认命令行管理工具：`virsh`。 其实我们也可以使用`kvm-qemu`命令行的管理工具，但是其参数过多，不便使用。 所以我们通常使用`libvirt`的解决方案，来对虚拟换进行管理。

`libvirt`是Hypervisor的管理方案，就是管理Hypervisor的。 

!!! question

    那Hypervisor到底有哪些呢？

Hypervisor（VMM）虚拟机监视器有以下分类：

1. Type-1，native or bare-metal hypervisors ：硬件虚拟化

    这些Hypervisor是直接安装并运行在宿主机上的硬件之上的，Hypervisor运行在硬件之上来控制和管理硬件资源。 比如：

    - `Microsoft Hyper-V`
    - `VMware ESXI`
    - `KVM`

2. Typer-2 or hosted hypervisors ：

    这些Hypervisor直接作为一种计算机程序运行在宿主机上的操作系统之上的。

    - `QEMU`
    - `VirtualBox`
    - `VMware Player`
    - `VMware WorkStation`

3. 虚拟化主要就是虚拟`CPU`，`MEM`（内存），`I/Odevices`

    - 其中`Intel VT-x/AMD-X`实现的是`CPU`虚拟化
    - `Intel EPT/AMD-NPT`实现`MEM`的虚拟化

4. `Qemu-Kvm`的结合：

    `KVM`只能进行`CPU`，`MEM`，的虚拟化，`QEMU`能进行硬件，比如：声卡，USE接口，...的虚拟化，因此通常将`QEMU`，`KVM`结合共同虚拟：`QEMU-KVM`。

我们通过`libvirt`命令行工具，来调动Hypervisor，从而使Hypervisor管理虚拟机。

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

创建流程具体描述：

1. 用户编写VM类型的资源清单
2. 使用`apply`命令创建VM资源
3. VM资源创建完成以后，`virt-controller`会检测到有个VM类型的资源创建
4. 检查此VM的状态，默认有个字段`Running: false`, 此时不会创建VMI资源
5. 使用`virtctl`命令和`virt-api`交互，从而启动VM
6. VM资源下的状态字段变成`Running: true`
7. `virt-controller`发现VM文件发生变化，并且检查到已经为`true`，表示可以创建VMI了
8. `virt-controller`检测到有个VMI资源被创建，并根据VMI相关配置信息以及现有的资源，从而创建`virt-launcher Pod`
9. `api-server`发现有个`virt-launcher Pod`即将被创建，先进行调度
10. `kubelet`创建此pod
11. 当`virt-launcher Pod`被拉起以后，`virt-handler`监测到这个pod
12. `virt-handler`开始创建相关的网络设备并且检查VMI资源状态，然后将VMI资源发送给`virt-launcher`
13. `virt-launcher`接收到VMI资源以后，将VMI资源转换为domain xml文件
14. xml文件被`libvirtd`识别
15. `libvirtd`将xml文件转换为`KVM`的启动参数并启动VM

#### 资源清单

关于资源清单，kubeVirt 主要实现了下面几种资源，以实现对虚拟机的管理：

| 资源对象                               | 描述                                                                                           |
|:-----------------------------------|:---------------------------------------------------------------------------------------------|
| `VirtualMachineInstance（VMI）`      | 类似于 kubernetes Pod，是管理虚拟机的最小资源。一个 `VirtualMachineInstance` 对象即表示一台正在运行的虚拟机实例，包含一个虚拟机所需要的各种配置。|
| `VirtualMachine（VM）`               | 为集群内的 `VirtualMachineInstance` 提供管理功能，例如开机/关机/重启虚拟机，确保虚拟机实例的启动状态，与虚拟机实例是 `1:1` 的关系，类似与 `spec.replica` 为 1 的 `StatefulSet`。|
| `VirtualMachineInstanceReplicaSet` | 类似 `ReplicaSet`，可以启动指定数量的 `VirtualMachineInstance`，并且保证指定数量的 `VirtualMachineInstance` 运行，可以配置 `HPA`。|
