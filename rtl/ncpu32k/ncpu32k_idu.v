/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module ncpu32k_idu(         
   input                      clk,
   input                      rst_n,
   output                     idu_in_ready, /* idu is ready to accepted Insn */
   input                      idu_in_valid, /* Insn is prestented at idu's input */
   input [`NCPU_IW-1:0]       idu_insn,
   output [`NCPU_AW-3:0]      idu_insn_pc,
   input                      idu_op_jmprel,
   input                      idu_op_jmpfar,
   input                      idu_op_syscall,
   input                      idu_op_ret,
   input                      idu_jmprel_link,
   input                      idu_specul_jmpfar,
   input [`NCPU_AW-3:0]       idu_specul_tgt,
   input                      idu_specul_jmprel,
   input                      idu_specul_bcc,
   input                      idu_specul_extexp,
   input                      idu_let_lsa_pc,
   input                      specul_flush,
   output                     regf_rs1_re,
   output [`NCPU_REG_AW-1:0]  regf_rs1_addr,
   input [`NCPU_DW-1:0]       regf_rs1_dout,
   output                     regf_rs2_re,
   output [`NCPU_REG_AW-1:0]  regf_rs2_addr,
   input [`NCPU_DW-1:0]       regf_rs2_dout,
   output                     ifu_jmpfar,
   output [`NCPU_AW-3:0]      ifu_jmpfar_addr,
   input                      ieu_in_ready, /* ieu is ready to accepted ops  */
   output                     ieu_in_valid, /* ops is presented at ieu's input */
   output [`NCPU_DW-1:0]      ieu_operand_1,
   output [`NCPU_DW-1:0]      ieu_operand_2,
   output [`NCPU_DW-1:0]      ieu_operand_3,
   output [`NCPU_LU_IOPW-1:0] ieu_lu_opc_bus,
   output [`NCPU_AU_IOPW-1:0] ieu_au_opc_bus,
   output                     ieu_au_cmp_eq,/* otherwise gt */
   output                     ieu_au_cmp_signed,
   output [`NCPU_EU_IOPW-1:0] ieu_eu_opc_bus,
   output                     ieu_emu_insn,
   output                     ieu_mu_load,
   output                     ieu_mu_store,
   output                     ieu_mu_sign_ext,
   output                     ieu_mu_barr,
   output [2:0]               ieu_mu_store_size,
   output [2:0]               ieu_mu_load_size,
   output                     ieu_wb_regf,
   output [`NCPU_REG_AW-1:0]  ieu_wb_reg_addr,
   output [`NCPU_AW-3:0]      ieu_insn_pc,
   output                     ieu_jmplink,
   output                     ieu_syscall,
   output                     ieu_ret,
   output                     ieu_specul_jmpfar,
   output [`NCPU_AW-3:0]      ieu_specul_tgt,
   output                     ieu_specul_jmprel,
   output                     ieu_specul_bcc,
   output                     ieu_specul_extexp,
   output                     ieu_let_lsa_pc
);

   wire [5:0] f_opcode = idu_insn[5:0];
   wire [5:0] f_rd = idu_insn[11:6];
   wire [5:0] f_rs1 = idu_insn[17:12];
   wire [5:0] f_rs2 = idu_insn[23:18];
   wire [7:0] f_attr = idu_insn[31:24];
   wire [13:0] f_imm14 = idu_insn[31:18];
   wire [17:0] f_imm18 = idu_insn[29:12];
   wire [20:0] f_rel26 = idu_insn[31:6];
   
   // VIRT insns
   // Please Reserve `ifdef...`else...`endif block for runtime switching
   // to be implemented in future.
`ifdef ENABLE_ASR
   wire enable_asr = 1'b1;
   wire enable_asr_i = 1'b1;
`else
   wire enable_asr = 1'b0;
   wire enable_asr_i = 1'b0;
`endif
`ifdef ENABLE_ADD
   wire enable_add = 1'b1;
   wire enable_add_i = 1'b1;
`else
   wire enable_add = 1'b0;
   wire enable_add_i = 1'b0;
`endif
`ifdef ENABLE_SUB
   wire enable_sub = 1'b1;
`else
   wire enable_sub = 1'b0;
`endif
`ifdef ENABLE_MUL
   wire enable_mul = 1'b1;
`else
   wire enable_mul = 1'b0;
`endif
`ifdef ENABLE_DIV
   wire enable_div = 1'b1;
`else
   wire enable_div = 1'b0;
`endif
`ifdef ENABLE_DIVU
   wire enable_divu = 1'b1;
`else
   wire enable_divu = 1'b0;
`endif
`ifdef ENABLE_MOD
   wire enable_mod = 1'b1;
`else
   wire enable_mod = 1'b0;
`endif
`ifdef ENABLE_MODU
   wire enable_modu = 1'b1;
`else
   wire enable_modu = 1'b0;
`endif
`ifdef ENABLE_LDB
   wire enable_ldb = 1'b1;
`else
   wire enable_ldb = 1'b0;
`endif
`ifdef ENABLE_LDBU
   wire enable_ldbu = 1'b1;
`else
   wire enable_ldbu = 1'b0;
`endif
`ifdef ENABLE_LDH
   wire enable_ldh = 1'b1;
`else
   wire enable_ldh = 1'b0;
`endif
`ifdef ENABLE_LDHU
   wire enable_ldhu = 1'b1;
`else
   wire enable_ldhu = 1'b0;
`endif
`ifdef ENABLE_STB
   wire enable_stb = 1'b1;
`else
   wire enable_stb = 1'b0;
`endif
`ifdef ENABLE_STH
   wire enable_sth = 1'b1;
`else
   wire enable_sth = 1'b0;
`endif
`ifdef ENABLE_MHI
   wire enable_mhi = 1'b1;
`else
   wire enable_mhi = 1'b0;
`endif
   
   wire op_ldb = (f_opcode == `NCPU_OP_LDB) & enable_ldb;
   wire op_ldbu = (f_opcode == `NCPU_OP_LDBU) & enable_ldbu;
   wire op_ldh = (f_opcode == `NCPU_OP_LDH) & enable_ldh;
   wire op_ldhu = (f_opcode == `NCPU_OP_LDHU) & enable_ldhu;
   wire op_ldwu = (f_opcode == `NCPU_OP_LDWU);
   wire op_stb = (f_opcode == `NCPU_OP_STB) & enable_stb;
   wire op_sth = (f_opcode == `NCPU_OP_STH) & enable_sth;
   wire op_stw = (f_opcode == `NCPU_OP_STW);
   
   wire op_and = (f_opcode == `NCPU_OP_AND);
   wire op_and_i = (f_opcode == `NCPU_OP_AND_I);
   wire op_or = (f_opcode == `NCPU_OP_OR);
   wire op_or_i = (f_opcode == `NCPU_OP_OR_I);
   wire op_xor = (f_opcode == `NCPU_OP_XOR);
   wire op_xor_i = (f_opcode == `NCPU_OP_XOR_I);
   wire op_lsl = (f_opcode == `NCPU_OP_LSL);
   wire op_lsl_i = (f_opcode == `NCPU_OP_LSL_I);
   wire op_lsr = (f_opcode == `NCPU_OP_LSR);
   wire op_lsr_i = (f_opcode == `NCPU_OP_LSR_I);
   wire op_asr = (f_opcode == `NCPU_OP_ASR) & enable_asr;
   wire op_asr_i = (f_opcode == `NCPU_OP_ASR_I) & enable_asr_i;
   
   wire op_cmp = (f_opcode == `NCPU_OP_CMP);
   wire op_add = (f_opcode == `NCPU_OP_ADD) & enable_add;
   wire op_add_i = (f_opcode == `NCPU_OP_ADD_I);
   wire op_sub = (f_opcode == `NCPU_OP_SUB) & enable_sub;
   wire op_mul = (f_opcode == `NCPU_OP_MUL) & enable_mul;
   wire op_div = (f_opcode == `NCPU_OP_DIV) & enable_div;
   wire op_divu = (f_opcode == `NCPU_OP_DIVU) & enable_divu;
   wire op_mod = (f_opcode == `NCPU_OP_MOD) & enable_mod;
   wire op_modu = (f_opcode == `NCPU_OP_MODU) & enable_modu;
   wire op_mhi = (f_opcode == `NCPU_OP_MHI) & enable_mhi;
   
   wire op_wmsr = (f_opcode == `NCPU_OP_WMSR);
   wire op_rmsr = (f_opcode == `NCPU_OP_RMSR);
   
   wire au_cmp_eq;
   wire au_cmp_signed;
   wire [`NCPU_LU_IOPW-1:0] lu_opc_bus;
   wire [`NCPU_AU_IOPW-1:0] au_opc_bus;
   wire [`NCPU_EU_IOPW-1:0] eu_opc_bus;
   
   //
   // Target Size of Memory Access.
   // 0 = None operation
   // 1 = 8bit
   // 2 = 16bit
   // 3 = 32bit
   // 4 = 64bit
   wire [2:0] mu_store_size = op_stb ? 3'd1 : op_sth ? 3'd2 : op_stw ? 3'd3 : 3'd0;
   wire [2:0] mu_load_size = (op_ldb|op_ldbu) ? 3'd1 : (op_ldh|op_ldhu) ? 3'd2 : (op_ldwu) ? 3'd3 : 3'd0;
   
   assign mu_sign_ext = op_ldb | op_ldh;
   
   wire op_mu_load = |mu_load_size;
   wire op_mu_store = |mu_store_size;
   wire op_mu_barr = (f_opcode == `NCPU_OP_MBARR);
   
   assign lu_opc_bus[`NCPU_LU_AND] = (op_and | op_and_i);
   assign lu_opc_bus[`NCPU_LU_OR] = (op_or | op_or_i);
   assign lu_opc_bus[`NCPU_LU_XOR] = (op_xor | op_xor_i);
   assign lu_opc_bus[`NCPU_LU_LSL] = (op_lsl | op_lsl_i);
   assign lu_opc_bus[`NCPU_LU_LSR] = (op_lsr | op_lsr_i);
   assign lu_opc_bus[`NCPU_LU_ASR] = (op_asr | op_asr_i);
   
   assign au_opc_bus[`NCPU_AU_CMP] = (op_cmp);
   assign au_opc_bus[`NCPU_AU_ADD] = (op_add | op_add_i);
   assign au_opc_bus[`NCPU_AU_SUB] = (op_sub);
   assign au_opc_bus[`NCPU_AU_MUL] = (op_mul);
   assign au_opc_bus[`NCPU_AU_DIV] = (op_div);
   assign au_opc_bus[`NCPU_AU_DIVU] = (op_divu);
   assign au_opc_bus[`NCPU_AU_MOD] = (op_mod);
   assign au_opc_bus[`NCPU_AU_MODU] = (op_modu);
   assign au_opc_bus[`NCPU_AU_MHI] = (op_mhi);
   
   assign au_cmp_eq = op_cmp & f_attr==`NCPU_ATTR_EQ;
   assign au_cmp_signed = op_cmp & f_attr==`NCPU_ATTR_GT;
   
   assign eu_opc_bus[`NCPU_EU_WMSR] = (op_wmsr);
   assign eu_opc_bus[`NCPU_EU_RMSR] = (op_rmsr);

   // Insn is to be emulated
   // This must covers all known insns
   wire emu_insn = ~(
                     // OPC Bus opcodes
                     (|lu_opc_bus) | (|au_opc_bus) | (|eu_opc_bus) |
                     // Branch insns
                     idu_op_jmpfar|idu_op_jmprel |
                     // MU insns
                     op_mu_load | op_mu_store | op_mu_barr |
                     // Exception insns
                     idu_op_syscall | idu_op_ret);
   
   // Insn presents rs1 and imm as operand.
   wire insn_imm14 = (op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
                     op_add_i |
                     op_mu_load | op_mu_store |
                     op_wmsr | op_rmsr);
   wire insn_imm18 = op_mhi;
   wire insn_imm = insn_imm14 | insn_imm18;
   // Insn requires Signed imm.
   wire imm14_signed = (op_xor_i | op_and_i | op_add_i | op_mu_load | op_mu_store);
   // Insn presents no operand.
   wire insn_non_op = (op_mu_barr | idu_op_syscall | idu_op_ret | idu_op_jmprel);
   
   // Insn writeback register file
   wire wb_regf = ~(idu_op_syscall | idu_op_ret | op_mu_barr | idu_op_jmprel | op_cmp | emu_insn | op_mu_store | op_wmsr) | idu_jmprel_link;
   wire [`NCPU_REG_AW-1:0] wb_reg_addr = idu_jmprel_link ? `NCPU_REGNO_LNK : f_rd[4:0];
   
   // Register-Indirect jump
   wire jmp_reg = (idu_op_jmpfar);
   // Link address ?
   wire jmp_link = (idu_op_jmpfar | idu_jmprel_link);
   
   // Register-operand jmp
   assign ifu_jmpfar_addr = regf_rs1_dout[`NCPU_AW-1:2]; // no unalign check
   
   
   // Pipeline
   wire                 pipebuf_cas;
   wire [`NCPU_DW-1:0]  imm_oper_r;

   ncpu32k_cell_pipebuf #(1) pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (),
         .dout       (),
         .in_valid   (idu_in_valid),
         .in_ready   (idu_in_ready),
         .out_valid  (ieu_in_valid),
         .out_ready  (ieu_in_ready),
         .cas        (pipebuf_cas)
      );

   wire rs1_frm_regf_r;
   wire rs2_frm_regf_r;
   wire rs2_frm_regf_nxt = regf_rs2_re & (~insn_imm & ~insn_non_op); // op_mu_store and op_wmsr are special cases
   wire rd_readas_rs2_r;
   wire rd_readas_rs2_nxt;
   
   ncpu32k_cell_dff_lr #(1) dff_rs1_dout_valid_r
                   (clk,rst_n, pipebuf_cas, regf_rs1_re, rs1_frm_regf_r);
   ncpu32k_cell_dff_lr #(1) dff_rs2_dout_valid_r
                   (clk,rst_n, pipebuf_cas, rs2_frm_regf_nxt, rs2_frm_regf_r);
   ncpu32k_cell_dff_lr #(1) dff_rd_readas_rs2_r
                   (clk,rst_n, pipebuf_cas, rd_readas_rs2_nxt, rd_readas_rs2_r);
   
   // Request operand(s) from Regfile when needed
   // Note that op_mu_store and op_wmsr are special cases 
   assign rd_readas_rs2_nxt = op_mu_store | op_wmsr;
   assign regf_rs1_re = (~insn_non_op) & pipebuf_cas;
   assign regf_rs1_addr = f_rs1[4:0];
   assign regf_rs2_re = ((~insn_imm & ~insn_non_op) | rd_readas_rs2_nxt) & pipebuf_cas;
   assign regf_rs2_addr = rd_readas_rs2_nxt ? f_rd[4:0] : f_rs2[4:0];
   
   // Sign-extended 14bit Integer
   wire [`NCPU_DW-1:0] simm14 = {{`NCPU_DW-14{f_imm14[13]}}, f_imm14[13:0]};
   // Zero-extended 14bit Integer
   wire [`NCPU_DW-1:0] uimm14 = {{`NCPU_DW-14{1'b0}}, f_imm14[13:0]};
   // Zero-extended 18bit Integer
   wire [`NCPU_DW-1:0] uimm18 = {{`NCPU_DW-18{1'b0}}, f_imm18[17:0]};
   // Immediate Operand
   wire [`NCPU_DW-1:0] imm_oper_nxt = insn_imm14
                           ? (imm14_signed ? simm14 : uimm14)
                           : uimm18;

   ncpu32k_cell_dff_lr #(`NCPU_DW) dff_imm_oper_r
                   (clk,rst_n, pipebuf_cas, imm_oper_nxt, imm_oper_r);

   // Final Operands
   assign ieu_operand_1 = rs1_frm_regf_r ? regf_rs1_dout : imm_oper_r;
   assign ieu_operand_2 = rs2_frm_regf_r ? regf_rs2_dout : imm_oper_r;
   assign ieu_operand_3 = (rd_readas_rs2_r ? regf_rs2_dout : {`NCPU_DW{1'b0}});

   wire not_flushing = ~specul_flush;
   
   // Data path: no need to flush
   // Note: LU/AU/EU (single-clk-op) insns wouldn't be commited when flushing
   // although we not flush the opc_bus, as we flush wb_regf.
   ncpu32k_cell_dff_lr #(`NCPU_LU_IOPW) dff_ieu_lu_opc_bus
                   (clk,rst_n, pipebuf_cas, lu_opc_bus[`NCPU_LU_IOPW-1:0], ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AU_IOPW) dff_ieu_au_opc_bus
                   (clk,rst_n, pipebuf_cas, au_opc_bus[`NCPU_AU_IOPW-1:0], ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_EU_IOPW) dff_ieu_eu_opc_bus
                   (clk,rst_n, pipebuf_cas, eu_opc_bus[`NCPU_EU_IOPW-1:0], ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_au_cmp_eq
                   (clk,rst_n, pipebuf_cas, au_cmp_eq, ieu_au_cmp_eq);
   ncpu32k_cell_dff_lr #(1) dff_ieu_au_cmp_signed
                   (clk,rst_n, pipebuf_cas, au_cmp_signed, ieu_au_cmp_signed);
                   
   ncpu32k_cell_dff_lr #(3) dff_ieu_mu_store_size
                   (clk,rst_n, pipebuf_cas, mu_store_size[2:0], ieu_mu_store_size[2:0]);
   ncpu32k_cell_dff_lr #(3) dff_ieu_mu_load_size
                   (clk,rst_n, pipebuf_cas, mu_load_size[2:0], ieu_mu_load_size[2:0]);

   ncpu32k_cell_dff_lr #(`NCPU_REG_AW) dff_ieu_wb_reg_addr
                   (clk,rst_n, pipebuf_cas, wb_reg_addr[`NCPU_REG_AW-1:0], ieu_wb_reg_addr[`NCPU_REG_AW-1:0]);

   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_ieu_insn_pc
               (clk, rst_n, pipebuf_cas, idu_insn_pc[`NCPU_AW-3:0], ieu_insn_pc[`NCPU_AW-3:0]);
                   
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_ieu_specul_tgt
                   (clk,rst_n, pipebuf_cas, idu_specul_tgt[`NCPU_AW-3:0], ieu_specul_tgt[`NCPU_AW-3:0]);
                   
   // Control path
   ncpu32k_cell_dff_lr #(1) dff_ieu_emu_insn
                   (clk,rst_n, pipebuf_cas, emu_insn & not_flushing, ieu_emu_insn);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_load
                   (clk,rst_n, pipebuf_cas, op_mu_load & not_flushing, ieu_mu_load);
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_store
                   (clk,rst_n, pipebuf_cas, op_mu_store & not_flushing, ieu_mu_store);
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_barr
                   (clk,rst_n, pipebuf_cas, op_mu_barr & not_flushing, ieu_mu_barr);
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_sign_ext
                   (clk,rst_n, pipebuf_cas, mu_sign_ext & not_flushing, ieu_mu_sign_ext);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_wb_regf
                   (clk,rst_n, pipebuf_cas, wb_regf & not_flushing, ieu_wb_regf);
   
   ncpu32k_cell_dff_lr #(1) dff_ifu_jmpfar
                   (clk,rst_n, pipebuf_cas, jmp_reg & not_flushing, ifu_jmpfar);
           
   ncpu32k_cell_dff_lr #(1) dff_ieu_jmp_link
                   (clk,rst_n, pipebuf_cas, jmp_link & not_flushing, ieu_jmplink);
   ncpu32k_cell_dff_lr #(1) dff_ieu_syscall
                   (clk,rst_n, pipebuf_cas, idu_op_syscall & not_flushing, ieu_syscall);
   ncpu32k_cell_dff_lr #(1) dff_ieu_ret
                   (clk,rst_n, pipebuf_cas, idu_op_ret & not_flushing, ieu_ret);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_specul_jmpfar
                   (clk,rst_n, pipebuf_cas, idu_specul_jmpfar & not_flushing, ieu_specul_jmpfar);
   ncpu32k_cell_dff_lr #(1) dff_ieu_specul_jmprel
                   (clk,rst_n, pipebuf_cas, idu_specul_jmprel & not_flushing, ieu_specul_jmprel);

   ncpu32k_cell_dff_lr #(1) dff_ieu_specul_bcc
                   (clk,rst_n, pipebuf_cas, idu_specul_bcc & not_flushing, ieu_specul_bcc);
   ncpu32k_cell_dff_lr #(1) dff_ieu_specul_exp
                   (clk,rst_n, pipebuf_cas, idu_specul_extexp & not_flushing, ieu_specul_extexp);
   ncpu32k_cell_dff_lr #(1) dff_ieu_let_lsa_pc
                   (clk,rst_n, pipebuf_cas, idu_let_lsa_pc & not_flushing, ieu_let_lsa_pc);

endmodule
