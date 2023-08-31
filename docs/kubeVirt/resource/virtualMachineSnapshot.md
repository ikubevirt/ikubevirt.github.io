# VirtualMachineSnapshot

您可以通过创建一个 VirtualMachineSnapshot 对象来为离线虚拟机创建虚拟机快照。

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
virtualMachineSnapshotContentName: vmsnapshot-content-28eedf08-5d6a-42c1-969c-2eda58e2a78d 4
```

1. `Progressing` 的 `status` 字段指定快照是否仍然在创建。
2. `Ready` 条件的 `status` 字段指定快照创建过程是否完成。
3. 指定快照是否准备就绪可用被使用。


检查 `VirtualMachineSnapshotContent` 资源的 `spec:volumeBackups` 属性，以验证快照中包含了预期的 PVC。

