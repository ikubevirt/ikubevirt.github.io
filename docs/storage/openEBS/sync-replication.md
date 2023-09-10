
OpenEBS管理k8s节点上存储，并为k8s有状态负载（StatefulSet）提供本地存储卷或分布式存储卷。

- 本地卷（Local PV）

    - OpenEBS可以使用宿主机裸块设备或分区，或者使用Hostpaths上的子目录，或者使用`LVM`、`ZFS`来创建持久化卷
    - 本地卷直接挂载到Stateful Pod中，而不需要OpenEBS在数据路径中增加任何开销
    - OpenEBS为本地卷提供了额外的工具，用于监控、备份/恢复、灾难恢复、由ZFS或LVM支持的快照等

- 对于分布式卷(即复制卷)

    - OpenEBS使用其中一个引擎(`Mayastor`、`cStor`或`Jiva`)为每个分布式持久卷创建微服务
    - 有状态Pod将数据写入OpenEBS引擎，OpenEBS引擎将数据同步复制到集群中的多个节点。 OpenEBS引擎本身作为pod部署，并由Kubernetes进行协调。 当运行Stateful Pod的节点失败时，Pod将被重新调度到集群中的另一个节点，OpenEBS将使用其他节点上的可用数据副本提供对数据的访问
    - 有状态的Pods使用`iSCSI` (`cStor`和`Jiva`)或NVMeoF (`Mayastor`)连接OpenEBS分布式持久卷
    - OpenEBS `cStor`和`Jiva`专注于存储的易用性和持久性。它们分别使用自定义版本的`ZFS`和`Longhorn`技术将数据写入存储。 OpenEBS `Mayastor`是最新开发的以耐久性和性能为设计目标的引擎，高效地管理计算(大页面、核心)和存储(`NVMe Drives`)，以提供快速分布式块存储

!!! warning "注意"

    OpenEBS分布式块卷被称为复制卷，以避免与传统的分布式块存储混淆，传统的分布式块存储倾向于将数据分布到集群中的许多节点上。 复制卷是为云原生有状态工作负载设计的，这些工作负载需要大量的卷，这些卷的容量通常可以从单个节点提供，而不是使用跨集群中的多个节点分片的单个大卷

## 复制卷

!!! info "复制卷"

    复制卷，顾名思义，是将数据同步复制到多个节点的卷。 卷可以承受节点故障。 还可以跨可用性区域设置复制，帮助应用程序跨可用性区域移动。

复制卷还具有企业存储功能，例如快照、克隆、卷扩展等。 复制卷是 `Percona/MySQL`、`Jira`、`GitLab` 等有状态工作负载的首选。

根据附加到 Kubernetes 工作节点的存储类型和应用程序性能要求，您可以从 `Jiva`、`cStor` 或 `Mayastor` 中进行选择。