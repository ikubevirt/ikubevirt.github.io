
`virt-handler` 的入口在下面这个函数
```go linenums="1"
src\kubevirt.io\kubevirt\cmd\virt-handler\virt-handler.go:main()
```

这个函数做的事情有：

1. 初始化一个 `virtHandlerApp` ，注册 `flag` 参数，使 virt-handler 可执行文件可以接收参数输入
2. 初始化日志记录器，日志级别为 `INFO`
3. 运行 app

`Run` 函数的主要逻辑就是实例化一个 VirtualMachineController 对象

```go linenums="1"
vmController := virthandler.NewController(
    recorder,
    app.virtCli,
    app.HostOverride,
    app.PodIpAddress,
    app.VirtShareDir,
    app.VirtPrivateDir,
    vmiSourceInformer,
    vmiTargetInformer,
    domainSharedInformer,
    gracefulShutdownInformer,
    int(app.WatchdogTimeoutDuration.Seconds()),
    app.MaxDevices,
    app.clusterConfig,
    podIsolationDetector,
    migrationProxy,
)
go vmController.Run(10, stop)
```

并且启用 10 个协程，使用 `wait.Until` 每间隔 1 秒运行程序

```go linenums="1"
func (c *VirtualMachineController) Run(threadiness int, stopCh chan struct{}) {
...more
    for i := 0; i < threadiness; i++ {
        go wait.Until(c.runWorker, time.Second, stopCh)
    }
...more
```

检查 `VirtualMachineController.Queue` 是否有需要处理的 vmi 实例，如果没有，退出等待下一循环，如果有，就执行 `c.execut` 去执行相应逻辑，包括 `virt-launcher` Pod 的网络准备，虚拟机的启动。

```go linenums="1"
func (c *VirtualMachineController) Execute() bool {
    key, quit := c.Queue.Get()
    if quit {
        return false
    }
    defer c.Queue.Done(key)
    if err := c.execute(key.(string)); err != nil {
        log.Log.Reason(err).Infof("re-enqueuing VirtualMachineInstance %v", key)
        c.Queue.AddRateLimited(key)
    } else {
        log.Log.V(4).Infof("processed VirtualMachineInstance %v", key)
        c.Queue.Forget(key)
    }
    return true
}
```

那么 `VirtualMachineController.Queue` 的队列消息是哪里塞入的呢？

这就不得不说到 K8S 的 Informer 机制具体可参考这篇文章：[https://www.kubernetes.org.cn/2693.html](https://www.kubernetes.org.cn/2693.html)

其实早在实例化 VirtualMachineController 对象的时候，就有传入几个 Informer 对象，包括：

- `vmiSourceInformer`：有新增到该节点的虚拟机
- `vmiTargetInformer`：有迁移到该台节点的虚拟机
- `domainSharedInformer` ：监听本节点上的 virt-launcher 中的 domain 实例

在 NewController 里会给这些 Informer 对象注册回调函数，当 K8S 上有该 Host 的 vmi 对象发生新增、销毁、更新的时候，就会触发相应的函数

```go linenums="1"
vmiSourceInformer.AddEventHandler(cache.ResourceEventHandlerFuncs{
    AddFunc:    c.addFunc,
    DeleteFunc: c.deleteFunc,
    UpdateFunc: c.updateFunc,
})
```

以新增为例，来看一下 `addFunc` 的代码

在函数中会将 vmi 的 key （类似 `default/vm-name`）塞入到 `VirtualMachineController.Queue` 队列中。

```go linenums="1"
func (d *VirtualMachineController) addFunc(obj interface{}) {
    key, err := controller.KeyFunc(obj)
    if err == nil {
        d.Queue.Add(key)
    }
}
```

说完消息队列的事情，再回到主体逻辑，继续往下看 `c.execute`的代码

在这个函数里，会拿着 key 去一个一个查看是在 `vmiSourceInformer` 、`vmiTargetInformer` 和 `domainInformer` 的哪一个缓存中，并获得具体的 vmi 对象信息。

然后再判断该 vmi 是迁移的源还是目标，如果都不是，就说明是新机创建，应该走 `defaultExecute`

```go linenums="1"
    if vmiExists && d.isPreMigrationTarget(vmi) {
        // 1. PRE-MIGRATION TARGET PREPARATION PATH
        //
        // If this node is the target of the vmi's migration, take
        // a different execute path. The target execute path prepares
        // the local environment for the migration, but does not
        // start the VMI
        return d.migrationTargetExecute(vmi, vmiExists, domainExists)
    } else if vmiExists && d.isOrphanedMigrationSource(vmi) {
        // 3. POST-MIGRATION SOURCE CLEANUP
        //
        // After a migration, the migrated domain still exists in the old
        // source's domain cache. Ensure that any node that isn't currently
        // the target or owner of the VMI handles deleting the domain locally.
        return d.migrationOrphanedSourceNodeExecute(vmi, domainExists)
    }
    return d.defaultExecute(key,
        vmi,
        vmiExists,
        domain,
        domainExists)
```

`defaultExecute` 函数中，会根据 vmi 和 domain 的真实状态的不同，选择不同的处理方案，由于场景过多，这里不一一解释，要用的时候来这边看代码即可，现在主要理清虚拟机创建流程，也即 vmi 的状态为 `Scheduled` 或者 `Failed` 的时候，而 domain 其实还没创建，`shouldUpdate` 就会是 `true`，因为就会走 `processVmUpdate` 就创建虚拟机，来保持 vmi 和 domain 的状态一致。

```go linenums="1"
// Determine if an active (or about to be active) VirtualMachineInstance should be updated.
if vmiExists && !vmi.IsFinal() {
    // requiring the phase of the domain and VirtualMachineInstance to be in sync is an
    // optimization that prevents unnecessary re-processing VMIs during the start flow.
    phase, err := d.calculateVmPhaseForStatusReason(domain, vmi)
    if err != nil {
        return err
    }
    if vmi.Status.Phase == phase {
        shouldUpdate = true
    }
}



switch {
    case forceIgnoreSync:
        log.Log.Object(vmi).V(3).Info("No update processing required: forced ignore")
    case shouldShutdown:
        log.Log.Object(vmi).V(3).Info("Processing shutdown.")
        syncErr = d.processVmShutdown(vmi, domain)
    case shouldDelete:
        log.Log.Object(vmi).V(3).Info("Processing deletion.")
        syncErr = d.processVmDelete(vmi)
    case shouldCleanUp:
        log.Log.Object(vmi).V(3).Info("Processing local ephemeral data cleanup for shutdown domain.")
        syncErr = d.processVmCleanup(vmi)
    case shouldUpdate:
        log.Log.Object(vmi).V(3).Info("Processing vmi update")
        syncErr = d.processVmUpdate(vmi)
    default:
        log.Log.Object(vmi).V(3).Info("No update processing required")
}
```

在 `processVmUpdate` 函数，还会继续判断该虚拟机是迁移流程还是新建流程

```go linenums="1"
func (d *VirtualMachineController) processVmUpdate(vmi *v1.VirtualMachineInstance) error {
...more

    if d.isPreMigrationTarget(vmi) {
        return d.vmUpdateHelperMigrationTarget(vmi)
    } else if d.isMigrationSource(vmi) {
        return d.vmUpdateHelperMigrationSource(vmi)
    } else {
        return d.vmUpdateHelperDefault(vmi)
    }
}
```

继续往 `vmUpdateHelperDefault` 函数查看具体的逻辑：

- 准备 virt-launcher 的网络环境：`d.setPodNetworkPhase1(vmi)`
- 发送 gRPC 消息给 virt-launcher：`client.SyncVirtualMachine(vmi, options)`
