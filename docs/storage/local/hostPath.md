
我们上面提到了 PV 是对底层存储技术的一种抽象，PV 一般都是由管理员来创建和配置的，我们首先来创建一个 hostPath 类型的 PersistentVolume。Kubernetes 支持 hostPath 类型的 PersistentVolume 使用节点上的文件或目录来模拟附带网络的存储，但是需要注意的是在生产集群中，我们不会使用 hostPath，集群管理员会提供网络存储资源，比如 NFS 共享卷或 Ceph 存储卷，集群管理员还可以使用 StorageClasses 来设置动态提供存储。因为 Pod 并不是始终固定在某个节点上面的，所以要使用 hostPath 的话我们就需要将 Pod 固定在某个节点上，这样显然就大大降低了应用的容错性。

## 配置属性

### 存储能力和访问模式

比如我们这里将测试的应用固定在节点 `node1` 上面，首先在该节点上面创建一个 `/data/k8s/test/hostpath` 的目录，然后在该目录中创建一个 `index.html` 的文件：

```bash
$ echo 'Hello from Kubernetes hostpath storage' > /data/k8s/test/hostpath/index.html
```

然后接下来创建一个 hostPath 类型的 PV 资源对象：

```yaml linenums="1" title="pv-hostpath.yaml"
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-hostpath
  labels:
    type: local
spec:
  storageClassName: manual
  capacity:
    storage: 10Gi
  accessModes:
    - ReadWriteOnce
  hostPath:
    path: "/data/k8s/test/hostpath"
```

配置文件中指定了该卷位于集群节点上的 `/data/k8s/test/hostpath` 目录，还指定了 10G 大小的空间和 `ReadWriteOnce` 的访问模式，这意味着该卷可以在单个节点上以读写方式挂载，另外还定义了名称为 manual 的 StorageClass，该名称用来将 PersistentVolumeClaim 请求绑定到该 PersistentVolume。下面是关于 PV 的这些配置属性的一些说明：

- `Capacity`（存储能力）：一般来说，一个 PV 对象都要指定一个存储能力，通过 PV 的 capacity 属性来设置的，目前只支持存储空间的设置，就是我们这里的 `storage=10Gi`，不过未来可能会加入 IOPS、吞吐量等指标的配置。
- `AccessModes`（访问模式）：用来对 PV 进行访问模式的设置，用于描述用户应用对存储资源的访问权限，访问权限包括下面几种方式：

    - `ReadWriteOnce（RWO）`：读写权限，但是只能被单个节点挂载
    - `ReadOnlyMany（ROX）`：只读权限，可以被多个节点挂载
    - `ReadWriteMany（RWX）`：读写权限，可以被多个节点挂载


    !!! warning "注意"

        一些 PV 可能支持多种访问模式，但是在挂载的时候只能使用一种访问模式，多种访问模式是不会生效的。

      
    下图是一些常用的 Volume 插件支持的访问模式：

    ??? info "访问模式"

          | Volume Plugin          | <div style="width:135px">ReadWriteOnce</div> | <div style="width:135px">ReadOnlyMany</div> | <div style="width:135px">ReadWriteMany</div>      |
          |:-----------------------|:--------------:|:-------------:|:-------------------:|
          | `AWSElasticBlockStore` |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `AzureFile`            |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;                    |
          | `AzureDisk`            |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `CephFS`               |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;                    |
          | `Cinder`               |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `FC`                   |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `FlexVolume`           |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `Flocker`              |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `GCEPersistentDisk`    |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `Glusterfs`            |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;                    |
          | `HostPath`             |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `ISCSI`                |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `Quobyte`              |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;                    |
          | `NFS`                  |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;                    |
          | `RBD`                  |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `VsphereVolume`        |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |
          | `PortworxVolume`       |&emsp;:material-check:&emsp;|&emsp;-&emsp;             |&emsp;:material-check:&emsp;                    |
          | `ScaleIO`              |&emsp;:material-check:&emsp;|&emsp;:material-check:&emsp;|&emsp;-&emsp;                    |
          | `StorageOS`            |&emsp;:material-check:&emsp;|&emsp;-&emsp;              |&emsp;-&emsp;                    |


直接创建上面的资源对象：

```bash
$ kubectl apply -f pv-hostpath.yaml
persistentvolume/pv-hostpath created
```

创建完成后查看 PersistentVolume 的信息，输出结果显示该 PersistentVolume 的状态（STATUS） 为 `Available`。 这意味着它还没有被绑定给 PersistentVolumeClaim：

### 回收策略

```bash
$ kubectl get pv pv-hostpath
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS      CLAIM   STORAGECLASS   REASON   AGE
pv-hostpath   10Gi       RWO            Retain           Available           manual                  58s
```

其中有一项 `RECLAIM POLICY` 的配置，同样我们可以通过 PV 的 `persistentVolumeReclaimPolicy`（回收策略）属性来进行配置，目前 PV 支持的策略有三种：

- `Retain`（保留）：保留数据，需要管理员手工清理数据
- `Recycle`（回收）：清除 PV 中的数据，效果相当于执行 `rm -rf /thevolume/*`
- `Delete`（删除）：与 PV 相连的后端存储完成 volume 的删除操作，当然这常见于云服务商的存储服务，比如 ASW EBS。

不过需要注意的是，目前只有 `NFS` 和 `HostPath` 两种类型支持回收策略，当然一般来说还是设置为 `Retain` 这种策略保险一点。


!!! warning "注意"

    `Recycle` 策略会通过运行一个 busybox 容器来执行数据删除命令，默认定义的 busybox 镜像是：`gcr.io/google_containers/busybox:latest`，并且 `imagePullPolicy: Always`，如果需要调整配置，需要增加kube-controller-manager 启动参数：`--pv-recycler-pod-template-filepath-hostpath` 来进行配置。


### PV的状态

关于 PV 的状态，实际上描述的是 PV 的生命周期的某个阶段，一个 PV 的生命周期中，可能会处于4种不同的阶段：

- `Available`（可用）：表示可用状态，还未被任何 PVC 绑定
- `Bound`（已绑定）：表示 PVC 已经被 PVC 绑定
- `Released`（已释放）：PVC 被删除，但是资源还未被集群重新声明
- `Failed`（失败）： 表示该 PV 的自动回收失败

现在我们创建完成了 PV，如果我们需要使用这个 PV 的话，就需要创建一个对应的 PVC 来和他进行绑定了，就类似于我们的服务是通过 Pod 来运行的，而不是 Node，只是 Pod 跑在 Node 上而已。

## PVC绑定

现在我们来创建一个 PersistentVolumeClaim，Pod 使用 PVC 来请求物理存储，我们这里创建的 PVC 请求至少 3G 容量的卷，该卷至少可以为一个节点提供读写访问，下面是 PVC 的配置文件：

```yaml linenums="1" title="pvc-hostpath.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: pvc-hostpath
spec:
  storageClassName: manual
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 3Gi
```

同样我们可以直接创建这个 PVC 对象：

```bash
$ kubectl create -f pvc-hostpath.yaml
persistentvolumeclaim/pvc-hostpath created
```

创建 PVC 之后，Kubernetes 就会去查找满足我们声明要求的 PV，比如 `storageClassName`、`accessModes` 以及容量这些是否满足要求，如果满足要求就会将 PV 和 PVC 绑定在一起。

!!! warning "注意"

    需要注意的是目前 PV 和 PVC 之间是一对一绑定的关系，也就是说一个 PV 只能被一个 PVC 绑定。

我们现在再次查看 PV 的信息：

```bash
$ kubectl get pv -l type=local
NAME          CAPACITY   ACCESS MODES   RECLAIM POLICY   STATUS   CLAIM                  STORAGECLASS   REASON   AGE
pv-hostpath   10Gi       RWO            Retain           Bound    default/pvc-hostpath   manual                  81m
```

现在输出的 STATUS 为 `Bound`，查看 PVC 的信息：

```bash
$ kubectl get pvc pvc-hostpath
NAME           STATUS   VOLUME        CAPACITY   ACCESS MODES   STORAGECLASS   AGE
pvc-hostpath   Bound    pv-hostpath   10Gi       RWO            manual         6m47s
```

输出结果表明该 PVC 绑定了到了上面我们创建的 `pv-hostpath` 这个 PV 上面了，我们这里虽然声明的3G的容量，但是由于 PV 里面是 10G，所以显然也是满足要求的。

PVC 准备好过后，接下来我们就可以来创建 Pod 了，该 Pod 使用上面我们声明的 PVC 作为存储卷：

```yaml linenums="1" title="pv-hostpath-pod.yaml"
apiVersion: v1
kind: Pod
metadata:
  name: pv-hostpath-pod
spec:
  volumes:
  - name: pv-hostpath
    persistentVolumeClaim:
      claimName: pvc-hostpath
  nodeSelector:
    kubernetes.io/hostname: ydzs-node1
  containers:
  - name: task-pv-container
    image: nginx
    ports:
    - containerPort: 80
    volumeMounts:
    - mountPath: "/usr/share/nginx/html"
      name: pv-hostpath
```

这里需要注意的是，由于我们创建的 PV 真正的存储在节点 `node1` 上面，所以我们这里必须把 Pod 固定在这个节点下面，另外可以注意到 Pod 的配置文件指定了 PersistentVolumeClaim，但没有指定 PersistentVolume，对 Pod 而言，PVC 就是一个存储卷。直接创建这个 Pod 对象即可：


```bash
$ kubectl create -f pv-hostpath-pod.yaml
pod/pv-hostpath-pod created
$ kubectl get pod pv-hostpath-pod
NAME              READY   STATUS    RESTARTS   AGE
pv-hostpath-pod   1/1     Running   0          105s
```

运行成功后，我们可以打开一个 shell 访问 Pod 中的容器：

```bash
$ kubectl exec -it pv-hostpath-pod -- /bin/bash
```

在 shell 中，我们可以验证 nginx 的数据 是否正在从 hostPath 卷提供 `index.html` 文件：

```bash
root@pv-hostpath-pod:/# apt-get update
root@pv-hostpath-pod:/# apt-get install curl -y
root@pv-hostpath-pod:/# curl localhost
Hello from Kubernetes hostpath storage
```

我们可以看到输出结果是我们前面写到 hostPath 卷种的 `index.html` 文件中的内容，同样我们可以把 Pod 删除，然后再次重建再测试一次，可以发现内容还是我们在 hostPath 种设置的内容。

??? question "我们在持久化容器数据的时候使用 PV/PVC 有什么好处呢？"

    比如我们这里之前直接在 Pod 下面也可以使用 hostPath 来持久化数据，为什么还要费劲去创建 PV、PVC 对象来引用呢？

    PVC 和 PV 的设计，其实跟“面向对象”的思想完全一致，PVC 可以理解为持久化存储的“接口”，它提供了对某种持久化存储的描述，但不提供具体的实现；而这个持久化存储的实现部分则由 PV 负责完成。这样做的好处是，作为应用开发者，我们只需要跟 PVC 这个“接口”打交道，而不必关心具体的实现是 hostPath、NFS 还是 Ceph。毕竟这些存储相关的知识太专业了，应该交给专业的人去做，这样对于我们的 Pod 来说就不用管具体的细节了，你只需要给我一个可用的 PVC 即可了，这样是不是就完全屏蔽了细节和解耦了啊，所以我们更应该使用 PV、PVC 这种方式。