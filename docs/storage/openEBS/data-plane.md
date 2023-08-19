
OpenEBS 持久化存储卷通过 Kubernetes 的 PV 来创建，使用 iSCSI 来实现，数据保存在节点上或者云存储中。OpenEBS 的卷完全独立于用户的应用的生命周期来管理，和 Kuberentes 中 PV 的思路一致。OpenEBS 卷为容器提供持久化存储，具有针对系统故障的弹性，更快地访问存储，快照和备份功能。同时还提供了监控使用情况和执行 QoS 策略的机制。

目前，OpenEBS 提供了两个可以轻松插入的存储引擎。这两个引擎分别叫做 `Jiva` 和 `cStor`。这两个存储引擎都完全运行在Linux 用户空间中，并且基于微服务架构。

## Jiva

`Jiva` 存储引擎是基于 Rancher 的 LongHorn 和 gotgt 开发的,采用 GO 语言编写，运行在用户空间。LongHorn 控制器将传入的 IO 同步复制到 LongHorn 复制器上。复制器考虑以 Linux 稀疏文件为基础，进行动态供应、快照、重建等存储功能。

## Cstor

`cStor` 数据引擎是用C语言编写的，具有高性能的 iSCSI 目标和`Copy-On-Write` 块系统，可提供数据完整性、数据弹性和时间点快照和克隆。`cStor` 具有池功能，可将节点上的磁盘以镜像式或 RAIDZ 模式聚合，以提供更大的容量和性能单位。

## Local PV

对于那些不需要存储级复制的应用，Local PV 可能是不错的选择，因为它能提供更高的性能。OpenEBS LocalPV 与 Kubernetes LocalPV 类似，只不过它是由 OpenEBS 控制平面动态调配的，就像其他常规 PV 一样。OpenEBS LocalPV 有两种类型--主机路径 LocalPV 或设备 LocalPV，主机路径 LocalPV 指的是主机上的一个子目录，设备 LocalPV 指的是节点上的一个被发现的磁盘（直接连接或网络连接）。OpenEBS 引入了一个LocalPV 供应器，用于根据 PVC 和存储类规范中的一些标准选择匹配的磁盘或主机路径。












