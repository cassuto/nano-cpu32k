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

module ncpu32k_core(
   input                   clk_i,
   input                   rst_n_i,
   input [`NCPU_DW-1:0]    d_i,              // data
   input [`NCPU_IW-1:0]    insn_i,           // instruction
   input                   insn_ready_i,     // Insn bus is ready
   input                   dbus_rd_ready_i,  // Data bus Dout is ready
   input                   dbus_we_done_i,   // Data bus Writing is done
   output [`NCPU_DW-1:0]   d_o,	            // data
   output [`NCPU_AW-1:0]   addr_o,           // data address
   output                  dbus_rd_o,        // data bus ReadEnable
   output                  dbus_we_o,        // data bus WriteEnable
   output [`NCPU_AW-1:0]   iaddr_o,          // instruction address
   output                  ibus_rd_o         // instruction bus ReadEnable
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  rs1_o;                  // From regfile0 of ncpu32k_regfile.v
   wire                 rs1_valid_o;            // From regfile0 of ncpu32k_regfile.v
   wire [`NCPU_DW-1:0]  rs2_o;                  // From regfile0 of ncpu32k_regfile.v
   wire                 rs2_valid_o;            // From regfile0 of ncpu32k_regfile.v
   // End of automatics
   
   /////////////////////////////////////////////////////////////////////////////
   // Regfile
   /////////////////////////////////////////////////////////////////////////////
   
   wire [`NCPU_REG_AW-1:0] regf_rs1_addr_i;
   wire [`NCPU_REG_AW-1:0] regf_rs2_addr_i;
   wire                    regf_rs1_re_i;
   wire                    regf_rs2_re_i;
   wire [`NCPU_REG_AW-1:0] regf_rd_addr_i;
   wire [`NCPU_DW-1:0]     regf_rd_i;
   wire                    regf_rd_we_i;
   
   /* ncpu32k_regfile AUTO_TEMPLATE (
      ..*_i                             (regf_@"vl-name"[]),
      .clk_i                            (clk_i),
      .rst_n_i                          (rst_n_i),
   );*/
   
   ncpu32k_regfile regfile0
      (/*AUTOINST*/
       // Outputs
       .rs1_o                           (rs1_o[`NCPU_DW-1:0]),
       .rs2_o                           (rs2_o[`NCPU_DW-1:0]),
       .rs1_valid_o                     (rs1_valid_o),
       .rs2_valid_o                     (rs2_valid_o),
       // Inputs
       .clk_i                           (clk_i),                 // Templated
       .rst_n_i                         (rst_n_i),               // Templated
       .rs1_addr_i                      (regf_rs1_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rs2_addr_i                      (regf_rs2_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rs1_re_i                        (regf_rs1_re_i),         // Templated
       .rs2_re_i                        (regf_rs2_re_i),         // Templated
       .rd_addr_i                       (regf_rd_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rd_i                            (regf_rd_i[`NCPU_DW-1:0]), // Templated
       .rd_we_i                         (regf_rd_we_i));          // Templated
   
   // SMR.PSR.CC - Condition Control Register
   wire                 smr_psr_cc_i;
   wire                 smr_psr_cc;
   wire                 smr_psr_cc_w;
   wire                 smr_psr_cc_we;
   
   ncpu32k_cell_dff_lr #(1) dff_smr_psr_cc (clk_i, rst_n_i, smr_psr_cc_we, smr_psr_cc_i, smr_psr_cc_w);
   
   assign smr_psr_cc = (smr_psr_cc_we ? smr_psr_cc_i : smr_psr_cc_w);
   
   // Pipeline Dispatcher
   wire pipe1_flow;
   wire pipe2_flow;
   wire pipe3_flow;
   wire pipe1_ready;
   wire pipe2_ready;
   wire pipe3_ready;
   
   assign pipe3_flow = pipe3_ready;
   assign pipe2_flow = pipe3_flow & pipe2_ready;
   assign pipe1_flow = pipe2_flow & pipe1_ready;
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1: Fetch
   /////////////////////////////////////////////////////////////////////////////
   wire fetch_jmp;
   wire fetch_jmpfar;
   wire fetch_jmp_ready;
   wire [`NCPU_AW-3:0] fetch_jmp_offset;
   wire [`NCPU_AW-3:0] fetch_jmpfar_addr;
   
   wire [`NCPU_AW-3:0] pc_addr;
   wire [`NCPU_AW-3:0] pc_addr_nxt;
   
   // Program Counter Register
   ncpu32k_cell_dff_lr #(`NCPU_AW-2, (`NCPU_ERST_VECTOR>>2)-1'b1) dff_pc_addr
                   (clk_i, rst_n_i, 1'b1, pc_addr_nxt[`NCPU_AW-3:0], pc_addr[`NCPU_AW-3:0]);
   assign pc_addr_nxt = pipe1_flow ?
                   (fetch_jmpfar ? fetch_jmpfar_addr :
                    pc_addr + (fetch_jmp ? fetch_jmp_offset : 1'b1)) :
                    pc_addr;
   
   wire [`NCPU_IW-1:0] insn;
   // Insn Bus addressing
   assign iaddr_o = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
   // Insn Bus reading
   assign ibus_rd_o = 1'b1;
   assign insn = insn_i;
   
   assign pipe1_ready = insn_ready_i & fetch_jmp_ready;
   
   // Pipeline
   wire [`NCPU_IW-1:0] dec_insn_i;
   wire [`NCPU_AW-3:0] dec_insn_pc_i;
   
   ncpu32k_cell_dff_lr #(`NCPU_IW) dff_dec_insn_i
                  (clk_i, rst_n_i, pipe1_flow, insn[`NCPU_IW-1:0], dec_insn_i[`NCPU_IW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_dec_insn_pc_i
                  (clk_i, rst_n_i, pipe1_flow, pc_addr_nxt[`NCPU_AW-3:0], dec_insn_pc_i[`NCPU_IW-3:0]);
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 2: Decode
   /////////////////////////////////////////////////////////////////////////////
   
   wire [5:0] f_opcode = dec_insn_i[5:0];
   wire [4:0] f_rd = dec_insn_i[10:6];
   wire [4:0] f_rs1 = dec_insn_i[15:11];
   wire [4:0] f_rs2 = dec_insn_i[20:16];
   wire [10:0] f_attr = dec_insn_i[31:21];
   wire [15:0] f_imm16 = dec_insn_i[31:16];
   wire [20:0] f_rel21 = dec_insn_i[31:11];
   
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
   wire emu_insn = !((|lu_opc_bus) | (|au_opc_bus) | bu_sel | (|eu_opc_bus) | op_mu_load | op_mu_store | op_mu_barr);
   
   // Insn presents rs1 and imm as operand.
   wire insn_imm = (op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
                     op_add_i |
                     op_mu_load | op_mu_store |
                     op_wsmr | op_rsmr);
   // Insn requires Signed imm.
   wire imm_signed = (op_xor_i | op_and_i | op_add_i | op_mu_load | op_mu_store);
   // Insn presents no operand.
   wire insn_non_op = (op_barr | op_raise | op_ret | op_jmp_i | op_bt | op_bf);
   
   // Insn writeback register file
   wire wb_regf = !(op_barr | op_bt|op_bf | op_cmp | emu_insn);
   wire [`NCPU_REG_AW-1:0] wb_reg_addr = f_rd;
   
   // PC-Relative address (sign-extended)
   wire [`NCPU_AW-3:0] rel21 = {{`NCPU_AW-23{f_rel21[20]}}, f_rel21[20:0]};
   // PC-Relative jump
   wire bcc = (op_bt | op_bf) & (smr_psr_cc);
   assign fetch_jmp = op_jmp_i | bcc;
   assign fetch_jmp_offset = rel21;
   // Register-Indirect jump
   wire jmp_reg = (op_jmp);
   // Link address ?
   wire jmp_link = (op_jmp | op_jmp_i);
   
   // Request operand(s) from Regfile when needed
   assign regf_rs1_re_i = (!insn_non_op);
   assign regf_rs1_addr_i = f_rs1;
   assign regf_rs2_re_i = (!insn_imm & !insn_non_op);
   assign regf_rs2_addr_i = f_rs2;
   
   // Operand of jmp insn is Ready.
   // We assume that operand is acquired after 1 CLKs exactly.
   wire jmp_ready;
   ncpu32k_cell_dff_lr #(1) dff_exc_jmp_ready
                   (clk_i,rst_n_i, 1'b1, jmp_reg, jmp_ready);
   assign fetch_jmp_ready = (!jmp_reg | jmp_ready);
   
   assign pipe2_ready = 1'b1;
   
   // Pipeline
   wire [`NCPU_DW-1:0] exc_operand_1_i;
   wire [`NCPU_DW-1:0] exc_operand_2_i;
   wire [`NCPU_LU_IOPW-1:0] exc_lu_opc_bus_i;
   wire [`NCPU_AU_IOPW-1:0] exc_au_opc_bus_i;
   wire [`NCPU_EU_IOPW-1:0] exc_eu_opc_bus_i;
   wire exc_emu_insn_i;
   wire exc_mu_load_i;
   wire exc_mu_store_i;
   wire exc_mu_barr_i;
   wire [2:0] exc_mu_store_size_i;
   wire [2:0] exc_mu_load_size_i;
   wire imm_signed_r;
   wire [15:0] imm16_r;
   wire exc_wb_regf_i;
   wire [`NCPU_REG_AW-1:0] exc_wb_reg_addr_i;
   wire exc_jmp_reg_i;
   wire [`NCPU_AW-2:0] exc_insn_pc_i;
   wire exc_jmp_link_i;
   
   ncpu32k_cell_dff_lr #(1) dff_imm_signed_r
                   (clk_i,rst_n_i, pipe2_flow, imm_signed, imm_signed_r);
   ncpu32k_cell_dff_lr #(16) dff_imm16_r
                   (clk_i,rst_n_i, pipe2_flow, f_imm16[15:0], imm16_r[15:0]);

   // Sign-extended Integer
   wire [`NCPU_DW-1:0] simm16_r = {{`NCPU_DW-16{imm16_r[15]}}, imm16_r[15:0]};
   // Zero-extended Integer
   wire [`NCPU_DW-1:0] uimm16_r = {{`NCPU_DW-16{1'b0}}, imm16_r[15:0]};
   // Immediate Operand
   wire [`NCPU_DW-1:0] imm_oper_r = (imm_signed_r ? simm16_r : uimm16_r);
   
   // Final Operands
   assign exc_operand_1_i = (rs1_valid_o ? rs1_o : imm_oper_r);
   assign exc_operand_2_i = (rs2_valid_o ? rs2_o : imm_oper_r);
   
   ncpu32k_cell_dff_lr #(`NCPU_LU_IOPW) dff_exc_lu_opc_bus_i
                   (clk_i,rst_n_i, pipe2_flow, lu_opc_bus[`NCPU_LU_IOPW-1:0], exc_lu_opc_bus_i[`NCPU_LU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AU_IOPW) dff_exc_au_opc_bus_i
                   (clk_i,rst_n_i, pipe2_flow, au_opc_bus[`NCPU_AU_IOPW-1:0], exc_au_opc_bus_i[`NCPU_AU_IOPW-1:0]);
   ncpu32k_cell_dff_lr #(`NCPU_EU_IOPW) dff_exc_eu_opc_bus_i
                   (clk_i,rst_n_i, pipe2_flow, eu_opc_bus[`NCPU_EU_IOPW-1:0], exc_eu_opc_bus_i[`NCPU_EU_IOPW-1:0]);

   ncpu32k_cell_dff_lr #(1) dff_exc_emu_insn_i
                   (clk_i,rst_n_i, pipe2_flow, emu_insn, exc_emu_insn_i);
                   
   ncpu32k_cell_dff_lr #(1) dff_exc_mu_load_i
                   (clk_i,rst_n_i, pipe2_flow, op_mu_load, exc_mu_load_i);
   ncpu32k_cell_dff_lr #(1) dff_exc_mu_store_i
                   (clk_i,rst_n_i, pipe2_flow, op_mu_store, exc_mu_store_i);
   ncpu32k_cell_dff_lr #(1) dff_exc_mu_barr_i
                   (clk_i,rst_n_i, pipe2_flow, op_mu_barr, exc_mu_barr_i);
   ncpu32k_cell_dff_lr #(3) dff_exc_mu_store_size_i
                   (clk_i,rst_n_i, pipe2_flow, mu_store_size[2:0], exc_mu_store_size_i[2:0]);
   ncpu32k_cell_dff_lr #(3) dff_exc_mu_load_size_i
                   (clk_i,rst_n_i, pipe2_flow, mu_load_size[2:0], exc_mu_load_size_i[2:0]);
                   
   ncpu32k_cell_dff_lr #(1) dff_exc_wb_regf_i
                   (clk_i,rst_n_i, pipe2_flow, wb_regf, exc_wb_regf_i);
   ncpu32k_cell_dff_lr #(`NCPU_REG_AW) dff_exc_wb_reg_addr_i
                   (clk_i,rst_n_i, pipe2_flow, wb_reg_addr, exc_wb_reg_addr_i);

   ncpu32k_cell_dff_lr #(1) dff_exc_jmp_reg_i
                   (clk_i,rst_n_i, pipe2_flow, jmp_reg, exc_jmp_reg_i);
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_exc_insn_pc_i
               (clk_i, rst_n_i, pipe2_flow, dec_insn_pc_i[`NCPU_AW-3:0], exc_insn_pc_i[`NCPU_IW-3:0]);
   ncpu32k_cell_dff_lr #(1) dff_exc_jmp_link_i
                   (clk_i,rst_n_i, pipe2_flow, jmp_link, exc_jmp_link_i);


   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3: Execution && Load/Store
   /////////////////////////////////////////////////////////////////////////////
   
   ///////////////////////////
   // LU (Logic Unit)
   ///////////////////////////
   
   wire [`NCPU_DW-1:0] lu_and = (exc_operand_1_i & exc_operand_2_i);
   wire [`NCPU_DW-1:0] lu_or = (exc_operand_1_i | exc_operand_2_i);
   wire [`NCPU_DW-1:0] lu_xor = (exc_operand_1_i ^ exc_operand_2_i);
   
   function [`NCPU_DW-1:0] reverse_bits;
      input [`NCPU_DW-1:0] a;
	   integer 			      i;
	   begin
         for (i = 0; i < `NCPU_DW; i=i+1) begin
            reverse_bits[`NCPU_DW-1-i] = a[i];
         end
      end
   endfunction

   wire [`NCPU_DW-1:0] shift_right;
   wire [`NCPU_DW-1:0] shift_lsw;
   wire [`NCPU_DW-1:0] shift_msw;
   wire [`NCPU_DW*2-1:0] shift_wide;
   wire [`NCPU_DW-1:0] lu_shift;

   assign shift_lsw = exc_lu_opc_bus_i[`NCPU_LU_LSL] ? reverse_bits(exc_operand_1_i) : exc_operand_1_i;
`ifdef ENABLE_ASR
   assign shift_msw = exc_lu_opc_bus_i[`NCPU_LU_ASR] ? {`NCPU_DW{exc_operand_1_i[`NCPU_DW-1]}} : {`NCPU_DW{1'b0}};
   assign shift_wide = {shift_msw, shift_lsw} >> exc_operand_2_i[4:0];
   assign shift_right = shift_wide[`NCPU_DW-1:0];
`else
   assign shift_right = shift_lsw >> exc_operand_2_i[4:0];
`endif
   assign lu_shift = exc_lu_opc_bus_i[`NCPU_LU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign lu_op_shift = exc_lu_opc_bus_i[`NCPU_LU_LSL] | exc_lu_opc_bus_i[`NCPU_LU_LSR] | exc_lu_opc_bus_i[`NCPU_LU_ASR];

   
   ///////////////////////////
   // AU (Arithmetic Unit)
   ///////////////////////////
   
   wire [`NCPU_DW-1:0] au_adder;
   wire [`NCPU_DW-1:0] au_mul;
   wire [`NCPU_DW-1:0] au_div;
   
   // Full Adder
   wire [`NCPU_DW-1:0] adder_operand2_com;
   wire                adder_sub;
   wire                adder_carry_in;
   wire                adder_carry_out;
   wire                adder_overflow;
   
   assign adder_sub = (exc_au_opc_bus_i[`NCPU_AU_SUB]);
   assign adder_carry_in = adder_sub;
   assign adder_operand2_com = adder_sub ? ~exc_operand_2_i : exc_operand_2_i;

   assign {adder_carry_out, au_adder} = exc_operand_1_i + adder_operand2_com + {{`NCPU_DW-1{1'b0}}, adder_carry_in};

   assign adder_overflow = (exc_operand_1_i[`NCPU_DW-1] == adder_operand2_com[`NCPU_DW-1]) &
                          (exc_operand_1_i[`NCPU_DW-1] ^ au_adder[`NCPU_DW-1]);

   wire au_op_adder = exc_au_opc_bus_i[`NCPU_AU_ADD] | adder_sub;

   // Multiplier
`ifdef ENABLE_MUL
`endif

`ifdef ENABLE_DIV
`endif
`ifdef ENABLE_DIVU
`endif
`ifdef ENABLE_MOD
`endif
`ifdef ENABLE_MODU
`endif

   ///////////////////////////
   // MU (Memory access Unit)
   ///////////////////////////
   wire load_ready;
   wire store_ready;
   wire [`NCPU_DW-1:0] mu_load;
   wire [`NCPU_DW-1:0] mu_store;
   
   assign addr_o = exc_operand_1_i + exc_operand_2_i;
   // Load from memory
   assign dbus_rd_o = exc_mu_load_i;
   assign mu_load = d_i;
   assign load_ready = dbus_rd_ready_i;
   // Store to memory
   assign dbus_we_o = exc_mu_store_i;
   assign mu_store = d_i;
   assign store_ready = dbus_we_done_i;
   
   // If Load/Store, then Wait for dbus.
   assign pipe3_ready = !(exc_mu_load_i|exc_mu_store_i) | (load_ready | store_ready);

   // Register-operand jmp
   assign fetch_jmpfar = exc_jmp_reg_i;
   assign fetch_jmpfar_addr = exc_operand_1_i[`NCPU_AW-1:2]; // TODO unalign check
   // Link address
   wire [`NCPU_DW:0] linkaddr = {{(`NCPU_DW-`NCPU_AW+1){1'b0}}, {exc_insn_pc_i[`NCPU_AW-3:0], 2'b00}};
   
   assign regf_rd_i = ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_AND]}} & lu_and[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_OR]}} & lu_or[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_XOR]}} & lu_xor[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{lu_op_shift}} & lu_shift[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{au_op_adder}} & au_adder[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_mu_load_i}} & mu_load[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_mu_store_i}} & mu_store[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_jmp_link_i}} & linkaddr[`NCPU_DW-1:0]);
   
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 4: Commit & WriteBack
   /////////////////////////////////////////////////////////////////////////////
   
   // WriteBack result to register file.
   assign regf_rd_we_i = pipe3_flow & exc_wb_regf_i;
   assign regf_rd_addr_i = exc_wb_reg_addr_i;
   
endmodule
