
在使用 SR-IOV 或 DPDK 类型网络时，KubeVirt 内置的 DHCP 无法在该网络模式下工作。Kube-OVN 可以利用 OVN 的 DHCP 能力在子网级别设置 DHCP 选项，从而帮助该网络类型的 KubeVirt 虚机正常使用 DHCP 获得分配的 IP 地址。Kube-OVN 同时支持 DHCPv4 和 DHCPv6。

子网 DHCP 的配置如下：

```yaml linenums="1"
apiVersion: kubeovn.io/v1
kind: Subnet
metadata:
  name: sn-dual
spec:
  cidrBlock: "10.0.0.0/24,240e::a00/120"
  default: false
  disableGatewayCheck: true
  disableInterConnection: false
  excludeIps:
    - 10.0.0.1
    - 240e::a01
  gateway: 10.0.0.1,240e::a01
  gatewayNode: ''
  gatewayType: distributed
  natOutgoing: false
  private: false
  protocol: Dual
  provider: ovn
  vpc: vpc-test
  enableDHCP: true
  dhcpV4Options: "lease_time=3600,router=10.0.0.1,server_id=169.254.0.254,server_mac=00:00:00:2E:2F:B8"
  dhcpV6Options: "server_id=00:00:00:2E:2F:C5"
  enableIPv6RA: true
  ipv6RAConfigs: "address_mode=dhcpv6_stateful,max_interval=30,min_interval=5,send_periodic=true"
```

| 参数字段         | 描述                                                                                                 |
|:-------------|:---------------------------------------------------------------------------------------------------|
| `enableDHCP`  | 是否开启子网的 DHCP 功能。                                                                        |
| `dhcpV4Options,dhcpV6Options` | 该字段直接暴露 `ovn-nb` 内 DHCP 相关选项，请参考 DHCP Options。 默认值分别为 "`lease_time=3600`, `router=$ipv4_gateway`, `server_id=169.254.0.254`, `server_mac=$random_mac`" 和 `server_id=$random_mac`。|
| `enableIPv6RA`    | 是否开启 DHCPv6 的路由广播功能。 |
| `ipv6RAConfigs`| 该字段直接暴露 `ovn-nb` 内 `Logical_Router_Port` 相关选项，请参考 `Logical Router Port` 默认值为 `address_mode=dhcpv6_stateful`, `max_interval=30`, `min_interval=5`, `send_periodic=true`。|

