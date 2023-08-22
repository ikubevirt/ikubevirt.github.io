

|      缩写      | 解释                                                                     |
|:------------:|:-----------------------------------------------------------------------|
|     GPU      | Graphics Processing Unit，显卡                                            |
|     CUDA     | Compute Unified Device Architecture，英伟达 2006 年推出的计算 API                |
| VT/VT-x/VT-d | Intel Virtualization Technology。-x 表示 x86 CPU，-d 表示 Device。            |
|     SVM      | AMD Secure Virtual Machine。AMD 的等价于 Intel VT-x 的技术。                    |
|     EPT      | Extended Page Table，Intel 的 CPU 虚拟化中的页表虚拟化硬件支持。                        |
|     NPT      | Nested Page Table，AMD 的等价于 Intel EPT 的技术。                              |
|    SR-IOV    | Single Root I/O Virtualization。PCI-SIG 2007 年推出的 PCIe 虚拟化技术。           |
|      PF      | Physical Function，亦即物理卡                                                |
|      VF      | Virtual Function，亦即 SR-IOV 的虚拟 PCIe 设备                                 |
|     MMIO     | Memory Mapped I/O。设备上的寄存器或存储，CPU 以内存读写指令来访问。                           |
|     CSR      | Control & Status Register，设备上的用于控制、或反映状态的寄存器。CSR 通常以 MMIO 的方式访问。       |
|     UMD      | User Mode Driver。GPU 的用户态驱动程序，例如 CUDA 的 UMD 是 libcuda.so               |
|     KMD      | Kernel Mode Driver。GPU 的 PCIe 驱动，例如英伟达 GPU 的 KMD 是 nvidia.ko           |
|     GVA      | Guest Virtual Address，VM 中的 CPU 虚拟地址                                   |
|     GPA      | Guest Physical Address，VM 中的物理地址                                       |
|     HPA      | Host Physical Address，Host 看到的物理地址                                     |
|     IOVA     | I/O Virtual Address，设备发出去的 DMA 地址                                      |
|   PCIe TLP   | PCIe Transaction Layer Packet                                          |
|     BDF      | Bus/Device/Function，一个 PCIe/PCI 功能的 ID                                 |
|     MPT      | Mediated Pass-Through，受控直通，一种设备虚拟化的实现方式                                |
|     MDEV     | Mediated Device，Linux 中的 MPT 实现                                        |
|     PRM      | Programming Reference Manual，硬件的编程手册                                   |
|     MIG      | Multi-Instance GPU，Ampere 架构高端 GPU 如 A100 支持的一种 hardware partition 方案  |
