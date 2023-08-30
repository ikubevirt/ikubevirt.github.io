
## 先决条件

在安装 GPU Operator 之前，您应该确保 Kubernetes 集群满足一些先决条件。

1. Kubernetes 集群中的所有工作节点必须运行相同的操作系统版本才能使用 NVIDIA GPU 驱动程序容器。 或者，如果您在节点上预安装 NVIDIA GPU 驱动程序，则可以运行不同的操作系统。
2. 节点必须配置容器引擎，例如 Docker CE/EE、`cri-o` 或 `containerd`。 对于 docker，请遵循官方[安装说明](https://docs.docker.com/engine/install/)。
3. 节点功能发现 (NFD) 是每个节点上 Operator 的依赖项。 默认情况下，NFD master 和worker 由 Operator 自动部署。 如果 NFD 已在集群中运行，则您必须在安装 Operator 时禁用部署 NFD。
    
    确定 NFD 是否已在集群中运行的一种方法是检查节点上的 NFD 标签：
    ```bash
    kubectl get nodes -o json | jq '.items[].metadata.labels | keys | any(startswith("feature.node.kubernetes.io"))'
    ```
    如果命令输出为 `true`，则 NFD 已在集群中运行。

4. 要在 Kubernetes 1.13 和 1.14 中进行监控，请启用 kubelet `KubeletPodResources` [特性门控](https://kubernetes.io/docs/reference/command-line-tools-reference/feature-gates/)。 从 Kubernetes 1.15 开始，默认启用。

!!! warning "注意"

    要启用 `KubeletPodResources` 特性门控，请运行以下命令： 
    ```bash
    echo -e "KUBELET_EXTRA_ARGS=--feature-gates=KubeletPodResources=true" | sudo tee /etc/default/kubelet
    ```
