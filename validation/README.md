# 验证范围

source_provenance.json 记录输入来源、字节指纹和排除的厂商生成物。input_manifest.json 是交付输入指纹清单，自身及会被回归重写的测试报告不纳入其哈希，避免递归和正常测试后误报。

重跑：`python build/check_release.py`；全新工作副本执行 prepare、audit_data 和 verify_replay；`python skill/validation/test_scripts.py` 为 25 项合成夹具回归。Skill 原独立试用和纠偏记录保持原样。

实际执行结果见 release_check.json。通过的软件检查不证明 Vivado、新建 XCI 工程、MATLAB 图形、上板或 RF 新采集已通过。本次没有运行这些工具/硬件；原板交接资料仍待补齐。

离线交付 ZIP 另附 validation/source_history.bundle，可用 Git 查看本次整理提交。它由已提交内容生成，不纳入自身所属发布的哈希清单；网页上传源码时可省略该历史包。
