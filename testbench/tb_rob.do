onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_rob/ROB/clk
add wave -noupdate /tb_rob/ROB/flush
add wave -noupdate -divider wb
add wave -noupdate /tb_rob/ROB/o_wb_BREADY
add wave -noupdate /tb_rob/ROB/i_wb_BVALID
add wave -noupdate /tb_rob/ROB/i_wb_BDATA
add wave -noupdate /tb_rob/ROB/i_wb_id
add wave -noupdate -divider issue
add wave -noupdate /tb_rob/ROB/o_disp_AREADY
add wave -noupdate /tb_rob/ROB/i_disp_AVALID
add wave -noupdate /tb_rob/ROB/i_disp_rd_addr
add wave -noupdate /tb_rob/ROB/i_disp_rd_we
add wave -noupdate /tb_rob/ROB/i_disp_rs1_addr
add wave -noupdate /tb_rob/ROB/i_disp_rs2_addr
add wave -noupdate /tb_rob/ROB/o_disp_id
add wave -noupdate /tb_rob/ROB/o_disp_rs1_from_ROB
add wave -noupdate /tb_rob/ROB/o_disp_rs1_dat
add wave -noupdate /tb_rob/ROB/o_disp_rs2_from_ROB
add wave -noupdate /tb_rob/ROB/o_disp_rs2_dat
add wave -noupdate /tb_rob/ROB/o_disp_rs1_in_ARF
add wave -noupdate /tb_rob/ROB/o_disp_rs2_in_ARF
add wave -noupdate -divider debug
add wave -noupdate -expand /tb_rob/ROB/rs1_ROB_match
add wave -noupdate /tb_rob/ROB/rs1_prec_bypass
add wave -noupdate /tb_rob/ROB/rs2_prec_bypass
add wave -noupdate /tb_rob/ROB/rs1_prec_ready
add wave -noupdate -expand /tb_rob/ROB/rs2_prec_ready
add wave -noupdate -divider commit
add wave -noupdate /tb_rob/ROB/i_commit_BREADY
add wave -noupdate /tb_rob/ROB/o_commit_BVALID
add wave -noupdate /tb_rob/ROB/o_commit_BDATA
add wave -noupdate /tb_rob/ROB/o_commit_BTAG
add wave -noupdate /tb_rob/ROB/o_commit_rd_addr
add wave -noupdate /tb_rob/ROB/o_commit_rd_we
add wave -noupdate -divider DFFs
add wave -noupdate -radix hexadecimal -childformat {{{/tb_rob/ROB/que_valid_r[3]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[2]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[1]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb_rob/ROB/que_valid_r[3]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[2]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[1]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[0]} {-height 15 -radix hexadecimal}} /tb_rob/ROB/que_valid_r
add wave -noupdate -radix hexadecimal /tb_rob/ROB/que_rd_addr_r
add wave -noupdate -expand /tb_rob/ROB/que_rd_ready_r
add wave -noupdate -radix hexadecimal -childformat {{{/tb_rob/ROB/que_rd_we_r[3]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[2]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[1]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb_rob/ROB/que_rd_we_r[3]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[2]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[1]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[0]} {-height 15 -radix hexadecimal}} /tb_rob/ROB/que_rd_we_r
add wave -noupdate /tb_rob/ROB/que_tag_r
add wave -noupdate -radix hexadecimal -childformat {{{/tb_rob/ROB/que_dat_r[3]} -radix hexadecimal} {{/tb_rob/ROB/que_dat_r[2]} -radix hexadecimal} {{/tb_rob/ROB/que_dat_r[1]} -radix hexadecimal} {{/tb_rob/ROB/que_dat_r[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb_rob/ROB/que_dat_r[3]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_dat_r[2]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_dat_r[1]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_dat_r[0]} {-height 15 -radix hexadecimal}} /tb_rob/ROB/que_dat_r
add wave -noupdate -divider controls
add wave -noupdate /tb_rob/ROB/rob_empty
add wave -noupdate /tb_rob/ROB/rob_full
add wave -noupdate /tb_rob/ROB/rst_n
add wave -noupdate /tb_rob/ROB/w_ptr_nxt
add wave -noupdate /tb_rob/ROB/w_ptr_r
add wave -noupdate -radix hexadecimal /tb_rob/ROB/r_ptr_r
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {887097 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 150
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
WaveRestoreZoom {423600 ps} {935600 ps}
