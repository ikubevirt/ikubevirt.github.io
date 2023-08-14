# VirtualMachine

## 虚拟机CRD

首先来看看VM这个CRD的定义：

```go linenums="1"
type VirtualMachine struct {
     metav1.TypeMeta   `json:",inline"`
     metav1.ObjectMeta `json:"metadata,omitempty"`
     // Spec contains the specification of VirtualMachineInstance created
     Spec VirtualMachineSpec `json:"spec" valid:"required"`
     // Status holds the current state of the controller and brief information
     // about its associated VirtualMachineInstance
     Status VirtualMachineStatus `json:"status,omitempty"`
 }
    
type VirtualMachineSpec struct {
     // Running controls whether the associatied VirtualMachineInstance is created or not
     // Mutually exclusive with RunStrategy
     Running *bool `json:"running,omitempty" optional:"true"`
    
     // Running state indicates the requested running state of the VirtualMachineInstance
     // mutually exclusive with Running
     RunStrategy *VirtualMachineRunStrategy `json:"runStrategy,omitempty" optional:"true"`
    
     // FlavorMatcher references a flavor that is used to fill fields in Template
     Flavor *FlavorMatcher `json:"flavor,omitempty" optional:"true"`
    
     // Template is the direct specification of VirtualMachineInstance
     Template *VirtualMachineInstanceTemplateSpec `json:"template"`
    
     // dataVolumeTemplates is a list of dataVolumes that the VirtualMachineInstance template can reference.
     // DataVolumes in this list are dynamically created for the VirtualMachine and are tied to the VirtualMachine's life-cycle.
     DataVolumeTemplates []DataVolumeTemplateSpec `json:"dataVolumeTemplates,omitempty"`
}
```

在`VirtualMachineSpec`中，有以下的参数：

- `Running`：与`RunStrategy`字段互斥（即只能二选一），如果该字段为`true`，创建了VM对象后会根据`Template`中的内容创建VMI，`false`则不会。
- `RunStrategy`：与`Running`字段互斥（即只能二选一），虚拟机的运行策略，可选值为：`Always`-表示VMI对象应该一直是`running`状态；Halted-表示VMI对象永远都不应该是`running`状态；Manual-VMI可以通过API接口启动或者停止；`RerunOnFailure`-VMI初始应为`running`，当有错误发生时会自动重启；Once-VMI只会运行一次，当出现错误等情况时不会重启。
- `Flavor`：虚拟机底层特性配置，从代码上看目前只有CPU的配置，相关配置项包括是否绑定CPU（绑定的CPU只能给该虚拟机使用）、虚拟机中的线程数、NUMA配置等。`flavor`有`VirtualMachineFlavor和VirtualMachineClusterFlavor`两种类型数据。该字段会被填充到VMI模板对应字段中。
- `Template`：VMI的模板，类似deployment中配置的pod模板。
- `DataVolumeTemplates`：数据卷模板，这里配置的数据卷会自动创建，并且可以被`Template`字段的模板中使用。这些数据卷的生命周期和VM对象的生命周期一致。
