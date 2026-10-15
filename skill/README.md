# 可复用工程协作技能包

本目录按“3.3.5.2 技能包”组织，供陌生队伍复制到自己的 FPGA、数据流或软件无线电题目中使用。核心方法来自随作品提交的《机载遥测系统 全工程大模型协作与纠偏记录》，具体对应见 telemetry-evidence-review/references/lessons.md。目录内不包含本队 bitstream、真实采集数据或板卡专用寄存器表。

## 陌生队伍从这里开始

1. 安装 Python 3.10 或更新版本；在终端切换到本 README 所在的 skill/ 目录。脚本仅使用标准库，无需联网、MATLAB、Vivado 或特定板卡。
2. 运行 `python validation/test_scripts.py`，检查环境与内置合成夹具；原始提交报告见 validation/test_report.json。
3. 先运行下列 IQ 与 golden 示例，理解输入输出，再按下文的数据契约替换自己的文件。demo 是人工合成单音，不是本队实测数据。
4. 按任务读取主技能 SKILL.md、提示词工作流和记录模板。可将两个技能子目录复制到支持 SKILL.md 的代理技能目录；也可直接把相应 SKILL.md 和引用资源交给模型。脚本可脱离大模型单独运行。
5. 最后记录自己的输入、唯一改动、输出、退出码和失效条件。不要把本包回归结果写成自己的硬件验证结果。

```bash
python telemetry-evidence-review/scripts/inspect_iq.py telemetry-evidence-review/assets/demo_iq.csv --fs 4000000 --sample sample --inc inc --inc-fs 4000000
python telemetry-evidence-review/scripts/compare_golden.py telemetry-evidence-review/assets/demo_iq.csv telemetry-evidence-review/assets/demo_iq.csv --columns sample i q inc
```

第一个示例应输出 4 条样本、PAPR 0 dB、相位差频率 1 MHz、inc 频率 1 MHz。第二个示例只是演示调用格式和相同文件比对；真正验证算法必须提供独立黄金参考。

## 目录导航

| 项目 | 入口 | 用途 |
|---|---|---|
| W 提示词工作流 | telemetry-evidence-review/references/workflows.md | 软硬件划分、单变量调试、资源时序、结果表述 |
| C 案例模板 | telemetry-evidence-review/assets/ | 接手工程、记录实验、对齐证据 |
| Q IQ 校验 | telemetry-evidence-review/scripts/inspect_iq.py | 复功率、PAPR、相邻相位差、inc 频率 |
| G 黄金参考比对 | telemetry-evidence-review/scripts/compare_golden.py | 指定列逐行数值比对 |
| R 交付一致性 | telemetry-evidence-review/scripts/release_manifest.py | 所列文件 SHA-256 和尺寸核验 |
| P 踩坑清单 | telemetry-evidence-review/references/pitfalls.md | 12 类触发条件与排查步骤 |
| U 通用 PYNQ Skill | pynq-overlay-preflight/ | 任意题目的 Overlay 静态交付预检 |
| 验证材料 | validation/ | 可重跑测试、测试报告、陌生任务试用记录 |

## W 提示词工作流

- **适用范围**：需要从算法约束设计处理链、排查仿真与硬件差异、解释综合时序报告或撰写有证据的技术结论。不限定遥测调制。
- **使用方法**：选择 W1 至 W4，替换方括号中的真实输入；第二轮必须给模型实际源码、报告或测量反馈，要求按保留、降级、撤回更新判断。不要一次粘贴所有模板代替提供数据。
- **已验证效果**：历史第1至7、8至12、16至20项显示，明确范围、核对时钟、检查激励和追溯数值能够暴露原回答的证据不足；新编模板不等于历史逐字提示词，也未证明在所有模型上稳定成功。独立陌生任务试用记录单列。
- **失效条件**：缺少实际输入、模型无法读文件、问题超出约束范围、引用未核实或用户把推测当结论。此时输出所缺证据，不输出假定达标。
- **来源**：需求与实现混淆、PCM-FM 频率量级异常、复单音激励错误、固定 PAPR、版本混用等失败与观察。

## C 案例模板

- **适用范围**：新队伍接手 FPGA 工程、安排单因素实验、形成可追溯复现记录。
- **使用方法**：复制 review_record_template.md 和 rebuild_checklist.md 到自己的工程文档目录，填写真实版本、时钟、输入、预期、实测和退出码；未执行写“未执行”。
- **已验证效果**：模板字段覆盖历史多次遗漏的烧录对应关系、样本率和测量批次；本次只验证模板结构与独立试用，不宣称另一队已经完成干净环境重建。
- **失效条件**：填入的是计划而非结果，漏掉外部 IP/系数依赖或没有实际烧录标识。只填写模板不能证明复现成功。
- **来源**：协作记录第4、10、11、17、19项。模板为本次技能化整理，不伪装成早期原始日志。

## Q IQ 数值校验

- **适用范围**：已映射为带唯一列名的 UTF-8 逗号 CSV 的复数样本，数据率恒定且已知。可用于 ADC、通信或其他复数据流。
- **使用方法**：指定 --fs（导出IQ有效采样率）；用 --sample 指定连续导出序号；inc 列需另传 --inc-fs（累加器更新率）。不同列名用 --i/--q 显式映射；--mode-column/--mode、--valid-column/--valid-value 可显式选择。
- **已验证效果**：本包回归覆盖已知单音、样本断段、全零、非有限数、列缺失、重复序号以及两种采样率不混用。已知合成单音得到预期 PAPR 与频率。详细结果见 test_report.json。
- **失效条件**：私有仪器头、I/Q交替单列、非均匀采样、多采样率混合、未知signed/电压约定、频率混叠。脚本不清除过渡段，不自动归一化，不输出 BER、校准RF功率或符合性结论。
- **来源**：协作记录第5、6、16、17项。脚本为本次新编，只在合成夹具上验证；历史工程重算值不能算作本脚本已复测结果。

## G 黄金参考比对

- **适用范围**：独立参考与待测 CSV 已有相同行序、等长样本和可比较的数值字段。
- **使用方法**：`python telemetry-evidence-review/scripts/compare_golden.py GOLDEN.csv ACTUAL.csv --columns sample i q --atol 1 --rtol 0`。根据定点误差预算明确设置容差，默认零容差。
- **已验证效果**：回归能识别注入的单样本幅度错误、长度不符和非有限数；给定容差内可通过。工具报告最多前20个错误以及错误总数。
- **失效条件**：参考来自同一待测输出、存在未处理的时延、相位模糊或字段含义不同。工具不对齐、不旋转、不补点，不能以自行放宽容差证明算法正确。
- **来源**：协作记录第5、6、15项对跨观测点核验和实测数据真实性的要求；工具属于新编可复用实现。

## R 交付文件一致性与复现证据

- **适用范围**：交付前后、换电脑或接手工程时，检查一组明确列出的源码、系数、构建脚本和报告是否发生变化。
- **使用方法**：`python telemetry-evidence-review/scripts/release_manifest.py record --root YOUR_PROJECT --files rtl/top.v coeff/table.mem build.tcl --manifest release-v1.json`；接收方运行 `python telemetry-evidence-review/scripts/release_manifest.py verify --root YOUR_PROJECT --manifest release-v1.json`。
- **已验证效果**：回归检出一字节变化和文件缺失，正常清单可复验；拒绝根目录逃逸路径。不覆盖已有清单，需显式使用新版本名。
- **失效条件**：清单本身未被信任、遗漏依赖、工具/IP版本不同或bit与源码没有构建关联。它检查字节身份，不自动发现全部依赖，也不证明可重建。按 rebuild_checklist.md 另行在干净环境实际构建。
- **来源**：协作记录第7、10、19项关于版本命名、顶层实例、内嵌系数与实际烧录不一致的观察。

## P 踩坑清单

- **适用范围**：出现 P01 至 P12 所列症状时，查相应一行；可作为模型回答和实验方案的评审清单。
- **使用方法**：先确认触发条件，再按步骤查证；将“撤回或停止条件”写入实验记录。匹配症状只提示排查方向，不认定根因。
- **已验证效果**：条目可逐项追溯历史失败或观察，保留零输入残余RF、激励不纯、PAPR固定值和“stable仍卡退”等反例。
- **失效条件**：新问题机制不同、只有外观相似、沿用其他版本寄存器配置、把某一原因列入清单就当它已成立。
- **来源**：lessons.md 中 L01 至 L09；未证实的最终归因在清单中未被改写为定论。

## U 通用 PYNQ Skill

- **适用范围**：使用常见 HWH MODULE 命名结构的 PYNQ Overlay 交付。不绑定本队调制、AD9361、板卡型号、DMA名称或寄存器地址，换题目后仍可用同一检查流程。
- **使用方法**：`python pynq-overlay-preflight/scripts/preflight_overlay.py --bit YOUR_DIR/design.bit --hwh YOUR_DIR/design.hwh --require-ip your_ip_0`。IP名称按实际HWH填写；只查配对时可不传 --require-ip。PYNQ板上元数据读取模板见 assets/overlay_metadata_probe.py。
- **已验证效果**：合成回归覆盖配对名称、XML解析、命名空间、指定IP缺项、未知schema和DTD拒绝。官方PYNQ v3.1文档已核对，链接见 references/method.md。未在真实PYNQ系统执行元数据探针。
- **失效条件**：XSA或部分重配置等其他流程、不支持的HWH结构、同名但不同源构建、器件或板卡不兼容。静态通过不验证 bit 格式、驱动、MMIO、DMA和功能。更换板卡需要重新提供对应bit/HWH，不可搬用旧bit。
- **来源**：由历史第19项“版本和元数据一致性”经验迁移，并根据官方文档新编。团队历史PL＋AD9361工程不因此变成已验证的PYNQ工程；是否获得通用PYNQ加分由评审认定。

## 验证说明与复用责任

本次脚本回归为25项合成测试，均通过；不是25次板上试验。独立陌生任务试用发现前导斜杠导致IP误报，修正后新增一项回归。可重跑 `python validation/test_scripts.py`，会更新 test_report.json。试用只验证已记录输入下的操作与结论边界，不能推出任意模型的稳定性。所有脚本只读取用户指定数据；release_manifest.py 的 record 创建新清单，测试程序在临时目录生成并删除合成夹具，不操作板卡。

可直接复用模板和脚本，但提交自己成果时须记录自己的版本、数据与验证范围。模型答复不得替代实际测试。原始交互证据、摘要和新编技能内容必须区分。

复用试用的原始命令与绝对路径保留在 validation/reuse_case_result.md，属于当时的审计记录；实际使用请按本README中的相对命令替换自己的输入。修正后结果见 validation/forward_retest.json。本开源仓库的交互记录位于 report/collaboration_record.docx，输入清单位于 validation/input_manifest.json；历史试用记录保持原样，实际使用按本README的相对路径执行。Git提交记录由仓库自身保存。
