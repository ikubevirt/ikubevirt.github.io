# VirtualMachinePool

## 什么是 VirtualMachinePool

!!! info "VirtualMachinePool定义"

    VirtualMachinePool 尝试确保指定数量的 VirtualMachine 副本及其各自的 VirtualMachineInstance 随时处于就绪状态。 换句话说，VirtualMachinePool 可确保一个 VirtualMachine 或一组 VirtualMachine 始终处于启动状态并准备就绪。

不保留任何状态，也不保证任何时候运行的 VirtualMachineInstance 副本的最大数量。 例如，

!!! example "例子"

    如果仍在运行的虚拟机可能进入未知状态，则 VirtualMachinePool 可能会决定创建新副本。


## VirtualMachinePool 使用

VirtualMachinePool 允许我们在`spec.virtualMachineTemplate` 中指定`VirtualMachineTemplate`。 它由`spec.virtualMachineTemplate.metadata`中的`ObjectMetadata和spec.virtualMachineTemplate.spec`中的`VirtualMachineSpec`组成。 虚拟机的规格等于VirtualMachine工作负载中虚拟机的规格。

`spec.replicas` 可用于指定需要多少个副本。 如果未指定，则默认值为 1。该值可以随时更新。 控制器将对变化做出反应。

控制器使用`spec.selector` 来跟踪托管虚拟机。 此处指定的选择器必须能够与 `spec.virtualMachineTemplate.metadata.labels` 中指定的虚拟机标签匹配。 如果选择器与这些标签不匹配，或者它们为空，则控制器除了记录错误之外将不执行任何操作。 用户负责避免创建可能与选择器和模板标签冲突的其他虚拟机或 VirtualMachinePools。


### 创建 VirtualMachinePool

`VirtualMachinePool` 是 Kubevirt API `pool.kubevirt.io/v1alpha1` 的一部分。以下是创建`VirtualMachinePool`的示例，

//// collapse-code
```yaml title="vm-pool-cirros.yaml"
apiVersion: pool.kubevirt.io/v1alpha1
kind: VirtualMachinePool
metadata:
  name: vm-pool-cirros
spec:
  replicas: 3
  selector:
    matchLabels:
      kubevirt.io/vmpool: vm-pool-cirros
  virtualMachineTemplate:
    metadata:
      creationTimestamp: null
      labels:
        kubevirt.io/vmpool: vm-pool-cirros
    spec:
      running: true
      template:
        metadata:
          creationTimestamp: null
          labels:
            kubevirt.io/vmpool: vm-pool-cirros
        spec:
          domain:
            devices:
              disks:
              - disk:
                  bus: virtio
                name: containerdisk
            resources:
              requests:
                memory: 128Mi
          terminationGracePeriodSeconds: 0
          volumes:
          - containerDisk:
              image: kubevirt/cirros-container-disk-demo:latest
            name: containerdisk
```
////

提交上述资源清单文件，

//// collapse-code
```bash
$ kubectl create -f vm-pool-cirros.yaml
virtualmachinepool.pool.kubevirt.io/vm-pool-cirros created
$ kubectl describe vmpool vm-pool-cirros
Name:         vm-pool-cirros
Namespace:    default
Labels:       <none>
Annotations:  <none>
API Version:  pool.kubevirt.io/v1alpha1
Kind:         VirtualMachinePool
Metadata:
  Creation Timestamp:  2023-02-09T18:30:08Z
  Generation:          1
    Manager:      kubectl-create
    Operation:    Update
    Time:         2023-02-09T18:30:08Z
    API Version:  pool.kubevirt.io/v1alpha1
    Fields Type:  FieldsV1
    fieldsV1:
      f:status:
        .:
        f:labelSelector:
        f:readyReplicas:
        f:replicas:
    Manager:         virt-controller
    Operation:       Update
    Subresource:     status
    Time:            2023-02-09T18:30:44Z
  Resource Version:  6606
  UID:               ba51daf4-f99f-433c-89e5-93f39bc9989d
Spec:
  Replicas:  3
  Selector:
    Match Labels:
      kubevirt.io/vmpool:  vm-pool-cirros
  Virtual Machine Template:
    Metadata:
      Creation Timestamp:  <nil>
      Labels:
        kubevirt.io/vmpool:  vm-pool-cirros
    Spec:
      Running:  true
      Template:
        Metadata:
          Creation Timestamp:  <nil>
          Labels:
            kubevirt.io/vmpool:  vm-pool-cirros
        Spec:
          Domain:
            Devices:
              Disks:
                Disk:
                  Bus:  virtio
                Name:   containerdisk
            Resources:
              Requests:
                Memory:                      128Mi
          Termination Grace Period Seconds:  0
          Volumes:
            Container Disk:
              Image:  kubevirt/cirros-container-disk-demo:latest
            Name:     containerdisk
Status:
  Label Selector:  kubevirt.io/vmpool=vm-pool-cirros
  Ready Replicas:  2
  Replicas:        3
Events:
  Type    Reason            Age   From                           Message
  ----    ------            ----  ----                           -------
  Normal  SuccessfulCreate  17s   virtualmachinepool-controller  Created VM default/vm-pool-cirros-0
  Normal  SuccessfulCreate  17s   virtualmachinepool-controller  Created VM default/vm-pool-cirros-2
  Normal  SuccessfulCreate  17s   virtualmachinepool-controller  Created VM default/vm-pool-cirros-1
```
////

`Replicas` 为 3，`Ready Replicas` 为 2。这意味着在显示状态时，已经创建了三个虚拟机，但只有两个正在运行并准备就绪。

### 通过 Scale Subresource 伸缩

`VirtualMachinePool` 支持Scale Subresource。 因此，可以通过 `kubectl` 对其进行伸缩。

```bash linenums="1"
$ kubectl scale vmpool vm-pool-cirros --replicas 5
```

### 从 VirtualMachinePool 中删除 VirtualMachine

从 `VirtualMachinePool` 中删除 `VirtualMachine`这种情况下，需要从虚拟机中删除`ownerReferences`。 这可以通过使用 `kubectl edit` 或 `kubectl patch` 来实现。 使用 `kubectl` 补丁，如下：

```bash linenums="1"
kubectl patch vm vm-pool-cirros-0 --type merge --patch '{"metadata":{"ownerReferences":null}}'
```

!!! note 

    您可能需要更新虚拟机标签label以避免对选择器selector产生影响。


### HPA使用

HorizontalPodAutoscaler (HPA) 可以与 `VirtualMachinePool` 一起使用。 只需在`Spec`中引用它即可：

```yaml linenums="1"
apiVersion: autoscaling/v1
kind: HorizontalPodAutoscaler
metadata:
  creationTimestamp: null
  name: vm-pool-cirros
spec:
  maxReplicas: 10
  minReplicas: 3
  scaleTargetRef:
    apiVersion: pool.kubevirt.io/v1alpha1
    kind: VirtualMachinePool
    name: vm-pool-cirros
  targetCPUUtilizationPercentage: 50
```

或者使用 `kubectl autoscale` 通过命令行定义 HPA：

```bash linenums="1"
$ kubectl autoscale vmpool vm-pool-cirros --min=3 --max=10 --cpu-percent=50
```

## 将 VirtualMachinePool 作为服务暴露

`VirtualMachinePool` 可以作为服务暴露。 完成此操作后，将选择一个虚拟机副本来实际交付服务。

例如，将 `SSH` 端口 (22) 暴露为 `ClusterIP` 服务：

```yaml linenums="1" title="vm-pool-cirros-ssh.yaml"
apiVersion: v1
kind: Service
metadata:
  name: vm-pool-cirros-ssh
spec:
  type: ClusterIP
  selector:
    kubevirt.io/vmpool: vm-pool-cirros
  ports:
    - protocol: TCP
      port: 2222
      targetPort: 22
```

将此清单保存到 `vm-pool-cirros-ssh.yaml` 并将其提交到 Kubernetes 将创建侦听端口 2222 并转发到端口 22 的 `ClusterIP` 服务。

有关更多详细信息，请参阅服务对象。

## 持久化存储

在`spec.virtualMachineTemplate.spec`中使用`DataVolumeTemplates`将导致为VMPool中的每个VM创建唯一的持久存储。 当从`spec.virtualMachineTemplate.spec.dataVolumeTemplates` 创建VM 时，`DataVolumeTemplate` 名称将附加 VM 的顺序后缀。 这使得每个虚拟机成为完全独特的有状态工作负载。


