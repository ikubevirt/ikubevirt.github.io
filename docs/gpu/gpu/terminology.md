
## 什么是GPU

可能喜欢打游戏的同学对GPU并不陌生，这里我介绍一下GPU的概念。

!!! note "GPU的概念"

    GPU 是由许多更小、更专业的内核组成的处理器，又称图形处理器。在多个内核之间划分并执行一项处理任务时，通过协同工作，这些内核可以提供强大的性能。它和CPU最大的区别在于GPU在大量计算和3D渲染任务远远比CPU有着更出色的表现。

GPU的工作大部分就是这样，计算量大，但没什么技术含量，而且要重复很多很多次。举个例子，

!!! example "GPU例子"

    就像你有个工作需要算几亿次一百以内加减乘除一样，最好的办法就是雇上几十个小学生一起算，一人算一部分，反正这些计算也没什么技术含量，纯粹体力活而已。而CPU就像老教授，积分微分都会算，就是工资高，一个老教授资顶二十个小学生，你要是富士康你雇哪个？GPU就是这样，用很多简单的计算单元去完成大量的计算任务，纯粹的人海战术。这种策略基于一个前提，就是小学生A和小学生B的工作没有什么依赖性，是互相独立的。很多涉及到大量计算的问题基本都有这种特性。

总而言之，CPU和GPU因为最初用来处理的任务就不同，所以设计上有不小的区别。

## 术语专有名词表

| <div style="width:135px">缩写</div> | 解释                                                                     |
|:---------------------------------:|:-----------------------------------------------------------------------|
|               `GPU`               | Graphics Processing Unit，显卡                                            |
|              `CUDA`               | Compute Unified Device Architecture，英伟达 2006 年推出的计算 API                |
|          `VT/VT-x/VT-d`           | Intel Virtualization Technology。-x 表示 x86 CPU，-d 表示 Device。            |
|               `SVM`               | AMD Secure Virtual Machine。AMD 的等价于 Intel VT-x 的技术。                    |
|               `EPT`               | Extended Page Table，Intel 的 CPU 虚拟化中的页表虚拟化硬件支持。                        |
|               `NPT`               | Nested Page Table，AMD 的等价于 Intel EPT 的技术。                              |
|             `SR-IOV`              | Single Root I/O Virtualization。PCI-SIG 2007 年推出的 PCIe 虚拟化技术。           |
|               `PF`                | Physical Function，亦即物理卡                                                |
|               `VF`                | Virtual Function，亦即 SR-IOV 的虚拟 PCIe 设备                                 |
|              `MMIO`               | Memory Mapped I/O。设备上的寄存器或存储，CPU 以内存读写指令来访问。                           |
|               `CSR`               | Control & Status Register，设备上的用于控制、或反映状态的寄存器。CSR 通常以 MMIO 的方式访问。       |
|               `UMD`               | User Mode Driver。GPU 的用户态驱动程序，例如 CUDA 的 UMD 是 libcuda.so               |
|               `KMD`               | Kernel Mode Driver。GPU 的 PCIe 驱动，例如英伟达 GPU 的 KMD 是 nvidia.ko           |
|               `GVA`               | Guest Virtual Address，VM 中的 CPU 虚拟地址                                   |
|               `GPA`               | Guest Physical Address，VM 中的物理地址                                       |
|               `HPA`               | Host Physical Address，Host 看到的物理地址                                     |
|              `IOVA`               | I/O Virtual Address，设备发出去的 DMA 地址                                      |
|            `PCIe TLP`             | PCIe Transaction Layer Packet                                          |
|               `BDF`               | Bus/Device/Function，一个 PCIe/PCI 功能的 ID                                 |
|               `MPT`               | Mediated Pass-Through，受控直通，一种设备虚拟化的实现方式                                |
|              `MDEV`               | Mediated Device，Linux 中的 MPT 实现                                        |
|               `PRM`               | Programming Reference Manual，硬件的编程手册                                   |
|               `MIG`               | Multi-Instance GPU，Ampere 架构高端 GPU 如 A100 支持的一种 hardware partition 方案  |
