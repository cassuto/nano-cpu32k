
# PlanAhead Launch Script for Post-Synthesis floorplanning, created by Project Navigator

create_project -name ncpu32k-spartan6 -dir "E:/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/planAhead_run_1" -part xc6slx16ftg256-2
set_property design_mode GateLvl [get_property srcset [current_run -impl]]
set_property edif_top_file "E:/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6/toplevel.ngc" [ get_property srcset [ current_run ] ]
add_files -norecurse { {E:/nano-cpu32k/sopc/fpga/xilinx-spartan6/ncpu32k-spartan6} {ipcore_dir} }
add_files [list {ipcore_dir/ip_bootrom.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/ip_dcache_bram.ncf}] -fileset [get_property constrset [current_run]]
add_files [list {ipcore_dir/ip_icache_bram.ncf}] -fileset [get_property constrset [current_run]]
set_property target_constrs_file "ncpu32k-spartan6.ucf" [current_fileset -constrset]
add_files [list {ncpu32k-spartan6.ucf}] -fileset [get_property constrset [current_run]]
link_design
