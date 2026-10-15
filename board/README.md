# 原板约束与 IP 配置

constraints/system_top.xdc 保留源字节，包括接口时序、调试核和原板专用 RX hold/非专用时钟路由处理。它不是通用 Zynq 接线文件。例外须结合原理图和实测校准复核，换板不可直接套用。

ip/ 仅含四份 XCI。原 CLK_PLL_sys.xci 文件名改为 clk_pll_sys.xci，XML 内模块名 CLK_PLL_sys 和顶层实例不变。厂商实现由本机 Vivado 生成。

硬件前提见 [hardware_handoff.md](hardware_handoff.md)。器件 xc7z030fbg484-1 不能用于推定电源电压、完整板型或连接线序。
