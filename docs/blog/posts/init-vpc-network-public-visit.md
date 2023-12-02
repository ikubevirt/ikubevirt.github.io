---
title: "VPC多租户网络初始化"
author: Peter Liao
description: 总结VPC多租户网络初始化，持续学习...
categories: "CNI"
date: 2023-11-28 23:52:19
tags: 
  - 'CNI'
  - '网络'
  - 'kubeOVN'
---

//// collapse-code
```bash
vpc-nat-gw-787-default-gw-0:/kube-ovn# ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host proto kernel_lo
       valid_lft forever preferred_lft forever
2: net1@if2: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1450 qdisc noqueue state UP group default
    link/ether 5a:10:75:59:e8:1b brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 192.168.239.102/24 brd 192.168.239.255 scope global net1
       valid_lft forever preferred_lft forever
    inet 192.168.239.200/24 scope global secondary net1
       valid_lft forever preferred_lft forever
    inet6 fe80::5810:75ff:fe59:e81b/64 scope link proto kernel_ll
       valid_lft forever preferred_lft forever
48: eth0@if49: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1350 qdisc noqueue state UP group default
    link/ether 00:00:00:e2:a6:2a brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.66.0.254/16 brd 172.66.255.255 scope global eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::200:ff:fee2:a62a/64 scope link proto kernel_ll
       valid_lft forever preferred_lft forever
vpc-nat-gw-787-default-gw-0:/kube-ovn# ping 114.114.114.114
PING 114.114.114.114 (114.114.114.114) 56(84) bytes of data.
^C
--- 114.114.114.114 ping statistics ---
48 packets transmitted, 0 received, 100% packet loss, time 48129ms

vpc-nat-gw-787-default-gw-0:/kube-ovn# iptables -t nat -L
Chain PREROUTING (policy ACCEPT)
target     prot opt source               destination
DNAT_FILTER  all  --  anywhere             anywhere

Chain INPUT (policy ACCEPT)
target     prot opt source               destination

Chain OUTPUT (policy ACCEPT)
target     prot opt source               destination

Chain POSTROUTING (policy ACCEPT)
target     prot opt source               destination
SNAT_FILTER  all  --  anywhere             anywhere

Chain DNAT_FILTER (1 references)
target     prot opt source               destination
EXCLUSIVE_DNAT  all  --  anywhere             anywhere
SHARED_DNAT  all  --  anywhere             anywhere

Chain EXCLUSIVE_DNAT (1 references)
target     prot opt source               destination

Chain EXCLUSIVE_SNAT (1 references)
target     prot opt source               destination

Chain SHARED_DNAT (1 references)
target     prot opt source               destination

Chain SHARED_SNAT (1 references)
target     prot opt source               destination
SNAT       all  --  172.66.0.0/16        anywhere             to:192.168.239.200 random-fully

Chain SNAT_FILTER (1 references)
target     prot opt source               destination
EXCLUSIVE_SNAT  all  --  anywhere             anywhere
SHARED_SNAT  all  --  anywhere             anywhere
```
////