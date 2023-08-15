# CDI概览

## 什么是CDI

!!! info "CDI定义"

    Containerized-Data-Importer (CDI) 是 Kubernetes 的持久存储管理插件。

它的主要目标是在PVC的基础上构建 Kubevirt VM 的虚拟机磁盘资源，并提供一种将不同数据源的数据填充到指定PVC的能力。让用户能够：

- 导入kubevirt VM的镜像
- 初始化PVC，导入指定数据

## 如何使用CDI

下面一张图我们可以了解CDI能够做什么：

![](https://cdn.jsdelivr.net/gh/ikubevirt/ikubevirt.github.io/docs/assets/images/what-cdi-do3.png){ loading=lazy }

我们把CDI当成一个黑盒，站在使用者的角度来观察它。用户可以通过两种方式使用CDI，分别是：

- 在PVC上添加`annotation`
- 创建`DataVolume`（CDI新增的CRD）实例

CDI始终做以下事情：

- 监听到PVC的`annotation`或者`DataVolume`
- 根据定义，从指定的`Source`，将VM Image或者其他数据导入到PVC中

通过`DataVolume`使用CDI的方式，可以通过版本管理API接口，便于其他项目（例如：kubevirt）与之集成，只需要指定特定版本的`DataVolume`即可，所有对`DataVolume`的修改都将体现在新的API版本上。

如果对`DataVolume`的数据结构感兴趣可以前往[DataVolume](https://ikubevirt.cn/cdi/resource/dataVolume/)。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 资源列表

<div class="grid cards" markdown>

-  __[DataVolume]__ – 深入了解资源`dataVolume`
-  __[DataImportCron]__ – 深入了解资源`dataImportCron`

</div>

  [DataVolume]: resource/dataVolume.md
  [DataImportCron]: resource/dataImportCron.md

### 特性功能

<div class="grid cards" markdown>

-  __[热插拔卷]__ – 深入了解特性热插拔卷

</div>

  [热插拔卷]: features/hotplug-volume.md
