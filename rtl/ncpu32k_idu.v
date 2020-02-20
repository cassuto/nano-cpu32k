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
   output                     ifu_jmprel,
   output [`NCPU_AW-3:0]      ifu_jmprel_offset,
   output                     regf_rs1_re,
   output [`NCPU_REG_AW-1:0]  regf_rs1_addr,
   input [`NCPU_DW-1:0]       regf_rs1_dout,
   input                      regf_rs1_dout_valid,
   output                     regf_rs2_re,
   output [`NCPU_REG_AW-1:0]  regf_rs2_addr,
   input [`NCPU_DW-1:0]       regf_rs2_dout,
   input                      regf_rs2_dout_valid,
   input                      msr_psr_cc,
   input                      ieu_in_ready, /* ieu is ready to accepted ops  */
   output                     ieu_in_valid, /* ops is presented at ieu's input */
   output [`NCPU_DW-1:0]      ieu_operand_1,
   output [`NCPU_DW-1:0]      ieu_operand_2,
   output [`NCPU_DW-1:0]      ieu_operand_3,
   output [`NCPU_LU_IOPW-1:0] ieu_lu_opc_bus,
   output [`NCPU_AU_IOPW-1:0] ieu_au_opc_bus,
   output [`NCPU_EU_IOPW-1:0] ieu_eu_opc_bus,
   output                     ieu_emu_insn,
   output                     ieu_mu_load,
   output                     ieu_mu_store,
   output                     ieu_mu_barr,
   output [2:0]               ieu_mu_store_size,
   output [2:0]               ieu_mu_load_size,
   output                     ieu_wb_regf,
   output [`NCPU_REG_AW-1:0]  ieu_wb_reg_addr,
   output                     ieu_jmpreg,
   output [`NCPU_AW-3:0]      ieu_insn_pc,
   output                     ieu_jmplink
);

   wire [5:0] f_opcode = idu_insn[5:0];
   wire [4:0] f_rd = idu_insn[10:6];
   wire [4:0] f_rs1 = idu_insn[15:11];
   wire [4:0] f_rs2 = idu_insn[20:16];
   wire [10:0] f_attr = idu_insn[31:21];
   wire [15:0] f_imm16 = idu_insn[31:16];
   wire [20:0] f_rel21 = idu_insn[31:11];
   
   // VIRT insns
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
   wire op_barr = (f_opcode == `NCPU_OP_BARR);
   
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
   
   wire op_jmp = (f_opcode == `NCPU_OP_JMP);
   wire op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   wire op_bt = (f_opcode == `NCPU_OP_BT);
   wire op_bf = (f_opcode == `NCPU_OP_BF);
   wire op_raise = (f_opcode == `NCPU_OP_RAISE);
   wire op_ret = (f_opcode == `NCPU_OP_RET);
   
   wire op_wsmr = (f_opcode == `NCPU_OP_WSMR);
   wire op_rsmr = (f_opcode == `NCPU_OP_RSMR);
   
   
   wire [`NCPU_LU_IOPW-1:0] lu_opc_bus;
   wire [`NCPU_AU_IOPW-1:0] au_opc_bus;
   wire [`NCPU_EU_IOPW-1:0] eu_opc_bus;
   
   //
   // Target Size of Memory Access.
   // 0 = None operation
   // 1 = 8bit
   // 2 = 16bit
   // 3 = 32 bit
   // 4 = 64bit
   wire [2:0] mu_store_size = op_stb ? 3'd1 : op_sth ? 3'd2 : op_stw ? 3'd3 : 3'd0;
   wire [2:0] mu_load_size = (op_ldb|op_ldbu) ? 3'd1 : (op_ldh|op_ldhu) ? 3'd2 : (op_ldwu) ? 3'd3 : 3'd0;
   
   wire op_mu_load = |mu_load_size;
   wire op_mu_store = |mu_store_size;
   wire op_mu_barr = (f_opcode == `NCPU_OP_BARR);
   
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
   
   assign eu_opc_bus[`NCPU_EU_WSMR] = (op_wsmr);
   assign eu_opc_bus[`NCPU_EU_RSMR] = (op_rsmr);

   wire bu_sel = (op_jmp|op_jmp_i|op_bt|op_bf);
   
   // Insn is to be emulated
   wire emu_insn = ~((|lu_opc_bus) | (|au_opc_bus) | bu_sel | (|eu_opc_bus) | op_mu_load | op_mu_store | op_mu_barr);
   
   // Insn presents rs1 and imm as operand.
   // Note that load and store insn are special cases 
   wire insn_imm = (op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
                     op_add_i |
                     op_mu_load | op_mu_store |
                     op_wsmr | op_rsmr);
   // Insn requires Signed imm.
   wire imm_signed = (op_xor_i | op_and_i | op_add_i | op_mu_load | op_mu_store);
   // Insn presents no operand.
   wire insn_non_op = (op_barr | op_raise | op_ret | op_jmp_i | op_bt | op_bf);
   
   // Insn writeback register file
   wire wb_regf = ~(op_barr | op_bt|op_bf | op_cmp | emu_insn);
   wire [`NCPU_REG_AW-1:0] wb_reg_addr = f_rd;
   
   // PC-Relative address (sign-extended)
   wire [`NCPU_AW-3:0] rel21 = {{`NCPU_AW-23{f_rel21[20]}}, f_rel21[20:0]};
   // PC-Relative jump
   wire bcc = (op_bt | op_bf) & (msr_psr_cc);
   assign ifu_jmprel = op_jmp_i | bcc;
   assign ifu_jmprel_offset = rel21;
   // Register-Indirect jump
   wire jmp_reg = (op_jmp);
   // Link address ?
   wire jmp_link = (op_jmp | op_jmp_i);
   
   // Request operand(s) from Regfile when needed
   assign regf_rs1_re = (~insn_non_op);
   assign regf_rs1_addr = f_rs1;
   assign regf_rs2_re = (~insn_imm & ~insn_non_op) | (op_mu_load|op_mu_store);
   assign regf_rs2_addr = op_mu_store ? f_rd : f_rs2;
   
   // Pipeline
   wire pipebuf_cas;
   wire                  imm_signed_r;
   wire [15:0]           imm16_r;

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
   
   ncpu32k_cell_dff_lr #(1) dff_imm_signed_r
                   (clk,rst_n, pipebuf_cas, imm_signed, imm_signed_r);
   ncpu32k_cell_dff_lr #(16) dff_imm16_r
                   (clk,rst_n, pipebuf_cas, f_imm16[15:0], imm16_r[15:0]);

   // Sign-extended Integer
   wire [`NCPU_DW-1:0] simm16_r = {{`NCPU_DW-16{imm16_r[15]}}, imm16_r[15:0]};
   // Zero-extended Integer
   wire [`NCPU_DW-1:0] uimm16_r = {{`NCPU_DW-16{1'b0}}, imm16_r[15:0]};
   // Immediate Operand
   wire [`NCPU_DW-1:0] imm_oper_r = (imm_signed_r ? simm16_r : uimm16_r);
   
   // Final Operands
   assign ieu_operand_1 = regf_rs1_dout_valid
                           ? regf_rs1_dout
                           : imm_oper_r;
   assign ieu_operand_2 = regf_rs2_dout_valid & (~insn_imm & ~insn_non_op)
                           ? regf_rs2_dout
                           : imm_oper_r;
   assign ieu_operand_3 = (op_mu_store ? regf_rs2_dout : {`NCPU_DW{1'b0}});

   ncpu32k_cell_dff_lr #(`NCPU_LU_IOPW) dff_ieu_lu_opc_bus
                   (clk,rst_n, pipebuf_cas, lu_opc_bus[`NCPU_LU_IOPW-1:0], ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AU_IOPW) dff_ieu_au_opc_bus
                   (clk,rst_n, pipebuf_cas, au_opc_bus[`NCPU_AU_IOPW-1:0], ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_EU_IOPW) dff_ieu_eu_opc_bus
                   (clk,rst_n, pipebuf_cas, eu_opc_bus[`NCPU_EU_IOPW-1:0], ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]);

   ncpu32k_cell_dff_lr #(1) dff_ieu_emu_insn
                   (clk,rst_n, pipebuf_cas, emu_insn, ieu_emu_insn);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_load
                   (clk,rst_n, pipebuf_cas, op_mu_load, ieu_mu_load);
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_store
                   (clk,rst_n, pipebuf_cas, op_mu_store, ieu_mu_store);
   ncpu32k_cell_dff_lr #(1) dff_ieu_mu_barr
                   (clk,rst_n, pipebuf_cas, op_mu_barr, ieu_mu_barr);
   ncpu32k_cell_dff_lr #(3) dff_ieu_mu_store_size
                   (clk,rst_n, pipebuf_cas, mu_store_size[2:0], ieu_mu_store_size[2:0]);
   ncpu32k_cell_dff_lr #(3) dff_ieu_mu_load_size
                   (clk,rst_n, pipebuf_cas, mu_load_size[2:0], ieu_mu_load_size[2:0]);
                   
   ncpu32k_cell_dff_lr #(1) dff_ieu_wb_regf
                   (clk,rst_n, pipebuf_cas, wb_regf, ieu_wb_regf);
   ncpu32k_cell_dff_lr #(`NCPU_REG_AW) dff_ieu_wb_reg_addr
                   (clk,rst_n, pipebuf_cas, wb_reg_addr, ieu_wb_reg_addr);

   ncpu32k_cell_dff_lr #(1) dff_ieu_jmp_reg
                   (clk,rst_n, pipebuf_cas, jmp_reg, ieu_jmpreg);
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_ieu_insn_pc
               (clk, rst_n, pipebuf_cas, idu_insn_pc[`NCPU_AW-3:0], ieu_insn_pc[`NCPU_AW-3:0]);
   ncpu32k_cell_dff_lr #(1) dff_ieu_jmp_link
                   (clk,rst_n, pipebuf_cas, jmp_link, ieu_jmplink);

endmodule
