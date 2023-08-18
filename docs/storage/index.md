# 存储

## 概念

!!! info "PV定义"

    PV 的全称是：`PersistentVolume`（持久化卷），是对底层共享存储的一种抽象，PV 由管理员进行创建和配置，它和具体的底层的共享存储技术的实现方式有关，比如 `Ceph`、`GlusterFS`、`NFS`、`hostPath` 等，都是通过插件机制完成与共享存储的对接。

!!! info "PVC定义"

    PVC 的全称是：`PersistentVolumeClaim`（持久化卷声明），PVC 是用户存储的一种声明，PVC 和 Pod 比较类似，Pod 消耗的是节点，PVC 消耗的是 PV 资源，Pod 可以请求 CPU 和内存，而 PVC 可以请求特定的存储空间和访问模式。对于真正使用存储的用户不需要关心底层的存储实现细节，只需要直接使用 PVC 即可。

但是通过 PVC 请求到一定的存储空间也很有可能不足以满足应用对于存储设备的各种需求，而且不同的应用程序对于存储性能的要求可能也不尽相同，比如读写速度、并发性能等，为了解决这一问题，Kubernetes 又为我们引入了一个新的资源对象：`StorageClass`，通过 `StorageClass` 的定义，管理员可以将存储资源定义为某种类型的资源，比如快速存储、慢速存储等，用户根据 `StorageClass` 的描述就可以非常直观的知道各种存储资源的具体特性了，这样就可以根据应用的特性去申请合适的存储资源了，此外 StorageClass 还可以为我们自动生成 PV，免去了每次手动创建的麻烦。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### Local 本地存储

我们有通过 `hostPath` 或者 `emptyDir` 的方式来持久化我们的数据，但是显然我们还需要更加可靠的存储来保存应用的持久化数据，这样容器在重建后，依然可以使用之前的数据。但是存储资源和 CPU 资源以及内存资源有很大不同，为了屏蔽底层的技术实现细节，让用户更加方便的使用，Kubernetes 便引入了 PV 和 PVC 两个重要的资源对象来实现对存储的管理。

Local 本地存储分为以下几类：

[cards cols="3" image-tags(./docs/assets/data/storage/local.yaml)]

### OpenEBS 存储

OpenEBS 是一种模拟了 AWS 的 EBS、阿里云的云盘等块存储实现的基于容器的存储开源软件。OpenEBS 是一种基于 CAS(Container Attached Storage) 理念的容器解决方案，其核心理念是存储和应用一样采用微服务架构，并通过 Kubernetes 来做资源编排。其架构实现上，每个卷的 Controller 都是一个单独的 Pod，且与应用 Pod 在同一个节点，卷的数据使用多个 Pod 进行管理。

OpenEBS 有很多组件，可以分为以下几类：

[cards cols="3" image-tags(./docs/assets/data/storage/openEBS.yaml)]

### Ceph 存储

Ceph 是一个统一的分布式存储系统，提供较好的性能、可靠性和可扩展性。最早起源于 Sage 博士期间的工作，随后贡献给开源社区。

参考内容如下:

[cards cols="3" image-tags(./docs/assets/data/storage/ceph.yaml)]
