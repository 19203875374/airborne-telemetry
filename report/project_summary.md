# 工程摘要

工程以 Zynq-7030 PL 与 AD9361 构成四模式发射原型，数据源为 PRBS。PCM-FM/SOQPSK-TG 共用 PCM 选择，BPSK/QPSK 共用 PSK 选择；经异步 FIFO 接入 CMOS DDR，PL SPI 和 VIO 用于配置观测。基带 30.72 MS/s、OSR=16；PCM 比特率和 PSK 符号率基线 1.92 M，QPSK 对应 3.84 Mbit/s。

交付内容为设计源码、初始化表、原始数据、复算入口及历史经验提炼的 Skill。skill/README.md 对每项给出适用范围、用法、失效条件、效果与失败来源。通用 PYNQ Skill 是 Overlay 静态预检，不表示本工程使用 PYNQ 或完成其板上测试。

SP→EP→TP→PCM 子帧属于理论/研究方案；不宣称已完成组帧、以太网/IP 栈、信道编码或完整相干接收链。板级接口、时序例外和 RF 激励判断需要实际证据。

[collaboration_record.docx](collaboration_record.docx) 含 21 个主要协作纠偏案例和 Skill 附录，区分原始引文、检索摘要及新编归纳，不是全量聊天的逐字导出。未确认根因、未完成实验和面板卡退保持未解决状态。

[reproduction.md](reproduction.md) 为当前目录的 20 步说明；[open_source_release.md](open_source_release.md) 为上传操作。本摘要索引不能替代竞赛完整设计报告。
