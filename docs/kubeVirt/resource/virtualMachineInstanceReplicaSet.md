# VirtualMachineInstanceReplicaSet

## 虚拟机实例弹性伸缩

!!! info "vmirs定义"

    VirtualMachineInstanceReplicaSet（vmirs）确保指定数量的 VirtualMachineInstance（vmi） 副本在任何时候都在运行。

我们可以这样理解，vmirs 就是kubernetes（k8s）里面的控制器（Deployment，ReplicaSet）管理我们pod的副本数，实现扩缩容、回滚等。也可以借助HorizontalPodAutoscaler（HPA）实现弹性伸缩。这里我们就说vmirs控制器，在这里的vmirs控制器，管理我们vmi虚拟机实例的副本数，也可以实现扩缩容，借助HPA实现弹性伸缩。所有我们的yaml文件写法原理都类似。

## 适用场景

当需要许多相同的虚拟机，并且不关心在虚拟机终止后任何磁盘状态时。

## vmirs使用

### 创建vmirs

编写vmirs的资源文件:

```yaml linenums="1" title="vmirs.yaml"
apiVersion: kubevirt.io/v1alpha3
kind: VirtualMachineInstanceReplicaSet
metadata:
  name: testreplicaset
spec:
  replicas: 2
  selector:
    matchLabels:
      myvmi: myvmi  # 保持一致，选择
  template:
    metadata:
      labels:
        myvmi: myvmi # 保持一致，匹配
    spec:
      domain:
        devices:
          disks:
          - name: containerdisk
            disk:
              bus: virtio
        resources:
          requests:
            memory: 1024M
      volumes:
      - name: containerdisk
        containerDisk:
          image: centos7
          imagePullPolicy: IfNotPresent
```

然后 `kubectl` 创建 vmirs,

```bash
[root@master vm]# kubectl apply -f vmirs.yaml
virtualmachineinstancereplicaset.kubevirt.io/testreplicaset created
```

查看运行状态，

```bash
[root@master vm]# kubectl get vmis
NAME                  AGE   PHASE        IP             NODENAME   READY
testreplicaset6vm9s   42s   Running      10.244.0.139   master     False
testreplicaset8dshm   22s   Scheduling                             False
testreplicasetbqxnb   22s   Scheduling                             False
[root@master vm]# kubectl get vmis
NAME                  AGE   PHASE     IP             NODENAME   READY
testreplicaset8dshm   46s   Running   10.244.0.141   master     False
testreplicasetbqxnb   46s   Running   10.244.0.140   master     False
[root@master vm]# kubectl get pod
NAME                                      READY   STATUS    RESTARTS   AGE
virt-launcher-testreplicaset8dshm-nz7x2   2/2     Running   0          69s
virt-launcher-testreplicasetbqxnb-ljp2f   2/2     Running   0          70s
```

`describe` 查看详细信息,

//// collapse-code
```bash
[root@master vm]# kubectl describe vmirs testreplicaset
Name:         testreplicaset
Namespace:    default
Labels:       <none>
Annotations:  kubevirt.io/latest-observed-api-version: v1
              kubevirt.io/storage-observed-api-version: v1alpha3
API Version:  kubevirt.io/v1
Kind:         VirtualMachineInstanceReplicaSet
Metadata:
  Creation Timestamp:  2022-05-02T13:50:05Z
  Generation:          2
  Managed Fields:
    API Version:  kubevirt.io/v1alpha3
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
          f:kubevirt.io/latest-observed-api-version:
          f:kubevirt.io/storage-observed-api-version:
      f:spec:
        f:template:
          f:metadata:
            f:creationTimestamp:
      f:status:
        .:
        f:labelSelector:
        f:replicas:
    Manager:      Go-http-client
    Operation:    Update
    Time:         2022-05-02T13:50:05Z
    API Version:  kubevirt.io/v1alpha3
    Fields Type:  FieldsV1
    fieldsV1:
      f:metadata:
        f:annotations:
 ...
 ...
                  .:
                  f:memory:
            f:volumes:
    Manager:         kubectl
    Operation:       Update
    Time:            2022-05-02T13:50:05Z
  Resource Version:  267261
  Self Link:         /apis/kubevirt.io/v1/namespaces/default/virtualmachineinstancereplicasets/testreplicaset
  UID:               96d17d12-17b5-4df7-940a-fac7c6b820d2
Spec:
  Replicas:  2
  Selector:
    Match Labels:
      Myvmi:  myvmi
  Template:
    Metadata:
      Creation Timestamp:  <nil>
      Labels:
        Myvmi:  myvmi
    Spec:
      Domain:
        Devices:
          Disks:
            Disk:
              Bus:  virtio
            Name:   containerdisk
        Resources:
          Requests:
            Memory:  1024M
      Volumes:
        Container Disk:
          Image:              kubevirt/cirros-container-disk-demo
          Image Pull Policy:  IfNotPresent
        Name:                 containerdisk
Status:
  Label Selector:  myvmi=myvmi
  Replicas:        2
Events:
  Type    Reason            Age    From                                 Message
  ----    ------            ----   ----                                 -------
  Normal  SuccessfulCreate  5m21s  virtualmachinereplicaset-controller  Started the virtual machine by creating the new virtual machine instance testreplicaseth6zsl
  Normal  SuccessfulCreate  5m21s  virtualmachinereplicaset-controller  Started the virtual machine by creating the new virtual machine instance testreplicasetw75s4
```
////

### 扩缩容

查看 vmirs,

```bash
[root@master vm]# kubectl get -f vmis.yaml
NAME             DESIRED   CURRENT   READY   AGE
testreplicaset   3         3                 2m52s
```

使用scale命令，设置副本数为5,

```bash
[root@master vm]# kubectl scale vmirs testreplicaset --replicas 5
virtualmachineinstancereplicaset.kubevirt.io/testreplicaset scaled
```

查看效果，

```bash
[root@master vm]# kubectl get vmis
NAME                  AGE     PHASE     IP             NODENAME   READY
testreplicaset98x8d   5m29s   Running   10.244.0.146   master     False
testreplicasetddqc9   2m24s   Running   10.244.0.148   master     False
testreplicasetdss8l   5m29s   Running   10.244.0.144   master     False
testreplicasetmhm6x   5m29s   Running   10.244.0.145   master     False
testreplicasetv4dzs   2m24s   Running   10.244.0.147   master     False

[root@master vm]# kubectl get pod
NAME                                      READY   STATUS    RESTARTS   AGE
virt-launcher-testreplicaset98x8d-5p99p   2/2     Running   0          3m15s
virt-launcher-testreplicasetddqc9-6c2m4   2/2     Running   0          10s
virt-launcher-testreplicasetdss8l-9mv56   2/2     Running   0          3m15s
virt-launcher-testreplicasetmhm6x-r76wt   2/2     Running   0          3m15s
virt-launcher-testreplicasetv4dzs-bm4s8   2/2     Running   0          10s
```

### 弹性伸缩

=== "yaml文件"

    使用Horizontal Pod Autoscaler（hpa），创建yaml文件,
    
    ```yaml linenums="1" title="vmirs-hpa.yaml"
    apiVersion: autoscaling/v1
    kind: HorizontalPodAutoscaler
    metadata:
      creationTimestamp: null
      name: testreplicaset
    spec:
      maxReplicas: 5
      minReplicas: 2
      scaleTargetRef:
        apiVersion: kubevirt.io/v1
        kind: VirtualMachineInstanceReplicaSet
        name: testreplicaset
    ```
    创建vmirs-hpa，

    ```bash
    [root@master vm]# kubectl apply -f vmirs-hpa.yaml
    horizontalpodautoscaler.autoscaling/testreplicaset created
    ```

    查看状态，
    ```bash
    [root@master vm]# kubectl get hpa
    NAME             REFERENCE                                         TARGETS         MINPODS   MAXPODS   REPLICAS   AGE
    testreplicaset   VirtualMachineInstanceReplicaSet/testreplicaset   <unknown>/80%   2         5         0          7s
    ```
=== "autoscale命令"

    使用`kubectl autoscale`命令,

    ```bash
    [root@master vm]# kubectl autoscale vmirs testreplicaset --min=2 --max=5
    ```

