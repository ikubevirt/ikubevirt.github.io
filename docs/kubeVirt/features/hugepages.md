
用户可以指定可选的资源请求，以允许调度程序在找到最合适的节点来放置虚拟机时做出更好的决策。

```yaml linenums="1"
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
metadata:
  name: myvmi
spec:
  domain:
    resources:
      requests:
        memory: "1Gi"
        cpu: "1"
      limits:
        memory: "2Gi"
        cpu: "2"
      disks:
      - name: myimage
        disk: {}
  volumes:
    - name: myimage
      persistentVolumeClaim:
        claimname: myclaim
```

## CPU

指定 CPU 限制将确定在运行 VM 的控制组上设置的 `cpu` 份额数量，换句话说，当存在 CPU 资源竞争时，VM 的 CPU 可以在分配的资源上执行的时间量。

## 内存开销

各种 VM 资源（例如视频适配器、IOThread 和补充系统软件）会消耗节点的额外内存，超出用于来宾操作系统消耗的请求内存。 为了给调度程序提供更好的估计，将计算此内存开销并将其添加到所请求的内存中。

## 大页内存

KubeVirt 使您可以使用大页作为虚拟机的后备内存。 您需要提供所需的内存资源量 `resources.requests.memory` 和大页的大小才能使用 `memory.hugepages.pageSize`，例如，对于 `x86_64` 架构，它可以是 `2Mi`。

```yaml linenums="1"
apiVersion: kubevirt.io/v1alpha1
kind: VirtualMachine
metadata:
  name: myvm
spec:
  domain:
    resources:
      requests:
        memory: "64Mi"
    memory:
      hugepages:
        pageSize: "2Mi"
    disks:
    - name: myimage
      disk: {}
  volumes:
    - name: myimage
      persistentVolumeClaim:
        claimname: myclaim
```
在上面的示例中，VM 将拥有 `64Mi` 内存，但它将使用大小为 `2Mi` 的节点大页，而不是常规内存。

### 限制

- 节点必须预先分配大页
- 大页的大小不能大于请求的内存
- 请求的内存必须能被大页大小整除
- `Hugepages` 默认使用 `memfd`。 `Memfd` 从内核 `>= 4.14` 开始受支持。 如果您在较旧的主机上运行（例如 `centos 7.9`），则需要在 VMI 元数据注释中使用注释 `kubevirt.io/memfd: "false"` 来禁用 `memfd`。
