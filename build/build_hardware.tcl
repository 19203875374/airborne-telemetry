# New project from visible sources and XCI parameters; Vivado 2019.1 required.
# This script has not been executed in the packaging environment.
set work [file normalize [file join [file dirname [info script]] ..]]
create_project telemetry_tx [file join $work hardware_project] -part xc7z030fbg484-1
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -fileset sources_1 [glob [file join $work rtl *.v]]
add_files -fileset sources_1 [glob [file join $work mem *.mem]]
add_files -fileset constrs_1 [file join $work constraints system_top.xdc]
set_property top system_top [get_filesets sources_1]
foreach name {clk_pll_sys pll_ad9361 fifo_128x64 vio_trx_ctrl} {
    read_ip [file join $work ip ${name}.xci]
}
report_ip_status -file [file join $work logs ip_status.rpt]
generate_target all [get_ips]
create_ip_run [get_ips]
set ip_runs [get_runs -quiet *_synth_1]
if {[llength $ip_runs] > 0} {
    launch_runs $ip_runs -jobs 4
    foreach run $ip_runs {
        wait_on_run $run
        if {![string match "*Complete*" [get_property STATUS $run]]} {
            error "IP synthesis did not complete: $run"
        }
    }
}
update_compile_order -fileset sources_1
launch_runs synth_1 -jobs 4
wait_on_run synth_1
if {![string match "*Complete*" [get_property STATUS [get_runs synth_1]]]} {
    error {Top-level synthesis did not complete}
}
launch_runs impl_1 -to_step write_bitstream -jobs 4
wait_on_run impl_1
if {![string match "*Complete*" [get_property STATUS [get_runs impl_1]]]} {
    error {Implementation did not complete}
}
open_run impl_1
report_timing_summary -file [file join $work output build timing_summary.rpt]
report_utilization -file [file join $work output build utilization.rpt]
report_cdc -file [file join $work output build cdc.rpt]
write_debug_probes -force [file join $work output build system_top.ltx]
set run_dir [get_property DIRECTORY [get_runs impl_1]]
file copy -force [file join $run_dir system_top.bit] [file join $work output build system_top.bit]
puts {Fresh bit/ltx and reports exported. Review constraints and timing before programming.}
