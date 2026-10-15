# 机载遥测发射系统从零复现说明

版本日期：2026 年 10 月 15 日

本说明面向第一次接触本工程的使用者，按准备环境、建立工作副本、离线复算、RTL 仿真、完整构建、同板上电与射频测试的顺序执行。每一步都给出输入、操作、产物和检查点。本文对应 Zynq-7030 与 AD9361 四模式发射原型；SP→EP→TP→PCM 子帧是研究方案，不作为本包已实现的组帧功能。

## 一 先确认能复现到哪一层

| 层次 | 所需条件 | 成功标志 |
|---|---|---|
| A 归档数据离线复算 | Python 3.10 或更新版本、本开源仓库 | 生成 audit_archived.json，统计与本说明参考表一致 |
| B 四模式 RTL 重新仿真 | A 加 Vivado 2019.1 | 控制台出现 TEST PASS，生成新的 IQ 与符号映射文件 |
| C 完整工程重建 | Vivado、器件与 IP 支持、完整依赖 | 生成新 bit/ltx 及资源、时序、CDC 报告并核查 |
| D 同板硬件与新射频测试 | C 加原板硬件资料、供电、JTAG、射频仪器 | 模式与频点变化有新采集数据支撑 |

A 层在本次编写中已实际执行。B、C 的脚本已依据实际源码组织，本次环境未运行 Vivado；MATLAB 静态导出和 D 层板上步骤也未在本次环境执行。历史构建或历史测量不能替代新执行的记录。

硬件实测前必须取得原板的具体型号或 PCB 版本、额定供电与极性、参考时钟接入方式、AD9361 模块连接图及射频端口定义。现有材料只确认 FPGA 器件和 XDC 引脚，不能据此推定电源插口电压。缺少这些材料时可以完整执行 A、B，不能按猜测给板卡上电。

## 二 获取开源仓库并检查文件

仓库地址：https://github.com/19203875374/airborne-telemetry 。使用 Git clone 或 Code → Download ZIP 获取源码，解压后以 C:\airborne-telemetry 为例。后续从这个仓库根目录运行 Python 命令，工作副本使用另外的新目录 C:\telemetry_work。

| 相对位置 | 内容 |
|---|---|
| src/rtl、src/mem | 16 个原始 RTL 模块与 7 个存储初始化文件，含单独补齐的 TX FIR |
| src/matlab | 原始 RF 恢复加载器与一次性静态导出入口 |
| sim/ | 1 ms 模式切换 TB、历史辅助 RX TB 与独立仿真 Tcl |
| build/prepare.py | 创建全新工作副本并在副本中适配路径 |
| build/audit_data.py、build/verify_replay.py | 离线复算与同一归档输入的数值参考比对 |
| build/build_hardware.tcl | 从可见 RTL、MEM、XDC 和 XCI 新建完整硬件工程 |
| board/constraints、board/ip | 原板 XDC、四个 IP 的配置输入；不含厂商实现代码 |
| data/ | 基带、同一组 N9000A 射频 CSV 与数值参考 |
| skill/ | 可复用工作流、脚本、模板、踩坑清单和通用 PYNQ Skill |
| validation/ | 来源、输入哈希及软件验证记录 |

本目录不分发原始大工程压缩包、旧 bit/ltx、厂商生成的 IP HDL 或检查点。硬件 Tcl 重新从输入建立工程并由本机 Vivado 生成 IP；该新建工程路线尚未在本次环境实际运行，不能把软件检查当作硬件构建成功。来源关系见 validation/source_provenance.json。

## 三 安装并记录环境

### 步骤 1 安装 Python

从 Python 官方渠道安装 Python 3.10 或更新版本，并启用命令行或 Python Launcher。打开 PowerShell，执行：

```powershell
Set-Location C:\airborne-telemetry
py -3 --version
```

若没有 py 而已有 python 命令，确认 python --version 满足要求后，将后续 py -3 替换为 python。仓库 Python 脚本只使用标准库，不需要 pip 安装第三方包。

### 步骤 2 准备 Vivado

使用 Vivado 2019.1 作为复现基线，在安装器中包含 Zynq-7000 器件支持和 JTAG Cable Drivers，确认器件列表能选择 xc7z030fbg484-1，并具备所需许可。不要在首次复现时升级 IP 或把工程转换为其他版本；确需升级时另建副本并记录差异。

官方下载页面：https://www.amd.com/en/support/downloads/adaptive-socs-and-fpgas/development-tools/2019-1.html

在 Vivado Tcl Console 执行 version -short 并保存输出。使用对应版本支持的操作系统；本说明以 Windows 路径举例，不据此声明所有新版 Windows 均经过该软件验证。

### 步骤 3 准备 MATLAB

以 MATLAB R2022a 为历史分析基线。安装后在命令窗口运行 version 与 ver，保存环境信息。静态复现入口和已查加载器未发现 comm、dsp、rcosdesign、pwelch 等外部工具箱调用；若实际运行报告缺少函数，先记录完整报错和路径，不随意用另一套恢复算法替代。

版本及系统要求：https://www.mathworks.com/support/requirements/previous-releases.html

未安装 Vivado 或 MATLAB 时，仍可先执行下面的 Python 离线路线。

## 四 创建干净的工作目录

### 步骤 4 运行准备脚本

确认 C:\telemetry_work 尚不存在，再执行：

```powershell
py -3 build\prepare.py --workspace C:\telemetry_work
```

脚本会复制 rtl、mem、constraints、ip、data、matlab_rf，并建立 scripts、output 和 logs，同时生成 preparation.json。Vivado 工程在后续 Tcl 执行时才创建。它不会覆盖已有工作目录；若名称已经使用，改用 C:\telemetry_work_02，并把后续命令中的工作根路径一起替换。

仓库已包含 tx_fir_coeff.mem。准备阶段只在独立 testbench 副本中改写 $fopen 导出路径，并在 RF 加载器副本中改写 specDir 与 iqDir；复制时依据发布输入清单检查 SHA-256。它不改 RTL 调制算法、硬件引脚、系数数值或载波恢复算法。

### 步骤 5 检查准备结果

应存在以下文件：

```text
C:/telemetry_work/preparation.json
C:/telemetry_work/scripts/run_baseband.tcl
C:/telemetry_work/scripts/build_hardware.tcl
C:/telemetry_work/scripts/tb_pcm_net_mode_switch.v
C:/telemetry_work/matlab_rf/load_rf_data.m
C:/telemetry_work/data/baseband_archived/pcm_net_mode_switch_iq.txt
```

打开 preparation.json，确认 release_manifest_sha256 与 validation/input_manifest.json 的指纹对应；simulation_executed、vivado_build_executed、matlab_executed、hardware_validated 初始均为 false。这些是准备阶段的状态，不会在后续自动变为已验证，实际执行结果另存日志。

## 五 先跑通归档数据复算

### 步骤 6 运行无图形分析

```powershell
py -3 build\audit_data.py --workspace C:\telemetry_work --baseband archived
```

对照归档参考执行：

```powershell
py -3 build\verify_replay.py C:\telemetry_work\output\audit_archived.json
```

应输出 passed=true。这是同一归档数据的复算比对，不是独立黄金参考对 RTL 的功能验证。

预期生成 C:\telemetry_work\output\audit_archived.json。基带应读到 126788 行；选择规则为每种 active_mode 的最长连续段，仅剔除两端零样本，不做增益归一化或理想星座替换。四份射频 IQ 各应读到 30001 个复样本，采样率约 15 MS/s；基带采样率为 30.72 MS/s，两者不能混用。

| 模式 | 基带 PAPR dB | RF IQ PAPR dB | 该批仪器 99% OBW MHz |
|---|---:|---:|---:|
| PCM-FM | 0.002688 | 0.940544 | 2.785361 |
| SOQPSK-TG | 0.002468 | 0.908381 | 1.945776 |
| BPSK | 3.848459 | 4.432887 | 2.726917 |
| QPSK | 3.789182 | 4.224933 | 2.715814 |

表中数值由本次附带脚本对包内文件实际复算；建议用 0.00001 的绝对容差比较表中舍入后的值。它只验证相同输入和统计规则的复算，不是硬件性能验收门限。仪器 OBW 从 CSV 的 MeasResult 读取，未以本脚本重新积分频谱。

本表使用同一归档 N9000A 文件组，不与后续 N9020A 的 2.19 MHz 等结果混用。面板旧固定数组 1.04／1.12 dB 不作为当前基带计算参考。

## 六 重新运行四模式 RTL 仿真

### 步骤 7 启动独立仿真

打开一个新的 Vivado 2019.1 会话，在 Tcl Console 输入：

```tcl
source {C:/telemetry_work/scripts/run_baseband.tcl}
```

该脚本创建独立的 repro_baseband 工程，加入 multi_mode_baseband_tx 等八个 RTL 模块，并加入 sine_lut.mem。它不需要完整 AD9361、VIO、FIFO 的 IP 仿真模型，也不加载板级 XDC。不要在此独立工程再加入完整 system_top。

testbench 的模块名仍为 tb_pcm_net_mode_switch，与文件名不同属于正常情况。四种主模式每次主要检查驻留 30720 个样本，按 30.72 MS/s 约为 1 ms，并含 288 样本等待和短反向切换检查。run all 应运行到 testbench 自行 $finish，不能只运行默认的 1000 ns 就取图。

### 步骤 8 检查仿真结果

控制台应有各模式 PASS，最终应出现：

```text
TEST PASS: PCM/NET switching and all sub-modulations are correct
```

PSK mapping checks 应大于 0，不能有 ERROR、FATAL 或 TEST FAIL。仿真器结束本身不等于测试通过；该 testbench 在部分失败情况下也使用 $finish，所以必须检查消息。

应新生成：

```text
C:/telemetry_work/data/baseband/pcm_net_mode_switch_iq.txt
C:/telemetry_work/data/baseband/psk_symbol_mapping.txt
```

IQ 首行字段应为 sample、mode_sel、pcm_mod_sel、net_mod_sel、active_mode、i、q、pcm_bit_en、net_sym_en。另一个文件是符号事件与映射证据，不是 psk_rrc_waveform.txt；不要仅重命名来冒充不同的数据格式。

### 步骤 9 复算新仿真数据

```powershell
py -3 build\audit_data.py --workspace C:\telemetry_work --baseband new
```

生成 audit_new.json，与 archived 结果分开保存。首先比较四种模式均存在、样本数、选择区间和 PAPR。若换了 RTL、系数、驻留或截取规则，不要求与归档值逐位一致，应先解释差异。新的仿真仍不证明 AD9361 已输出正确的 GHz 射频。

## 七 MATLAB 一次性静态导出

### 步骤 10 导出已有数据的图和表

在 MATLAB R2022a 命令窗口执行：

```matlab
addpath('C:/telemetry_work/scripts');
reproduce_results('C:/telemetry_work','archived');
```

使用新仿真输出时，第二个参数改为 'new'。首次先用 archived 验证软件路径，再处理 new。输出位于 output/matlab，包含四模式基带静态图、基带汇总 CSV、四模式 RF 图、rf_summary.csv、rf_recovery.mat 和 matlab_reproduction.log。

脚本会把工作副本的 matlab_rf 加到路径，打印 which load_rf_data -all。确认实际调用路径位于 C:/telemetry_work/matlab_rf，避免同名旧函数遮蔽。若只完成基带后 RF 部分报错，保留已生成结果并核查八份 RF CSV、加载器路径与格式。

PCM-FM／SOQPSK 的 RF 图为原始 I/Q 轨迹；BPSK／QPSK 为加载器实际恢复、硬判决之前的符号。基带单窗 FFT 图仅展示频谱形态，不作为 99% OBW 定稿算法。程序不会运行 showcase_dashboard_v11 动态面板；历史该面板存在卡退反馈，不能把它列为必经步骤。

本次环境未运行 MATLAB，图形导出与恢复结果须由执行者在该版本实际确认。若仍发生崩溃，先单独运行 R=load_rf_data() 区分计算与绘图，再保存 crash dump；不要通过替换成理想点让图形“看起来通过”。

## 八 完整工程重新综合与实现

### 步骤 11 核对板级构建前提

工程目标为 xc7z030fbg484-1，顶层 system_top；板卡使用 PL 逻辑与 VIO 控制，不需要在本复现路线中编写 ARM 应用、安装 PYNQ 或建立以太网协议栈。

完整工程包含 CLK_PLL_sys、pll_ad9361、fifo_128x64、vio_trx_ctrl 等 IP。先核对工作 rtl、mem、constraints、ip 四个目录和 tx_fir_coeff.mem；四个 XCI 配置已复制到工作 ip 目录，脚本会据此创建全新工程。若跨版本导致 IP 锁定，先回到原版本或取得对应依赖，不盲目升级。

### 步骤 12 运行完整构建

关闭先前仿真工程，启动新的 Vivado 会话，在 Tcl Console 执行：

```tcl
source {C:/telemetry_work/scripts/build_hardware.tcl}
```

脚本新建 hardware_project/telemetry_tx.xpr，加入可见源码、全部 MEM、板级 XDC 和四份 XCI，由本机 Vivado 生成并综合 IP，再综合顶层并实现到 write_bitstream。它不依赖旧工程缓存或旧检查点，也不改仓库原始文件。若工作副本已经创建过同名 Vivado 工程，应重新准备另一个新工作目录后重试。

检查 logs/ip_status.rpt 与 Vivado 日志。成功时 output/build 应包含 system_top.bit、system_top.ltx、timing_summary.rpt、utilization.rpt 和 cdc.rpt。bit 和 ltx 必须来自同一次新构建，不混用归档调试探针文件。

构建完成后查看报告是否满足实际约束、是否有未约束路径或重要 CDC／DRC 问题；不能只凭生成 bit 宣布接口正确。现有 XDC 带板卡相关约束和调试逻辑，包含 RX hold 检查例外等设计处理，换板时必须重新核对，不能复制后删约束来取得通过。

脚本未在本次环境运行。如 generate_target、综合或实现报错，保留完整日志、IP 状态和当前源码哈希，停止烧录新产物，定位缺失依赖或版本差异。

## 九 同板上电 烧录与发射控制

### 步骤 13 填齐硬件交接信息

实际执行者在上电前应取得并核对下表；未知项不能由 FPGA 型号推定。

| 项目 | 已知或需填写内容 |
|---|---|
| FPGA 器件 | xc7z030fbg484-1 |
| 板卡型号与 PCB 版本 | 由实板或硬件交接资料填写 |
| 供电电压 极性 电流限制与上电顺序 | 按板卡额定标注和原理图填写，现有材料未确认 |
| FPGA mclk1 | XDC／PLL 基线为 20 MHz，确认板上来源 |
| AD9361 模块与参考时钟连接 | 按实际模块资料填写，确认配置与原工程一致 |
| CMOS 接口 | 6 bit DDR，LVCMOS18 相关端口；核对 bank 电压与连接图 |
| RF 发射端口 衰减与仪器输入额定值 | 按模块端口与实际功率核对后填写 |
| JTAG 线缆及复位操作 | 按实板丝印或接线图填写 |

XDC 的封装引脚可用于核对原板，如 mclk1=Y12、resetb=AA21、rx_clk_in_p=H2、tx_clk_out_p=H3；它不是另一块 PCB 的接线说明。电源、时钟和接口未核对时，先停留在离线与仿真路线。

### 步骤 14 烧录新构建产物

在 TX 关闭状态连接已核对的供电、JTAG 与射频测量链路。按原板要求上电和释放复位。Vivado 中依次打开 Hardware Manager、Open Target、Auto Connect，确认识别到目标器件。选择 Program Device，指定 output/build/system_top.bit 与同目录 system_top.ltx，再执行编程。

若看不到器件，先检查供电、JTAG 驱动、线缆和复位；若看不到 VIO／ILA，先确认 ltx 与 bit 同源、系统时钟与复位正常。不得因器件枚举成功就认定 RF 初始化完成。

### 步骤 15 设置 VIO 并检查状态

VIO 端口对应当前 system_top.v：

| VIO 端口 | 字段 | 首次设置 |
|---|---|---|
| probe_out0 | mode_sel | 0 |
| probe_out1 | pcm_mod_sel | 0 |
| probe_out2 | net_mod_sel | 0 |
| probe_out3 | tx_enable | 0，完成初始化与接线检查后再设 1 |
| probe_out4 | rx_enable | 0，本复现以发射为目标 |
| probe_out5 | tx_freq_index 12 bit | 0，按查表规划对应 2200 MHz，实际由仪器确认 |
| probe_out6 | rx_freq_index 10 bit | 0 |
| probe_out7 | freq_req | 记录初值，频点请求靠翻转而非一直置 1 |

先提交配置，观察 probe_in0 的 32 bit status。按当前源码：bit11 为 init_done，bit10 为 rf_clk_locked，bit9 为 sys_locked，bit8 为 txe_sync，bit7:6 为 active_mode，bit15 为 freq_error，bit14 为 runtime_error_latched，bit13 为 runtime_done_latched，bit12 为 freq_busy，bit5／4 为 FIFO empty／full。高 16 bit 是调试寄存器值，不套用早期其他版本状态字。

初始化完成且无错误后才开启 TX。记录状态、实际中心频率和 ILA 的 bb_i、bb_q、active_mode 等。ILA 的 tx_underflow 应检查是否持续置位；频谱有中心峰不独立证明有效动态 IQ 已传输。

### 步骤 16 逐一验证四种模式

| 模式 | mode_sel | pcm_mod_sel | net_mod_sel |
|---|---:|---:|---:|
| PCM-FM | 0 | 0 | 无关 |
| SOQPSK-TG | 0 | 1 | 无关 |
| BPSK | 1 | 无关 | 0 |
| QPSK | 1 | 无关 | 1 |

首次逐模式复现时，先令 tx_enable=0，提交模式，再待 active_mode 和配置状态稳定后开启 TX，分别保存状态、频谱与 IQ。基础工作条件为复基带 30.72 MS/s、OSR=16、符号或 PCM 比特率 1.92 M；QPSK 比特率 3.84 Mbit/s。

这种停发后切换用于分离各模式测试，不证明在线切换时间或无丢样。若验证在线切换，应另在 TX 连续开启时触发模式变化，同步记录配置请求、基带静音、FIFO、RF 恢复和错误状态，不能只用 128 样本静音计数当作总切换时间。

修改频点时，先提交 tx_freq_index，再把 freq_req 由当前值翻转一次，例如 0→1，下一次为 1→0；等待 busy 结束且完成／错误状态更新，再由仪器确认新频点。不要连续提交未完成请求，也不由表项数量宣称全部频点已实测。

## 十 新射频数据采集与替换

### 步骤 17 固定采集配置并保存原始文件

按实际发射端口与仪器额定输入配置同轴、必要衰减和终端，首次测试不接天线。记录线缆损耗、衰减、参考电平和端口。新测试至少记录中心频率、跨度、RBW／VBW、平均状态、迹线／检测方式；IQ 记录样本间隔、样本数、采集时间和幅值约定。

包内参考数据来自 N9000A，IQ 元信息约为 15 MS/s、2 ms，频谱扫宽 12.7 MHz，历史 RBW 为 300 kHz。相同配置便于比较，但设置能否选择取决于当前仪器模式与选件。不要把 BASIC:WAV 与普通 SA 轨迹导出视为同一功能。

过去导出时曾出现实际菜单没有 Format→CSV 的情况，因此本说明不要求点击未经确认的通用菜单。按具体仪器手册导出后，先检查文件头与包内样本一致；只有频谱截图无法执行数值复算。仪器输出格式不一致时须做可追溯适配，不是改扩展名即可。

### 步骤 18 新批次单独保存并复算

先完整复制工作目录或另建新工作目录，保留归档八份原数据。将同一批四模式频谱和 IQ 分别保存为 f_pcm_fm.csv、f_soqpsk.csv、f_bpsk.csv、f_qpsk.csv 与 iq_pcm_fm.csv、iq_soqpsk.csv、iq_bpsk.csv、iq_qpsk.csv，放入该批次的 data/f_wave 与 data/iq_wave。

加载器只读这些标准文件名，忽略带 (1)／(3) 的副本。不要把不同仪器或不同日期的数据凑成一组后与参考表强行比较。新格式须先核对 parse_iq／parse_spectrum 的解析契约。重新运行 MATLAB 静态入口，并保留日志和原始文件指纹。

使用新的基带或 RF 数据，统计数值不同不自动表示失败。先核对采样率、数据区间、仪器设置与算法。不得把接收测量端口功率直接当作功放输出；不得从恢复星座或硬判决理想点推出 BER 达标。

## 十一 最终验收与常见故障

### 步骤 19 按证据层次填写验收结果

| 项目 | 检查方法 | 留存材料 |
|---|---|---|
| 输入一致性 | 核对 source_manifest 与 preparation 输入指纹 | 发布输入清单及 preparation.json |
| 离线链路 | archived 报告样本数和参考统计一致 | audit_archived.json |
| RTL 行为 | TEST PASS、映射检查大于0、四模式均有新输出 | xsim 日志、IQ、映射文件 |
| 完整构建 | 新 bit/ltx 同源，检查资源、约束、时序与 CDC | 构建日志及三类报告 |
| RF 逐模式发射 | 新频谱、IQ、VIO/ILA 状态对应同一配置 | 原始 CSV、配置与接线记录 |
| 接收或协议端到端 | 本路线不作为已完成验收项 | 未测试则明确记未测试 |

每个项目填写通过、失败、未执行或不适用，不能把未执行写成通过。完成复现后按实际文件生成交付哈希，并记录日期、工具版本、操作者、板卡和烧录标识。

### 步骤 20 按症状定位

| 症状 | 先检查 | 处理 |
|---|---|---|
| 准备脚本称目录已存在 | 目标是否有旧结果 | 换新工作根目录，不覆盖旧证据 |
| 仿真无法打开导出文件 | 是否运行生成的路径适配 TB | 核对工作 data/baseband 已建立；不要改调制器 |
| 仿真出现 sine_lut 缺失或 X | Memory 文件是否加入独立项目 | 核对输入 mem 与仿真日志，不以空图继续 |
| IP locked 或缺失 | Vivado版本、器件与IP输出 | 回到2019.1，保存IP状态；不盲目升级 |
| 无 VIO／ILA | bit/ltx、时钟、复位 | 用同次新构建产物，核查板级条件 |
| RF 只有中心峰 | TX状态与有效数据 | 检查实际FIFO输入、ILA及单音激励，不仅看LO泄漏 |
| 修改频点无变化 | freq_req 是否真正翻转 | 等待上次请求完成，核对busy/error与实际频谱 |
| MATLAB 找错函数 | which load_rf_data -all | 确认工作副本路径，清理同名函数遮蔽 |
| 旧面板PAPR与脚本不符 | 面板是否固定数组 | 使用实际数据重算，保留区间和单位 |
| MATLAB 卡退 | 计算与绘图是否可分离 | 先离线Python或R=load_rf_data，保存日志，不伪造恢复图 |

## 十二 提交前最后检查

接收方应取得完整仓库内容，包括源码、系数、四份 IP 配置、独立 TB、九份原始数据、复现脚本、Skill 与许可证。执行 `python build/check_release.py` 检查发布清单、文件名、依赖数量与尺寸；它不代替综合、时序或上板测试。

补齐第九节的原板供电与连接资料后再交给需要硬件复现的队伍。换板须重新进行管脚、bank 电压、时钟、接口及时序适配；不能直接复用原板 XDC 或旧 bit。

软件验证记录见 validation/release_check.json 与 validation/README.md。Python 已实际从新工作副本复算归档数据，Skill 合成用例可单独重跑；Vivado、MATLAB 和硬件路线在本次环境未执行。发布时请保留这种验证边界。

官方参考：AMD Vivado 2019.1 下载与 UG973／UG910，MathWorks 旧版本系统要求；PYNQ 文档链接见对应 Skill。厂商工具与生成的 IP 依赖按其原许可获取，不由本仓库 MIT 许可重新授权。
