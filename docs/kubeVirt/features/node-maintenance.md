
在从集群中删除 kubernetes 节点之前，用户需要确保 VirtualMachineInstances 在关闭节点电源之前已正常终止。 由于所有 VirtualMachineInstances 都由 Pod 支持，因此驱逐 VirtualMachineInstances 的推荐方法是使用 `kubectl drain` 命令，或者在 OKD 的情况下使用 `oc adm drain` 命令。

## 从节点中逐出所有虚拟机

通过从集群节点列表中识别节点来选择要从中驱逐 VirtualMachineInstances 的节点。

以下命令将正常终止特定节点上的所有虚拟机。 将 `<node-name>` 替换为应发生驱逐的节点的名称。

```bash
kubectl drain <node-name> --delete-local-data --ignore-daemonsets=true --force --pod-selector=kubevirt.io=virt-launcher
```

下面详细解释了为什么需要传递给排出命令的每个参数。

- `kubectl drain <node-name>` 正在选择特定节点作为驱逐目标

- `--delete-local-data` 是删除任何使用 emptyDir 卷的 pod 所必需的必需标志。 VirtualMachineInstance Pod 确实使用 emptyDir 卷，但是这些卷中的数据是短暂的，这意味着终止后可以安全地删除。

- `--ignore-daemonsets=true` 是必需的标志，因为运行 VirtualMachineInstance 的每个节点也将运行我们称为 virt-handler 的助手 DaemonSet。 不允许使用 `kubectl drain` 驱逐 DaemonSet。 默认情况下，如果此命令在目标节点上遇到 DaemonSet，则该命令将失败。 该标志告诉命令可以安全地进行驱逐并忽略 DaemonSet。

- `--force` 是必需的标志，因为 VirtualMachineInstance pod 不属于 ReplicaSet 或 DaemonSet 控制器。 这意味着 kubectl 无法保证在目标节点上终止的 pod 在 pod 被驱逐后将得到重新安排的替换，并将其放置在集群中的其他位置。 KubeVirt 有自己的控制器来管理底层 VirtualMachineInstance pod。 每个控制器对于被驱逐的 VirtualMachineInstance 的行为都不同。 本文档下面进一步概述了该行为。

- `--pod-selector=kubevirt.io=virt-launcher` 表示只有 KubeVirt 管理的 VirtualMachineInstance pod 才会从节点中删除。

## 从节点中逐出所有 VM 和 Pod

通过从上一个命令中删除 `-pod-selector` 参数，我们可以驱逐节点上的所有 Pod。 此命令可确保与 VM 关联的 Pod 以及所有其他 Pod 均从目标节点逐出。

```bash
kubectl drain <节点名称> --delete-local-data --ignore-daemonsets=true --force
```

## 通过从节点实时迁移撤出 VMI

如果启用了 LiveMigration 特性门控，则可以在 VMI 上指定 `evictionStrategy`，它将对节点上特定污点的实时迁移做出反应。 VMI 或虚拟机中的 VMI 模板上的以下代码片段可确保在节点驱逐期间迁移 VMI：

```yaml
spec:
  evictionStrategy: LiveMigrate
```

这是完整的VMI,
```yaml linenums="1"
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  name: testvmi-nocloud
spec:
  terminationGracePeriodSeconds: 30
  evictionStrategy: LiveMigrate
  domain:
    resources:
      requests:
        memory: 1024M
    devices:
      disks:
      - name: containerdisk
        disk:
          bus: virtio
      - disk:
          bus: virtio
        name: cloudinitdisk
  volumes:
  - name: containerdisk
    containerDisk:
      image: kubevirt/fedora-cloud-container-disk-demo:latest
  - name: cloudinitdisk
    cloudInitNoCloud:
      userData: |-
        #cloud-config
        password: fedora
        chpasswd: { expire: False }
```

在幕后，为每个定义了 `evictionStrategy` 的 VMI 创建一个 `PodDisruptionBudget`。 这确保了这些 VMI 上的驱逐被阻止，并且我们可以保证 VMI 将被迁移而不是关闭。

## 驱逐后重新启用节点

`kubectl drain`将导致目标节点被标记为不可调度。 这意味着该节点将没有资格运行新的 VirtualMachineInstances 或 Pod。

如果确定目标节点应再次变得可调度，则必须运行以下命令。

```bash
kubectl uncordon <节点名称>
```
或者在 OKD 的情况下。

```bash
oc adm uncordon <节点名称>
```

## 驱逐后关闭节点

从 KubeVirt 的角度来看，一旦所有 VirtualMachineInstances 从节点中被逐出，该节点就可以安全关闭。 在多用途集群中，VirtualMachineInstances 与其他容器化工作负载一起调度，集群管理员需要确保在关闭节点电源之前所有其他 Pod 已被安全驱逐。

