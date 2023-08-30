# GPU Operator

Kubernetes 通过设备插件框架提供对特殊硬件资源的访问，例如 NVIDIA GPU、NIC、Infiniband 适配器和其他设备。 然而，使用这些硬件资源配置和管理节点需要配置多个软件组件，例如驱动程序、容器运行时或其他库，这是困难且容易出错的。 NVIDIA GPU Operator 使用 Kubernetes 中的算子框架来自动管理配置 GPU 所需的所有 NVIDIA 软件组件。 这些组件包括 NVIDIA 驱动程序（用于启用 CUDA）、GPU 的 Kubernetes 设备插件、NVIDIA 容器工具包、使用 GFD 的自动节点标记、基于 DCGM 的监控等。

## 研究内容

以下研究内容细分了几项供读者学习和参考。

### 快速了解

[cards cols="3" image-tags(./docs/assets/data/gpu/gpu-operator.yaml)]
