
## kubeVirt资源管理

Kubernetes通过Pod的Resource `requests`来申请占用资源，根据资源请求量Kubernetes计算主机节点资源进行Pod的调度。默认情况下kubeVirt根据虚拟机VM的资源请求从主机申请资源创建虚拟机virt-launcher Pod，Pod调度后调用`libvirt`创建对应虚拟机，通过这种方式达到了Kubernetes对虚拟机资源的管理和调度。

通过上面介绍，我们知道kubeVirt可以分开配置Pod的资源`request`与`libvirt`虚拟机资源，比如通过设置一个比例来达到虚拟机资源超卖。举例说明，如果我们设置内存超卖比例为`150%`，创建一个虚拟机内存为`3072M`，那么Pod请求内存资源则为`2048M`。假设主机内存为`100G`，不考虑其他组件资源开销，根据Pod请求则可以创建出内存总量为`150G`的虚拟机。

## CPU时间

Kubernetes将CPU一个核切分为1000时间片，使用m作为单位，`1m`表示千分之一核milliCPU。

## 资源超卖实践

### kubeVirt配置资源分配比例

`cpuAllocationRatio`指定CPU分配比例`2000%`，比如虚拟机CPU核数为12核，Pod virt-launcher的CPU资源请求则为`600m`。`memoryOvercommit`指定内存分配比例为`150%`。

```yaml linenums="1"
kubectl -n kubevirt edit kubevirt
...
spec:
  configuration:
    developerConfiguration:
      cpuAllocationRatio: 20
      featureGates:
      - HardDisk
      - DataVolumes
      memoryOvercommit: 150
...
```

### 创建kubeVirt虚拟机

可以看到`spec.template.domain`下的`spec.template.domain.cpu`和`spec.template.domain.memory`指定了创建虚拟机资源。

`spec.template.domain.resources.overcommitGuestOverhead`配置不请求额外资源开销，管理虚拟机的基础设施组件需要的内存资源。默认为`false`，当创建一个虚拟机内存为`1Gi`时，virt-launcher Pod请求的内存资源为`1Gi + 200Mi`。

`spec.template.domain.resources.requests`这里仍然指定了`requests`，virt-launcher Pod将使用这个`requests`来请求k8s资源，这样就会不使用上面配置的比例。一般情况不需要再这里指定`requests`，kubeVirt使用比例计算出`requests`的资源量。

//// collapse-code
```yaml
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  labels:
    kubevirt.io/vm: mailserver
  name: ubuntu-c
  namespace: mail263
spec:
  running: true
  template:
    metadata:
      labels:
        kubevirt.io/vm: ubuntu-c
      annotations:
        ovn.kubernetes.io/ip_address: 172.16.3.203
        ovn.kubernetes.io/mac_address: 00:00:00:1F:C5:8F
    spec:
      domain:
        cpu:
          cores: 12
          model: host-passthrough
        memory:
          guest: 96Gi
        devices:
          disks:
          - name: bootdisk
            disk:
              bus: virtio
          - disk:
              bus: virtio
            name: cloudinitdisk
          interfaces:
          - name: default
            bridge: {}
            macAddress: 00:00:00:1f:c5:8f
        resources:
          overcommitGuestOverhead: true
          requests:
            memory: 16Gi
      networks:
      - name: default
        pod: {}
      terminationGracePeriodSeconds: 0
      volumes:
      - name: bootdisk
        dataVolume:
          name: ubuntuboot-c
      - name: cloudinitdisk
        cloudInitNoCloud:
          userData: |-
            #cloud-config
            ssh_pwauth: True
            chpasswd:
              list: |
                ubuntu:ubuntu
```
////

### 查看kubeVirt的ubuntu-c虚拟机VMI资源定义

```yaml linenums="1"
spec:
  domain:
    cpu:
      cores: 12
      model: host-passthrough

    memory:
      guest: 96Gi
    resources:
      overcommitGuestOverhead: true
      requests:
        memory: 16Gi
```

### 查看virt-launcher Pod资源请求

可以看到CPU根据配置的比例`2000%`计算得到，内存根据`requests`指定值申请。

```yaml
    resources:
          limits:
            devices.kubevirt.io/kvm: "1"
            devices.kubevirt.io/tun: "1"
            devices.kubevirt.io/vhost-net: "1"
          requests:
            cpu: 600m
            devices.kubevirt.io/kvm: "1"
            devices.kubevirt.io/tun: "1"
            devices.kubevirt.io/vhost-net: "1"
            ephemeral-storage: 50M
            memory: 16Gi
```

### 查看虚拟机系统资源

```bash
ubuntu@ubuntu-c:~$ free -m
              total        used        free      shared  buff/cache   available
Mem:          96575         290       95782           1         503       95442
Swap:             0           0           0
ubuntu@ubuntu-c:~$ top
top - 10:38:49 up 10:17,  1 user,  load average: 0.48, 0.20, 0.08
Tasks: 198 total,   1 running, 197 sleeping,   0 stopped,   0 zombie
%Cpu0  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu1  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu2  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu3  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu4  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu5  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu6  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu7  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu8  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu9  :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu10 :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
%Cpu11 :  0.0 us,  0.0 sy,  0.0 ni,100.0 id,  0.0 wa,  0.0 hi,  0.0 si,  0.0 st
MiB Mem :  96575.3 total,  95781.5 free,    290.4 used,    503.4 buff/cache
MiB Swap:      0.0 total,      0.0 free,      0.0 used.  95441.8 avail Mem
```

