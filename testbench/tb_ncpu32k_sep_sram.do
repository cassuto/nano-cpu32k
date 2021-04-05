onerror {resume}
quietly WaveActivateNextPane {} 0
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/clk
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/rst_n
add wave -noupdate -divider ibus
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_AREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_AVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_AADDR
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_AEXC
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_BREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_BVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_BDATA
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_ibus_BEXC
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/fb_irqs
add wave -noupdate -divider IFU
add wave -noupdate -divider IDU
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/flush
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_AREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_AVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_exc
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_insn
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_pc
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/IDU/idu_pred_tgt
add wave -noupdate -divider DISP
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_AREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_AVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_barr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_load
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_load_size
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_sign_ext
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_store
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_agu_store_size
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_alu_opc_bus
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_epu_opc_bus
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_imm32
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_lpu_opc_bus
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_pc
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_pred_tgt
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rd_addr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rd_we
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rel15
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rs1_addr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rs1_re
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rs2_addr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/DISP/disp_rs2_re
add wave -noupdate -divider ALU
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_AID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_AREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_AVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_opc_bus
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_operand_1
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_operand_2
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_rel15
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_uop
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ALU/alu_uop_opc
add wave -noupdate -divider {WB ALU}
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BBRANCH_OP
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BBRANCH_REG_TAKEN
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BBRANCH_REL_TAKEN
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BDATA
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_BVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_exc
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/wb_alu_tag
add wave -noupdate -divider wb
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_wb_BDATA
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_wb_BREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_wb_BTAG
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_wb_BVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_wb_id
add wave -noupdate -divider COMMIT
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_BDATA
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_BREADY
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_BTAG
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_BVALID
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_pc
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_pred_tgt
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_ptr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_rd_addr
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/WB_COMMIT/rob_commit_rd_we
add wave -noupdate -divider ARF
add wave -noupdate /tb_ncpu32k_sep_sram/ncpu32k/CORE/ARF/dpram_sclk0/mem_vector
TreeUpdate [SetDefaultTree]
WaveRestoreCursors {{Cursor 1} {95619 ps} 0}
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
WaveRestoreZoom {0 ps} {512 ns}
