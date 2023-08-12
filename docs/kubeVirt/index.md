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

- `VirtualMachineInstance（VMI）` : 类似于 kubernetes Pod，是管理虚拟机的最小资源。一个 `VirtualMachineInstance` 对象即表示一台正在运行的虚拟机实例，包含一个虚拟机所需要的各种配置。
- `VirtualMachine（VM）`: 为集群内的 `VirtualMachineInstance` 提供管理功能，例如开机/关机/重启虚拟机，确保虚拟机实例的启动状态，与虚拟机实例是 `1:1` 的关系，类似与 `spec.replica` 为 1 的 `StatefulSet`。
- `VirtualMachineInstanceReplicaSet` : 类似 `ReplicaSet`，可以启动指定数量的 `VirtualMachineInstance`，并且保证指定数量的 `VirtualMachineInstance` 运行，可以配置 `HPA`。

## 实战演练

### 部署虚拟机Centos7

#### 准备工作

首先，我们需要安装`libvirt`和`qemu`，

```bash linenums="1"
yum install -y qemu-kvm libvirt virt-install bridge-utils
```

查看节点是否支持 kvm 虚拟机化

```bash linenums="1"
$ virt-host-validate qemu
  QEMU: 正在检查 for hardware virtualization                           : PASS
  QEMU: 正在检查 if device /dev/kvm exists                             : PASS
  QEMU: 正在检查 if device /dev/kvm is accessible                      : PASS
  QEMU: 正在检查 if device /dev/vhost-net exists                       : PASS
  QEMU: 正在检查 if device /dev/net/tun exists                         : PASS
  QEMU: 正在检查 for cgroup 'memory' controller support                : PASS
  QEMU: 正在检查 for cgroup 'memory' controller mount-point            : PASS
  QEMU: 正在检查 for cgroup 'cpu' controller support                   : PASS
  QEMU: 正在检查 for cgroup 'cpu' controller mount-point               : PASS
  QEMU: 正在检查 for cgroup 'cpuacct' controller support               : PASS
  QEMU: 正在检查 for cgroup 'cpuacct' controller mount-point           : PASS
  QEMU: 正在检查 for cgroup 'cpuset' controller support                : PASS
  QEMU: 正在检查 for cgroup 'cpuset' controller mount-point            : PASS
  QEMU: 正在检查 for cgroup 'devices' controller support               : PASS
  QEMU: 正在检查 for cgroup 'devices' controller mount-point           : PASS
  QEMU: 正在检查 for cgroup 'blkio' controller support                 : PASS
  QEMU: 正在检查 for cgroup 'blkio' controller mount-point             : PASS
  QEMU: 正在检查 for device assignment IOMMU support                   : WARN (No ACPI DMAR table found, IOMMU either disabled in BIOS or not supported by this hardware platform)
```

如果不支持，则让 Kubevirt 使用软件虚拟化：

```bash linenums="1"
kubectl create namespace kubevirt
kubectl create configmap -n kubevirt kubevirt-config --from-literal debug.useEmulation=true
```

开始部署最新版本的kubeVirt，

```bash linenums="1"
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-operator.yaml
kubectl apply -f https://github.com/kubevirt/kubevirt/releases/download/${VERSION}/kubevirt-cr.yaml
```

查看命令执行结果

```bash linenums="1"
$ kubectl get pods -n kubevirt
NAME                               READY   STATUS    RESTARTS      AGE
virt-api-59d4c5cb49-6b2r2          1/1     Running   1 (82m ago)   82m
virt-api-59d4c5cb49-d9w4z          1/1     Running   1 (82m ago)   82m
virt-controller-8684f9db98-d6w6p   1/1     Running   0             82m
virt-controller-8684f9db98-hrkjg   1/1     Running   0             82m
virt-handler-2hfxz                 1/1     Running   0             82m
virt-handler-4vk84                 1/1     Running   0             82m
virt-handler-qg4qt                 1/1     Running   0             82m
virt-handler-qnzsh                 1/1     Running   0             82m
virt-operator-5fcd4ff76f-47n27     1/1     Running   0             84m
virt-operator-5fcd4ff76f-kq4h8     1/1     Running   0             84m
```

接着我们部署CDI，CDI (Containerized Data Importer) 可以使用 PVC 作为 KubeVirt VM 磁盘，建议同时安装：

```bash linenums="1"
export VERSION=$(curl -s https://github.com/kubevirt/containerized-data-importer/releases | grep -o "v[0-9]\.[0-9]*\.[0-9]*" | head -1)
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-operator.yaml
kubectl create -f https://github.com/kubevirt/containerized-data-importer/releases/download/$VERSION/cdi-cr.yaml
```

安装`virtctl`工具，virtctl 工具可以直接用来操作虚拟机，执行以下命令下载，

```bash linenums="1"
export VERSION=$(curl -s https://api.github.com/repos/kubevirt/kubevirt/releases | grep tag_name | grep -v -- '-rc' | head -1 | awk -F': ' '{print $2}' | sed 's/,//' | xargs)
curl -L -o /usr/local/bin/virtctl https://github.com/kubevirt/kubevirt/releases/download/$VERSION/virtctl-$VERSION-linux-amd64
chmod +x /usr/local/bin/virtctl
```

#### 准备系统镜像

下载 CentOS7 镜像，选择阿里云镜像站 [https://mirrors.aliyun.com/centos/7/isos/x86_64/](https://mirrors.aliyun.com/centos/7/isos/x86_64/)

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/aliyun-image-source.png){ loading=lazy }

#### 上传镜像文件

KubeVirt 可以使用 PVC 作为后端磁盘，使用 `filesystem` 类型的 PVC 时，默认使用的时 `/disk.img` 这个镜像，用户可以将镜像上传到 PVC， 在创建 VMI 时使用此 PVC。使用这种方式需要注意下面几点：

- 一个 PVC 只允许存在一个镜像，只允许一个 VMI 使用，要创建多个 VMI，需要上传多次
- `/disk.img` 的格式必须是 RAW 格式

CDI 提供了使用使用 PVC 作为虚拟机磁盘的方案，在虚拟机启动前通过下面方式填充 PVC：

- 通过 URL 导入虚拟机镜像到 PVC，URL 可以是 http 链接，s3 链接
- Clone 一个已经存在的 PVC
- 通过 container registry 导入虚拟机磁盘到 PVC，需要结合 `ContainerDisk` 使用
- 通过客户端上传本地镜像到 PVC

通过命令行 `virtctl`，结合 CDI 项目，可以上传本地镜像到 PVC 上，支持的镜像格式有：

- `.img`
- `.qcow2`
- `.iso`
- 压缩为 `.tar`，`.gz`，`.xz` 格式的上述镜像

上传镜像文件

```bash linenums="1"
$  export CDI_PROXY=`kubectl -n cdi get svc -l cdi.kubevirt.io=cdi-uploadproxy -o go-template --template='{{ (index .items 0).spec.clusterIP }}'`
$ virtctl image-upload --image-path='/root/iso/CentOS-7-x86_64-DVD-2009.iso' --pvc-name=iso-centos7  --pvc-size=5G --uploadproxy-url=https://$CDI_PROXY  --insecure  --wait-secs=240
PVC default/iso-centos7 not found
PersistentVolumeClaim default/iso-centos7 created
Waiting for PVC iso-centos7 upload pod to be ready...
Pod now ready
Uploading data to https://10.98.254.51

 4.39 GiB / 4.39 GiB [=============================================================================================================================================================] 100.00% 3m43s

Uploading data completed successfully, waiting for processing to complete, you can hit ctrl-c without interrupting the progress
Processing completed successfully
Uploading /root/iso/CentOS-7-x86_64-DVD-2009.iso completed successfully
```

参数说明：

- `–image-path` : 操作系统镜像路径。
- `–pvc-name` : 指定存储操作系统镜像的 PVC，这个 PVC 不需要提前准备好，镜像上传过程中会自动创建。
- `–pvc-size` : PVC 大小，根据操作系统镜像大小来设定，一般略大一个 G 就行。
- `–uploadproxy-url` : `cdi-uploadproxy` 的 Service IP，可以通过命令 `kubectl -n cdi get svc -l cdi.kubevirt.io=cdi-uploadproxy` 来查看。

#### 启动HostDisk特性门控

kubeVirt支持`HostDisk`

```bash linenums="1"
$ kubectl edit kubevirt kubevirt -n kubevirt
    ...
    spec:
      configuration:
        developerConfiguration:
          featureGates:
            - DataVolumes
            - LiveMigration
            - HostDisk
    ...
```

#### 编排CentOS7虚拟机模板文件

```yaml linenums="1"
# kubevirt-centos7.yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: centos7
spec:
  running: false
  template:
    metadata:
      labels:
        kubevirt.io/domain: centos7
    spec:
      domain:
        cpu:
          cores: 1
        devices:
          disks:
          - bootOrder: 1
            cdrom:
              bus: sata
            name: cdromiso
          - disk:
              bus: virtio
            name: harddrive
          - cdrom:
              bus: sata
            name: virtiocontainerdisk
          interfaces:
          - masquerade: {}
            model: e1000
            name: default
        machine:
          type: q35
        resources:
          requests:
            memory: 2G
      networks:
      - name: default
        pod: {}
      volumes:
      - name: cdromiso
        persistentVolumeClaim:
          claimName: iso-centos7
      - name: harddrive
        hostDisk:
          capacity: 30Gi
          path: /data/disk.img
          type: DiskOrCreate
      - containerDisk:
          image: kubevirt/virtio-container-disk
        name: virtiocontainerdisk
```

这里用到了 3 个 Volume：

- `cdromiso` : 提供操作系统安装镜像，即上文上传镜像后生成的 PVC iso-centos7。
- `harddrive` : 虚拟机使用的磁盘，即操作系统就会安装在该磁盘上。这里选择 `hostDisk` 直接挂载到宿主机以提升性能，如果使用分布式存储则体验非常不好。
- `containerDisk` : 由于 Windows 默认无法识别 `raw` 格式的磁盘，所以需要安装 `virtio` 驱动。 `containerDisk` 可以将打包好 `virtio` 驱动的容器镜像挂载到虚拟机中。

关于网络部分，`spec.template.spec.networks` 定义了一个网络叫 `default`，这里表示使用 Kubernetes 默认的 CNI。`spec.template.spec.domain.devices.interfaces` 选择定义的 网络 `default`，并开启 `masquerade`，以使用网络地址转换 (NAT) 来通过 Linux 网桥将虚拟机连接至 Pod 网络后端。

编排模板文件，

```bash linenums="1"
kubectl apply -f kubevirt-centos7.yaml
```

#### 启动虚拟机和vnc代理

启动虚拟机，

```bash linenums="1"
virtctl start centos7
```

启动vnc代理，

```bash linenums="1"
$ virtctl vnc centos7 --proxy-only --address=0.0.0.0
{"port":42743}
{"component":"","level":"info","msg":"connection timeout: 1m0s","pos":"vnc.go:153","timestamp":"2022-06-07T10:06:11.066704Z"}
{"component":"","level":"info","msg":"VNC Client connected in 7.866330333s","pos":"vnc.go:166","timestamp":"2022-06-07T10:06:18.933070Z"}
```

执行完上面的命令后，就会打开本地的 VNC 客户端连接到虚拟机，

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/centos7-vnc.png){ loading=lazy }

直接下一步直到完成即可。安装完成重启后虚拟机依旧会从 `cdrom` 启动，修改 vm，

```bash linenums="1"
virtctl stop centos7
kubectl edit virtualmachine.kubevirt.io/centos7
```

设硬盘为第一启动项，

```bash linenums="1"
...
        devices:
          disks:
          - bootOrder: 2
            cdrom:
              bus: sata
            name: cdromiso
          - bootOrder: 1
            disk:
              bus: virtio
            name: harddrive
...
```

修改完成，重启虚拟机

```bash linenums="1"
virtctl start centos7
```

centOS7 虚拟机启动正常。

![](https://cdn.jsdelivr.net/gh/hyperter96/cloud-native-docs/docs/assets/images/centos7-start.png){ loading=lazy }