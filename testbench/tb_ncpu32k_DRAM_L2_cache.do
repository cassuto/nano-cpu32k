onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/clk
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_cmd_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_cmd_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_cmd_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_cmd_we_msk
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_din
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_dout
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_dbus_valid
add wave -noupdate -divider ibus
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_cmd_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_cmd_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_cmd_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_dout
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_ibus_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_irqs
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_cmd_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_cmd_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_cmd_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_cmd_we_msk
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_din
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_dout
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/fb_mbus_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_cmd_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_cmd_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_cmd_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_cmd_we_msk
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_din
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_dout
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_flush
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/l2_ch_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/rst_n
add wave -noupdate -divider cache
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/clk
add wave -noupdate -radix binary /tb_ncpu32k_DRAM_L2_cache/L2_cache/status_r
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1i_entry_idx
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1o_tag_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1o_tag_v
add wave -noupdate {/tb_ncpu32k_DRAM_L2_cache/L2_cache/genblk1[0]/s2i_entry_idx}
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s2i_tag_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s2i_tag_v
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/wb_idle_r
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/pipe_en
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1o_hit
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1o_valid
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1_ready
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s1_cke
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/L2_cache/s2_cke
add wave -noupdate -divider sdr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_clk
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_cmd_addr
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_cmd_bst_rd_ack
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_cmd_bst_rd_req
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_cmd_bst_we_ack
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_cmd_bst_we_req
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_din
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_dout
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_r_vld
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/sdr_w_rdy
add wave -noupdate -divider ifu
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/ncpu32k/core/ifu/idu_insn
add wave -noupdate /tb_ncpu32k_DRAM_L2_cache/ncpu32k/core/ifu/idu_insn_pc_w
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {335168875 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 175
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
configure wave -timelineunits ns
update
WaveRestoreZoom {334946103 ps} {335193627 ps}
