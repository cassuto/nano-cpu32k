onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/clk
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_issue_AVALID
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/o_issue_AREADY
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs1_addr
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs1_dat
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs1_rdy
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs2_addr
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs2_dat
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_rs2_rdy
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_uop
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/o_fu_uop
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/i_fu_AREADY
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/o_fu_AVALID
add wave -noupdate -divider internal
add wave -noupdate /tb_issue_queue_FIFO/ISSUE_QUEUE/free
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {98323 ps} 0}
quietly wave cursor active 1
configure wave -namecolwidth 159
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
WaveRestoreZoom {0 ps} {505856 ps}
