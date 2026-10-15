# 构建与复算

从仓库根目录依次执行 `python build/check_release.py` 和 `python build/prepare.py --workspace NEW_DIRECTORY`。准备程序拒绝已有目录和仓库内工作目录，先核对发布输入哈希，再复制材料，仅适配 TB 导出和 MATLAB 数据路径。

离线：`python build/audit_data.py --workspace NEW_DIRECTORY --baseband archived`。然后 `python build/verify_replay.py NEW_DIRECTORY/output/audit_archived.json`。这是同一归档输入复算，不是独立 golden 对 RTL 的验证。

build_hardware.tcl 复制到工作 scripts 后，在 Vivado 2019.1 新会话执行；从 RTL/MEM/XDC/XCI 新建工程并生成 IP、综合实现。未在打包环境运行。接收者保留真实日志、资源/时序/CDC 报告及同次 bit/ltx。重试应准备另一新工作目录。

完整步骤见 ../report/reproduction.md。程序不下载软件、不写外部服务、不烧录板卡。
