# VirtualMachineExport

您可能需要将虚拟机及其相关磁盘从集群中导出，以便您可以将该虚拟机导入到另一个系统或集群中。 虚拟机磁盘是您想要导出的最重要的内容。 导出 API 可以以声明方式导出虚拟机磁盘。 还可以导出单个 PVC 及其内容，例如当您从虚拟机创建内存转储或使用 `virtio-fs` 让虚拟机填充 PVC 时。

为了不使 kubernetes API 服务器过载，数据通过专用的导出代理服务器传输。 然后，代理服务器可以通过与 `Ingress/Route` 或 `NodePort` 关联的服务向外界发布。

## Export 特性门控

必须在特性门控中启用 `VMExport` 支持才能可用。 KubeVirt CR 中的`feature gates`字段必须通过添加 `VMExport` 来扩展。

## Export token

为了安全地导出虚拟机磁盘，您必须创建一个用于授权用户访问导出端点的`token`。 此令牌必须与虚拟机位于同一命名空间中。 密钥的内容可以作为`token`标头或参数传递到导出 URL。 标头或参数的名称是 `x-kubevirt-export-token`，其值与密钥的内容匹配。 该秘密可以命名为命名空间中的任何有效秘密。 我们建议您生成至少 12 个字符的字母数字标记。 数据密钥应该是`token`。 例如：

```yaml linenums="1"
apiVersion: v1
kind: Secret
metadata:
  name: example-token
stringData:
  token: 1234567890ab
```

## 导出虚拟机卷

创建`token`后，您现在可以创建一个 VMExport CR 来标识要导出的虚拟机。 您可以创建如下所示的 `VMExport`：

```yaml linenums="1"
apiVersion: export.kubevirt.io/v1alpha1
kind: VirtualMachineExport
metadata:
  name: example-export
spec:
  tokenSecretRef: example-token
  source:
    apiGroup: "kubevirt.io"
    kind: VirtualMachine
    name: example-vm
```

将导出 VM 中存在的以下卷：

- PVC
- DataVolumes
- 内存转储

不会导出所有其他卷类型。 为了避免导出不一致的数据，虚拟机只能在关闭电源时导出。 如果虚拟机启动，任何活动的 VM 导出都将终止。 要从正在运行的虚拟机导出数据，您必须首先创建虚拟机快照（见下文）。

如果 VM 包含多个可导出的卷，则每个卷将获得自己的 URL 链接。 如果 VM 不包含可导出的卷，`VMExport` 将进入“跳过”阶段，并且不会启动导出服务器。

## 导出虚拟机快照卷

您可以创建一个 VMExport CR 来标识要导出的虚拟机快照。 您可以创建如下所示的 `VMExport`：

```yaml linenums="1"
apiVersion: export.kubevirt.io/v1alpha1
kind: VirtualMachineExport
metadata:
  name: example-export
spec:
  tokenSecretRef: example-token
  source:
    apiGroup: "snapshot.kubevirt.io"
    kind: VirtualMachineSnapshot
    name: example-vmsnapshot
```

当您基于虚拟机快照创建 `VMExport` 时，控制器将尝试从虚拟机快照中包含的卷快照创建 PVC。 一旦所有 PVC 准备就绪，导出服务器将启动，您可以开始导出。 如果虚拟机快照包含多个可导出的卷，则每个卷将获得自己的 URL 链接。 如果虚拟机快照不包含可导出的卷，`VMExport` 将进入跳过阶段，并且不会启动导出服务器。

## 导出PVC

您可以创建一个 VMExport CR 来标识要导出的持久卷声明 (PVC)。 您可以创建如下所示的 `VMExport`：

```yaml linenums="1"
apiVersion: export.kubevirt.io/v1alpha1
kind: VirtualMachineExport
metadata:
  name: example-export
spec:
  tokenSecretRef: example-token
  source:
    apiGroup: ""
    kind: PersistentVolumeClaim
    name: example-pvc
```

在此示例中，PVC 名称为 `example-pvc`。 请注意，PVC 不需要包含虚拟机磁盘，它可以包含任何内容，但主要用例是导出虚拟机磁盘。 将此 yaml 发布到集群后，将在与 PVC 相同的命名空间中创建一个新的导出服务器。 如果源 PVC 正在被另一个 pod（例如 virt-launcher pod）使用，则导出将保持挂起状态，直到 PVC 不再使用。 如果导出器服务器处于活动状态并且另一个 pod 开始使用 PVC，则导出器服务器将被终止，直到 PVC 不再使用。

## 导出状态链接

`VirtualMachineExport` CR 将包含带有导出服务的内部和外部链接的状态。 内部链接仅在集群内部有效，外部链接仅对通过 Ingress 或 Route 的外部访问有效。 `cert` 字段将包含签署内部链接导出服务器证书的 CA，或签署路由或入口的 CA。
