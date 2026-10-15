# 设计与分析源码

rtl/ 的 16 个模块、mem/ 的 7 个文件按原始输入保存字节；tx_fir_coeff.mem 来自单独补齐的依赖。顶层 system_top，基带顶层 multi_mode_baseband_tx。

MATLAB 使用 reproduce_results.m 静态入口与原始 load_rf_data.m 恢复链。两处数据目录仅在工作副本改写。动态 dashboard 不是必经步骤，未用理想星座替换实际恢复数据。

历史注释可能落后于实际参数，应核对当前系数长度和实例。psk_demod.v 的累加判决不代表完整载波/定时恢复。来源见 ../validation/source_provenance.json。
