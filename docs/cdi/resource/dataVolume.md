
## DataVolume

!!! title "DataVolume定义"

    CDI 自定义了CRD `DataVolume` 作为K8S标准PVC之上的抽象，当用户创建 `DataVolume` 资源时控制器会自动为其创建PVC，并填充数据。

目前支持以下数据源：

- URL (HTTP)
- Container Registry (Registry)
- 其他PVC (PVC)
- 从客户端上传 (Upload)
- 创建空白磁盘 (Blank)
- 从`oVirt/VMWare`的API (Imageio和VDDK)

支持一下两种数据类型：

- kubeVirt：这种类型的数据，被认为是磁盘镜像！cdi会自动为其转换数据格式（如 `QCOW2 -> Raw`）,并调整其虚拟空间的大小。
- archive：tar包格式的数据，cdi会将其中的内容自动解压缩到指定的卷中。

!!! warning

    注意，特定数据源只能处理特定格式的数据，关系如下：
    
    - http → kubevirt, archive
    - registry → kubevirt
    - pvc → Not applicable - content is cloned
    - upload → kubevirt
    - imageio → kubevirt
    - vddk → kubevirt

## 数据源

### HTTP Source

创建 HTTP Source 类型的源时，CDI 基于`qemu-img` 工具工作，支持的镜像格式主要包括以下几种：

- VMDK：VMWare 镜像的格式
- VDI：VirtualBox 镜像格式
- VHD：Hyper-V 镜像的格式
- QCOW2/QCOW
- RAW

### Upload Source

Upload Source数据源可以提供API接口，用户可以将数据直接推送到该接口，`upload`的方式如下：

1. 管理员部署了`cdi-uploadproxy`，并暴露到用户可以访问的网络上
2. 用户创建`DataVolume`
3. 用户创建`UploadTokenRequest`
4. 用户使用`curl`等网络工具携带`token`上传镜像或者其他数据

具体操作如下：

用户需要将`cdi-uploadproxy`服务的svc暴露到Kubernetes集群之外：

```yaml linenums="1" title="cdi-uploadproxy-nodeport.yaml"
apiVersion: v1
kind: Service
metadata:
  name: cdi-uploadproxy-nodeport
  namespace: cdi
  labels:
    cdi.kubevirt.io: "cdi-uploadproxy"
spec:
  type: NodePort
  ports:
    - port: 443
      targetPort: 8443
      nodePort: 31001
      protocol: TCP
  selector:
    cdi.kubevirt.io: cdi-uploadproxy
```
并执行

```bash
kubectl apply -f cdi-uploadproxy-nodeport.yaml
```

手工创建DV, 并将source指定为`upload`，

```yaml linenums="1"
apiVersion: cdi.kubevirt.io/v1beta1
kind: DataVolume
metadata:
  name: upload-datavolume
spec:
  source:
      upload: {}
  pvc:
    accessModes:
      - ReadWriteOnce
    resources:
      requests:
        storage: 500Mi
```

创建Upload Token，集群创建以下ServiceAccount，并绑定相关权限


```yaml linenums="1"
apiVersion: v1
kind: ServiceAccount
metadata:
  name: cdi-uploadtokenrequests
  namespace: cdi
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: cdi-uploadtokenrequests
rules:
  - apiGroups:
      - "upload.cdi.kubevirt.io"
    resources:
      - 'uploadtokenrequests'
    verbs:
      - '*'
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: ruijie:openplatform:openplatform-controller
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cdi-uploadtokenrequests
subjects:
  - kind: ServiceAccount
    name: cdi-uploadtokenrequests
    namespace: cdi
```

创建的`cdi-uploadtokenrequests`后，在cdi的命名空间下会自动创建`secret`，名称格式为：`cdi-uploadtokenrequests-token-xxx` ，describe该`secret`中的`token`字段，可以获取用于上传的UploadToken：

!!! info "POST请求"

    POST：`/apis/upload.cdi.kubevirt.io/v1beta1/namespaces/{namespace}/uploadtokenrequests`

    有两种方式上传，一种是`json`做BODY, 另一种是用资源清单`yaml`文件发POST请求。

如果BODY信息用json，该BODY信息如下：

```json linenums="1"
{
  "apiVersion": "upload.cdi.kubevirt.io/v1beta1",
  "kind": "UploadTokenRequest",
  "metadata": {
    "name": "DV名称",
    "namespace": "default",
    "spec": {
      "pvcName": "DV名称"
    }
  }
}
```

返回信息
```json linenums="1"
{
  "kind": "UploadTokenRequest",
  "apiVersion": "upload.cdi.kubevirt.io/v1beta1",
  "metadata": {
    "name": "upload-datavolume",
    "namespace": "default",
    "creationTimestamp": null
  },
  "spec": {
    "pvcName": ""
  },
  "status": {
    "token": "UPLOADTOKEN"
  }
}
```

如果BODY用资源清单yaml，BODY信息如下：

```yaml linenums="1" title="upload-datavolume-token.yaml"
apiVersion: upload.cdi.kubevirt.io/v1beta1
kind: UploadTokenRequest
metadata:
  name: DV名称
  namespace: default
spec:
  pvcName: DV名称
```

describe一下`uploadTokenRequest`，

```yaml linenums="1"
apiVersion: upload.cdi.kubevirt.io/v1beta1
kind: UploadTokenRequest
metadata:
  annotations:
    kubectl.kubernetes.io/last-applied-configuration: |
      {"apiVersion":"upload.cdi.kubevirt.io/v1beta1","kind":"UploadTokenRequest","metadata":{"annotations":{},"name":"DV名称","namespace":"default"},"spec":{"pvcName":"DV名称"}}
  creationTimestamp: null
  name: DV名称
  namespace: default
spec:
  pvcName: DV名称
status:
  token: eyJhbGciOiJQUzUxMiIsImtpZCI6IiJ9.eyJwdmNOYW1lIjoidXBsb2FkLXRlc3QiLCJuYW1lc3BhY2UiOiJkZWZhdWx0IiwiY3JlYXRpb25UaW1lc3RhbXAiOiIyMDE4LTA5LTIxVDE4OjEyOjE5LjQwODI1MDQ4NFoifQ.JWk1VyvzSse3eFiBROKgGoLnOPCiYW9JdDWKXFROEL6XY0O5lFb1R0rwdfWwC3BBOtEA9mC9x3ZGYPnYWO-5G_r1fWKHjF-zifrCX_3Dhp3vfSq6Zfpu-vV0Qn0A3YkSCCmiC_nONAhVjEDuQsRFIKwYcxBoEOpye92ggH2u5FxQE7FwxxH6-RHun9tc_lIFX-ZFKnq7n5tWbjsTmAZI_4rDNgYkVFhFtENU6e-5_Ncokxs3YVzkbSrXweZpRmmaYQOmZhjXSLjKED_2FVq7tYeVueEEhKC_zJ-AEivstALPwPjiwyWXJyfE3dCmbA1sBKuNUrAaDlBvSAp1uPV9eQ

```

可以通过执行以下命令直接获取`UPLOADTOKEN`，
```bash
UPLOADTOKEN=$(kubectl apply -f upload-datavolume-token.yaml -o="jsonpath={.status.token}")
```

通过`curl`上传数据到`datavolume`，

```bash linenums="1"
# 同步上传
curl -v --insecure -H "Authorization: Bearer $UPLOADTOKEN" --data-binary @tests/images/cirros-qcow2.img https://$(minikube ip):31001/v1alpha1/upload

# 异步上传
curl -v --insecure -H "Authorization: Bearer $UPLOADTOKEN" --data-binary @tests/images/cirros-qcow2.img https://$(minikube ip):31001/v1alpha1/upload-async
```