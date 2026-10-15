# ----------------------------------------------------------------------------
# Board pinout copied from the hardware-verified telemetry_TX project.
# Target part: xc7z030fbg484-1, confirmed from the device top marking.
# Do not reuse on another PCB without checking
# the schematic, bank voltages and AD9361 interface mode.
# ----------------------------------------------------------------------------
set_property PACKAGE_PIN N3 [get_ports {P1_D11_D6[5]}]
set_property PACKAGE_PIN K2 [get_ports {P1_D11_D6[4]}]
set_property PACKAGE_PIN K3 [get_ports {P1_D11_D6[3]}]
set_property PACKAGE_PIN M2 [get_ports {P1_D11_D6[2]}]
set_property PACKAGE_PIN M3 [get_ports {P1_D11_D6[1]}]
set_property PACKAGE_PIN P3 [get_ports {P1_D11_D6[0]}]

set_property PACKAGE_PIN M7 [get_ports {rx_data_in_p[5]}]
set_property PACKAGE_PIN P5 [get_ports {rx_data_in_p[4]}]
set_property PACKAGE_PIN N1 [get_ports {rx_data_in_p[3]}]
set_property PACKAGE_PIN L1 [get_ports {rx_data_in_p[2]}]
set_property PACKAGE_PIN L2 [get_ports {rx_data_in_p[1]}]
set_property PACKAGE_PIN N2 [get_ports {rx_data_in_p[0]}]

set_property PACKAGE_PIN J3 [get_ports {tx_data_out_p[5]}]
set_property PACKAGE_PIN F2 [get_ports {tx_data_out_p[4]}]
set_property PACKAGE_PIN J1 [get_ports {tx_data_out_p[3]}]
set_property PACKAGE_PIN K1 [get_ports {tx_data_out_p[2]}]
set_property PACKAGE_PIN E1 [get_ports {tx_data_out_p[1]}]
set_property PACKAGE_PIN F1 [get_ports {tx_data_out_p[0]}]

set_property PACKAGE_PIN V20 [get_ports en_agc]
set_property PACKAGE_PIN N7 [get_ports data_clk_n]
set_property PACKAGE_PIN Y21 [get_ports enable]
set_property PACKAGE_PIN Y12 [get_ports mclk1]
set_property PACKAGE_PIN AA21 [get_ports resetb]
set_property PACKAGE_PIN H2 [get_ports rx_clk_in_p]
set_property PACKAGE_PIN G4 [get_ports rx_frame_in_p]
set_property PACKAGE_PIN H6 [get_ports spi_clk]
set_property PACKAGE_PIN H5 [get_ports spi_csn]
set_property PACKAGE_PIN F4 [get_ports spi_miso]
set_property PACKAGE_PIN F5 [get_ports spi_mosi]
set_property PACKAGE_PIN H3 [get_ports tx_clk_out_p]
set_property PACKAGE_PIN J6 [get_ports tx_frame_out_p]
set_property PACKAGE_PIN W21 [get_ports txnrx]

set_property IOSTANDARD LVCMOS33 [get_ports mclk1]
set_property IOSTANDARD LVCMOS33 [get_ports resetb]
set_property IOSTANDARD LVCMOS33 [get_ports en_agc]
set_property IOSTANDARD LVCMOS33 [get_ports enable]
set_property IOSTANDARD LVCMOS33 [get_ports txnrx]
set_property IOSTANDARD LVCMOS18 [get_ports spi_clk]
set_property IOSTANDARD LVCMOS18 [get_ports spi_csn]
set_property IOSTANDARD LVCMOS18 [get_ports spi_miso]
set_property IOSTANDARD LVCMOS18 [get_ports spi_mosi]
set_property IOSTANDARD LVCMOS18 [get_ports data_clk_n]
set_property IOSTANDARD LVCMOS18 [get_ports rx_clk_in_p]
set_property IOSTANDARD LVCMOS18 [get_ports rx_frame_in_p]
set_property IOSTANDARD LVCMOS18 [get_ports tx_clk_out_p]
set_property IOSTANDARD LVCMOS18 [get_ports tx_frame_out_p]
set_property IOSTANDARD LVCMOS18 [get_ports {{P1_D11_D6[*]} {rx_data_in_p[*]} {tx_data_out_p[*]}}]

set_property SLEW FAST [get_ports {spi_clk spi_csn spi_mosi tx_clk_out_p tx_frame_out_p {tx_data_out_p[*]}}]
set_property DRIVE 8 [get_ports {spi_clk spi_csn spi_mosi tx_clk_out_p tx_frame_out_p {tx_data_out_p[*]}}]

# ----------------------------------------------------------------------------
# Primary clocks. mclk1 is the PCB 20 MHz system reference. rx_clk_in_p is the
# AD9361 DATA_CLK output at 61.44 MHz; pll_ad9361 derives the 30.72 MHz complex
# sample clock from it. These are intentionally different clock domains.
# ----------------------------------------------------------------------------
# CLK_PLL_sys.xci already creates the 50 ns primary clock on mclk1. Do not
# create it again here, otherwise this XDC overrides the IP clock constraint.
create_clock -period 16.276 -name ad9361_data_clk_in [get_ports rx_clk_in_p]


# spi_div[4] is generated from the 20 MHz sys_clk20 clock.
# Its output frequency is 20 MHz / 32 = 625 kHz.
create_generated_clock -name ad9361_spi_int -source [get_pins {spi_div_reg[4]/C}] -divide_by 32 [get_pins {spi_div_reg[4]/Q}]
# SPI SCLK output is directly driven by spi_div[4].
create_generated_clock -name ad9361_spi_sclk -source [get_pins {spi_div_reg[4]/Q}] -divide_by 1 [get_ports spi_clk]


# The feedback clock is forwarded by the ODDR used by the verified design.
create_generated_clock -name ad9361_fb_clk -source [get_pins u_txif/u_tx_clk_oddr/C] -divide_by 1 -invert [get_ports tx_clk_out_p]

# 1.8 V CMOS timing from the AD9361 data sheet, excluding PCB trace skew:
# DATA_CLK-to-RX data 0..1.5 ns; DATA_CLK-to-RX_FRAME 0..1.0 ns.
set_input_delay -clock ad9361_data_clk_in -min 0.000 [get_ports {rx_data_in_p[*]}]
set_input_delay -clock ad9361_data_clk_in -max 1.500 [get_ports {rx_data_in_p[*]}]
set_input_delay -clock ad9361_data_clk_in -clock_fall -min -add_delay 0.000 [get_ports {rx_data_in_p[*]}]
set_input_delay -clock ad9361_data_clk_in -clock_fall -max -add_delay 1.500 [get_ports {rx_data_in_p[*]}]
set_input_delay -clock ad9361_data_clk_in -min 0.000 [get_ports rx_frame_in_p]
set_input_delay -clock ad9361_data_clk_in -max 1.000 [get_ports rx_frame_in_p]
set_input_delay -clock ad9361_data_clk_in -clock_fall -min -add_delay 0.000 [get_ports rx_frame_in_p]
set_input_delay -clock ad9361_data_clk_in -clock_fall -max -add_delay 1.000 [get_ports rx_frame_in_p]
# --------------------------------------------------------------------------
# RX CMOS DDR hold exception.
# The sampling point is calibrated using AD9361 register 0x006 because the
# PCB routes DATA_CLK through a non-clock-capable FPGA pin.
# Setup timing remains checked; only the RX input hold check is disabled.
# Enable this only after hardware delay/BER calibration.
# --------------------------------------------------------------------------


set_false_path -hold -from [get_ports {{rx_data_in_p[*]} rx_frame_in_p}] -to [get_pins -hier -quiet -filter {
REF_NAME == IDDR &&
REF_PIN_NAME == D &&
NAME =~ u_rxif/*
}]


# AD9361 CMOS DDR发送接口
# 最大值仍按1.0 ns建立时间要求检查。
# 最小值计入0x007=0x0F产生的TX数据内部延时。

set_output_delay -clock ad9361_fb_clk -max 1.000 [get_ports {{tx_data_out_p[*]} tx_frame_out_p}]
set_output_delay -clock ad9361_fb_clk -min 0.500 [get_ports {{tx_data_out_p[*]} tx_frame_out_p}]

set_output_delay -clock ad9361_fb_clk -clock_fall -max -add_delay 1.000 [get_ports {{tx_data_out_p[*]} tx_frame_out_p}]
set_output_delay -clock ad9361_fb_clk -clock_fall -min -add_delay 0.500 [get_ports {{tx_data_out_p[*]} tx_frame_out_p}]



# FIFO and explicit two-flop synchronizers are the only crossings between
# these independent clock families.
set_clock_groups -asynchronous -group [get_clocks -include_generated_clocks mclk1] -group [get_clocks -include_generated_clocks ad9361_data_clk_in]

# Global reset is intentionally asynchronous at the first stage of each
# reset synchronizer.
set_false_path -from [get_ports resetb]

# The fixed PCB routes AD9361 DATA_CLK to H2, which is not connected to the
# selected MMCM through a dedicated clock route. The hardware-verified source
# project used this exact, narrowly-scoped exception. A PCB revision should
# move DATA_CLK to a clock-capable pin and remove this exception.
set_property CLOCK_DEDICATED_ROUTE FALSE [get_nets rx_clk_in_p]










set_property MARK_DEBUG true [get_nets -of_objects [get_pins -hier -filter {NAME =~ "*u_txif/half_sel_reg/Q"}]]
set_property MARK_DEBUG true [get_nets -of_objects [get_pins -hier -filter {NAME =~ "*u_txif/half_sel_reg/Q"}]]
create_debug_core u_ila_0 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_0]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_0]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_0]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_0]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_0]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_0]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_0]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_0]
set_property port_width 1 [get_debug_ports u_ila_0/clk]
connect_debug_port u_ila_0/clk [get_nets [list u_rfclk/inst/clk_out4]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe0]
set_property port_width 12 [get_debug_ports u_ila_0/probe0]
connect_debug_port u_ila_0/probe0 [get_nets [list {bb_q[0]} {bb_q[1]} {bb_q[2]} {bb_q[3]} {bb_q[4]} {bb_q[5]} {bb_q[6]} {bb_q[7]} {bb_q[8]} {bb_q[9]} {bb_q[10]} {bb_q[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe1]
set_property port_width 12 [get_debug_ports u_ila_0/probe1]
connect_debug_port u_ila_0/probe1 [get_nets [list {bb_i[0]} {bb_i[1]} {bb_i[2]} {bb_i[3]} {bb_i[4]} {bb_i[5]} {bb_i[6]} {bb_i[7]} {bb_i[8]} {bb_i[9]} {bb_i[10]} {bb_i[11]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe2]
set_property port_width 2 [get_debug_ports u_ila_0/probe2]
connect_debug_port u_ila_0/probe2 [get_nets [list {active_mode[0]} {active_mode[1]}]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe3]
set_property port_width 1 [get_debug_ports u_ila_0/probe3]
connect_debug_port u_ila_0/probe3 [get_nets [list bb_valid]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe4]
set_property port_width 1 [get_debug_ports u_ila_0/probe4]
connect_debug_port u_ila_0/probe4 [get_nets [list net_sym_en]]
create_debug_port u_ila_0 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_0/probe5]
set_property port_width 1 [get_debug_ports u_ila_0/probe5]
connect_debug_port u_ila_0/probe5 [get_nets [list pcm_bit_en]]
create_debug_core u_ila_1 ila
set_property ALL_PROBE_SAME_MU true [get_debug_cores u_ila_1]
set_property ALL_PROBE_SAME_MU_CNT 1 [get_debug_cores u_ila_1]
set_property C_ADV_TRIGGER false [get_debug_cores u_ila_1]
set_property C_DATA_DEPTH 4096 [get_debug_cores u_ila_1]
set_property C_EN_STRG_QUAL false [get_debug_cores u_ila_1]
set_property C_INPUT_PIPE_STAGES 0 [get_debug_cores u_ila_1]
set_property C_TRIGIN_EN false [get_debug_cores u_ila_1]
set_property C_TRIGOUT_EN false [get_debug_cores u_ila_1]
set_property port_width 1 [get_debug_ports u_ila_1/clk]
connect_debug_port u_ila_1/clk [get_nets [list u_rfclk/inst/clk_out1]]
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe0]
set_property port_width 6 [get_debug_ports u_ila_1/probe0]
connect_debug_port u_ila_1/probe0 [get_nets [list {u_rxif/data_rise[0]} {u_rxif/data_rise[1]} {u_rxif/data_rise[2]} {u_rxif/data_rise[3]} {u_rxif/data_rise[4]} {u_rxif/data_rise[5]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe1]
set_property port_width 6 [get_debug_ports u_ila_1/probe1]
connect_debug_port u_ila_1/probe1 [get_nets [list {u_txif/tx_data_q[0]} {u_txif/tx_data_q[1]} {u_txif/tx_data_q[2]} {u_txif/tx_data_q[3]} {u_txif/tx_data_q[4]} {u_txif/tx_data_q[5]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe2]
set_property port_width 32 [get_debug_ports u_ila_1/probe2]
connect_debug_port u_ila_1/probe2 [get_nets [list {u_txif/sample_hold[0]} {u_txif/sample_hold[1]} {u_txif/sample_hold[2]} {u_txif/sample_hold[3]} {u_txif/sample_hold[4]} {u_txif/sample_hold[5]} {u_txif/sample_hold[6]} {u_txif/sample_hold[7]} {u_txif/sample_hold[8]} {u_txif/sample_hold[9]} {u_txif/sample_hold[10]} {u_txif/sample_hold[11]} {u_txif/sample_hold[12]} {u_txif/sample_hold[13]} {u_txif/sample_hold[14]} {u_txif/sample_hold[15]} {u_txif/sample_hold[16]} {u_txif/sample_hold[17]} {u_txif/sample_hold[18]} {u_txif/sample_hold[19]} {u_txif/sample_hold[20]} {u_txif/sample_hold[21]} {u_txif/sample_hold[22]} {u_txif/sample_hold[23]} {u_txif/sample_hold[24]} {u_txif/sample_hold[25]} {u_txif/sample_hold[26]} {u_txif/sample_hold[27]} {u_txif/sample_hold[28]} {u_txif/sample_hold[29]} {u_txif/sample_hold[30]} {u_txif/sample_hold[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe3]
set_property port_width 6 [get_debug_ports u_ila_1/probe3]
connect_debug_port u_ila_1/probe3 [get_nets [list {u_rxif/data_fall[0]} {u_rxif/data_fall[1]} {u_rxif/data_fall[2]} {u_rxif/data_fall[3]} {u_rxif/data_fall[4]} {u_rxif/data_fall[5]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe4]
set_property port_width 6 [get_debug_ports u_ila_1/probe4]
connect_debug_port u_ila_1/probe4 [get_nets [list {u_txif/tx_data_i[0]} {u_txif/tx_data_i[1]} {u_txif/tx_data_i[2]} {u_txif/tx_data_i[3]} {u_txif/tx_data_i[4]} {u_txif/tx_data_i[5]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe5]
set_property port_width 32 [get_debug_ports u_ila_1/probe5]
connect_debug_port u_ila_1/probe5 [get_nets [list {fifo_dout[0]} {fifo_dout[1]} {fifo_dout[2]} {fifo_dout[3]} {fifo_dout[4]} {fifo_dout[5]} {fifo_dout[6]} {fifo_dout[7]} {fifo_dout[8]} {fifo_dout[9]} {fifo_dout[10]} {fifo_dout[11]} {fifo_dout[12]} {fifo_dout[13]} {fifo_dout[14]} {fifo_dout[15]} {fifo_dout[16]} {fifo_dout[17]} {fifo_dout[18]} {fifo_dout[19]} {fifo_dout[20]} {fifo_dout[21]} {fifo_dout[22]} {fifo_dout[23]} {fifo_dout[24]} {fifo_dout[25]} {fifo_dout[26]} {fifo_dout[27]} {fifo_dout[28]} {fifo_dout[29]} {fifo_dout[30]} {fifo_dout[31]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe6]
set_property port_width 8 [get_debug_ports u_ila_1/probe6]
connect_debug_port u_ila_1/probe6 [get_nets [list {fifo_level[0]} {fifo_level[1]} {fifo_level[2]} {fifo_level[3]} {fifo_level[4]} {fifo_level[5]} {fifo_level[6]} {fifo_level[7]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe7]
set_property port_width 12 [get_debug_ports u_ila_1/probe7]
connect_debug_port u_ila_1/probe7 [get_nets [list {rx_q[0]} {rx_q[1]} {rx_q[2]} {rx_q[3]} {rx_q[4]} {rx_q[5]} {rx_q[6]} {rx_q[7]} {rx_q[8]} {rx_q[9]} {rx_q[10]} {rx_q[11]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe8]
set_property port_width 12 [get_debug_ports u_ila_1/probe8]
connect_debug_port u_ila_1/probe8 [get_nets [list {rx_i[0]} {rx_i[1]} {rx_i[2]} {rx_i[3]} {rx_i[4]} {rx_i[5]} {rx_i[6]} {rx_i[7]} {rx_i[8]} {rx_i[9]} {rx_i[10]} {rx_i[11]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe9]
set_property port_width 2 [get_debug_ports u_ila_1/probe9]
connect_debug_port u_ila_1/probe9 [get_nets [list {rx_bits[0]} {rx_bits[1]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe10]
set_property port_width 4 [get_debug_ports u_ila_1/probe10]
connect_debug_port u_ila_1/probe10 [get_nets [list {u_demod/count[0]} {u_demod/count[1]} {u_demod/count[2]} {u_demod/count[3]}]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe11]
set_property port_width 1 [get_debug_ports u_ila_1/probe11]
connect_debug_port u_ila_1/probe11 [get_nets [list fifo_empty]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe12]
set_property port_width 1 [get_debug_ports u_ila_1/probe12]
connect_debug_port u_ila_1/probe12 [get_nets [list fifo_rd_en]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe13]
set_property port_width 1 [get_debug_ports u_ila_1/probe13]
connect_debug_port u_ila_1/probe13 [get_nets [list u_rxif/frame_fall]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe14]
set_property port_width 1 [get_debug_ports u_ila_1/probe14]
connect_debug_port u_ila_1/probe14 [get_nets [list u_rxif/frame_rise]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe15]
set_property port_width 1 [get_debug_ports u_ila_1/probe15]
connect_debug_port u_ila_1/probe15 [get_nets [list u_txif/half_sel]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe16]
set_property port_width 1 [get_debug_ports u_ila_1/probe16]
connect_debug_port u_ila_1/probe16 [get_nets [list u_txif/running]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe17]
set_property port_width 1 [get_debug_ports u_ila_1/probe17]
connect_debug_port u_ila_1/probe17 [get_nets [list rx_bits_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe18]
set_property port_width 1 [get_debug_ports u_ila_1/probe18]
connect_debug_port u_ila_1/probe18 [get_nets [list rx_sample_valid]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe19]
set_property port_width 1 [get_debug_ports u_ila_1/probe19]
connect_debug_port u_ila_1/probe19 [get_nets [list u_txif/tx_frame]]
create_debug_port u_ila_1 probe
set_property PROBE_TYPE DATA_AND_TRIGGER [get_debug_ports u_ila_1/probe20]
set_property port_width 1 [get_debug_ports u_ila_1/probe20]
connect_debug_port u_ila_1/probe20 [get_nets [list tx_underflow]]
set_property C_CLK_INPUT_FREQ_HZ 300000000 [get_debug_cores dbg_hub]
set_property C_ENABLE_CLK_DIVIDER false [get_debug_cores dbg_hub]
set_property C_USER_SCAN_CHAIN 1 [get_debug_cores dbg_hub]
connect_debug_port dbg_hub/clk [get_nets sys_clk20]
