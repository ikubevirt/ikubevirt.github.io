
## 用途

默认 VPC 下的 Overlay 子网，打开 `natOutgoing` 开关时，Subnet 下的所有 Pod 访问外网都需要做 SNAT 成节点的 IP，但是有些场景我们并不希望子网内所有 Pod 访问外网都做 SNAT。

因此 NAT 策略就是为了提供一个接口让用户决定子网内的哪些 CIDR 或者 IP 访问外网做 SNAT。


## 使用方法

在 `subnet.Spec` 中开启 `natOutgoing` 开关， 并且添加字段 `natOutgoingPolicyRules` 如下：

```yaml linenums="1"
spec:
  natOutgoing: true
  natOutgoingPolicyRules:
    - action: forward
      match:
        srcIPs: 10.0.11.0/30,10.0.11.254
    - action: nat
      match:
        srcIPs: 10.0.11.128/26
        dstIPs: 114.114.114.114,8.8.8.8
```

以上案例表示有两条 NAT 策略规则：

1. 源 IP 是 `10.0.11.0/30` 或者 `10.0.11.254` 的报文访问外网时不会做 SNAT。
2. 源 IP 是 `10.0.11.128/26` 并且目的 IP 是 `114.114.114.114` 或者 `8.8.8.8` 的报文访问外网时会做 SNAT。

| <div style="width:160px">参数字段</div> | 描述                                                                                           |
|:------------------------------------|:---------------------------------------------------------------------------------------------|
| `action`                | 满足 `match` 对应条件的报文，会执行的 `action`, `action` 分为两种 `forward` 和 `nat` ，`forward` 表示报文出外网不做 SNAT, nat 表示报文出外网做 SNAT。 没有配置 `natOutgoingPolicyRules` 时，默认情况报文仍然是做 SNAT。                                                                       |
| `match`                              | 表示报文的匹配段，匹配段有 `srcIPs` 和 `dstIPs`， 这里表示从子网内到外网方向上的报文的源 IP 和 目的 IP。`match.srcIPs` 和 `match.dstIPs` 支持多个 CIDR 和 IP，之间用逗号间隔 |

如果出现多个 `match` 规则重叠，则按照 `natOutgoingPolicyRules` 数组顺序进行匹配，最先被匹配的 `action` 会被执行。