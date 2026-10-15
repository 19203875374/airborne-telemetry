---
name: telemetry-evidence-review
description: 核查 FPGA 或软件无线电工程中的版本、采样率、IQ 数据、实验归因和成果表述。用于从算法约束推导软硬件划分、定位异常频谱或同步问题、比对黄金参考、检查交付一致性以及整理有证据的协作记录。可迁移到其他 FPGA 数据流工程；不把历史项目参数或推测当作新工程事实。
---

# 工程证据核查与调试复用

先读取用户提供的当前源码、数据和要求。按任务选择资源，不加载整套历史聊天。

1. 建立证据表：记录文件路径与哈希、工具版本、实际烧录标识、时钟域、有效样本率、数据批次。未提供的字段明确为未知。使用 [记录模板](assets/review_record_template.md)。
2. 区分需求、方案、源码存在、仿真通过、板上观测、端到端验证。读取 [踩坑清单](references/pitfalls.md) 与 [经验来源](references/lessons.md)，只选匹配当前证据的条目。
3. 按 [提示词工作流](references/workflows.md) 组织输入与输出。用最小变量实验比较互斥假设；先核对测试激励，记录会推翻当前假设的观测。
4. 分析数据前读取 [数据契约](references/data_contract.md)。先保留原始数据，再显式筛选模式与有效区间。禁止把复制样本、重画理想星座、固定数组当作新的实测证据。
5. 使用 Python 3.10 或更新版本运行脚本。仅处理明确映射的 CSV，不猜仪器导出格式。输入含缺失或非有限数值时报告失败，不静默丢弃。
6. 修改代码时只修改当前授权层次；记录唯一改动与预期现象。运行约定的检查；失败即保留失败状态。脚本不负责 Vivado 构建或实际烧录。
7. 输出任务结果、证据位置、仍未排除的原因、下一项最小实验和结论适用范围。规范原文未取得时不补造条款或文献。

## 工具入口

在本技能目录执行：
- IQ 统计：`python scripts/inspect_iq.py assets/demo_iq.csv --fs 4000000 --sample sample --inc inc --inc-fs 4000000`
- 黄金比对：`python scripts/compare_golden.py assets/demo_iq.csv assets/demo_iq.csv --columns sample i q inc`
- 文件指纹：`python scripts/release_manifest.py record --root . --files SKILL.md assets/demo_iq.csv --manifest release.json`
- 验证文件指纹：`python scripts/release_manifest.py verify --root . --manifest release.json`

将实际工程文件另行显式列入清单；不要把技能自身的示例清单当作工程完整性证明。
脚本退出码：0 表示所列检查通过；1 表示比较或内容检查不符；2 表示输入或格式错误。
IQ 脚本输出数值无“整机通过”含义；全零输入的 PAPR 为 null。

## 必须保留的边界

相位差频率受混叠限制；图形连续不独立证明标准符合性。没有已知发送序列、可靠对齐和统计过程时不报告 BER 通过。哈希相同只证明所列文件字节一致，不证明依赖完整或可重建。原始记录缺失时使用概要转述，不补写逐字对话、模型版本、时间和测试成功。

