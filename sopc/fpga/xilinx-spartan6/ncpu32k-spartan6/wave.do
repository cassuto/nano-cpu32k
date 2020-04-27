onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_toplevel/clk
add wave -noupdate /tb_toplevel/rst_n
add wave -noupdate /tb_toplevel/DRAM_CKE
add wave -noupdate /tb_toplevel/DRAM_ADDR
add wave -noupdate /tb_toplevel/DRAM_BA
add wave -noupdate /tb_toplevel/DRAM_DATA
add wave -noupdate /tb_toplevel/DRAM_DQM
add wave -noupdate /tb_toplevel/DRAM_CAS_L
add wave -noupdate /tb_toplevel/DRAM_RAS_L
add wave -noupdate /tb_toplevel/DRAM_WE_L
add wave -noupdate /tb_toplevel/DRAM_CS_L
add wave -noupdate /tb_toplevel/SPI_SCK
add wave -noupdate /tb_toplevel/SPI_CS_L
add wave -noupdate /tb_toplevel/SPI_MOSI
add wave -noupdate /tb_toplevel/SPI_MISO
add wave -noupdate /tb_toplevel/SF_DQ0
add wave -noupdate /tb_toplevel/SF_DQ1
add wave -noupdate /tb_toplevel/SF_Vpp_W_DQ2
add wave -noupdate /tb_toplevel/SF_HOLD_DQ3
add wave -noupdate /tb_toplevel/DRAM_CLK
add wave -noupdate /tb_toplevel/UART_RX_L
add wave -noupdate /tb_toplevel/UART_TX_L
add wave -noupdate /glbl/GSR
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/bus_pending_nxt }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/[0].dff_bus_dout_sel/Q_0_32611 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/[1].dff_bus_dout_sel/Q_0_32614 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/[2].dff_bus_dout_sel/Q_0_32613 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/[3].dff_bus_dout_sel/Q_0_32612 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/hds_bus_cmd[0]_hds_bus_dout[0]_OR_71_o1_36011 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/hds_bus_cmd[3]_hds_bus_dout[3]_OR_77_o_37533 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/hds_bus_cmd[0]_hds_bus_dout[0]_OR_71_o1_36011 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_router/hds_bus_cmd[3]_hds_bus_dout[3]_OR_77_o_37533 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_bus_cmd_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/l2_ch_cmd_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/l2_ch_valid_r_33792 }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_cmd_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_cmd_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_cmd_we_msk }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_ready }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_valid }
add wave -noupdate {/tb_toplevel/soc/\soc/fb_mbus_dout }
add wave -noupdate {/tb_toplevel/soc/\soc/L2_cache/pending_r_32449 }
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
configure wave -namecolwidth 299
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
WaveRestoreZoom {1251812 ps} {1252605 ps}
