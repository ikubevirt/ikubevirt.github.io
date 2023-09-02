
Kube-OVN 支持了安全组的配置，配置安全组使用的 CRD 为 `SecurityGroup`。

## 安全组使用

!!! example "例子"

    ```yaml linenums="1"
    apiVersion: kubeovn.io/v1
    kind: SecurityGroup
    metadata:
      name: sg-example
    spec:
      allowSameGroupTraffic: true
      egressRules:
      - ipVersion: ipv4
        policy: allow
        priority: 1
        protocol: all
        remoteAddress: 10.16.0.13/16
        remoteType: address
      ingressRules:
      - ipVersion: ipv4
        policy: deny
        priority: 1
        protocol: icmp
        remoteAddress: 10.16.0.14/16
        remoteType: address
    ```

安全组各字段的具体含义如下：

| `securityGroupSpec`参数字段 | 描述                                                                                                  |
|:------------------------|:----------------------------------------------------------------------------------------------------|
| `ingressRules`          | 入方向安全组规则                                                                                            |
| `egressRules`           | 出方向安全组规则                                                                                            |
| `allowSameGroupTraffic` | 同一安全组内的 lsp 是否可以互通，以及流量规则是否需要更新                                                                     |


| `SgRule`参数字段            | 描述                                                                                                  |
|:------------------------|:----------------------------------------------------------------------------------------------------|
| `ipVersion`             | IP 版本号，取值为 `ipv4` 或者 `ipv6`                                                                         |
| `protocol`              | 取值为 `all`、`icmp`、`tcp` 或者 `udp`                                                                     |
| `priority`              | Int	Acl 优先级，取值范围为 1-200，数值越小，优先级越高                                                                  |
| `remoteType`            | 取值为 `address` 或者 `securityGroup`                                                                    |
| `remoteAddress`         | 对端地址                                                                                                |
| `remoteSecurityGroup`   | 对端安全组                                                                                               |
| `portRangeMin`          | 端口范围起始值，最小取值为 1                                                                                     |
| `portRangeMax`          | Int	端口范围最大值，最大取值为 `65535`                                                                           |
| `policy`                | 取值为 `allow` 或者 `drop`                                                                               |


Pod 通过添加 `annotation` 来绑定安全组，使用的 `annotation` 有两个：

```yaml
    ovn.kubernetes.io/port_security: "true"
    ovn.kubernetes.io/security_groups: sg-example
```

## 注意事项

安全组最后是通过设置 ACL 规则来限制访问的，OVN 文档中提到，如果匹配到的两个 ACL 规则拥有相同的优先级，实际起作用的是哪个 ACL 是不确定的。因此设置安全组规则的时候，需要注意区分优先级。

当添加安全组的时候，要清楚的知道是在添加什么限制。Kube-OVN 作为 CNI，创建 Pod 后会进行 Pod 到网关的连通性测试，如果访问不通网关，就会导致 Pod 一直处于 `ContainerCreating` 状态，无法顺利切换到 `Running` 状态。

## 实际测试

利用以下 yaml 创建 Pod，在 `annotation` 中指定绑定示例中的安全组：

```yaml linenums="1"
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: static
  annotations:
    ovn.kubernetes.io/port_security: 'true'
    ovn.kubernetes.io/security_groups: 'sg-example'
  name: sg-test-pod
  namespace: default
spec:
  nodeName: kube-ovn-worker
  containers:
  - image: docker.io/library/nginx:alpine
    imagePullPolicy: IfNotPresent
    name: qatest
```

实际测试结果显示如下：

```bash
$ kubectl get pod -o wide
NAME                   READY   STATUS              RESTARTS   AGE     IP           NODE                     NOMINATED NODE   READINESS GATES
sg-test-pod            0/1     ContainerCreating   0          5h32m   <none>       kube-ovn-worker          <none>           <none>
test-99fff7f86-52h9r   1/1     Running             0          5h41m   10.16.0.14   kube-ovn-control-plane   <none>           <none>
test-99fff7f86-qcgjw   1/1     Running             0          5h43m   10.16.0.13   kube-ovn-worker          <none>           <none>
```

执行 `kubectl describe pod` 查看 Pod 的信息，可以看到报错提示：

```bash
# kubectl describe pod sg-test-pod
Name:         sg-test-pod
Namespace:    default
Priority:     0
Node:         kube-ovn-worker/172.18.0.2
Start Time:   Tue, 28 Feb 2023 10:29:36 +0800
Labels:       app=static
Annotations:  ovn.kubernetes.io/allocated: true
              ovn.kubernetes.io/cidr: 10.16.0.0/16
              ovn.kubernetes.io/gateway: 10.16.0.1
              ovn.kubernetes.io/ip_address: 10.16.0.15
              ovn.kubernetes.io/logical_router: ovn-cluster
              ovn.kubernetes.io/logical_switch: ovn-default
              ovn.kubernetes.io/mac_address: 00:00:00:FA:17:97
              ovn.kubernetes.io/pod_nic_type: veth-pair
              ovn.kubernetes.io/port_security: true
              ovn.kubernetes.io/routed: true
              ovn.kubernetes.io/security_groups: sg-allow-reject
Status:       Pending
IP:
IPs:          <none>
·
·
·
Events:
  Type     Reason                  Age                    From     Message
  ----     ------                  ----                   ----     -------
  Warning  FailedCreatePodSandBox  5m3s (x70 over 4h59m)  kubelet  (combined from similar events): Failed to create pod sandbox: rpc error: code = Unknown desc = failed to setup network for sandbox "40636e0c7f1ade5500fa958486163d74f2e2300051a71522a9afd7ba0538afb6": plugin type="kube-ovn" failed (add): RPC failed; request ip return 500 configure nic failed 10.16.0.15 network not ready after 200 ping 10.16.0.1
```

修改安全组的规则，添加到网关的访问规则，参考如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: SecurityGroup
metadata:
  name: sg-gw-both
spec:
  allowSameGroupTraffic: true
  egressRules:
  - ipVersion: ipv4
    policy: allow
    priority: 2
    protocol: all
    remoteAddress: 10.16.0.13/16
    remoteType: address
  - ipVersion: ipv4
    policy: allow
    priority: 1
    protocol: all
    remoteAddress: 10.16.0.1/16
    remoteType: address
  ingressRules:
  - ipVersion: ipv4
    policy: deny
    priority: 2
    protocol: icmp
    remoteAddress: 10.16.0.14/16
    remoteType: address
  - ipVersion: ipv4
    policy: allow
    priority: 1
    protocol: icmp
    remoteAddress: 10.16.0.1/16
    remoteType: address
```

分别在入方向和出方向规则中，添加允许到网关的访问规则，并且设置该规则的优先级最高。

利用以下 yaml 绑定安全组，部署 Pod 后，确认 Pod 可以正常运行：

```yaml linenums="1"
apiVersion: v1
kind: Pod
metadata:
  labels:
    app: static
  annotations:
    ovn.kubernetes.io/port_security: 'true'
    ovn.kubernetes.io/security_groups: 'sg-gw-both'
  name: sg-gw-both
  namespace: default
spec:
  nodeName: kube-ovn-worker
  containers:
  - image: docker.io/library/nginx:alpine
    imagePullPolicy: IfNotPresent
    name: qatest
```

部署后查看 Pod 信息：

```bash
$ kubectl get pod -o wide
NAME                   READY   STATUS              RESTARTS   AGE     IP           NODE                     NOMINATED NODE   READINESS GATES
sg-test-pod            0/1     ContainerCreating   0          5h41m   <none>       kube-ovn-worker          <none>           <none>
sg-gw-both             1/1     Running             0          5h37m   10.16.0.19   kube-ovn-worker          <none>           <none>
```

因此对于安全组的使用，要特别明确添加的限制规则的作用。如果单纯是限制流量访问，可以考虑使用网络策略实现。
