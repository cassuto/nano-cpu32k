
# PlanAhead Launch Script for Post PAR Floorplanning, created by Project Navigator

create_project -name ncpu32k-spartan6 -dir "E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/planAhead_run_2" -part xc6slx16ftg256-2
set srcset [get_property srcset [current_run -impl]]
set_property design_mode GateLvl $srcset
set_property edif_top_file "E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel_cs.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6} {ipcore_dir} }
add_files [list {ipcore_dir/ramblk_bootrom.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/ramblk_cache_mem.ncf}] -fileset [get_property constrset [current_run]]
set_property target_constrs_file "ncpu32k-spartan6.ucf" [current_fileset -constrset]
add_files [list {ncpu32k-spartan6.ucf}] -fileset [get_property constrset [current_run]]
link_design
read_xdl -file "E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel.ncd"
if {[catch {read_twx -name results_1 -file "E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel.twx"} eInfo]} {
   puts "WARNING: there was a problem importing \"E:/_processor_cores/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel.twx\": $eInfo"
}
