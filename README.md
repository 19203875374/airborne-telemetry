# Airborne Telemetry

基于 FPGA 与 AD9361 的四模式遥测发射原型及可复用大模型协作技能包。支持 PCM-FM、SOQPSK-TG、BPSK 和 QPSK；目标器件 `xc7z030fbg484-1`，复基带 30.72 MS/s，OSR=16，使用 PL 与 VIO 控制。

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

Vivado 2019.1 新会话中运行独立基带仿真：

```tcl
source {C:/telemetry_work/scripts/run_baseband.tcl}
```

控制台须有 TEST PASS，且 PSK mapping checks 大于零。完整构建入口为工作副本 `scripts/build_hardware.tcl`；先核对依赖、板级约束和硬件资料。

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

当前代码使用 PRBS 激励。SP→EP→TP→PCM 子帧属于研究方案；本仓库不把它列为已实现的组帧链路，也不宣称已实现以太网/IP 栈、完整 iNET 设备、LDPC 或完整相干接收机。历史辅助 RX 模块不是接收性能达标证据。

归档 N9000A 数据有四组频谱与 IQ；基带 126788 行，RF IQ 每模式 30001 个复样本。离线统计与 Skill 合成测试已执行，记录见 validation。此次环境没有 Vivado、MATLAB 或目标硬件；新建工程 Tcl、静态 MATLAB 出图、综合实现和上板路线需接收者实际执行。

尚缺原板型号/PCB 版本、额定供电和接线确认，见 [硬件交接表](board/hardware_handoff.md)。这不影响 Python 归档复算，影响硬件复现。所有约束须与实际板卡对应。

## 开源与来源

自有代码及配套文档沿用仓库创建者选择的 [MIT License](LICENSE)，署名保持 `19203875374`。第三方工具和厂商 IP 不由本项目重新授权，见 [第三方说明](third_party.md)。未提交厂商生成 HDL、DCP、旧 bit/ltx、安装器或标准全文。

来源和改动见 [source_provenance.json](validation/source_provenance.json)。输入材料以字节指纹记录，路径适配在工作副本进行。代码标识符保持原样。

路径使用英文、数字、下划线与连字符；按约定保留 README.md、SKILL.md、LICENSE、.gitignore 和 .gitattributes 名称，其余文件名为小写。中文仅在文件正文出现。
