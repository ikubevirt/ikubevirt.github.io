
[//]: # (``` mermaid)

[//]: # (sequenceDiagram)

[//]: # (  autonumber)

[//]: # (  Alice->>John: Hello John, how are you?)

[//]: # (  loop Healthcheck)

[//]: # (      John->>John: Fight against hypochondria)

[//]: # (  end)

[//]: # (  Note right of John: Rational thoughts!)

[//]: # (  John-->>Alice: Great!)

[//]: # (  John->>Bob: How about you?)

[//]: # (  Bob-->>John: Jolly good!)

[//]: # (```)

## 通用源码入口

在此之前，需要知道所有的 kubevirt 组件都是从 `cmd/virt-*` 开始的

![](https://cdn.jsdelivr.net/gh/ikubevirt/ikubevirt.github.io/docs/assets/images/kubeVirt-entry.png){ loading=lazy }

## 启动流程

首先调用入口函数
```go linenums="1" title="kubevirt/cmd/virt-controller/virt-controller.go"
import (
	_ "kubevirt.io/kubevirt/pkg/monitoring/client/prometheus"    // import for prometheus metrics
	_ "kubevirt.io/kubevirt/pkg/monitoring/reflector/prometheus" // import for prometheus metrics
	_ "kubevirt.io/kubevirt/pkg/monitoring/workqueue/prometheus" // import for prometheus metrics
	"kubevirt.io/kubevirt/pkg/virt-controller/watch"
)

func main() {
	watch.Execute()
}
```
直接调用`kubevirt/pkg/virt-controller/watch/application.go`中的`Execute`函数启动virt-controller。下面主要分析`Execute`函数中的内容。

### 获取`leaderElectionConfiguration`

获取`leaderElectionConfiguration`, 可通过`leaderelectionconfig`包获取：
```go linenums="1" title="kubevirt/pkg/virt-controller/watch/application.go"
app.LeaderElection = leaderelectionconfig.DefaultLeaderElectionConfiguration()
```

### 获取`KubevirtClient`
```go linenums="1" title="kubevirt/pkg/virt-controller/watch/application.go"
clientConfig, err := kubecli.GetKubevirtClientConfig()
if err != nil {
    panic(err)
}
clientConfig.RateLimiter = app.reloadableRateLimiter
app.clientSet, err = kubecli.GetKubevirtClientFromRESTConfig(clientConfig)
if err != nil {
	golog.Fatal(err)
}
```

### 获取`informerFactory`

获取`informerFactory`，并实例化一系列具体资源类型的Informer，例如`crdInformer`、`kubeVirtInformer`、`vmiInformer`、`kvPodInformer`、`nodeInformer`、`vmInformer`、`migrationInformer`等
```go linenums="1" title="kubevirt/pkg/virt-controller/watch/application.go"
app.informerFactory = controller.NewKubeInformerFactory(app.restClient, app.clientSet, nil, app.kubevirtNamespace)
   
// 实例化各资源类型的informer
app.crdInformer = app.informerFactory.CRD()
app.kubeVirtInformer = app.informerFactory.KubeVirt()
// ...
```

### 初始化一系列controller

这一系列controller主要包括`vmiController`、`nodeController`、`migrationController`、`vmController`、`evacuationController`、`snapshotController`、`restoreController`、`replicaSetController`、`disruptionBudgetController`
```go linenums="1" title="kubevirt/pkg/virt-controller/watch/application.go"
// 初始化一系列controller
app.initCommon()
app.initReplicaSet()
app.initPool()
app.initVirtualMachines()
app.initDisruptionBudgetController()
app.initEvacuationController()
app.initSnapshotController()
app.initRestoreController()
app.initExportController()
app.initWorkloadUpdaterController()
app.initCloneController()
```

### 通过`leaderElector`启动virt-controller

通过`leaderElector`来启动virt-controller，并在`leaderElector`中启动各个controller的`Run`函数。

//// collapse-code
```go linenums="1" title="kubevirt/pkg/virt-controller/watch/application.go"
func (vca *VirtControllerApp) Run() {
  logger := log.Log

  promCertManager := bootstrap.NewFileCertificateManager(vca.promCertFilePath, vca.promKeyFilePath)
  go promCertManager.Start()
  promTLSConfig := kvtls.SetupPromTLS(promCertManager, vca.clusterConfig)

  go func() {
	httpLogger := logger.With("service", "http")
	_ = httpLogger.Level(log.INFO).Log("action", "listening", "interface", vca.BindAddress, "port", vca.Port)
	http.Handle("/metrics", promhttp.Handler())
	server := http.Server{
		Addr:      vca.Address(),
		Handler:   http.DefaultServeMux,
		TLSConfig: promTLSConfig,
	}
	if err := server.ListenAndServeTLS("", ""); err != nil {
		golog.Fatal(err)
	}
  }()

  if err := vca.setupLeaderElector(); err != nil {
	golog.Fatal(err)
  }

  readyGauge.Set(1)
  vca.leaderElector.Run(vca.ctx)
  readyGauge.Set(0)
  panic("unreachable")
}
```
////
///
## virt-controller分析

<div class="grid cards" markdown>

-  __[vmController]__ – 深入剖析`vmController`实现过程
-  __[vmiController]__ – 深入剖析`vmiController`实现过程


</div>

  [vmController]: vm-controller.md
  [vmiController]: vmi-controller.md
