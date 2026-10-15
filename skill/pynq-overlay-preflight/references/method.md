# 方法与失效条件

## 从工程观察迁移

遥测协作记录第19项显示：文件名、上传时间、注释与实际实例可能不一致。将其迁移为“配对元数据、记录文件指纹、分别检查静态与运行时”的通用交付流程。它是本次新编的PYNQ静态技能，不是历史PYNQ板上验证。

## 官方依据

查阅日期：2026-10-15。按PYNQ v3.1文档核对：
- Overlay设计与HWH配对：https://pynq.readthedocs.io/en/v3.1/overlay_design_methodology/overlay_design.html
- Overlay实例化与download=False：https://pynq.readthedocs.io/en/v3.1/pynq_libraries/overlay.html

官方文档要求相匹配的bit/HWH，Overlay默认会下载bit；download=False用于仅实例化而不下载。不同版本请重新核对该接口。

## 静态检查覆盖

文件存在且非空、后缀、同目录同basename、HWH XML可解析、MODULE的FULLNAME/INSTANCE、用户指定IP名称、两个文件SHA-256。XML支持带命名空间的MODULE标签；拒绝DTD/entity和大于16 MiB的HWH。

静态检查不验证bit二进制格式、器件part、两个文件是否同一构建、时钟配置、地址映射正确性、驱动绑定、DMA、寄存器、吞吐或输出精度。合成测试的非空占位bit仅验证文件规则，绝不能上板下载。

## 使用与失效

从本技能目录执行：
`python scripts/preflight_overlay.py --bit /your/path/design.bit --hwh /your/path/design.hwh --require-ip your_ip_0`

退出0：所列静态规则通过；1：指定IP缺项；2：缺文件、命名或格式不支持等输入问题。
schema没有MODULE名称、部分重配置、XSA或其他元数据流不由本脚本处理。不要为了让预检通过而修改元数据来伪装bit；应从正确构建重新导出并核对版本。

换题目和换板卡时复用脚本与流程，替换输入文件、目标器件、版本和IP清单；不会使旧bit变成新板卡可用。

