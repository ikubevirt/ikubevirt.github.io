---
title: "LinuxCNI网卡相关命令"
author: Peter Liao
description: 总结相关CNI网卡的命令，持续学习...
categories: "CNI"
date: 2023-10-28 23:52:19
tags: 
  - 'CNI'
  - '网络'
---

## 虚拟网卡和物理网卡

查看全部网卡，目录在`/sys/class/net/`:

```bash
[root@localhost ~]# ls /sys/class/net/
br-df65b94a220f  docker0  enp0s31f6  lo  veth1706661  veth2566f96  veth7c083c7  vethd4a4beb  vethfa8ecf9  vethfd44a20  wlp1s0
```

查看虚拟网卡，目录在`/sys/devices/virtual/net/`：

```bash
[root@localhost ~]# ls /sys/devices/virtual/net/
br-df65b94a220f  docker0  lo  veth1706661  veth2566f96  veth7c083c7  vethd4a4beb  vethfa8ecf9  vethfd44a20
```

查看物理网卡：

```bash
[root@localhost ~]# ls /sys/class/net/ | grep -v "`ls /sys/devices/virtual/net/`"
enp0s31f6
wlp1s0
```