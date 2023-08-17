
!!! info "内核同页合并定义"

    内核同页合并 (KSM) 允许内存重复数据删除。 KSM 尝试找到相同的内存页并将它们合并以释放内存。

## 通过 KubeVirt CR 启用 KSM

可以通过 KubeVirt CR 中的 `spec.configuration.ksmConfiguration` 在节点上启用 KSM。 `ksmConfiguration` 指示将在哪些节点上启用 KSM，从而公开 `nodeLabelSelector`。

`nodeLabelSelector` 是一个 `LabelSelector`，并根据节点标签定义过滤器。 如果节点的标签与标签选择器术语匹配，则在该节点上将启用 KSM。

!!! note "备注"

    - 如果 `nodeLabelSelector` 为`nil`，则不会在任何节点上启用 KSM。
    - 空的`nodeLabelSelector`将在每个节点上启用KSM。

让我们看几个例子：

!!! example "启用KSM的例子"

    - 在主机名为`node01`或`node03`的节点上启用KSM：
          ```yaml
          spec:
            configuration:
              ksmConfiguration:
                nodeLabelSelector:
                  matchExpressions:
                    - key: kubernetes.io/hostname
                      operator: In
                      values:
                        - node01
                        - node03
          ```
    - 在带有标签 `kubevirt.io/first-label: true、kubevirt.io/second-label: true` 的节点上启用 KSM：
          ```yaml
          spec:
            configuration:
              ksmConfiguration:
                nodeLabelSelector:
                  matchLabels:
                    kubevirt.io/first-label: "true"
                    kubevirt.io/second-label: "true"
          ```
    - 在每个节点上启用KSM:
          ```yaml
          spec:
            configuration:
              ksmConfiguration:
                nodeLabelSelector: {}
          ```

## 注解和恢复机制

在 kubeVirt 通过配置启用 KSM 的节点上，将添加注释 (`kubevirt.io/ksm-handler-management`)。 该注释是一个内部记录，用于跟踪哪些节点当前由 virt-handler 管理，以便在将来 ksmConfiguration 更改时可以区分应恢复哪些节点。

让我们想象一下这个场景：

1. 集群中有 3 个节点，其中一个（`node01`）已外部启用 KSM。
2. 管理员修补 KubeVirt CR，添加 ksmConfiguration，为 `node02` 和 `node03` 启用 ksm。
3. 一段时间后，管理员再次修补 KubeVirt CR，删除 ksmConfiguration。

由于该注释，virt-handler 能够仅在其本身已启用的节点（`node02`、`node03`）上禁用 ksm，而其他节点保持不变（`node01`）。

## 节点打标签

kubeVirt 可以发现哪些节点启用了 KSM，并将使用值为 `true` 的特殊标签 (`kubevirt.io/ksm-enabled`) 来标记它们。 该标签可用于调度启用或未启用 KSM 的节点中的虚拟机。

```yaml linenums="1"
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: testvm
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/vm: testvm
    spec:
      nodeSelector:
        kubevirt.io/ksm-enabled: "true"
      [...]
```
