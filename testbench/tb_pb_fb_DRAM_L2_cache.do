onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/clk
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/rst_n
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_cmd_addr
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_cmd_ready
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_cmd_valid
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_cmd_we_msk
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_din
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_dout
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_ready
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/l2_ch_valid
add wave -noupdate -radix binary /tb_pb_fb_DRAM_L2_cache/L2_cache/status_r
add wave -noupdate -divider pipeline
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1_ready
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_valid
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1i_addr
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_addr_r
add wave -noupdate -divider blk
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_match_way_idx
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s2o_blk_dout_b
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_addr_b}
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_din_b}
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_en_b}
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_addr_a}
add wave -noupdate -expand /tb_pb_fb_DRAM_L2_cache/L2_cache/s2o_blk_dout_b
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_din_a}
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_en_a}
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk4[0]/s2i_blk_we_a}
add wave -noupdate -divider tag
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/cls_cnt
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1_cke
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/pipe_en
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1i_entry_idx
add wave -noupdate {/tb_pb_fb_DRAM_L2_cache/L2_cache/genblk1[0]/entry_idx}
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_tag_lru
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_tag_dirty
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_tag_v
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s1o_entry_idx
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s2_cke
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s2i_tag_lru
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s2i_tag_dirty
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/s2i_tag_v
add wave -noupdate -divider sdr
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/line_adr_cnt
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/L2_cache/line_adr_cnt_msb_sr
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_clk
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_cmd_addr
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_cmd_bst_rd_ack
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_cmd_bst_rd_req
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_cmd_bst_we_ack
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_cmd_bst_we_req
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_din
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_dout
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_r_vld
add wave -noupdate /tb_pb_fb_DRAM_L2_cache/sdr_w_rdy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {333382887 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 178
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
WaveRestoreZoom {333160094 ps} {333652406 ps}
