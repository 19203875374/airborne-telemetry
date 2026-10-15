---
name: pynq-overlay-preflight
description: 对任意题目与板卡的 PYNQ Overlay 交付执行通用静态预检，检查 bit 与 HWH 文件配对、XML 元数据、用户指定 IP 名称和文件指纹。用于交付前发现缺失文件、命名错误或元数据缺项。不要把静态通过当作板卡兼容、DMA或硬件功能验证。
---

# PYNQ Overlay 通用交付预检

1. 获取待交付 bit/HWH 路径、目标器件和板卡、PYNQ/Vivado版本、必需 IP 的完整名称。把未知项保留为未知，不默认任何板卡、DMA名称或寄存器地址。
2. 读取 [方法与边界](references/method.md)，核对官方资料与用户版本。
3. 离线运行 `python scripts/preflight_overlay.py --bit PATH/demo.bit --hwh PATH/demo.hwh`。按用户要求添加 `--require-ip hierarchy/ip_name`。替换路径与IP名称，不使用遥测题目固定配置。
4. 记录配对、XML解析、缺项及哈希结果；检查构建日志是否把两个文件关联到同一构建。相同名称与记录哈希并不证明同源。
5. 仅在用户已有PYNQ板卡环境且要求运行时，使用 [元数据探针模板](assets/overlay_metadata_probe.py)。模板使用 download=False，不执行下载、DMA或寄存器写入；运行时仍可能要求板上PYNQ环境及版本匹配。不要自动改成默认下载。
6. 输出静态检查结果和仍需板上执行的项目。保留 hardware_validated=false。不得将本分项描述成本队已经使用PYNQ的历史成果。

验证程度：本包只在合成XML和占位二进制上验证脚本规则，未在真实PYNQ硬件运行。适用范围为常见MODULE命名的HWH结构；不支持的schema返回输入错误。方法不限具体板卡，但bit文件本身必须针对实际器件构建，不能跨板卡直接复用。

