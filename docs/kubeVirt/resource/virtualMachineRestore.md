# VirtualMachineRestore

您可以使用虚拟机快照将现有虚拟机（VM）恢复到以前的配置。

## 恢复流程

创建一个 YAML 文件来定义 `VirtualMachineRestore` 对象，它指定您要恢复的虚拟机的名称以及要用作源的快照名称。例如:

```yaml linenums="1" title="my-vmrestore.yaml"
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineRestore
metadata:
  name: my-vmrestore # (1)
spec:
  target:
    apiGroup: kubevirt.io
    kind: VirtualMachine
    name: my-vm # (2)
  virtualMachineSnapshotName: my-vmsnapshot # (3)
```

1. 新 `VirtualMachineRestore` 对象的名称。
2. 要恢复的目标虚拟机的名称。
3. 作为源的 `VirtualMachineSnapshot` 对象的名称。

然后创建 `VirtualMachineRestore` 资源。快照控制器更新了 `VirtualMachineRestore` 对象的 `status` 字段，并将现有虚拟机配置替换为快照内容。

```bash
kubectl create -f my-vmrestore.yaml
```

验证虚拟机是否已恢复到快照代表的以前的状态。`complete` 标志需要被设置为 `true`。

```bash
kubectl get vmrestore my-vmrestore
```

输出示例：
```bash
apiVersion: snapshot.kubevirt.io/v1alpha1
kind: VirtualMachineRestore
metadata:
creationTimestamp: "2020-09-30T14:46:27Z"
generation: 5
name: my-vmrestore
namespace: default
ownerReferences:
- apiVersion: kubevirt.io/v1alpha3
  blockOwnerDeletion: true
  controller: true
  kind: VirtualMachine
  name: my-vm
  uid: 355897f3-73a0-4ec4-83d3-3c2df9486f4f
  resourceVersion: "5512"
  selfLink: /apis/snapshot.kubevirt.io/v1alpha1/namespaces/default/virtualmachinerestores/my-vmrestore
  uid: 71c679a8-136e-46b0-b9b5-f57175a6a041
  spec:
    target:
      apiGroup: kubevirt.io
      kind: VirtualMachine
      name: my-vm
  virtualMachineSnapshotName: my-vmsnapshot
  status:
  complete: true # (1)
  conditions:
  - lastProbeTime: null
  lastTransitionTime: "2020-09-30T14:46:28Z"
  reason: Operation complete
  status: "False" # (2)
  type: Progressing
  - lastProbeTime: null
  lastTransitionTime: "2020-09-30T14:46:28Z"
  reason: Operation complete
  status: "True" # (3)
  type: Ready
  deletedDataVolumes:
  - test-dv1
  restoreTime: "2020-09-30T14:46:28Z"
  restores:
  - dataVolumeName: restore-71c679a8-136e-46b0-b9b5-f57175a6a041-datavolumedisk1
  persistentVolumeClaim: restore-71c679a8-136e-46b0-b9b5-f57175a6a041-datavolumedisk1
  volumeName: datavolumedisk1
  volumeSnapshotName: vmsnapshot-28eedf08-5d6a-42c1-969c-2eda58e2a78d-volume-datavolumedisk1
```

1. 指定将虚拟机恢复到快照代表的状态的进程是否已完成。
2. `Progressing` 条件的 `status` 字段指定 VM 是否仍然被恢复。
3. `Ready` 条件的 `status` 字段指定 VM 恢复过程是否完成。
