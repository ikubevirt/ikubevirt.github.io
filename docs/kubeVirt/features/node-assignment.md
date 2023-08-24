
您可以限制虚拟机仅在特定节点上运行或更喜欢在特定节点上运行：

- 节点选择器
- 亲和性与反亲和性
- 污点和容忍

## 节点选择器

设置`spec.nodeSelector`要求，限制调度程序仅在包含指定标签的节点上调度VM。 在以下示例中，vmi 包含标签 `cpu: Slow` 和 `storage: fast`：

```yaml linenums="1"
metadata:
  name: testvmi-ephemeral
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
spec:
  nodeSelector:
    cpu: slow
    storage: fast
  domain:
    resources:
      requests:
        memory: 64M
    devices:
      disks:
      - name: mypvcdisk
        lun: {}
  volumes:
    - name: mypvcdisk
      persistentVolumeClaim:
        claimName: mypvc
```

因此，调度程序只会将 vmi 调度到元数据中包含这些标签的节点。 它的工作原理与 Pods 节点选择器完全相同。 有关更多示例，请参阅 [Pod nodeSelector 文档](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#nodeselector)。

## 亲和性和反亲和性

`spec.affinity` 字段允许指定虚拟机的硬亲和力和软亲和力。 可以针对工作负载（VM 和 Pod）和节点编写匹配规则。 由于 VM 是基于 Pod 的工作负载类型，因此 Pod 亲和性也会影响 VM。

`podAffinity` 和 `podAntiAffinity` 的示例可能如下所示：

```yaml linenums="1"
metadata:
  name: testvmi-ephemeral
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
spec:
  nodeSelector:
    cpu: slow
    storage: fast
  domain:
    resources:
      requests:
        memory: 64M
    devices:
      disks:
      - name: mypvcdisk
        lun: {}
  affinity:
    podAffinity:
      requiredDuringSchedulingIgnoredDuringExecution:
      - labelSelector:
          matchExpressions:
          - key: security
            operator: In
            values:
            - S1
        topologyKey: failure-domain.beta.kubernetes.io/zone
    podAntiAffinity:
      preferredDuringSchedulingIgnoredDuringExecution:
      - weight: 100
        podAffinityTerm:
          labelSelector:
            matchExpressions:
            - key: security
              operator: In
              values:
              - S2
          topologyKey: kubernetes.io/hostname
  volumes:
    - name: mypvcdisk
      persistentVolumeClaim:
        claimName: mypvc
```

亲和性和反亲和性的工作原理与 Pod 亲和性完全相同。 这包括 `podAffinity`、`podAntiAffinity`、`nodeAffinity` 和 `nodeAntiAffinity`。 有关更多示例和详细信息，请参阅 [Pod 亲和性和反亲和性文档](https://kubernetes.io/docs/concepts/scheduling-eviction/assign-pod-node/#affinity-and-anti-affinity)。

## 污点和容忍

如上所述，亲和性是 VM 的一个属性，它将 VM 吸引到一组节点（作为偏好或硬性要求）。 污点则相反——它们允许一个节点排斥一组虚拟机。

污点和容忍协同工作以确保虚拟机不会被调度到不适当的节点上。 一个或多个污点被应用到一个节点； 这标志着该节点不应接受任何不能容忍污点的虚拟机。 容忍应用于虚拟机，并允许（但不要求）虚拟机调度到具有匹配污点的节点上。

您可以使用 `kubectl taint` 将污点添加到节点。 例如，

```bash
kubectl taint nodes node1 key=value:NoSchedule
```

容忍度的示例可能如下所示：

```yaml linenums="1"
metadata:
  name: testvmi-ephemeral
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
spec:
  nodeSelector:
    cpu: slow
    storage: fast
  domain:
    resources:
      requests:
        memory: 64M
    devices:
      disks:
      - name: mypvcdisk
        lun: {}
  tolerations:
  - key: "key"
    operator: "Equal"
    value: "value"
    effect: "NoSchedule"
```

## 使用 Descheduler 进行节点平衡

在某些情况下，我们可能需要根据当前的调度策略和负载条件重新平衡集群。 Descheduler 可以找到 pod，例如这违反了 调度决策并根据调度器策略驱逐它们。 kubeVirt VM 被视为具有本地存储的 Pod，因此默认情况下，descheduler 不会驱逐它们。 但可以通过向 VM 中的 VMI 模板添加特殊注释来轻松覆盖它：

```yaml
spec:
  template:
    metadata:
      annotations:
        descheduler.alpha.kubernetes.io/evict: true
```

此注释将导致 descheduler 能够驱逐 VM 的 pod，然后调度程序可以在不同的节点上调度该 pod。 在从集群中删除 VirtualMachineInstance 的当前实例之前，VirtualMachine 永远不会重新启动或重新创建 VirtualMachineInstance。