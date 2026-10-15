# Copy to WORKSPACE/scripts with build/prepare.py; run in a fresh Vivado 2019.1 session.
set work [file normalize [file join [file dirname [info script]] ..]]
create_project repro_baseband [file join $work sim_project] -part xc7z030fbg484-1
set_property target_language Verilog [current_project]
foreach name {multi_mode_baseband_tx pcm_fm_top premod_fir pcm_fm_mod soqpsk_precoder soqpsk_mod psk_mod fir_sym} {
    add_files -fileset sources_1 [file join $work rtl ${name}.v]
}
add_files -fileset sources_1 [file join $work mem sine_lut.mem]
add_files -fileset sim_1 [file join $work scripts tb_pcm_net_mode_switch.v]
set_property top tb_pcm_net_mode_switch [get_filesets sim_1]
update_compile_order -fileset sources_1
update_compile_order -fileset sim_1
set_property xsim.simulate.runtime 0ns [get_filesets sim_1]
launch_simulation -simset sim_1 -mode behavioral
run all
close_sim
puts {Simulation returned. Inspect TEST PASS, nonzero mapping checks, and new output files.}
