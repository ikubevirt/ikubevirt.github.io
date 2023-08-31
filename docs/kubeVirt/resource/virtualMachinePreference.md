
kubeVirt 还提供了两个基于偏好的 CRD，同样是集群范围的 `VirtualMachineClusterPreference` 和具体命名空间下的 `VirtualMachinePreference`。 这些 CRD 封装了运行给定工作负载所需的 VirtualMachine 的任何剩余属性的首选值，这也是通过共享 `VirtualMachinePreferenceSpec` 实现的。

!!! example "例子"

    ```yaml linenums="1"
    apiVersion: instancetype.kubevirt.io/v1beta1
    kind: VirtualMachinePreference
    metadata:
      name: example-preference
    spec:
      devices:
        preferredDiskBus: virtio
        preferredInterfaceModel: virtio
    ```

与Instancetypes不同，首选项仅代表首选值，因此它们可以被用户提供的 VirtualMachine 中的值覆盖。

在下面所示的示例中，用户提供了一个带有已在 `DiskTarget` 中定义的磁盘总线的 VirtualMachine，并且还使用 `DevicePreference` 和 `PreferredDiskBus` 选择了一组首选项，因此使用用户在 VirtualMachine 和 `DiskTarget` 中的原始选择：

```yaml linenums="1" title="vmPref.yaml"
---
apiVersion: instancetype.kubevirt.io/v1beta1
kind: VirtualMachinePreference
metadata:
  name: example-preference-disk-virtio
spec:
  devices:
    preferredDiskBus: virtio
---
apiVersion: kubevirt.io/v1
kind: VirtualMachine
metadata:
  name: example-preference-user-override
spec:
  preference:
    kind: VirtualMachinePreference
    name: example-preference-disk-virtio
  running: false
  template:
    spec:
      domain:
        memory:
          guest: 128Mi
        devices:
          disks:
          - disk:
              bus: sata
            name: containerdisk
          - disk: {}
            name: cloudinitdisk
        resources: {}
      terminationGracePeriodSeconds: 0
      volumes:
      - containerDisk:
          image: registry:5000/kubevirt/cirros-container-disk-demo:devel
        name: containerdisk
      - cloudInitNoCloud:
          userData: |
            #!/bin/sh

            echo 'printed from cloud-init userdata'
        name: cloudinitdisk
```

对上述清单对象进行编排，并启动VM，

```bash
$ kubectl apply -f vmiPref.yaml
virtualmachinepreference.instancetype.kubevirt.io/example-preference-disk-virtio created
virtualmachine.kubevirt.io/example-preference-user-override configured

$ virtctl start example-preference-user-override
VM example-preference-user-override was scheduled to start

# We can see the original request from the user within the VirtualMachine lists `containerdisk` with a `SATA` bus
$ kubectl get vms/example-preference-user-override -o json | jq .spec.template.spec.domain.devices.disks
[
  {
    "disk": {
      "bus": "sata"
    },
    "name": "containerdisk"
  },
  {
    "disk": {},
    "name": "cloudinitdisk"
  }
]

# This is still the case in the VirtualMachineInstance with the remaining disk using the `preferredDiskBus` from the preference of `virtio`
$ kubectl get vmis/example-preference-user-override -o json | jq .spec.domain.devices.disks
[
  {
    "disk": {
      "bus": "sata"
    },
    "name": "containerdisk"
  },
  {
    "disk": {
      "bus": "virtio"
    },
    "name": "cloudinitdisk"
  }
]
```
