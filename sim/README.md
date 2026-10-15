# 仿真入口

tb_pcm_net_mode_switch.v 是单独提供的约 1 ms/模式 TB，模块名相同。原始导出路径保留；先运行根目录 build/prepare.py，再使用工作副本中的 TB 和 run_baseband.tcl。

独立仿真不含 AD9361/FIFO/VIO IP。日志须有 TEST PASS、映射检查次数大于零，无 TEST FAIL/ERROR/FATAL。部分失败也调用 $finish，不能只看进程退出。输出在工作 data/baseband/。

tb_psk_demod.v 是历史辅助输入，不作为此次独立基带仿真的入口，也不是 BER/接收性能验收证据。
