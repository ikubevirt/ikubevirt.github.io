
Kube-OVN 支持使用 `QoSPolicy` CRD 对自定义 VPC 的流量速率进行限制。

## EIP QoS

对 EIP 进行限速，限速值为 `1Mbps`，优先级为 1，这里 `shared=false`，表示这个 `QoSPolicy` 只能给这个 EIP 使用且支持动态修改 `QoSPolicy` 去变更 QoS 规则。

`QoSPolicy` 配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: QoSPolicy
metadata:
  name: qos-eip-example
spec:
  shared: false
  bindingType: EIP
  bandwidthLimitRules:
  - name: eip-ingress
    rateMax: "1" # Mbps
    burstMax: "1" # Mbps
    priority: 1
    direction: ingress
  - name: eip-egress
    rateMax: "1" # Mbps
    burstMax: "1" # Mbps
    priority: 1
    direction: egress
```

IptablesEIP 配置如下：

```yaml linenums="1"
kind: IptablesEIP
apiVersion: kubeovn.io/v1
metadata:
  name: eip-1
spec:
  natGwDp: gw1
  qosPolicy: qos-eip-example
```

`.spec.qosPolicy`的值支持创建时传入，也支持创建后修改。

## 查看已启用 QoS 的 EIP

通过label查看已经设置对应 qos 的 eip：

```bash
$ kubectl get eip  -l ovn.kubernetes.io/qos=qos-eip-example
NAME    IP             MAC                 NAT   NATGWDP   READY
eip-1   172.18.11.24   00:00:00:34:41:0B   fip   gw1       true
```

对 VPC NATGW 的 `net1` 网卡速率进行限制，限速值为 `10Mbps`，优先级为 3，这里 `shared=true`，表示这个 `QoSPolicy` 可以同时给多个资源使用，这种场景下不允许修改 `QoSPolicy` 的内容。

`QoSPolicy` 配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: QoSPolicy
metadata:
  name: qos-natgw-example
spec:
  shared: true
  bindingType: NATGW
  bandwidthLimitRules:
  - name: net1-ingress
    interface: net1
    rateMax: "10" # Mbps
    burstMax: "10" # Mbps
    priority: 3
    direction: ingress
  - name: net1-egress
    interface: net1
    rateMax: "10" # Mbps
    burstMax: "10" # Mbps
    priority: 3
    direction: egress
```

`VpcNatGateway` 配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: VpcNatGateway
metadata:
  name: gw1
spec:
  vpc: test-vpc-1
  subnet: net1
  lanIp: 10.0.1.254
  qosPolicy: qos-natgw-example
  selector:
    - "kubernetes.io/hostname: kube-ovn-worker"
    - "kubernetes.io/os: linux"
```

`.spec.qosPolicy`的值支持创建传入，也支持后续修改。

## net1 网卡特定流量 QoS

对 net1 网卡上特定流量进行限速，限速值为 `5Mbps`，优先级为 2，这里 `shared=true`，表示这个 `QoSPolicy` 可以同时给多个资源使用，此时不允许修改 `QoSPolicy` 的内容。

`QoSPolicy` 配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: QoSPolicy
metadata:
  name: qos-natgw-example
spec:
  shared: true
  bindingType: NATGW
  bandwidthLimitRules:
  - name: net1-extip-ingress
    interface: net1
    rateMax: "5" # Mbps
    burstMax: "5" # Mbps
    priority: 2
    direction: ingress
    matchType: ip
    matchValue: src 172.18.11.22/32
  - name: net1-extip-egress
    interface: net1
    rateMax: "5" # Mbps
    burstMax: "5" # Mbps
    priority: 2
    direction: egress
    matchType: ip
    matchValue: dst 172.18.11.23/32
```

`VpcNatGateway` 配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: VpcNatGateway
metadata:
  name: gw1
spec:
  vpc: test-vpc-1
  subnet: net1
  lanIp: 10.0.1.254
  qosPolicy: qos-natgw-example
  selector:
    - "kubernetes.io/hostname: kube-ovn-worker"
    - "kubernetes.io/os: linux"
```

## 查看已启用 QoS 的 NATGW

通过`label`查看已经设置对应 qos 的 eip：

```bash
$ kubectl get vpc-nat-gw  -l ovn.kubernetes.io/qos=qos-natgw-example
NAME   VPC          SUBNET   LANIP
gw1    test-vpc-1   net1     10.0.1.254
```

## 查看 qos 规则

```bash
$ kubectl get qos -A
NAME                SHARED   BINDINGTYPE
qos-eip-example     false    EIP
qos-natgw-example   true     NATGW
```

## 限制

- 只有在未使用时才能删除 QoS 策略。因此，在删除 QoS 策略之前，请先查看已启用 QoS 的 EIP 和 NATGW，去掉它们的 `spec.qosPolicy` 配置。