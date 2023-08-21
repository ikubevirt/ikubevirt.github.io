
`VirtualMachineInstancePresets` 是一般 `VirtualMachineInstance` 配置的扩展，其行为与 Kubernetes 中的 `PodPresets` 非常相似。 创建 `VirtualMachineInstance` 时，任何适用的 `VirtualMachineInstancePresets` 将应用于 `VirtualMachineInstance` 的现有规范。 这允许重复使用应用于多个 `VirtualMachineInstances` 的通用设置。

## 执行逻辑

`VirtualMachineInstancePresets` 在处理 `VirtualMachineInstance` 资源时尽早应用。 这意味着 `VirtualMachineInstance` 资源在被 KubeVirt 的任何其他组件处理之前被修改。

一旦 `VirtualMachineInstancePreset` 成功应用于 `VirtualMachineInstance`，`VirtualMachineInstance` 将被标记一个注释以表明它已被应用。 如果在应用 `VirtualMachineInstancePreset` 时发生冲突，则 `VirtualMachineInstancePreset` 的该部分将被跳过。


## 创建和使用

KubeVirt 使用 Kubernetes 标签和选择器来确定哪些 `VirtualMachineInstancePresets` 适用于任何给定的 `VirtualMachineInstance`，类似于 `PodPresets` 在 Kubernetes 中的工作方式。 成功完成后，`VirtualMachineInstance` 会标有注释。

任何域结构都可以在 `VirtualMachineInstancePreset` 的规范中列出。 例如 时钟、功能、内存、CPU 或网络接口等设备。 `VirtualMachineInstancePreset` 的规范部分的所有元素都将应用于 `VirtualMachineInstance`。

`VirtualMachineInstancePresets` 是命名空间资源，因此应在与使用它们的 `VirtualMachineInstances` 相同的命名空间中创建：

```bash
kubectl create -f <预设>.yaml [--namespace <命名空间>]
```

KubeVirt 将通过匹配标签来确定哪些 `VirtualMachineInstancePresets` 应用于特定的 `VirtualMachineInstance`。 例如：

```yaml linenums="1"
kind: VirtualMachineInstancePreset
metadata:
  name: example-preset
spec:
  selector:
    matchLabels:
      kubevirt.io/flavor: foo
  ...
```

将匹配同一命名空间中标签为 `kubevirt.io/flavor: foo` 的任何 `VirtualMachineInstance`。 例如：

```yaml linenums="1"
kind: VirtualMachineInstance
version: v1
metadata:
  name: myvm
  labels:
    kubevirt.io/flavor: foo
  ...
```

## 排除vmiPreset

由于 `VirtualMachineInstancePresets` 使用选择器来指示其设置应应用于哪些 `VirtualMachineInstances`，因此需要存在一种机制，`VirtualMachineInstances` 可以通过该机制完全选择退出 `VirtualMachineInstancePresets`。 这是使用注释完成的：

```yaml linenums="1"
kind: VirtualMachineInstance
version: v1
metadata:
  name: myvm
  annotations:
    virtualmachinepresets.admission.kubevirt.io/exclude: "true"
  ...
```