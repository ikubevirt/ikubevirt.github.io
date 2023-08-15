在使用虚拟机时，会有因磁盘空间不足需要外挂存储卷的操作（当然也有反向的操作，即卸载存储卷），本文我们来了解下kubevirt对运行中的虚拟机动态操作存储卷的实现，也就是热插拔存储卷。

## 热插拔卷介绍

!!! info "热插拔卷定义"

    `hotplug volume`热插拔卷，热插拔在这里指的是虚拟机在不关机断电的情况支持插入或者拔出卷而不影响虚拟机的正常工作。

kubeVirt封装了`virtctl addvolume`和`virtctl removevolume`两个命令来支持热插拔卷。

kubeVirt支持运行中的vmi实例使用热插拔卷，但是卷必须是块设备（block volume）或者包含一个磁盘镜像（disk image）。当一个有热插拔卷的vm（注意是vm）实例重启（reboot）后，热插拔卷会attach到该vm中。如果此时卷存在的话，热插拔卷会成为`vm spec`下的一部分，此时不会被当做热插拔卷。如果此时不存在，这个卷则会作为热插拔卷重新attach。

## 使能 hotplug volume

要使用热插拔卷功能，必须打开相应配置开关，即在kubeVirt这个CR中添加`HotplugVolume`配置项。

## virtctl 支持

为了热插拔卷功能，首先必须准备好一个卷，这个卷可以是被`DataVolume`（DV，kubeVirt的一个CRD）创建。为了添加额外的存储到一个运行中的vmi实例中，我们在示例中使用一个空的DV。

```yaml linenums="1"
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: example-volume-hotplug
spec:
  source:
    blank: {}
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 5Gi
```

在这个示例中我们使用`ReadWriteOnce`访问模式和默认的FileSystem卷模式。只要用户的存储支持组合，热插拔卷就支持所有块设备卷模式和`ReadWriteMany`/`ReadWriteOnce`/`ReadOnlyMany`访问模式的组合。

### 添加卷

假设当前我们已经启动了一个vmi实例，而且这个vmi实例的名称叫“`vmi-fedora`”，我们可以通过`virtctl addvolume`命令添加上述空白卷到这个运行中的虚拟机中。

```bash linenums="1"
$ virtctl addvolume vmi-fedora --volume-name=example-volume-hotplug
```

#### 序列号

也可以使用`–serial`参数修改磁盘的序列号：

```bash linenums="1"
$ virtctl addvolume vmi-fedora --volume-name=example-volume-hotplug --serial=1234567890
```

这个序列号只在guest（即虚拟机）中使用，在虚拟机中，磁盘by-id会包含这个序列号：

```bash linenums="1"
$ virtctl console vmi-fedora

Fedora 32 (Cloud Edition)
Kernel 5.6.6-300.fc32.x86_64 on an x86_64 (ttyS0)

SSH host key: SHA256:c8ik1A9F4E7AxVrd6eE3vMNOcMcp6qBxsf8K30oC/C8 (ECDSA)
SSH host key: SHA256:fOAKptNAH2NWGo2XhkaEtFHvOMfypv2t6KIPANev090 (ED25519)
eth0: 10.244.196.144 fe80::d8b7:51ff:fec4:7099
vmi-fedora login:fedora
Password:fedora
[fedora@vmi-fedora ~]$ ls /dev/disk/by-id
scsi-0QEMU_QEMU_HARDDISK_1234567890
[fedora@vmi-fedora ~]$ 
```

可以看到序列号是磁盘名称的一部分，可以利用该序列号来唯一识别。序列号的格式和长度在libvirt文档中有说明：

```bash linenums="1"
If present, this specify serial number of virtual hard drive. For example, it may look like <serial>WD-WMAP9A966149</serial>. Not supported for scsi-block devices, that is those using disk type 'block' using device 'lun' on bus 'scsi'. Since 0.7.1

    Note that depending on hypervisor and device type the serial number may be truncated silently. IDE/SATA devices are commonly limited to 20 characters. SCSI devices depending on hypervisor version are limited to 20, 36 or 247 characters.

    Hypervisors may also start rejecting overly long serials instead of truncating them in the future so it's advised to avoid the implicit truncation by testing the desired serial length range with the desired device and hypervisor combination.
```

#### 为什么是virtio-scsi?

热插拔磁盘类型被指定为`scsi`磁盘，为什么不像普通的磁盘一样指定为`virtio`类型？原因是`virtio`磁盘的数量限制，因为在虚拟机里，每一个
磁盘都会使用一个`PCIe`槽，而`PCIe`槽的数量上限是32，再加上一些其它设备也会使用PCIe槽，因此用户可热插拔磁盘的数量非常有限。另一个问题是这些热插拔槽需要提前预留，因为如果事先不知道热插拔磁盘的数量，则无法正确保留所需的插槽数量。为了解决上述问题，每一个vm都有一个`virtio-scsi`控制器（controller），它允许热插拔磁盘使用`scsi`总线。这个控制器允许热插拔超过400W个磁盘，而且`virtio-scsi`的性能和`virtio`性能也非常接近。

### 重启之后保留热插拔卷

在许多场景下都期望vm重启后能保留热插拔卷，当然也期望在重启后能支持拔出（unplug）热插拔卷。配置`persist`参数虚拟机重启后不能卸下之前的热插拔卷，如果没有声明`persist`参数，默认是在vm重启后会以热插拔卷的形式保留插拔卷。因此大部分时候`persist`参数都不用配置，除非你想虚拟机重启后把这个卷作为一个持久化的卷。

### 持久化

在一些场景下用户希望vm重启后之前的热插拔卷能作为vm的一个标准磁盘，例如你向vm添加了一些永久存储。我们假设正在运行的vmi具有定义其规范匹配的vm对象，你可以使用`–persistent`标志调用`addvolume`命令。除了更新vmi domain磁盘外，这将更新vm domain磁盘部分。这意味着当您重新启动vm时，磁盘已经在vm中定义，因此在新的vmi中也会定义。

```bash linenums="1"
$ virtctl addvolume vm-fedora --volume-name=example-volume-hotplug --persist
```

在vm spec字段中会显示成一个新的磁盘：

```yaml linenums="1"
spec:
    domain:
        devices:
            disks:
            - disk:
                bus: virtio
                name: containerdisk
            - disk:
                bus: virtio
                name: cloudinitdisk
            - disk:
                bus: scsi
                name: example-volume-hotplug
        machine:
          type: ""
```

### 卸载热插拔卷

使用热插拔卷后，可以使用`virtctl removevolume`命令将热插拔卷拔出：

```bash linenums="1"
$ virtctl removevolume vmi-fedora --volume-name=example-volume-hotplug
```

!!! note

    只能卸下使用`virtctl addvolume`命令或者调API接口添加的热插拔卷。

### 卷的状态

vmi对象有一个新的`status.VolumeStatus`字段，这是一个包含每个磁盘的数组（不管磁盘是否是热插拔）。例如，在`addvolume`示例中热插拔卷后，vmi状态将包含以下内容：

```yaml linenums="1"
volumeStatus:
    - name: cloudinitdisk
      target: vdb
    - name: containerdisk
      target: vda
    - hotplugVolume:
        attachPodName: hp-volume-7fmz4
        attachPodUID: 62a7f6bf-474c-4e25-8db5-1db9725f0ed2
      message: Successfully attach hotplugged volume volume-hotplug to VM
      name: example-volume-hotplug
      phase: Ready
      reason: VolumeReady
      target: sda
```

`vda`是包含`Fedora OS`的容器磁盘，`vdb`是`cloudinit`磁盘，正如你所看到的，它们只包含在将它们分配给vm时使用的名称和目标（target）。目标是指定磁盘时传递给qemu的值，该值对于vm是唯一的，不代表guest（虚拟机）内部的命名。例如，对于Windows虚拟机操作系统，target没有意义，热插拔卷也一样。target只是qemu的唯一标识符，在guest中可以为磁盘分配不同的名称。

热插拔卷有一些常规卷状态没有的额外信息。`attachPodName`是用于将卷attach到vmi运行的节点的pod的名称。如果删除此pod，它也将停止vmi，此时kubeVirt无法保证卷将继续attach到节点。其他字段与conditions类似，表示热插拔过程的状态。一旦卷就绪，vm就可以使用它。

