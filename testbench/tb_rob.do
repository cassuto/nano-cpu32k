onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_rob/ROB/clk
add wave -noupdate /tb_rob/ROB/flush
add wave -noupdate -divider byp
add wave -noupdate /tb_rob/ROB/byp_rd_addr
add wave -noupdate /tb_rob/ROB/byp_rd_we
add wave -noupdate -divider wb
add wave -noupdate /tb_rob/ROB/rob_wb_BDATA
add wave -noupdate /tb_rob/ROB/rob_wb_BREADY
add wave -noupdate /tb_rob/ROB/rob_wb_BTAG
add wave -noupdate /tb_rob/ROB/rob_wb_BVALID
add wave -noupdate /tb_rob/ROB/rob_wb_id
add wave -noupdate -divider dispatch
add wave -noupdate /tb_rob/ROB/rob_disp_AREADY
add wave -noupdate /tb_rob/ROB/rob_disp_AVALID
add wave -noupdate /tb_rob/ROB/rob_disp_id
add wave -noupdate /tb_rob/ROB/rob_disp_pc
add wave -noupdate /tb_rob/ROB/rob_disp_pred_tgt
add wave -noupdate /tb_rob/ROB/rob_disp_rd_addr
add wave -noupdate /tb_rob/ROB/rob_disp_rd_we
add wave -noupdate /tb_rob/ROB/rob_disp_rs1_addr
add wave -noupdate /tb_rob/ROB/rob_disp_rs1_dat
add wave -noupdate /tb_rob/ROB/rob_disp_rs1_in_ARF
add wave -noupdate /tb_rob/ROB/rob_disp_rs1_in_ROB
add wave -noupdate /tb_rob/ROB/rob_disp_rs2_addr
add wave -noupdate /tb_rob/ROB/rob_disp_rs2_dat
add wave -noupdate /tb_rob/ROB/rob_disp_rs2_in_ARF
add wave -noupdate /tb_rob/ROB/rob_disp_rs2_in_ROB
add wave -noupdate -divider debug
add wave -noupdate /tb_rob/ROB/rs1_ROB_match
add wave -noupdate /tb_rob/ROB/rs1_first_match
add wave -noupdate /tb_rob/ROB/rs2_first_match
add wave -noupdate /tb_rob/ROB/rs1_prec_bypass
add wave -noupdate /tb_rob/ROB/rs2_prec_bypass
add wave -noupdate /tb_rob/ROB/rs1_prec_ready
add wave -noupdate /tb_rob/ROB/rs2_prec_ready
add wave -noupdate /tb_rob/ROB/rob_wb_id
add wave -noupdate /tb_rob/ROB/payload_wb_din
add wave -noupdate /tb_rob/ROB/payload_wb_id
add wave -noupdate /tb_rob/ROB/payload_wb_dout
add wave -noupdate -divider commit
add wave -noupdate /tb_rob/ROB/rob_commit_BDATA
add wave -noupdate /tb_rob/ROB/rob_commit_BREADY
add wave -noupdate /tb_rob/ROB/rob_commit_BTAG
add wave -noupdate /tb_rob/ROB/rob_commit_BVALID
add wave -noupdate /tb_rob/ROB/rob_commit_pc
add wave -noupdate /tb_rob/ROB/rob_commit_pred_tgt
add wave -noupdate /tb_rob/ROB/rob_commit_ptr
add wave -noupdate /tb_rob/ROB/rob_commit_rd_addr
add wave -noupdate /tb_rob/ROB/rob_commit_rd_we
add wave -noupdate -divider DFFs
add wave -noupdate -radix hexadecimal -childformat {{{/tb_rob/ROB/que_valid_r[3]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[2]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[1]} -radix hexadecimal} {{/tb_rob/ROB/que_valid_r[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb_rob/ROB/que_valid_r[3]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[2]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[1]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_valid_r[0]} {-height 15 -radix hexadecimal}} /tb_rob/ROB/que_valid_r
add wave -noupdate -radix hexadecimal /tb_rob/ROB/que_rd_addr_r
add wave -noupdate -expand /tb_rob/ROB/que_rd_ready_r
add wave -noupdate -radix hexadecimal -childformat {{{/tb_rob/ROB/que_rd_we_r[3]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[2]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[1]} -radix hexadecimal} {{/tb_rob/ROB/que_rd_we_r[0]} -radix hexadecimal}} -expand -subitemconfig {{/tb_rob/ROB/que_rd_we_r[3]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[2]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[1]} {-height 15 -radix hexadecimal} {/tb_rob/ROB/que_rd_we_r[0]} {-height 15 -radix hexadecimal}} /tb_rob/ROB/que_rd_we_r
add wave -noupdate -divider controls
add wave -noupdate /tb_rob/ROB/rob_empty
add wave -noupdate /tb_rob/ROB/rob_full
add wave -noupdate /tb_rob/ROB/rst_n
add wave -noupdate /tb_rob/ROB/w_ptr_nxt
add wave -noupdate /tb_rob/ROB/w_ptr_r
add wave -noupdate -radix hexadecimal /tb_rob/ROB/r_ptr_r
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {82056 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 166
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
WaveRestoreZoom {0 ps} {501150 ps}
