# 归档数据与参考

baseband_archived/pcm_net_mode_switch_iq.txt 为 126788 行归档数据，Fs=30.72 MS/s。每种模式取最长连续段，仅剔除两端零点；原始列和数值未修改。

iq_wave/ 与 f_wave/ 是同一组 N9000A 四模式原始 CSV；每份 IQ 为 30001 个复样本，约 15 MS/s。不得与后续 N9020A 的 PCM-FM 2.19 MHz 结果混为一组。

reference/audit_archived.json 是同一输入的复算参考；RF PAPR 按模式约为 0.940544、0.908381、4.432887、4.224933 dB；OBW 从仪器字段读取。它们不是其他批次的性能验收门限。

新批次新建工作目录，记录仪器配置并单独保存。修改扩展名不等于格式适配，恢复图不证明 BER 或标准符合性。文件身份见 ../validation/input_manifest.json。
