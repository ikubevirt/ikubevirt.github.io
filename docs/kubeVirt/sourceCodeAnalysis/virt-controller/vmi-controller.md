
## vmiController

代码位于`kubevirt/pkg/virt-controller/watch/vmi.go`文件中。

1. 监听`VMI`对象、`Pod`对象、`DataVolume`对象并添加对应的EventHandler。
2. 收到Event事件之后加入到workQueue。
    - `VMI`对象的Event事件直接加入workQueue。
    - `Pod`对象的Event事件先判断是否由VM对象所控制，如果是则将该VM对象加入workQueue，否则不处理。
    - `DataVolume`对象的Event事件，根据`DataVolume`的Namespace和Name获取匹配的vmis，然后将vmis对象依次加入到workQueue。
3. 通过`Run()`->`runWorker()`->`Execute()`->`execute()`，从workQueue中取出对象的key，然后在`execute`中处理。
4. `execute()` 函数的处理逻辑
    - 根据key，从Informer的本地缓存中获取VM对象。
    - 获取和当前vmi对象匹配的Pod。
    - 根据`vmi.Spec.Volumes`，获取匹配的`DataVolumes`对象。
    - 同步sync，若Pod不存在，则创建lanucher所在的Pod。
    - 更新vmi对象的status。