
KubeVirt 为实例类型提供了两种 CRD：集群范围的 `VirtualMachineClusterInstancetype` 和具体命名空间下的 `VirtualMachineInstancetype`。 这些 CRD 通过共享 `VirtualMachineInstancetypeSpec` 封装了 VirtualMachine 的以下资源相关特征：

| <div style="width:280px">`VirtualMachineInstancetypeSpec`参数</div> | 描述                        |
|:------------------------------------------------------------------|:--------------------------|
| `CPU`                                                             | 提供给`guest`的所需 vCPU 数量     |
| `Memory`                                                          | 提供给`guest`所需的内存量          |
| `GPUs`                                                            | 要直通的可选 vGPU 列表            |
| `HostDevices`                                                     | 要直通的主机设备的可选列表             |
| `IOThreadsPolicy`                                                 | 要使用的`IOThreadsPolicy`（可选） |
| `LaunchSecurity`                                                  | 要使用的`LaunchSecurity`（可选）  |

例如:

```yaml linenums="1"
apiVersion: instancetype.kubevirt.io/v1beta1
kind: VirtualMachineInstancetype
metadata:
  name: example-instancetype
spec:
  cpu:
    guest: 1
  memory:
    guest: 128Mi
```

实例类型中提供的任何内容都不能在虚拟机中覆盖。 例如，由于`CPU`和`Memory`都是实例类型的必需属性，如果用户在底层`VirtualMachine`中请求`CPU`或`Memory`资源，实例类型将发生冲突，并且在创建过程中请求将被拒绝。
