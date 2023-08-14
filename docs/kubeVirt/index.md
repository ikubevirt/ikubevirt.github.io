# kubeVirt概览

## 研发背景

随着云时代的到来，各大企业纷纷将以往的传统业务转移至K8s集群通过容器化将业务逻辑跑起来，但同时背后的支持依然是靠着Openstack主打虚拟化，而近年OpenStack
的活跃度日趋下降，这也给各企业在虚拟机运行业务带来诸多不稳定性。

于是，后Kubernetes时代的虚拟机管理技术kubeVirt便逐渐崛起。kubeVirt是 Red Hat 开源的以容器方式运行虚拟机的项目，是基于kubernetes运行，利用k8s CRD为增加资源类型`VirtualMachineInstance（VMI）`，使用CRD的方式是由于kubeVirt对虚拟机的管理不局限于pod管理接口。通过CRD机制，kubeVirt可以自定义额外的操作，来调整常规容器中不可用的行为。kubeVirt可以使用容器的image registry去创建虚拟机并提供VM生命周期管理。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 快速了解

<div class="grid cards" markdown>

-  __[架构与生命周期管理]__ – 快速了解kubeVirt的架构和生命周期管理
-  __[实战演练]__ – 实践是检验真理的唯一标准

[//]: # (- :material-page-layout-header: __[Header]__ – Customize the behavior of the header, add an announcement bar)

[//]: # (- :material-page-layout-footer: __[Footer]__ – Add links to your social media profiles or websites in the footer )

[//]: # (- :material-tab-search: __[Search]__ – Set up and configure search, running entirely in the user's browser)

[//]: # (- :material-tag-plus-outline: __[Tags]__ – Categorize your pages with tags and group related pages)

</div>

  [架构与生命周期管理]: kubeVirt/quick-learn.md
  [实战演练]: kubeVirt/quick-deploy.md

### 资源列表

kubeVirt资源分为以下几大类。

#### 虚拟机实例

<div class="grid cards" markdown>

-  __[VirtualMachine]__ – 深入了解资源`virtualMachine`
-  __[VirtualMachineInstance]__ – 深入了解资源`virtualMachineInstance`

</div>

  [VirtualMachine]: resource/virtualMachine.md
  [VirtualMachineInstance]: resource/virtualMachineInstance.md

#### 虚拟机迁移

<div class="grid cards" markdown>

-  __[VirtualMachineInstanceMigration]__ – 深入了解资源`virtualMachineInstanceMigration`

</div>

  [VirtualMachineInstanceMigration]: resource/virtualMachineInstanceMigration.md

#### 虚拟机快照

<div class="grid cards" markdown>

-  __[VirtualMachineSnapshot]__ – 深入了解资源`virtualMachineSnapshot`

</div>

  [VirtualMachineSnapshot]: resource/virtualMachineSnapshot.md

### 源码分析

<div class="grid cards" markdown>

-  __[virt-controller]__ – 深入了解组件`virt-controller`
-  __[virt-launcher]__ – 深入了解组件`virt-launcher`
-  __[virt-handler]__ – 深入了解组件`virt-handler`

</div>

  [virt-controller]: sourceCodeAnalysis/virt-controller/virt-controller-start.md
  [virt-launcher]: sourceCodeAnalysis/virt-launcher.md
  [virt-handler]: sourceCodeAnalysis/virt-handler.md
