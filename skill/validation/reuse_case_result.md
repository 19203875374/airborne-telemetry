# 工程核查记录

记录性质：题面数据转录后的离线复算；非原始采集档案、非板卡实验。
任务与允许修改范围：使用现有两个技能核查；未修改技能源码；全部中间文件仅位于本目录。
工具：Python 3.12.14；实际运行脚本指纹见 tool_fingerprints.json。

## 证据与未知项

- iq.csv 是按题面四行逐值转录，UTF-8、LF、保留全部行，没有补点、归一化、旋转或判决。Fs=2 MHz 和累加器更新率8 MHz均为题面提供的元信息，未上板测量。
- sample 暂按技能契约解释为导出 IQ 流样本序号。若它实际是别的时钟周期索引，需要先重新确认索引与有效率；当前频率结论受此条件限制。
- inc=8192按已解释的正整数处理，相位累加器16位。I/Q单位、位宽、底层signed编码、导出观测点、批次、模式、valid、稳态范围未知；四行全选不能称为经验证的稳态段。
- stable 仅是版本名称，未取得可核验源码/程序字节、哈希、构建日志或实际烧录对应证据。
- design.hwh 是题面XML原样转录（无尾部换行）。design.bit 本地测试夹具精确内容为 ASCII `PLACEHOLDER_NOT_A_REAL_BITSTREAM` 加LF，33字节；题面没有给出原占位字节，所列bit哈希只指本地夹具。
- 目标器件、板卡、PYNQ/Vivado版本、必需IP完整清单、同一构建证明均未知。
- 没有真实板卡、真实bitstream、Vivado构建、PYNQ运行时、下载、DMA或寄存器测试。hardware_validated=false。

## 可支持的统计与结论

| 量 | 实际结果 | 范围 |
|---|---|---|
| 行数/零行 | 4 / 0 | 仅给定四行 |
| I²+Q² | 每行4，最小/平均/最大均4 | 单位未知，不能写成W或dBm |
| PAPR | 10log10(4/4)=0 dB | 仅该四点，不证明长时间恒包络或标准通过 |
| 样本断段 | 1处：1→4；缺索引2、3 | 不插值，不跨缺口计算相位差 |
| 相位差对 | (0,1)、(4,5)，共2对 | 都是+π/2 |
| 相位差频率 | 最小/平均/最大500000 Hz | Δφ×2e6/(2π)，主值频率，存在采样混叠限制 |
| inc换算频率 | 8192×8e6/2^16=1000000 Hz | 名义累加器相位推进频率，非独立测量 |

若该inc直接驱动此导出IQ的同一相位、更新使能确为8 MHz且无混频/重采样/观测点差异，则每0.5 μs应该推进π而不是π/2，两个数不能直接判为一致。这是需核实的观测/元信息关系，不能唯一归因为PLL或某个硬件模块。单纯把相位差频率加2 MHz的整数倍也不会得到1 MHz。未明确inc与IQ的信号路径前，不能把两者直接作锁相误差。

锁相：未证明。没有参考相位/频率、锁定误差与门限、持续时间、捕获/失锁行为；四点等幅和固定inc不证明环路闭合或锁定。
BER：未测，不能报通过或0。没有已知发送比特/PRBS参数、可靠帧/符号/比特对齐、统计比特数和错误数、失锁/丢帧处理、信道条件及通过门限/置信要求。
PYNQ：仅通过文件存在非空、同目录同basename、XML可解析和MODULE名称提取/指定名称存在检查。两个MODULE不证明地址映射、处理器配置、驱动和完整HWH语义可供PYNQ使用；占位bit连真实bit格式都未验证。不得声称完成所有板卡适配。

验证层次：需求为“锁相/BER/所有板卡适配通过”；只有题面陈述、离线统计和静态文件规则结果。源码、独立黄金参考、仿真、板上观测、端到端验证均没有可核验证据。本次没有把iq.csv复制为golden开展自比自证。

## 竞争假设与下一项最小实验

| 观察 | 假设 | 反证条件 | 下一项唯一改变 | 实际状态 |
|---|---|---|---|---|
| inc换算1 MHz而连续IQ相位差500 kHz | 更新率/使能或导出率定义不同 | 同步记录证实实际时钟和valid节拍均与题面一致 | 保持构建和所有设置，增加同步记录原始IQ、inc、相位累加值、tick与valid | 未执行，保留假设 |
| 同上 | inc与IQ位于不同信号路径或经过额外处理 | 经核对的信号路径无额外变换，且同拍相位推进一致 | 先核查当前实际烧录构建的路径与观测点，不修改功能 | 未执行，保留假设 |
| static_checks_passed=true | 交付可能具备板卡适配 | 真实器件/板卡版本不匹配或运行测试失败 | 用正确器件重新构建真实bit/HWH并保留同构建日志；再按明确板卡矩阵测试 | 未执行，适配结论不成立 |

下一步先取得stable的字节/哈希、实际烧录标识和同步连续抓取，解决时钟/观测点关系；然后按预先约定的锁相指标测量。BER需要另设已知发送序列并固定对齐与统计规则。PYNQ交付需要真实同构建bit/HWH、目标part/板卡和工具版本、IP/时钟/地址/驱动证据；只在具备相应板卡环境且获准运行时使用download=False元数据探针，继而另行开展真实硬件功能测试。本次不得下载占位文件。

## 文件指纹

| 文件 | 字节数 | SHA-256 |
|---|---:|---|
| iq.csv | 61 | `f563cdf5c74984340440e3f895d913e6e12bed42de99407d55fe0b9d8a276faf` |
| design.bit | 33 | `1ac431104315e9f79e2f48ef169d5dffb7465e360d1579d8729478d5d74b3cc0` |
| design.hwh | 78 | `7f7b717b399f0cfbd89aa3782e6c6fa57d2c138f48edd98beefd5af58ee7cae1` |

清单record/verify通过仅证明这三个本地文件在该次核查中的字节一致，不证明依赖完整、可重建、同一构建或实际烧录。

## 必要命令与实际输出

工作目录：`/workspace/scratch/1aabef080324/reuse_case`。`python --version`实际输出 `Python 3.12.14`。
`--require-ip dsp/filter_0` 是对已知XML条目的演示性存在检查；未把它推定成用户完整必需IP清单。

### 命令 1

```sh
python ../submission_skill/skill/telemetry-evidence-review/scripts/inspect_iq.py iq.csv --fs 2000000 --sample sample --inc inc --inc-fs 8000000 --phase-bits 16
```

退出码：0；stderr为空。实际stdout：

```json
{
  "input": "/workspace/scratch/1aabef080324/reuse_case/iq.csv",
  "rows": 4,
  "iq_fs_hz": 2000000.0,
  "zero_rows": 0,
  "power_mean": 4.0,
  "power_min": 4.0,
  "power_max": 4.0,
  "papr_db": 0.0,
  "sample_index_breaks": 1,
  "phase_difference_pairs": 2,
  "phase_frequency_min_hz": 500000.0,
  "phase_frequency_max_hz": 500000.0,
  "phase_frequency_mean_hz": 500000.0,
  "selection": {
    "mode_column": null,
    "mode": null,
    "valid_column": null,
    "valid_value": "1"
  },
  "limits": [
    "No hidden normalization, interpolation, ideal-point projection or zero removal.",
    "Phase differences use consecutive indices only and lie in the principal interval.",
    "No assertion of unaliased carrier, BER, RF power or standards compliance."
  ],
  "inc_frequency_hz": {
    "min": 1000000.0,
    "max": 1000000.0
  },
  "accumulator_update_hz": 8000000.0
}
```

### 命令 2

```sh
python ../submission_skill/skill/pynq-overlay-preflight/scripts/preflight_overlay.py --bit design.bit --hwh design.hwh
```

退出码：0；stderr为空。实际stdout：

```json
{
  "static_checks_passed": true,
  "module_names": [
    "dsp/filter_0",
    "processor"
  ],
  "missing_required_ip": [],
  "sha256": {
    "design.bit": "1ac431104315e9f79e2f48ef169d5dffb7465e360d1579d8729478d5d74b3cc0",
    "design.hwh": "7f7b717b399f0cfbd89aa3782e6c6fa57d2c138f48edd98beefd5af58ee7cae1"
  },
  "hardware_validated": false,
  "limits": [
    "Does not prove bit/HWH originate from the same build.",
    "Does not validate bitstream format, device part or board compatibility.",
    "Does not exercise PYNQ parsers, clocks, DMA, MMIO or functionality."
  ]
}
```

### 命令 3

```sh
python ../submission_skill/skill/pynq-overlay-preflight/scripts/preflight_overlay.py --bit design.bit --hwh design.hwh --require-ip dsp/filter_0
```

退出码：0；stderr为空。实际stdout：

```json
{
  "static_checks_passed": true,
  "module_names": [
    "dsp/filter_0",
    "processor"
  ],
  "missing_required_ip": [],
  "sha256": {
    "design.bit": "1ac431104315e9f79e2f48ef169d5dffb7465e360d1579d8729478d5d74b3cc0",
    "design.hwh": "7f7b717b399f0cfbd89aa3782e6c6fa57d2c138f48edd98beefd5af58ee7cae1"
  },
  "hardware_validated": false,
  "limits": [
    "Does not prove bit/HWH originate from the same build.",
    "Does not validate bitstream format, device part or board compatibility.",
    "Does not exercise PYNQ parsers, clocks, DMA, MMIO or functionality."
  ]
}
```

### 命令 4

```sh
python ../submission_skill/skill/telemetry-evidence-review/scripts/release_manifest.py record --root . --files iq.csv design.bit design.hwh --manifest release.json
```

退出码：0；stderr为空。实际stdout：

```json
{"recorded": 3, "manifest": "/workspace/scratch/1aabef080324/reuse_case/release.json"}
```

### 命令 5

```sh
python ../submission_skill/skill/telemetry-evidence-review/scripts/release_manifest.py verify --root . --manifest release.json
```

退出码：0；stderr为空。实际stdout：

```json
{
  "passed": true,
  "checked_files": 3,
  "issues": []
}
```

## 技能输入/步骤不够清楚之处

核心证据边界、两种采样率、断段处理和不把静态检查当硬件通过的规则清楚。本次遇到的具体歧义是：

1. PYNQ技能要求“IP完整名称”，但未明说`--require-ip`应去除前导`/`；HWH中的FULLNAME恰好带`/`。脚本仅规范化XML名称，不规范化参数。对同一份未修改XML，下面探针返回1，不应解读成物理IP真的缺失。建议补充输入名称规范或示例。
2. 遥测技能要求先保留原始数据、再筛选稳态；对仅有题面片段、没有原文件和稳态规则的输入，没有明确写出应先标成“转录夹具/未经稳态验证”再继续可确定统计。此次采用该保守做法，没有以stable标签选择稳态。

```sh
python ../submission_skill/skill/pynq-overlay-preflight/scripts/preflight_overlay.py --bit design.bit --hwh design.hwh --require-ip /dsp/filter_0
```

退出码：1；实际stdout：

```json
{
  "static_checks_passed": false,
  "module_names": [
    "dsp/filter_0",
    "processor"
  ],
  "missing_required_ip": [
    "/dsp/filter_0"
  ],
  "sha256": {
    "design.bit": "1ac431104315e9f79e2f48ef169d5dffb7465e360d1579d8729478d5d74b3cc0",
    "design.hwh": "7f7b717b399f0cfbd89aa3782e6c6fa57d2c138f48edd98beefd5af58ee7cae1"
  },
  "hardware_validated": false,
  "limits": [
    "Does not prove bit/HWH originate from the same build.",
    "Does not validate bitstream format, device part or board compatibility.",
    "Does not exercise PYNQ parsers, clocks, DMA, MMIO or functionality."
  ]
}
```

## 官方边界核对

本次已打开PYNQ v3.1官方文档核对：
- https://pynq.readthedocs.io/en/v3.1/overlay_design_methodology/overlay_design.html ：Overlay包含bitstream及配套HWH；HWH与bit同名。
- https://pynq.readthedocs.io/en/v3.1/pynq_libraries/overlay.html ：Overlay默认下载bit；download=False用于仅实例化不下载。

这只核对文档中的接口与配对边界，不是对未知用户版本或硬件的兼容验证。
