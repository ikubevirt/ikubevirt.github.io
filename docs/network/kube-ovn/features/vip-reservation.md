
在一些场景下我们希望动态的预留一部分 IP 但是并不分配给 Pod 而是分配给其他的基础设施启用，例如：

- Kubernetes 嵌套 Kubernetes 的场景中上层 Kubernetes 使用 Underlay 网络会占用底层 Subnet 可用地址。
- LB 或其他网络基础设施需要使用一个 `Subnet` 内的 IP，但不会单独起 Pod。

## 创建随机地址 VIP

如果只是为了预留若干 IP 而对 IP 地址本身没有要求可以使用下面的 yaml 进行创建：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vip
metadata:
  name: vip-dynamic-01
spec:
  subnet: ovn-default
  type: "
```

| 参数字段     | 描述                                                                                                 |
|:---------|:---------------------------------------------------------------------------------------------------|
| `subnet` | 将从该 Subnet 中预留 IP。|
| `type`     | 目前支持两种类型，为空表示仅用于 ipam ip 占位，`switch_lb_vip` 表示该 vip 仅用于 switch lb 前端 vip 和后端 ip 需处于同一子网。|

创建成功后查询该 VIP：

```bash
$ kubectl get vip
NAME             V4IP         PV4IP   MAC                 PMAC   V6IP   PV6IP   SUBNET        READY
vip-dynamic-01   10.16.0.12           00:00:00:F0:DB:25                         ovn-default   true
```

可见该 VIP 被分配了 `10.16.0.12` 的 IP 地址，该地址可以之后供其他网络基础设施使用。

## 创建固定地址 VIP

如对预留的 VIP 的 IP 地址有需求可使用下面的 yaml 进行固定分配：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vip
metadata:
  name: static-vip01
spec:
  subnet: ovn-default 
  v4ip: "10.16.0.121"
```

| 参数字段     | 描述                                                                                                 |
|:---------|:---------------------------------------------------------------------------------------------------|
| `subnet` | 将从该 Subnet 中预留 IP。|
| `v4ip`   | 固定分配的 IP 地址，该地址需在 `subnet` 的 CIDR 范围内。|

创建成功后查询该 VIP：

```bash
$ kubectl get vip
NAME             V4IP         PV4IP   MAC                 PMAC   V6IP   PV6IP   SUBNET        READY
static-vip01   10.16.0.121           00:00:00:F0:DB:26                         ovn-default   true
```

可见该 VIP 被分配了所预期的 IP 地址。

## Pod 使用 VIP 来固定 IP

可以使用 `annotation` 将某个 VIP 分配给一个 Pod：

```yaml linenums="1"
apiVersion: v1
kind: Pod
metadata:
  name: static-ip
  annotations:
    ovn.kubernetes.io/vip: vip-dynamic-01 # 指定 vip
  namespace: default
spec:
  containers:
    - name: static-ip
      image: docker.io/library/nginx:alpine
```

## StatefulSet 和 Kubevirt VM 保留 VIP

针对 StatefulSet 和 VM 的特殊性，在他们的 Pod 销毁再拉起起后会重新使用之前设置的 VIP。

VM 保留 VIP 需要确保 `kube-ovn-controller` 的 `keep-vm-ip` 参数为 `true`。请参考 [Kubevirt VM 固定地址开启设置](./fixed-ip-address.md/#kubevirt-vm)