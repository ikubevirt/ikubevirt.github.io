
!!! info "SSP Operator定义"

    SSP Operator 是一个基于 Golang 编写的 Operator，负责部署 kubevirt-tekton-tasks 和示例CI。

SSP 作为`hyperconverged-cluster-operator`的一部分，也可以由用户从最新版本独立部署。

!!! note "备注"

    SSP 需要 Tekton 才能工作。

默认情况下，SSP 不部署 KubeVirt Tekton 任务资源。 用户必须在 HCO CR 中启用 `deployTektonTaskResources` 特性门控才能部署其所有资源：

```yaml linenums="1"
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: kubevirt-hyperconverged
spec:
  featureGates:
    deployTektonTaskResources: true
```

或者是在SSP CR，

```yaml linenums="1"
apiVersion: ssp.kubevirt.io/v1beta2
kind: SSP
metadata:
  name: ssp
  namespace: kubevirt
spec:
  featureGates:
    deployTektonTaskResources: true
```

用户可以通过命令行在HCO CR中启用 `deployTektonTaskResources` 特性门控：

=== "Kubernetes"

    ```bash linenums="1"
    kubectl patch hco kubevirt-hyperconverged  --type=merge -p '{"spec":{"featureGates": {"deployTektonTaskResources": true}}}'
    ```

=== "OKD"

    ```bash linenums="1"
    oc patch hco kubevirt-hyperconverged  --type=merge -p '{"spec":{"featureGates": {"deployTektonTaskResources": true}}}'
    ```

或者通过patch给SSP CR打补丁，

=== "Kubernetes"

    ```bash linenums="1"
    kubectl patch ssp ssp  --type=merge -p '{"spec":{"featureGates": {"deployTektonTaskResources": true}}}'
    ```

=== "OKD"

    ```bash linenums="1"
    oc patch ssp ssp  --type=merge -p '{"spec":{"featureGates": {"deployTektonTaskResources": true}}}'
    ```

一旦特性门控`spec.featureGates.deployTektonTaskResources`被置为`true`时，SSP将不会删除任何任务和示例CI，就算是特性门控回置成`false`。

用户可以通过在HCO CR中配置两个字段 `spec.tektonPipelinesNamespace` 或 `spec.tektonTasksNamespace`将示例CI或者任务部署到哪个命名空间下，

```yaml linenums="1"
apiVersion: hco.kubevirt.io/v1beta1
kind: HyperConverged
metadata:
  name: kubevirt-hyperconverged
  namespace: kubevirt-hyperconverged
spec:
  tektonPipelinesNamespace: userNamespace
  tektonTasksNamespace: userNamespace
```

或者在SSP CR中配置两个字段 `spec.tektonPipelines.namespace` 或 `spec.tektonTasks.namespace`:

```yaml linenums="1"
apiVersion: ssp.kubevirt.io/v1beta2
kind: SSP
metadata:
  name: ssp
  namespace: kubevirt
spec:
  tektonPipelines:
    namespace: kubevirt
  tektonTasks:
    namespace: kubevirt
```
