
## 概述

对象传输 API 允许在命名空间之间逻辑移动 `PersistentVolumeClaims` 和 `DataVolume`。 它通过维护 Kubernetes API 资源来实现此目的，并且不会移动卷上的任何物理数据。 此 API 由 CDI 控制器内部使用，以促进 `DataVolume` 的高效跨命名空间克隆。 集群管理员还可以直接使用对象传输 API。 鉴于以下清单：

```yaml linenums="1"
apiVersion: cdi.kubevirt.io/v1beta1
kind: ObjectTransfer
metadata:
  name: t1
spec:
  source:
    kind: PersistentVolumeClaim
    namespace: source
    name: source-pvc
  target:
    namespace: destintation
    name: destination-pvc
```

命名空间源中的 PersistentVolumeClaim `source-pvc` 将移动到具有给定名称`destination-pvc` 的命名空间目标。

!!! note "备注"

    请注意，这是集群范围的资源。


## 传输操作

执行上面的`ObjectTransfer`时会发生以下操作：

1. 如果尚未将绑定到 (`source-pv`) 的 PersistentVolume `source-pvc` 设置为 `Retain`
2. `source-pvc` 已删除
3. `source-pv` ClaimRef 设置为`destination\destination-pvc`
4. 删除之前使用与`source-pvc` 相同的规格创建`destination-pvc`
