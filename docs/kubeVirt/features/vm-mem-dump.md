
kubeVirt 现在支持获取 VM 内存转储以进行分析。 内存转储可用于诊断、识别和解决虚拟机中的问题。 通常提供有关程序、应用程序和系统终止或崩溃之前的最后状态的信息。

!!! note "备注"

    此内存转储不用于保存虚拟机状态并在以后恢复。

## 先决条件

### 热插拔门控

内存转储进程将 PVC 安装到 virt-launcher，以便获取该 PVC 中的输出，因此必须启用热插拔卷功能门。 KubeVirt CR 中的功能门字段必须通过添加 `HotplugVolumes` 来扩展。

## virtctl 支持

### 获取内存转储

现在假设我们有一个正在运行的虚拟机，并且该虚拟机的名称是"my-vm"。 我们可以转储到现有的 pvc，或者请求创建一个。

#### 现有 PVC

PVC 的大小必须足够大以容纳内存转储。 计算公式为 `(VMMemorySize + 100Mi) * FileSystemOverhead`，其中 `VMMemorySize` 是内存大小，`100Mi` 是为内存转储开销保留的空间，`FileSystemOverhead` 是用于根据文件系统开销调整请求的 PVC 大小的值。 PVC 还必须具有文件系统卷模式。

例如：

!!! example "PVC例子"

    ```yaml linenums="1"
    apiVersion: v1
    kind: PersistentVolumeClaim
    metadata:
      name: my-pvc
    spec:
      accessModes:
        - ReadWriteOnce
      resources:
        requests:
          storage: 2Gi
      storageClassName: rook-ceph-block
      volumeMode: Filesystem
    ```

我们可以使用 virtctl 提供的`memory-dump get`命令将 VM 的内存转储到 PVC，

```bash linenums="1"
$ virtctl memory-dump get my-vm --claim-name=my-pvc
```

#### 按需 PVC

对于按需 PVC，我们需要在 virtctl 请求中添加 `--create-claim` 标志：

```bash linenums="1"
$ virtctl memory-dump get my-vm --claim-name=new-pvc --create-claim
```

将创建大小足以容纳转储的 PVC。 我们还可以使用适当的标志来请求特定的存储类别和访问模式。

#### 下载内存转储

通过添加 `--output` 标志，内存将转储到 PVC，然后下载到给定的输出路径。

```bash linenums="1"
$ virtctl memory-dump get myvm --claim-name=memoryvolume --create-claim --output=memoryDump.dump.gz
```

要从与 VM 关联的 PVC 下载最后的内存转储而不触发另一个内存转储，请使用内存转储下载命令。

```bash linenums="1"
$ virtctl memory-dump download myvm --output=memoryDump.dump.gz
```

要从已与 VM 解除关联的 PVC 下载内存转储，可以使用 `virtctl vmexport` 命令。

### 监控内存转储


