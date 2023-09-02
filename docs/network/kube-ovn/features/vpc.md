
Kube-OVN 支持多租户隔离级别的 VPC 网络。不同 VPC 网络相互独立，可以分别配置 Subnet 网段， 路由策略，安全策略，出网网关，EIP 等配置。

## 使用场景

VPC 主要用于有多租户网络强隔离的场景，部分 Kubernetes 网络功能在多租户网络下存在冲突。 

!!! example "例子"

    例如节点和 Pod 互访，NodePort 功能，基于网络访问的健康检查和 DNS 能力在多租户网络场景暂不支持。 

为了方便常见 Kubernetes 的使用场景，Kube-OVN 默认 VPC 做了特殊设计，该 VPC 下的 Subnet 可以满足 Kubernetes 规范。用户自定义 VPC 支持本文档介绍的静态路由，EIP 和 NAT 网关等功能。 常见隔离需求可通过默认 VPC 下的网络策略和子网 ACL 实现，在使用自定义 VPC 前请明确是否需要 VPC 级别的隔离，并了解自定义 VPC 下的限制。 在 Underlay 网络下，物理交换机负责数据面转发，VPC 无法对 Underlay 子网进行隔离。

![](../../../assets/images/network-topology.png){ loading=lazy }

## 创建自定义VPC

创建两个 VPC：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vpc
metadata:
  name: test-vpc-1
spec:
  namespaces:
  - ns1
---
kind: Vpc
apiVersion: kubeovn.io/v1
metadata:
  name: test-vpc-2
spec:
  namespaces:
  - ns2
```

- `namespaces` 可以限定只有哪些 Namespace 可以使用当前 VPC，若为空则不限定。

创建两个子网，分属两个不同的 VPC 并有相同的 CIDR:

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: net1
spec:
  vpc: test-vpc-1
  cidrBlock: 10.0.1.0/24
  protocol: IPv4
  namespaces:
    - ns1
---
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: net2
spec:
  vpc: test-vpc-2
  cidrBlock: 10.0.1.0/24
  protocol: IPv4
  namespaces:
    - ns2
```

分别在两个 Namespace 下创建 Pod:

```yaml linenums="1"
apiVersion: v1
kind: Pod
metadata:
  annotations:
    ovn.kubernetes.io/logical_switch: net1
  namespace: ns1
  name: vpc1-pod
spec:
  containers:
    - name: vpc1-pod
      image: docker.io/library/nginx:alpine
---
apiVersion: v1
kind: Pod
metadata:
  annotations:
    ovn.kubernetes.io/logical_switch: net2
  namespace: ns2
  name: vpc2-pod
spec:
  containers:
    - name: vpc2-pod
      image: docker.io/library/nginx:alpine
```

运行成功后可观察两个 Pod 地址属于同一个 CIDR，但由于运行在不同的租户 VPC，两个 Pod 无法相互访问。

### 自定义 VPC Pod 支持 livenessProbe 和 readinessProbe

由于常规配置下自定义 VPC 下的 Pod 和节点的网络之间并不互通，所以 kubelet 发送的探测报文无法到达自定 VPC 内的 Pod。Kube-OVN 通过 TProxy 将 kubelet 发送的探测报文重定向到自定义 VPC 内的 Pod，从而实现这一功能。

配置方法如下，在 Daemonset `kube-ovn-cni` 中增加参数 `--enable-tproxy=true`：

```yaml
spec:
  template:
    spec:
      containers:
      - args:
        - --enable-tproxy=true
```

该功能限制条件：

1. 当同一个节点下出现不同 VPC 下的 Pod 具有相同的 IP，探测功能失效。
2. 目前暂时只支持 `tcpSocket` 和 `httpGet` 两种探测方式。

## 创建 VPC 网关

!!! warning "注意"

    自定义 VPC 下的子网不支持默认 VPC 下的分布式网关和集中式网关。

VPC 内容器访问外部网络需要通过 VPC 网关，VPC 网关可以打通物理网络和租户网络，并提供 浮动 IP，SNAT 和 DNAT 功能。

VPC 网关功能依赖 Multus-CNI 的多网卡功能，安装请参考 multus-cni。

### 配置外部网络

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: ovn-vpc-external-network
spec:
  protocol: IPv4
  provider: ovn-vpc-external-network.kube-system
  cidrBlock: 192.168.0.0/24
  gateway: 192.168.0.1  # IP address of the physical gateway
  excludeIps:
  - 192.168.0.1..192.168.0.10
---
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ovn-vpc-external-network
  namespace: kube-system
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "macvlan",
      "master": "eth1",
      "mode": "bridge",
      "ipam": {
        "type": "kube-ovn",
        "server_socket": "/run/openvswitch/kube-ovn-daemon.sock",
        "provider": "ovn-vpc-external-network.kube-system"
      }
    }'
```

- 该 Subnet 用来管理可用的外部地址，网段内的地址将会通过 Macvlan 分配给 VPC 网关，请和网络管理沟通给出可用的物理段 IP。
- VPC 网关使用 Macvlan 做物理网络配置，NetworkAttachmentDefinition 的 master 需为对应物理网路网卡的网卡名。
- `name` 外部网络名称

在 Macvlan 模式下，附属网卡会将数据包直接通过该节点网卡对外发送，L2/L3 层面的转发能力需要依赖底层网络设备。 需要预先在底层网络设备配置对应的网关、Vlan 和安全策略等配置。

1. 对于 OpenStack 的 VM 环境，需要将对应网络端口的 `PortSecurity` 关闭。
2. 对于 VMware 的 vSwitch 网络，需要将 `MAC Address Changes`, `Forged Transmits` 和 `Promiscuous Mode Operation` 设置为 `allow`。
3. 对于 Hyper-V 虚拟化，需要开启虚拟机网卡高级功能中的 `MAC Address Spoofing`。
4. 公有云，例如 AWS、GCE、阿里云等由于不支持用户自定义 Mac 无法支持 Macvlan 模式网络。
5. 由于 Macvlan 本身的限制，Macvlan 子接口无法访问父接口地址。
6. 如果物理网卡对应交换机接口为 Trunk 模式，需要在该网卡上创建子接口再提供给 Macvlan 使用。

### 开启 VPC 网关功能

VPC 网关功能需要通过 `kube-system` 下的 `ovn-vpc-nat-gw-config` 开启：

```yaml linenums="1"
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: ovn-vpc-nat-config
  namespace: kube-system
data:
  image: 'docker.io/kubeovn/vpc-nat-gateway:v1.12.0' 
---
kind: ConfigMap
apiVersion: v1
metadata:
  name: ovn-vpc-nat-gw-config
  namespace: kube-system
data:
  enable-vpc-nat-gw: 'true'
```

- `image`: 网关 Pod 所使用的镜像。
- `enable-vpc-nat-gw`： 控制是否启用 VPC 网关功能。

### 创建 VPC 网关并配置默认路由

```yaml linenums="1"
kind: VpcNatGateway
apiVersion: kubeovn.io/v1
metadata:
  name: gw1
spec:
  vpc: test-vpc-1
  subnet: net1
  lanIp: 10.0.1.254
  selector:
    - "kubernetes.io/hostname: kube-ovn-worker"
    - "kubernetes.io/os: linux"
  externalSubnets:
    - ovn-vpc-external-network
```

| 参数字段         | 描述                                                                                                 |
|:-------------|:---------------------------------------------------------------------------------------------------|
| `vpc`  | 该 `VpcNatGateway` 所属的 VPC。                                                                           |
| `subnet` | 为 VPC 内某个 `Subnet` 名，VPC 网关 Pod 会在该子网下用 `lanIp` 来连接租户网络。                                               |
| `lanIp`    | `subnet` 内某个未被使用的 IP，VPC 网关 Pod 最终会使用该 Pod。当 VPC 配置路由需要指向当前 `VpcNatGateway` 时 `nextHopIP` 需要设置为这个 `lanIp`。 |
| `selector`   | `VpcNatGateway` Pod 的节点选择器，格式和 Kubernetes 中的 NodeSelector 格式相同。                                      |
| `externalSubnets`| VPC 网关使用的外部网络，如果不配置则默认使用 `ovn-vpc-external-network`，当前版本只支持配置一个外部网络。                                 |
| `tolerations`| 为 VPC 网关配置容忍度，具体配置参考 污点和容忍度。（可配）                                                                   |
| `affinity`| 为 VPC 网关 Pod 或节点配置亲和性，具体设置参考 亲和性与反亲和性。（可配）                                                         |

### 创建 EIP

EIP 为外部网络段的某个 IP 分配给 VPC 网关后可进行 DNAT，SNAT 和浮动 IP 操作。

随机分配一个地址给 EIP：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eip-random
spec:
  natGwDp: gw1
```

固定 EIP 地址分配：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eip-static
spec:
  natGwDp: gw1
  v4ip: 10.0.1.111
```

指定 EIP 所在的外部网络：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eip-random
spec:
  natGwDp: gw1
  externalSubnet: ovn-vpc-external-network
```

- `externalSubnet`： EIP 所在外部网络名称，如果不指定则默认为 `ovn-vpc-external-network`，如果指定则必须为所在 VPC 网关的 `externalSubnets` 中的一个。

### 创建 DNAT 规则

通过 DNAT 规则，外部可以通过一个 EIP 加端口的方式来访问 VPC 内的一个 IP 和端口。

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eipd01
spec:
  natGwDp: gw1

---
kind: IptablesDnatRule
apiVersion: kubeovn.io/v1
metadata:
  name: dnat01
spec:
  eip: eipd01 
  externalPort: '8888'
  internalIp: 10.0.1.10
  internalPort: '80'
  protocol: tcp
```

### 创建 SNAT 规则

通过 SNAT 规则，VPC 内的 Pod 访问外部的地址时将会通过对应 EIP 进行 SNAT。

```yaml linenums="1"
---
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eips01
spec:
  natGwDp: gw1
---
apiVersion: kubeovn.io/v1
kind: IptablesSnatRule
metadata:
  name: snat01
spec:
  eip: eips01
  internalCIDR: 10.0.1.0/24
```

### 创建浮动 IP

通过浮动 IP 规则，VPC 内的一个 IP 会和 EIP 进行完全映射，外部可以通过这个 EIP 方位 VPC 内的 IP，VPC 内的这个 IP 访问外部地址时也会 SNAT 成这个 EIP。

```yaml linenums="1"
---
apiVersion: kubeovn.io/v1
kind: IptablesEIP
metadata:
  name: eipf01
spec:
  natGwDp: gw1

---
apiVersion: kubeovn.io/v1
kind: IptablesFIPRule
metadata:
  name: fip01
spec:
  eip: eipf01
  internalIp: 10.0.1.5
```

## 自定义路由

在自定义 VPC 内，用户可以自定义网络内部的路由规则，结合网关实现更灵活的转发。 Kube-OVN 支持静态路由和更为灵活的策略路由。

### 静态路由

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vpc
metadata:
  name: test-vpc-1
spec:
  staticRoutes:
    - cidr: 0.0.0.0/0
      nextHopIP: 10.0.1.254
      policy: policyDst
    - cidr: 172.31.0.0/24
      nextHopIP: 10.0.1.253
      policy: policySrc
      routeTable: "rtb1"
```

- `policy`: 支持目的地址路由 `policyDst` 和源地址路由 `policySrc`。
- 当路由规则存在重叠时，CIDR 掩码较长的规则优先级更高，若掩码长度相同则目的地址路由优先于源地址路由。
- `routeTable`: 可指定静态路由所在的路由表，默认在主路由表。子网关联路由表请参考[创建子网](./subnet.md/#_7)

### 策略路由

针对静态路由匹配的流量，可通过策略路由进行更细粒度的控制。策略路由提供了更精确的匹配规则，优先级控制 和更多的转发动作。该功能为 OVN 内部逻辑路由器策略功能的一个对外暴露，更多使用信息请参考 Logical Router Policy。

简单示例如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Vpc
metadata:
  name: test-vpc-1
spec:
  policyRoutes:
    - action: drop
      match: ip4.src==10.0.1.0/24 && ip4.dst==10.0.1.250
      priority: 11
    - action: reroute
      match: ip4.src==10.0.1.0/24
      nextHopIP: 10.0.1.252
      priority: 10
```

## 自定义内部负载均衡规则

Kubernetes 本身提供的 Service 能力可以完成内部负载均衡的功能，但是受限于 Kubernetes 实现， Service 的 IP 地址是全局分配且不能重复。对于 VPC 的使用场景，用户希望能自定义内部负载均衡的地址 范围，不同 VPC 下的负载均衡地址可能重叠，Kubernetes 内置的 Service 功能无法完全满足。

针对这类场景，Kube-OVN 提供了 `SwitchLBRule` 资源，用户可以自定义内部负载均衡的地址范围。

一个 `SwitchLBRule` 例子如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: SwitchLBRule
metadata:
  name:  cjh-slr-nginx
spec:
  vip: 1.1.1.1
  sessionAffinity: ClientIP
  namespace: default
  selector:
    - app:nginx
  ports:
  - name: dns
    port: 8888
    targetPort: 80
    protocol: TCP
```

| 参数字段         | 描述                                                                      |
|:-------------|:------------------------------------------------------------------------|
| `vip`  | 自定义内部负载均衡的地址。                               |
| `namespace` | 负载均衡器后端 Pod 所在的 Namespace。 |
| `sessionAffinity`    | 和 Service 的 sessionAffinity 功能相同。   |
| `selector`   | 和 Service 的 selector 功能相同。  |
| `ports`| 和 Service 的 port 功能相同。|

查看部署的内部负载均衡器规则：

```bash
$ kubectl get slr
NAME                VIP         PORT(S)                  SERVICE                             AGE
vpc-dns-test-cjh2   10.96.0.3   53/UDP,53/TCP,9153/TCP   kube-system/slr-vpc-dns-test-cjh2   88m
```

## 自定义 vpc-dns

由于自定义 VPC 和默认 VPC 网络相互隔离，VPC 内 Pod 无法使用默认的 coredns 服务进行域名解析。 如果希望在自定义 VPC 内使用 coredns 解析集群内 Service 域名，可以通过 Kube-OVN 提供的 vpc-dns 资源来实现。

### 创建附加网卡

```yaml linenums="1"
apiVersion: "k8s.cni.cncf.io/v1"
kind: NetworkAttachmentDefinition
metadata:
  name: ovn-nad
  namespace: default
spec:
  config: '{
      "cniVersion": "0.3.0",
      "type": "kube-ovn",
      "server_socket": "/run/openvswitch/kube-ovn-daemon.sock",
      "provider": "ovn-nad.default.ovn"
    }'
```

### 修改 ovn-default 逻辑交换机的 provider

修改 `ovn-default` 的 provider，为上面 nad 配置的 provider `ovn-nad.default.ovn`：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: ovn-default
spec:
  cidrBlock: 10.16.0.0/16
  default: true
  disableGatewayCheck: false
  disableInterConnection: false
  enableDHCP: false
  enableIPv6RA: false
  excludeIps:
  - 10.16.0.1
  gateway: 10.16.0.1
  gatewayType: distributed
  logicalGateway: false
  natOutgoing: true
  private: false
  protocol: IPv4
  provider: ovn-nad.default.ovn
  vpc: ovn-cluster
```

### 配置 vpc-dns 的 ConfigMap

在 `kube-system` 命名空间下创建 `configmap`，配置 `vpc-dns` 使用参数，用于后面启动 `vpc-dns` 功能：

```yaml linenums="1"
apiVersion: v1
kind: ConfigMap
metadata:
  name: vpc-dns-config
  namespace: kube-system
data:
  coredns-vip: 10.96.0.3
  enable-vpc-dns: true
  nad-name: ovn-nad
  nad-provider: ovn-nad.default.ovn
```

| 参数字段                | 描述                                                                      |
|:--------------------|:------------------------------------------------------------------------|
| `enable-vpc-dns`    | （可缺省）`true` 启用功能，false 关闭功能。默认 `true`。|
| `coredns-image`     | （可省略）：dns 部署镜像。默认为集群 coredns 部署版本。 |
| `coredns-template`  | （可省略）：dns 部署模板所在的 URL。默认：当前版本仓库里的 `yamls/coredns-template.yaml`   |
| `coredns-vip`       | 为 coredns 提供 lb 服务的 `vip`。|
| `nad-name`          | 配置的 `network-attachment-definitions` 资源名称。|
| `nad-provider`      | 使用的 `provider` 名称。|
| `k8s-service-host`| （可缺省） 用于 coredns 访问 k8s apiserver 服务的 `ip`。|
| `k8s-service-port`| （可缺省）用于 coredns 访问 k8s apiserver 服务的 `port`。|

### 部署 vpc-dns 依赖资源

//// collapse-code
```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: system:vpc-dns
rules:
  - apiGroups:
    - ""
    resources:
    - endpoints
    - services
    - pods
    - namespaces
    verbs:
    - list
    - watch
  - apiGroups:
    - discovery.k8s.io
    resources:
    - endpointslices
    verbs:
    - list
    - watch
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  annotations:
    rbac.authorization.kubernetes.io/autoupdate: "true"
  labels:
    kubernetes.io/bootstrapping: rbac-defaults
  name: vpc-dns
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: system:vpc-dns
subjects:
- kind: ServiceAccount
  name: vpc-dns
  namespace: kube-system
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: vpc-dns
  namespace: kube-system
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: vpc-dns-corefile
  namespace: kube-system
data:
  Corefile: |
    .:53 {
        errors
        health {
          lameduck 5s
        }
        ready
        kubernetes cluster.local in-addr.arpa ip6.arpa {
          pods insecure
          fallthrough in-addr.arpa ip6.arpa
        }
        prometheus :9153
        forward . /etc/resolv.conf {
          prefer_udp
        }
        cache 30
        loop
        reload
        loadbalance
    }
```
////

### 部署 vpc-dns

```yaml linenums="1"
kind: VpcDns
apiVersion: kubeovn.io/v1
metadata:
  name: test-cjh1
spec:
  vpc: cjh-vpc-1
  subnet: cjh-subnet-1
```

| 参数字段                | 描述                                                                      |
|:--------------------|:------------------------------------------------------------------------|
| `vpc`    | 用于部署 dns 组件的 vpc 名称。|
| `subnet`     | 用于部署 dns 组件的子名称。 |


查看资源信息：

```bash
[root@hci-dev-mst-1 kubeovn]# kubectl get vpc-dns
NAME        ACTIVE   VPC         SUBNET   
test-cjh1   false    cjh-vpc-1   cjh-subnet-1   
test-cjh2   true     cjh-vpc-1   cjh-subnet-2 
```

- `ACTIVE: true` 成功部署了自定义 dns 组件，`false` 无部署

### 限制

- 一个 vpc 下只会部署一个自定义 dns 组件;
- 当一个 vpc 下配置多个 vpc-dns 资源（即同一个 vpc 不同的 `subnet`），只有一个 vpc-dns 资源状态 `true`，其他为 `false`;
- 当 `true` 的 vpc-dns 被删除掉，会获取其他 `false` 的 vpc-dns 进行部署。