onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_issue_queue/clk
add wave -noupdate /tb_issue_queue/rst_n
add wave -noupdate -divider BYP
add wave -noupdate /tb_issue_queue/byp_BDATA
add wave -noupdate /tb_issue_queue/byp_BVALID
add wave -noupdate /tb_issue_queue/byp_rd_addr
add wave -noupdate /tb_issue_queue/byp_rd_we
add wave -noupdate -divider misc
add wave -noupdate {/tb_issue_queue/ISSUE_QUEUE/gen_write[0]/rs1_r_bypass_rdy}
add wave -noupdate {/tb_issue_queue/ISSUE_QUEUE/gen_write[0]/rs2_r_bypass_rdy}
add wave -noupdate -expand /tb_issue_queue/ISSUE_QUEUE/que_v_r
add wave -noupdate -radix hexadecimal -childformat {{{/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[3]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[2]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[1]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[0]} -radix hexadecimal}} -subitemconfig {{/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[3]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[2]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[1]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs1_r[0]} {-height 15 -radix hexadecimal}} /tb_issue_queue/ISSUE_QUEUE/que_rs1_r
add wave -noupdate /tb_issue_queue/ISSUE_QUEUE/que_rs1_rdy_r
add wave -noupdate -radix hexadecimal -childformat {{{/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[3]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[2]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[1]} -radix hexadecimal} {{/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[0]} -radix hexadecimal}} -subitemconfig {{/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[3]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[2]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[1]} {-height 15 -radix hexadecimal} {/tb_issue_queue/ISSUE_QUEUE/que_rs2_r[0]} {-height 15 -radix hexadecimal}} /tb_issue_queue/ISSUE_QUEUE/que_rs2_r
add wave -noupdate /tb_issue_queue/ISSUE_QUEUE/que_rs2_rdy_r
add wave -noupdate -divider FU
add wave -noupdate /tb_issue_queue/fu_ready
add wave -noupdate /tb_issue_queue/fu_valid
add wave -noupdate -radix hexadecimal /tb_issue_queue/fu_rs1_dat
add wave -noupdate -radix hexadecimal -childformat {{{/tb_issue_queue/fu_rs2_dat[31]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[30]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[29]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[28]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[27]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[26]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[25]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[24]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[23]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[22]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[21]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[20]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[19]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[18]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[17]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[16]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[15]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[14]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[13]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[12]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[11]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[10]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[9]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[8]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[7]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[6]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[5]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[4]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[3]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[2]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[1]} -radix hexadecimal} {{/tb_issue_queue/fu_rs2_dat[0]} -radix hexadecimal}} -subitemconfig {{/tb_issue_queue/fu_rs2_dat[31]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[30]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[29]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[28]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[27]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[26]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[25]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[24]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[23]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[22]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[21]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[20]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[19]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[18]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[17]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[16]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[15]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[14]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[13]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[12]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[11]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[10]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[9]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[8]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[7]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[6]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[5]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[4]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[3]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[2]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[1]} {-height 15 -radix hexadecimal} {/tb_issue_queue/fu_rs2_dat[0]} {-height 15 -radix hexadecimal}} /tb_issue_queue/fu_rs2_dat
add wave -noupdate /tb_issue_queue/fu_uop
add wave -noupdate -divider ISSUE
add wave -noupdate /tb_issue_queue/issue_ready
add wave -noupdate /tb_issue_queue/issue_valid
add wave -noupdate /tb_issue_queue/rs1_addr
add wave -noupdate /tb_issue_queue/rs1_dat
add wave -noupdate /tb_issue_queue/rs1_rdy
add wave -noupdate /tb_issue_queue/rs2_addr
add wave -noupdate /tb_issue_queue/rs2_dat
add wave -noupdate /tb_issue_queue/rs2_rdy
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {145825 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 169
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
WaveRestoreZoom {23863 ps} {522551 ps}
