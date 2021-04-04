onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/clk
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rst_n
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/fu_commit_BDATA
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/fu_commit_BREADY
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/fu_commit_BTAG
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/fu_commit_BVALID
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/fu_commit_id
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rob_commit_BDATA
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rob_commit_BREADY
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rob_commit_BTAG
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rob_commit_BVALID
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/rob_commit_id
add wave -noupdate -divider internal
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/grant
add wave -noupdate /tb_byp_arbiter/CDB_ARBITER/id
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {0 ps} 0}
quietly wave cursor active 0
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
WaveRestoreZoom {0 ps} {1 ns}
