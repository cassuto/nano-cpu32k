onerror {resume}
quietly virtual signal -install /tb_toplevel/soc { (context /tb_toplevel/soc )&{\soc/fb_mbus_cmd_addr[0] , \soc/fb_mbus_cmd_addr[10] , \soc/fb_mbus_cmd_addr[11] , \soc/fb_mbus_cmd_addr[12] , \soc/fb_mbus_cmd_addr[13] , \soc/fb_mbus_cmd_addr[14] , \soc/fb_mbus_cmd_addr[15] , \soc/fb_mbus_cmd_addr[16] , \soc/fb_mbus_cmd_addr[17] , \soc/fb_mbus_cmd_addr[18] , \soc/fb_mbus_cmd_addr[19] , \soc/fb_mbus_cmd_addr[1] , \soc/fb_mbus_cmd_addr[20] , \soc/fb_mbus_cmd_addr[21] , \soc/fb_mbus_cmd_addr[22] , \soc/fb_mbus_cmd_addr[23] , \soc/fb_mbus_cmd_addr[24] , \soc/fb_mbus_cmd_addr[25] , \soc/fb_mbus_cmd_addr[2] , \soc/fb_mbus_cmd_addr[31] , \soc/fb_mbus_cmd_addr[3] , \soc/fb_mbus_cmd_addr[4] , \soc/fb_mbus_cmd_addr[5] , \soc/fb_mbus_cmd_addr[6] , \soc/fb_mbus_cmd_addr[7] , \soc/fb_mbus_cmd_addr[8] , \soc/fb_mbus_cmd_addr[9] }} fb_mbus_cmd_addr
quietly virtual signal -install /tb_toplevel/soc { (context /tb_toplevel/soc )&{\soc/fb_mbus_cmd_addr[25] , \soc/fb_mbus_cmd_addr[24] , \soc/fb_mbus_cmd_addr[23] , \soc/fb_mbus_cmd_addr[22] , \soc/fb_mbus_cmd_addr[21] , \soc/fb_mbus_cmd_addr[20] , \soc/fb_mbus_cmd_addr[19] , \soc/fb_mbus_cmd_addr[18] , \soc/fb_mbus_cmd_addr[17] , \soc/fb_mbus_cmd_addr[16] , \soc/fb_mbus_cmd_addr[15] , \soc/fb_mbus_cmd_addr[14] , \soc/fb_mbus_cmd_addr[13] , \soc/fb_mbus_cmd_addr[12] , \soc/fb_mbus_cmd_addr[11] , \soc/fb_mbus_cmd_addr[10] , \soc/fb_mbus_cmd_addr[9] , \soc/fb_mbus_cmd_addr[8] , \soc/fb_mbus_cmd_addr[7] , \soc/fb_mbus_cmd_addr[6] , \soc/fb_mbus_cmd_addr[5] , \soc/fb_mbus_cmd_addr[4] , \soc/fb_mbus_cmd_addr[3] , \soc/fb_mbus_cmd_addr[2] , \soc/fb_mbus_cmd_addr[1] , \soc/fb_mbus_cmd_addr[0] }} fb_mbus_cmd_addr_g1
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_toplevel/rst_n
add wave -noupdate /tb_toplevel/DRAM_DQM
add wave -noupdate /tb_toplevel/soc/dram_clk
add wave -noupdate /tb_toplevel/soc/sdr_clk
add wave -noupdate /tb_toplevel/DRAM_CLK
add wave -noupdate /tb_toplevel/DRAM_DATA
add wave -noupdate {/tb_toplevel/soc/\soc/fb_DRAM_ctrl/sdr_dout }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_DRAM_ctrl/status_delay_r }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_DRAM_ctrl/DRAM_CS_WE_RAS_CAS_L }
add wave -noupdate /tb_toplevel/DRAM_CS_L
add wave -noupdate /tb_toplevel/DRAM_WE_L
add wave -noupdate /tb_toplevel/DRAM_RAS_L
add wave -noupdate /tb_toplevel/DRAM_CAS_L
add wave -noupdate /tb_toplevel/soc/clk
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_addr_a }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/din_r }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_en_a }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_we_a<2>_0 }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_we_a[0] }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_we_a[2] }
add wave -noupdate -divider 0
add wave -noupdate -divider 8
add wave -noupdate -divider {New Divider}
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_en_b }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_dout[31]_ch_mem_dout[15]_mux_58_OUT<6> }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_dout[31]_ch_mem_dout[15]_mux_58_OUT<7> }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_dout[31]_ch_mem_dout[15]_mux_58_OUT<8> }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/ch_mem_dout[31]_ch_mem_dout[15]_mux_58_OUT<9> }
add wave -noupdate /tb_toplevel/soc/fb_mbus_cmd_addr_g1
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_cmd_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_cmd_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_dout }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_bus_sel }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_ibus_cmd_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_ibus_cmd_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/ncpu32k/i_mmu/dff_id/Q }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_ibus_dout }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_ibus_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_dbus_cmd_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_dbus_dout }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_dbus_valid }
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {250054820 ps} 0} {{Cursor 2} {250136630 ps} 0} {{Cursor 3} {8917 ps} 0} {{Cursor 4} {151133400039 ps} 0} {{Cursor 5} {151133401963 ps} 0}
quietly wave cursor active 5
configure wave -namecolwidth 183
configure wave -valuecolwidth 100
configure wave -justifyvalue left
configure wave -signalnamewidth 0
configure wave -snapdistance 10
configure wave -datasetprefix 0
configure wave -rowmargin 4
configure wave -childrowmargin 2
configure wave -gridoffset 0
configure wave -gridperiod 1
configure wave -griddelta 40
configure wave -timeline 0
configure wave -timelineunits us
update
WaveRestoreZoom {151133384645 ps} {151133504997 ps}
