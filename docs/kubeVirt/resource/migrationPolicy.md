# MigrationPolicy

!!! info "migrationPolicy定义"

    `migrationPolicy`提供了一种将迁移配置应用到虚拟机的新方法。 这些策略可以细化 KubeVirt CR 的 `MigrationConfiguration`，用于设置集群范围的迁移配置。 这样，集群范围的设置就可以作为默认设置，可以通过`migrationPolicy`进行细化（即更改、删除或添加）。

## 概述

kubeVirt 支持虚拟机工作负载的实时迁移。 在引入`migrationPolicy`之前，只能通过编辑 kubeVirt CR 的规范或更具体地说 `MigrationConfiguration` CRD 在集群范围内配置迁移设置。

可以自定义的迁移行为的几个方面（尽管不是全部）包括： 

- 带宽 
- 自动收敛 
- 后/预复制 
- 并行迁移的最大数量 
- 超时

`migrationPolicy`概括了定义迁移配置的概念，因此可以将不同的配置应用于特定的虚拟机组。

这种功能对于许多需要区分不同工作负载的不同用例非常有用。 可能需要区分不同的配置，因为不同的工作负载被认为具有不同的优先级、安全隔离、具有不同要求的工作负载、有助于聚合不适合迁移的工作负载以及许多其他原因。

## MigrationPolicy使用

目前，`migrationPolicy` 规范仅包含 KubeVirt CR 的 `MigrationConfiguration` 中的以下配置（将来会添加更多不属于 KubeVirt CR 的配置）：

```yaml linenums="1"
apiVersion: migrations.kubevirt.io/v1alpha1
kind: MigrationPolicy
spec:
    allowAutoConverge: true
    bandwidthPerMigration: 217Ki
    completionTimeoutPerGiB: 23
    allowPostCopy: false
```

以上所有字段都是可选的。 省略时，配置将按照 KubeVirt CR 的 `MigrationConfiguration` 中的定义应用。 这样，KubeVirt CR 将充当未绑定到任何 `MigrationPolicy` 的 VM 和绑定到未定义配置的所有字段的 `MigrationPolicy` 的 VM 的一组可配置默认值。
