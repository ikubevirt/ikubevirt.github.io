# VirtualMachineSnapshot

## 关于虚拟机快照

!!! info "虚拟机快照"

    快照代表虚拟机（VM）在特定时间点的状态和数据。您可以使用快照将现有虚拟机恢复到以前的状态（由快照代表）进行备份和恢复，或者快速回滚到以前的开发版本。

从关闭（停止状态）的虚拟机创建离线虚拟机快照。快照存储附加到虚拟机的每个 Container Storage Interface（CSI）卷的副本以及虚拟机规格和元数据的副本。创建后无法更改快照。

通过离线虚拟机快照功能，集群管理员和应用程序开发人员可以：

- 创建新快照
- 列出附加到特定虚拟机的所有快照
- 从快照恢复虚拟机
- 删除现有虚拟机快照

您可以通过创建一个 `VirtualMachineSnapshot` 对象来为离线虚拟机创建虚拟机快照。

### 虚拟机快照CRD

VM 快照功能引入了三个新的 API 对象，定义为 CRD，用于管理快照：

| 资源对象                               | 描述                                                                                           |
|:-----------------------------------|:---------------------------------------------------------------------------------------------|
| `VirtualMachineSnapshot`      | 代表创建快照的用户请求。它包含有关虚拟机当前状态的信息。|
| `VirtualMachineSnapshotContent`               | 代表集群中置备的资源（快照）。它由虚拟机快照控制器创建，其中包含恢复虚拟机所需的所有资源的引用。|
| `VirtualMachineRestore` | 代表从快照中恢复虚拟机的用户请求。|

VM 快照控制器会把一个 `VirtualMachineSnapshotContent` 对象与创建它的 `VirtualMachineSnapshotContent` 对象绑定，并具有一对一的映射。

## 先决条件

!!! info "先决条件"

    - 确保持久性卷声明（PVC）位于支持 Container Storage Interface（CSI）卷快照的存储类中。
    - 关闭您要为其创建快照的虚拟机。

## 创建流程

创建一个 YAML 文件来定义 `VirtualMachineSnapshot` 对象，以指定新 `VirtualMachineSnapshot` 的名称和源虚拟机的名称。 例如：

```yaml linenums="1" title="my-vmsnapshot.yaml"
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineSnapshot
metadata:
  name: my-vmsnapshot # (1)
spec:
  source:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: my-vm # (2)
```

1.  新的 `VirtualMachineSnapshot` 对象的名称。
2. 源虚拟机的名称。

创建 `VirtualMachineSnapshot` 资源。快照控制器会创建一个 `VirtualMachineSnapshotContent` 对象，将其绑定到 `VirtualMachineSnapshot` 并更新 `VirtualMachineSnapshot` 对象的 `status` 和 `readyToUse` 字段。

```bash
kubectl create -f my-vmsnapshot.yaml
```

验证 `VirtualMachineSnapshot` 对象是否已创建并绑定到 `VirtualMachineSnapshotContent`。`readyToUse` 标志必须设为 `true`。

```bash
kubectl describe vmsnapshot my-vmsnapshot
```

输出示例:

```bash
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineSnapshot
metadata:
creationTimestamp: "2020-09-30T14:41:51Z"
finalizers:
- snapshot.kubevirt.io/vmsnapshot-protection
generation: 5
name: mysnap
namespace: default
resourceVersion: "3897"
selfLink: /apis/snapshot.kubevirt.io/v1alpha1/namespaces/default/virtualmachinesnapshots/my-vmsnapshot
uid: 28eedf08-5d6a-42c1-969c-2eda58e2a78d
spec:
source:
apiGroup: kubevirt.io
kind: VirtualMachine
name: my-vm
status:
conditions:
  - lastProbeTime: null
  lastTransitionTime: "2020-09-30T14:42:03Z"
  reason: Operation complete
  status: "False" # (1)
  type: Progressing
  - lastProbeTime: null
  lastTransitionTime: "2020-09-30T14:42:03Z"
  reason: Operation complete
  status: "True" # (2)
  type: Ready
creationTime: "2020-09-30T14:42:03Z"
readyToUse: true # (3)
sourceUID: 355897f3-73a0-4ec4-83d3-3c2df9486f4f
virtualMachineSnapshotContentName: vmsnapshot-content-28eedf08-5d6a-42c1-969c-2eda58e2a78d # (4)
```

1. `Progressing` 的 `status` 字段指定快照是否仍然在创建。
2. `Ready` 条件的 `status` 字段指定快照创建过程是否完成。
3. 指定快照是否准备就绪可用被使用。
4. 指定快照被绑定到快照控制器创建的 `VirtualMachineSnapshotContent` 对象。


检查 `VirtualMachineSnapshotContent` 资源的 `spec:volumeBackups` 属性，以验证快照中包含了预期的 PVC。

