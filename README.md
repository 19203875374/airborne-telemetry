# Airborne Telemetry

本项目面向传统 PCM 遥测与网络遥测应用，设计了一种基于 Zynq-7030 与 AD9361 的机载遥测发射系统。系统采用软件无线电架构，在统一 FPGA 平台上实现 PCM-FM、SOQPSK-TG、BPSK 和 QPSK 四种调制波形。两种遥测体制着眼于数据组织和业务交互，四种调制方式则适应设备兼容、频谱占用和传输容量的不同要求。当前工程重点实现并验证两类工作模式对应的发射信号处理链路。

PCM 遥测发射模式支持 PCM-FM 与 SOQPSK-TG，兼顾传统遥测设备兼容性与频谱利用需求；网络遥测发射模式支持 BPSK 与 QPSK，在相同符号率下，QPSK 的比特率为 BPSK 的两倍。系统通过两级模式选择实现工作模式及调制方式的在线切换，并在切换期间对数字基带输出实施静默控制。

各波形经相应数字滤波处理后，通过 CMOS DDR 接口向 AD9361 输出复基带 I/Q 数据，完成射频发射。FPGA 通过 SPI 配置 AD9361，发射频点采用 0.1 MHz 的配置步进，本次频点调节测试选取 2200～2260 MHz 范围。系统内置 PRBS-15 测试数据源，用于基带功能验证与射频测试，具有多波形共平台、模式可切换和频点可重配等特点。

仓库：https://github.com/19203875374/airborne-telemetry

## 从这里开始

首次使用者按 [20 步复现说明](report/reproduction.md) 操作。Python 3.10 或更新版本即可复算归档数据，Python 工具只使用标准库。Windows PowerShell 示例：

```powershell
Set-Location C:\airborne-telemetry
py -3 build\check_release.py
py -3 build\prepare.py --workspace C:\telemetry_work
py -3 build\audit_data.py --workspace C:\telemetry_work --baseband archived
py -3 build\verify_replay.py C:\telemetry_work\output\audit_archived.json
py -3 skill\validation\test_scripts.py
```

工作目录必须是仓库外的新路径，不得已存在。Linux 可将 `py -3` 换成 `python3` 并使用 `/` 路径；先完成离线步骤，再配置对应版本的 FPGA 或 MATLAB 环境。

在 Vivado 2019.1 的新会话中运行独立基带仿真：

```tcl
source {C:/telemetry_work/scripts/run_baseband.tcl}
```

控制台须出现 `TEST PASS`，且 PSK mapping checks 大于零。完整构建入口为工作副本中的 `scripts/build_hardware.tcl`；执行前先核对依赖、板级约束和硬件资料。

## 目录

| 目录 | 内容 |
|---|---|
| [src/](src/README.md) | 原始 RTL、MEM 与 MATLAB 分析源码 |
| [sim/](sim/README.md) | 四模式 TB 与独立仿真入口 |
| [build/](build/README.md) | 工作副本、构建、复算及发布检查 |
| [board/](board/README.md) | 原板约束、IP 配置及硬件交接表 |
| [data/](data/README.md) | 归档原始输入与数值参考 |
| [skill/](skill/README.md) | 工作流、模板、脚本、踩坑清单和通用 PYNQ Skill |
| [report/](report/project_summary.md) | 工程摘要、20 步复现说明与协作纠偏记录 |
| [validation/](validation/README.md) | 来源、指纹与实际软件验证记录 |

## 实现与验证范围

### 已实现功能

本项目基于 Zynq-7030 FPGA 与 AD9361 射频收发器，实现 PCM-FM、SOQPSK-TG、BPSK 和 QPSK 四种调制方式，包含模式选择与切换控制、复基带信号生成、异步 FIFO 跨时钟传输、CMOS DDR 发射接口，以及 PL 侧 SPI 初始化和频点配置。当前使用 PRBS 序列作为测试激励，主要验证多模式发射信号处理链路。

系统采用 VIO 对模式选择、发射使能和频率配置参数进行在线设置。在 FPGA 程序正常运行时，可通过 Vivado Hardware Manager 修改控制参数，完成不同工作状态之间的切换，无需修改数字基带模块或重新生成 FPGA 配置文件。

调制模式采用分层控制方式：`mode_sel` 选择 PCM 或 PSK 发射支路，`pcm_mod_sel` 选择 PCM-FM 或 SOQPSK-TG，`net_mod_sel` 选择 BPSK 或 QPSK。`active_mode` 为实际生效的模式状态，控制关系如下。

| active_mode | 遥测工作模式 | 调制体制 | mode_sel | pcm_mod_sel | net_mod_sel |
|---|---|---|---:|---:|---:|
| `00` | PCM 遥测模式 | PCM-FM | 0 | 0 | 无关 |
| `01` | PCM 遥测模式 | SOQPSK-TG | 0 | 1 | 无关 |
| `10` | 网络遥测模式 | BPSK | 1 | 无关 | 0 |
| `11` | 网络遥测模式 | QPSK | 1 | 无关 | 1 |

表中的工作模式名称对应顶层控制分类，当前仓库的实现与功能验证对象为多模式发射链路。

发射频率采用索引查表方式配置，目标频率关系为：

**目标发射频率（MHz）= 2200 + 0.1 × 发射频点索引。**

发射频点索引对应 `tx_freq_index`。索引 0～600 对应 2200～2260 MHz；这一范围为本文选取的配置与测试范围，不表示已逐点测量全部频点。设置索引后，通过翻转 `freq_req` 发起配置请求，由 FPGA 读取对应的 AD9361 寄存器配置数据，经 SPI 完成发射本振配置及相关校准。

### 已开展的工程验证

上板测试通过 VIO 依次设置 PCM-FM、SOQPSK-TG、BPSK 和 QPSK 四种工作状态，利用 ILA 观察 `active_mode`，并使用频谱分析仪观测 AD9361 射频输出。测试中，`active_mode` 能够随控制参数进入对应状态，四种模式均可观察到射频输出，为顶层模式选择与调制支路切换功能提供了验证依据。在已测试的频点上，实测射频中心频率能够随设定值变化，验证了频点索引、SPI 配置与射频输出之间的控制链路。

为开展分层分析，项目基于 MATLAB R2022a 建立数字基带与射频实测数据离线分析程序，分别处理 Vivado 仿真导出的数据和频谱分析仪采集的频谱、IQ 数据，完成 I/Q 波形与轨迹、包络、相位及频谱特征的可视化，并对峰均功率比和仪器记录的占用带宽进行统计与对照。上述工程验证覆盖多模式发射、模式控制和所测频点的配置功能。

仓库保存四模式基带仿真导出数据、射频频谱与实测 IQ 数据，以及相应分析脚本。不同仪器、采集批次和采样率的数据分别管理；统计结果须结合对应输入文件、数据区间和分析条件解释。

### 交付校验与新环境复现

当前整理版本已完成归档数据的 Python 离线复算，以及 25 项 Skill 脚本合成用例回归。相关软件验证记录见 [validation/](validation/README.md) 和 [Skill 验证说明](skill/README.md)，与已有上板测试记录分别管理。

已有工程验证与新环境复现分别记录。源码整理后的新建工程构建脚本及 MATLAB 静态导出入口尚需在对应软件环境中实际执行确认；复现者应保存重新仿真、综合实现、绘图及上板测试的实际日志和结果。操作步骤见 [复现说明](report/reproduction.md)，上板前应按 [硬件交接表](board/hardware_handoff.md) 补齐并核对板卡、供电、时钟及接口连接信息。

## 开源与来源

自有代码及配套文档沿用仓库创建者选择的 [MIT License](LICENSE)，署名保持 `19203875374`。第三方工具和厂商 IP 不由本项目重新授权，见 [第三方说明](third_party.md)。未提交厂商生成的 HDL、DCP、旧 bit/ltx、安装器或标准全文。

来源和改动见 [source_provenance.json](validation/source_provenance.json)。输入材料以字节指纹记录，路径适配在工作副本中进行，代码标识符保持原样。

路径使用英文、数字、下划线与连字符；按约定保留 `README.md`、`SKILL.md`、`LICENSE`、`.gitignore` 和 `.gitattributes` 名称，其余文件名为小写。中文仅在文件正文中出现。
