---
title: "关于OpenEBS的cstore引擎部署以及一些存储方案"
author: Peter Liao
description: OpenEBS的cstor引擎部署以及一些存储方案
categories: "存储"
date: 2023-11-17 23:52:19
tags: 
  - '存储'
  - 'OpenEBS'
---

## 块设备

## OpenEBS的cstor引擎安装

按照官方文档 [https://openebs.io/docs/user-guides/cstor](https://openebs.io/docs/user-guides/cstor), 使用helm部署，

```bash
helm repo add openebs https://openebs.github.io/charts
helm repo update
helm install openebs --namespace openebs openebs/openebs --set cstor.enabled=true --create-namespace
```

部署完发现命名空间openebs下面的statefulSet: `openebs-cstor-csi-controller` 以及 daemonSet: `openebs-cstor-csi-node` 的Pod拉不起来，这是由于镜像源`registry.k8s.io`国内拉取镜像的原因，需要添加前缀`m.daocloud.io`加速镜像拉取 (`m.daocloud.io/registry.k8s.io`)。

