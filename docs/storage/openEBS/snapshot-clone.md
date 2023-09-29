## 如何在 Kubernetes 集群中创建卷快照并从快照恢复卷

您的集群中必须有正在使用的现有卷，您可以通过创建 PersistentVolumeClaim (PVC) 来创建该卷。 出于本教程的目的，假设我们已经通过使用如下所示的 YAML 文件调用 `kubectl create -f your_pvc_file.yaml` 创建了 PVC：

```yaml linenums="1" title="your_pvc_file.yaml"
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: cstor-pvc
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 5Gi
  storageClassName: cstor-csi-disk
```

下面详细介绍的示例解释了使用快照所需的构造，并展示了如何创建和使用快照。 在创建卷快照之前，必须设置 `VolumeSnapshotClass`。

```yaml linenums="1"
kind: VolumeSnapshotClass
apiVersion: snapshot.storage.k8s.io/v1
metadata:
  name: csi-cstor-snapshotclass
  annotations:
    snapshot.storage.kubernetes.io/is-default-class: "true"
driver: cstor.csi.openebs.io
deletionPolicy: Delete
```

该驱动程序指向 OpenEBS CStor CSI 驱动程序。 删除策略可以设置为 `delete` 或 `retain`。 设置为 `retain` 时，即使删除 `VolumeSnapshot` 对象，也会保留存储集群上的底层物理快照。

## 创建卷的快照

要创建卷的快照，下面是定义快照的 YAML 文件示例：

```yaml linenums="1"
apiVersion: snapshot.storage.k8s.io/v1
kind: VolumeSnapshot
metadata:
  name: cstor-pvc-snap
spec:
  volumeSnapshotClassName: csi-cstor-snapshotclass
  source:
    persistentVolumeClaimName: cstor-pvc
```

为名为 `cstor-pvc` 的 PVC 创建快照，并且快照的名称设置为 `cstor-pvc-snap`。

```bash
$ kubectl create -f snapshot.yaml
volumesnapshot.snapshot.storage.k8s.io/cstor-pvc-snap created

$ kubectl get volumesnapshots
NAME                   AGE
cstor-pvc-snap              10s
```

