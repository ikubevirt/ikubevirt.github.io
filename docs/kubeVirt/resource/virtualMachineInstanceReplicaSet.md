# VirtualMachineInstanceReplicaSet

## 虚拟机实例弹性伸缩

!!! info "vmirs定义"

    VirtualMachineInstanceReplicaSet（vmirs）确保指定数量的 VirtualMachineInstance（vmi） 副本在任何时候都在运行。

我们可以这样理解，vmirs 就是kubernetes（k8s）里面的控制器（Deployment，ReplicaSet）管理我们pod的副本数，实现扩缩容、回滚等。也可以借助HorizontalPodAutoscaler（HPA）实现弹性伸缩。这里我们就说vmirs控制器，在这里的vmirs控制器，管理我们vmi虚拟机实例的副本数，也可以实现扩缩容，借助HPA实现弹性伸缩。所有我们的yaml文件写法原理都类似。

## 适用场景

当需要许多相同的虚拟机，并且不关心在虚拟机终止后任何磁盘状态时。

## 
