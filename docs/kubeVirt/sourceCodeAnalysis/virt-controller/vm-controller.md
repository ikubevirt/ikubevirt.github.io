

## vmController

代码位于`kubevirt/pkg/virt-controller/watch/vm.go`文件中。

1. 监听`VM`对象、`VMI`对象、`DataVolume`对象并添加对应的`EventHandler`。 
2. 收到Event事件之后加入到workQueue。
    - `VM`对象的Event事件直接加入workQueue。
    - `VMI`对象的Event事件先判断是否由VM对象所控制，如果是则将该VM对象加入workQueue，否则找到匹配的VM，将匹配的VM加入到workQueue，尝试收养孤儿的VMI对象。
    - `DataVolume`对象的Event事件先判断是否由VM对象所控制，如果是则将该VM对象加入workQueue，否则不处理。
3. 通过`Run()`->`runWorker()`->`Execute()`->`execute()`，从workQueue中取出对象的key，然后在`execute`中处理。
4. `execute()` 函数的处理逻辑
    - 根据key，从Informer的本地缓存中获取VM对象。
    - 创建`VirtualMachineControllerRefManager`。
    - 根据key，从Informer的本地缓存中获取VMI对象
    - 如果获取VMI对象成功，则`VirtualMachineControllerRefManager`尝试收养或遗弃VMI。
    - 根据`Spec.DataVolumeTemplates`,从Informer的本地缓存中获取dataVolumes。
    - 检查`dataVolumes`是否已经`ready`，若已经`ready`则调用`startStop()`
         - `RunStrategy==Always`:虚拟机实例VMI应该总是存在，如果虚拟机实例VMI crash，会创建一个新的虚拟机。等同于`spec.running:true`。
         - `RunStrategy==RerunOnFailure`:如果虚拟机实例VMI运行失败，会创建一个新的虚拟机。如果是由客户端主动成功关闭，则不会再重新创建。
         - `RunStrategy==Manual`:虚拟机实例VMI运行状况通过start/stop/restart手工来控制。
         - `RunStrategy==Halted`:虚拟机实例VMI应该总是挂起。等同于`spec.running:false`。
    - 更新VMStatus
         - 修改`vm.Status.Created，vm.Status.Ready`
         - 修改`vm.Status.StateChangeRequests`
         - 修改`vm.Status.Conditions`
         - 更新VMStatus