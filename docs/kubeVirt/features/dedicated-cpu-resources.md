
某些在执行过程中需要可预测延迟和增强性能的工作负载将受益于获得专用 CPU 资源。 KubeVirt 依赖 Kubernetes CPU 管理器，能够将客户机的 vCPU 固定到主机的 pCPU。

## Kubernetes CPU 管理器

Kubernetes CPU 管理器是一种影响工作负载调度的机制，如果满足以下要求，则将其放置在可以分配`Guaranteed`资源并将某些 Pod 容器固定到托管 pCPU 的主机上：

- Pod 的 QoS 有保证
    - 资源请求和限制是相等的
    - Pod 中的所有容器都表达了 CPU 和内存需求
- 请求的 CPU 数量是一个整数

附加信息：

- [在 Kubernetes 上启用 CPU 管理器](https://kubernetes.io/docs/tasks/administer-cluster/cpu-management-policies/)
- [在 OKD 上启用 CPU 管理器](https://docs.openshift.com/container-platform/4.10/scalability_and_performance/using-cpu-manager.html)
- [Kubernetes 博客解释该功能](https://kubernetes.io/blog/2018/07/24/feature-highlight-cpu-manager/)


## 申请专用CPU资源

在 VMI 规范中将 `spec.domain.cpu.dedicatedCpuPlacement` 设置为 `true` 将表示希望将专用 CPU 资源分配给 VMI

Kubevirt 将验证是否满足所有必要条件，以便 Kubernetes CPU 管理器将 virt-launcher 容器固定到专用主机 CPU。 一旦 virt-launcher 运行，VMI 的 vCPU 将固定到专用于 virt-launcher 容器的 `pCPUS`。

可以通过将`spec.domain.cpu`（套接字、核心、线程）或`spec.domain.resources.requests/limits.cpu`中的来宾拓扑设置为整数（`[ 1-9]+`) 指示为 VMI 请求的 vCPU 数量。 vCPU 的数量计算为套接字 * 核心 * 线程，或者如果`spec.domain.cpu` 为空，则它从`spec.domain.resources.requests.cpu` 或`spec.domain.resources.limits.cpu` 获取值。

!!! note "备注"

    - 用户不应同时指定`spec.domain.cpu`和`spec.domain.resources.requests/limits.cpu`
    - `spec.domain.resources.requests.cpu`必须等于`spec.domain.resources.limits.cpu`
    - 使用`spec.domain.cpu.sockets` 而不是`spec.domain.cpu.cores` 时，多个CPU 绑定的微基准测试显示出显着的性能优势。

所有不一致的要求都将被拒绝。

```yaml linenums="1"
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
spec:
  domain:
    cpu:
      sockets: 2
      cores: 1
      threads: 1
      dedicatedCpuPlacement: true
    resources:
      limits:
        memory: 2Gi
...
```
或者
```yaml linenums="1"
apiVersion: kubevirt.io/v1
kind: VirtualMachineInstance
spec:
  domain:
    cpu:
      dedicatedCpuPlacement: true
    resources:
      limits:
        cpu: 2
        memory: 2Gi
...
```

## 为 QEMU 模拟器申请专用 CPU

许多 QEMU 线程（例如 QEMU 主事件循环、异步 I/O 操作完成等）也在与 VMI 的 vCPU 相同的物理 CPU 上执行。 这可能会影响 vCPU 的预期延迟。 为了增强 KubeVirt 中的实时支持并改善延迟，KubeVirt 将分配一个额外的专用 CPU，专门用于将其固定的模拟器线程。 这将有效地将模拟器线程与 VMI 的 vCPU“隔离”。 如果 `ioThreadsPolicy` 设置为 `auto`，`IOThreads` 也将被“隔离”并放置在与 QEMU 仿真器线程相同的物理 CPU 上。

可以通过在 VMI 规范的 `Spec.Domain.CPU` 部分中指定`isolateEmulatorThread: true` 来启用此功能。 当然，这个设置必须与`dicatedCpuPlacement: true` 结合起来指定。

!!! example "例子"

    ```yaml linenums="1"
    apiVersion: kubevirt.io/v1
    kind: VirtualMachineInstance
    spec:
      domain:
        cpu:
          dedicatedCpuPlacement: true
          isolateEmulatorThread: true
        resources:
          limits:
            cpu: 2
            memory: 2Gi
    ```
