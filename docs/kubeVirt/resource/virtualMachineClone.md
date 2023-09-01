## 先决条件

### snapshot 和 restore

从底层方面看，`clone` API 依赖于`snapshot`和`restore` API。 因此，为了能够使用`clone` API，请参阅[snapshot](./virtualMachineSnapshot.md)和[restore](./virtualMachineRestore.md)先决条件。

### 快照特性门控

目前，`clone` API 由`snapshot`特性门控保护。 KubeVirt CR 中的`feature gates`字段必须通过添加快照来扩展。

## Clone 对象

首先，如上所述，`clone` API 依赖于底层的`snapshot`和`restore` API。 因此，查看`snapshot`和`restore`用户指南页面以获取更多信息可能会有所帮助。

### vmClone 对象概述

为了启动克隆，需要在集群上创建 `VirtualMachineClone` 对象 (CRD)。 这种对象的一个例子是：

!!! example "vmClone例子"

    ```yaml linenums="1"
    apiVersion: "clone.kubevirt.io/v1alpha1"
    kind: VirtualMachineClone
    metadata:
      name: testclone
    
    spec:
      # source & target definitions
      source:
        apiGroup: kubevirt.io
        kind: VirtualMachine
        name: vm-cirros
      target:
        apiGroup: kubevirt.io
        kind: VirtualMachine
        name: vm-clone-target
    
      # labels & annotations definitions
      labelFilters:
        - "*"
        - "!someKey/*"
      annotationFilters:
        - "anotherKey/*"
    
      # other identity stripping specs:
      newMacAddresses:
        interfaceName: "00-11-22"
      newSMBiosSerial: "new-serial"
    ```

#### source 和 target

`source`和`target`表示`source`/`target` API 组、种类和名称。 一些重要的注意事项：

- 目前，唯一支持的类型是 `VirtualMachine`（属于 `kubevirt.io` api 组）和 `VirtualMachineSnapshot`（属于 `snapshot.kubevirt.io` api 组），但预计将来会支持更多类型。 有关详细信息，请参阅下面的“未来路线图”。

- `target`名称是可选的。 如果未指定，克隆控制器将自动为`target`生成名称。

- `target`和`source`必须位于同一命名空间中。

#### label 和 annotation filters 

这些规范字段旨在确定哪些`label/annotations`被复制到目标或被剥离。

过滤器是字符串列表。 每个字符串代表源中可能存在的一个键。 与这些值之一匹配的每个源密钥都将被复制到克隆的目标。 此外，还可以使用特殊的类似正则表达式的字符：

- 通配符 `(*)` 可用于匹配任何内容。 通配符只能用在过滤器的末尾。
- 这些过滤器有效：
    - `"*"`
    - `"some/key*"`
- 这些过滤器无效：
    - `"some/*/key"`
    - `"*/key"`
- 否定字符 `(!)` 可用于避免匹配某些键。 否定只能用在过滤器的开头。 请注意，否定和通配符可以一起使用。
- 这些过滤器有效：
    - `"!some/key"`
    - `"!some/*"`
- 这些过滤器无效：
    - `"key!"`
    - `"some/!key"`

设置`label/annotation`过滤器是可选的。 如果未设置，则默认复制所有`label/annotations`。

#### newMacAddresses

该字段用于显式替换某些接口的 MAC 地址。 该字段是字符串到字符串的映射； 键代表接口名称，值代表克隆目标的新 MAC 地址。

该字段是可选的。 默认情况下，所有 MAC 地址都会被删除。 这适合在集群中部署 `kube-mac-pool` 时的情况，该集群会自动为目标分配新的有效 MAC 地址。

#### newSMBiosSerial

该字段用于显式设置目标的 SMBios 串行。

该字段是可选的。 默认情况下，目标将具有基于虚拟机名称自动生成的序列号。

### 创建 vmClone 对象

`clone`清单准备好后，我们可以创建它：

```bash
kubectl create -f clone.yaml
```

要等待`clone`完成，请执行：
```bash
kubectl wait vmclone testclone --for condition=Ready
```

您可以在`clone`状态中检查`clone`的阶段。 它可以是以下之一：

- `Progressing`
- `Succeeded`

`clone`完成后，可以检查`target`：

```bash
kubectl get vm vm-clone-target -o yaml
```


