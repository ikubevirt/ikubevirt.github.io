# CDI概览

## 什么是CDI

!!! info "CDI定义"

    Containerized-Data-Importer (CDI) 是 Kubernetes 的持久存储管理插件。

它的主要目标是在PVC的基础上构建 kubeVirt VM 的虚拟机磁盘资源，并提供一种将不同数据源的数据填充到指定PVC的能力。让用户能够：

- 导入kubeVirt VM的镜像
- 初始化PVC，导入指定数据

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 资源列表

cdi资源分为以下几大类：

[cards cols="3" image-tags(./docs/assets/data/cdi/cdi.yaml)]

### 特性功能

cdi具备以下特性功能：

- 卷管理
- 磁盘管理

#### 卷管理

[cards cols="3" image-tags(./docs/assets/data/cdi/features-vol.yaml)]
