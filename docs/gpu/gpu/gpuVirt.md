
## 作为PCIe设备的GPU

不考虑嵌入式平台的话，那么，GPU 首先是一个 PCIe 设备。GPU 的虚拟化，还是要首先从 PCIe 设备虚拟化角度来考虑。

??? question "那么一个 PCIe 设备，有什么资源？有什么能力？"

    2 种资源:

    - 配置空间
    - `MMIO`
    - (有的还有 `PIO` 和 Option ROM，此略)

    2 种能力:

    - 中断能力
    - DMA 能力

一个典型的 GPU 设备的工作流程是:

1. 应用层调用 GPU 支持的某个 API，如 OpenGL 或 CUDA
2. OpenGL 或 `CUDA` 库，通过 `UMD` (User Mode Driver)，提交 workload 到 `KMD` (Kernel Mode Driver)
3. `KMD` 写 `CSR MMIO`，把它提交给 GPU 硬件
4. GPU 硬件开始工作... 完成后，`DMA` 到内存，发出中断给 CPU
5. CPU 找到中断处理程序 —— `KMD` 此前向 OS Kernel 注册过的 —— 调用它
6. 中断处理程序找到是哪个 workload 被执行完毕了，...最终驱动唤醒相关的应用

## PCIe直通

我们首先来到 GPU 虚拟化的最保守的实现: PCIe 设备直通。

如前述，一个 PCIe 设备拥有 2 种资源、2 种能力。你把这 2 种资源都（直接或间接地）交给 VM、针对这 2 种能力都把设备和 VM 接通，那么，VM 就能完整使用这个 PCIe 设备，就像在物理机上一样。这种方案，我们称之为 PCIe 直通（PCIe Pass-Through）。它只能 1:1，不支持 `1:N`。其实并不能算真正的虚拟化，也没有超卖的可能性。

VM 中，使用的是原生的 GPU 驱动。它向 VM 内核分配内存，把 GPA 填入到 GPU 的 `CSR` 寄存器，GPU 用它作为 `IOVA` 来发起 `DMA` 访问，`VT-d` 保证把 GPA 翻译为正确的 HPA，从而 `DMA` 到达正确的物理内存。

PCIe 协议，在事务层(`Transaction Layer`)，有多种 TLP，`DMA` 即是其中的一种: `MRd/MWr`。在这种 TLP 中，必须携带发起者的 Routing ID，而在 `IOMMU` 中，就根据这样的 Routing ID，可以使用不同的 `IOMMU` 页表进行翻译。

很显然，PCIe 直通只能支持 `1:1` 的场景，无法满足 `1:N` 的需求。

## SR-IOV

??? question "那么，业界对 `1:N` 的 PCIe 虚拟化是如何实现的呢？"

    我们首先就会想到 SR-IOV。SR-IOV 是 PCI-SIG 在 2007 年推出的规范，目的就是 PCIe 设备的虚拟化。SR-IOV 的本质是什么？考虑我们说过的 2 种资源和 2 种能力，来看看一个 VF 有什么:

    - 配置空间是虚拟的（特权资源）
    - `MMIO` 是物理的
    - 中断和 DMA，因为 VF 有自己的 PCIe 协议层的标识（Routing ID，就是 BDF），从而拥有独立的地址空间。

??? question "那么，什么设备适合实现 SR-IOV？"

    其实无非是要满足两点:

    - 硬件资源要容易 partition
    - 无状态（至少要接近无状态）

常见 PCIe 设备中，最适合 SR-IOV 的就是网卡了: 一或多对 `TX/RX queue` + 一或多个中断，结合上一个 Routing ID，就可以抽象为一个 VF。而且它是近乎无状态的。

试考虑 NVMe 设备，它的资源也很容易 partition，但是它有存储数据，因此在实现 SR-IOV 方面，就会有更多的顾虑。

## API转发

因此，在业界长期缺乏 SRIOV-capable GPU、又有强烈的 `1:N` 需求的情形下，就有更 high-level 的方案出现了。我们首先回到 GPU 应用的场景:

1. 渲染（`OpenGL`、`DirectX`，etc.）
2. 计算（`CUDA`，`OpenCL`）
3. 媒体编解码（`VAAPI`...)

业界就从这些 API 入手，在软件层面实现了**GPU 虚拟化**。以 AWS Elastic GPU 为例:

- VM 中看不到真的或假的 GPU，但可以调用 OpenGL API 进行渲染
- 在 OpenGL API 层，软件捕捉到该调用，转发给 Host
- Host 请求 GPU 进行渲染
- Host 把渲染的结果，转发给 VM

API 层的 GPU 虚拟化是目前业界应用最广泛的 GPU 虚拟化方案。它的好处是:

- **灵活**。`1:N` 的 N，想定为多少，软件可自行决定；哪个 VM 的优先级高，哪个 VM 的优先级低，同理。
- **不依赖于 GPU 硬件厂商**。微软、VMWare、Citrix、华为……都可以实现。这些 API 总归是公开的。
- **不限于系统虚拟化环境**。容器也好，普通的物理机也好，都可以 API 转发到远端。

缺点呢？

复杂度极高。同一功能有多套 API（渲染的 DirectX 和 OpenGL），同一套 API 还有不同版本（如 DirectX 9 和 DirectX 11），兼容性就复杂的要命。
功能不完整。计算渲染媒体都支持的 API 转发方案，还没听说过。并且，编解码甚至还不存在业界公用的 API

## MPT/MDEV/vGPU

鉴于这些困难，业界就出现了 SR-IOV、API 转发之外的第三种方案。我们称之为 `MPT`（Mediated Pass-Through，受控的直通）。 `MPT` 本质上是一种通用的 PCIe 设备虚拟化方案，甚至也可以用于 PCIe 之外的设备。它的基本思路是：

- 敏感资源如配置空间，是虚拟的
- 关键资源如 `MMIO`（CSR 部分），是虚拟的，以便 `trap-and-emulate`
- 性能关键资源如 `MMIO`（GPU 显存、NVMe CMB 等），硬件 partition 后直接赋给 VM
- Host 上必须存在一个 Virtualization-Aware 的驱动程序，以负责模拟和调度，它实际上是 vGPU 的 device-model

这样，VM 中就能看到一个看似完整的 GPU PCIe 设备，它也可以 attach 原生的 GPU 驱动。以渲染为例，vGPU 的基本工作流程是:

1. VM 中的 GPU 驱动，准备好一块内存，保存的是渲染 workload
2. VM 中的 GPU 驱动，把这块内存的物理地址(GPA)，写入到 `MMIO CSR` 中
3. Host/Hypervisor/驱动: 捕捉到这次的 `MMIO CSR` 写操作，拿到了 GPA
4. Host/Hypervisor/驱动: 把 GPA 转换成 HPA，并 pin 住相应的内存页
5. Host/Hypervisor/驱动: 把 HPA（而不是 GPA），写入到 pGPU 的真实的 `MMIO CSR` 中
6. pGPU 工作，完成这个渲染 workload，并发送中断给驱动
7. 驱动找到该中断对应哪个 workload —— 当初我是为哪个 vGPU 提交的这个 workload？ —— 并注入一个虚拟的中断到相应的 VM 中
8. VM 中的 GPU 驱动，收到中断，知道该 workload 已完成、结果在内存中

这就是 `nVidia GRID vGPU`、`Intel GVT-g`（KVMGT、XenGT）的基本实现思路。一般认为 graphics stack 是 OS 中最复杂的，加上虚拟化之后复杂度更是暴增，任何地方出现一个编程错误，调试起来都是无比痛苦。但只要稳定下来，这种 `MPT` 方案，就能兼顾 `1:N` 灵活性、高性能、渲染计算媒体的功能完整性
