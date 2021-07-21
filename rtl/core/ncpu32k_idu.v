/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_idu
#(
   parameter CONFIG_ENABLE_MUL
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIV
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIVU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MOD
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MODU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_ASR
   `PARAM_NOT_SPECIFIED
)
(
`ifdef NCPU_ENABLE_ASSERT
   input                      clk,
`endif
   input [`NCPU_IW-1:0]       idu_insn,
   input                      idu_EITM,
   input                      idu_EIPF,
   input                      idu_EIRQ,
   output [`NCPU_ALU_IOPW-1:0] alu_opc_bus,
   output [`NCPU_LPU_IOPW-1:0] lpu_opc_bus,
   output [`NCPU_EPU_IOPW-1:0] epu_opc_bus,
   output [`NCPU_BRU_IOPW-1:0] bru_opc_bus,
   output                     op_lsu_load,
   output                     op_lsu_store,
   output                     lsu_sign_ext,
   output                     op_lsu_barr,
   output [2:0]               lsu_store_size,
   output [2:0]               lsu_load_size,
   output                     wb_regf,
   output [`NCPU_REG_AW-1:0]  wb_reg_addr,
   output [`NCPU_DW-1:0]      imm32,
   // Regfile
   output                     rf_rs1_re,
   output [`NCPU_REG_AW-1:0]  rf_rs1_addr,
   output                     rf_rs2_re,
   output [`NCPU_REG_AW-1:0]  rf_rs2_addr
);

   wire [6:0]                 f_opcode;
   wire [4:0]                 f_rd;
   wire [4:0]                 f_rs1;
   wire [4:0]                 f_rs2;
   wire [3:0]                 f_cond;
   wire [14:0]                f_imm15;
   wire [16:0]                f_imm17;
   wire [24:0]                f_rel25;
   wire                       enable_asr;
   wire                       enable_asr_i;
   wire                       enable_mul;
   wire                       enable_div;
   wire                       enable_divu;
   wire                       enable_mod;
   wire                       enable_modu;
   wire                       op_ldb;
   wire                       op_ldbu;
   wire                       op_ldh;
   wire                       op_ldhu;
   wire                       op_ldwu;
   wire                       op_stb;
   wire                       op_sth;
   wire                       op_stw;
   wire                       op_and;
   wire                       op_and_i;
   wire                       op_or;
   wire                       op_or_i;
   wire                       op_xor;
   wire                       op_xor_i;
   wire                       op_lsl;
   wire                       op_lsl_i;
   wire                       op_lsr;
   wire                       op_lsr_i;
   wire                       op_asr;
   wire                       op_asr_i;
   wire                       op_add;
   wire                       op_add_i;
   wire                       op_sub;
   wire                       op_mul;
   wire                       op_div;
   wire                       op_divu;
   wire                       op_mod;
   wire                       op_modu;
   wire                       op_mhi;
   wire                       op_jmp_i;
   wire                       op_jmp_lnk_i;
   wire                       op_jmpreg;
   wire                       op_beq;
   wire                       op_bne;
   wire                       op_bgt;
   wire                       op_bgtu;
   wire                       op_ble;
   wire                       op_bleu;
   wire                       op_syscall;
   wire                       op_ret;
   wire                       op_wmsr;
   wire                       op_rmsr;
   wire                       insn_rs1_imm15;
   wire                       insn_rd_rs1_imm15;
   wire                       insn_uimm17;
   wire                       insn_rel25;
   wire                       imm15_signed;
   wire                       insn_no_rops;
   wire                       insn_not_wb;
   wire                       read_rd_as_rs2;
   wire [`NCPU_DW-1:0]        simm15;
   wire [`NCPU_DW-1:0]        uimm15;
   wire [`NCPU_DW-1:0]        uimm17;
   wire [`NCPU_EPU_IOPW-1:0]  epu_opc_no_EINSN;
   wire                       bcc;
   wire                       fnt_exc;

   assign fnt_exc = (idu_EITM | idu_EIPF | idu_EIRQ);

   // If the frontend raised exceptions, displace the insn with NOP.
   assign f_opcode = idu_insn[6:0] & {7{~fnt_exc}};
   assign f_rd = idu_insn[11:7];
   assign f_rs1 = idu_insn[16:12];
   assign f_rs2 = idu_insn[21:17];
   assign f_cond = idu_insn[25:22] & {4{~fnt_exc}};
   assign f_imm15 = idu_insn[31:17];
   assign f_imm17 = idu_insn[28:12];
   assign f_rel25 = idu_insn[31:7];

   // TODO: Dynamically power on/off functional units to optimize consumption
   assign enable_asr = 1'b1;
   assign enable_asr_i = 1'b1;
   assign enable_mul = 1'b1;
   assign enable_div = 1'b1;
   assign enable_divu = 1'b1;
   assign enable_mod = 1'b1;
   assign enable_modu = 1'b1;

   assign op_ldb = (f_opcode == `NCPU_OP_LDB);
   assign op_ldbu = (f_opcode == `NCPU_OP_LDBU);
   assign op_ldh = (f_opcode == `NCPU_OP_LDH);
   assign op_ldhu = (f_opcode == `NCPU_OP_LDHU);
   assign op_ldwu = (f_opcode == `NCPU_OP_LDWU);
   assign op_stb = (f_opcode == `NCPU_OP_STB);
   assign op_sth = (f_opcode == `NCPU_OP_STH);
   assign op_stw = (f_opcode == `NCPU_OP_STW);

   assign op_and = (f_opcode == `NCPU_OP_AND) & ~fnt_exc; // NOTE: AND is actually the nop insn
   assign op_and_i = (f_opcode == `NCPU_OP_AND_I);
   assign op_or = (f_opcode == `NCPU_OP_OR);
   assign op_or_i = (f_opcode == `NCPU_OP_OR_I);
   assign op_xor = (f_opcode == `NCPU_OP_XOR);
   assign op_xor_i = (f_opcode == `NCPU_OP_XOR_I);
   assign op_lsl = (f_opcode == `NCPU_OP_LSL);
   assign op_lsl_i = (f_opcode == `NCPU_OP_LSL_I);
   assign op_lsr = (f_opcode == `NCPU_OP_LSR);
   assign op_lsr_i = (f_opcode == `NCPU_OP_LSR_I);

   assign op_add = (f_opcode == `NCPU_OP_ADD);
   assign op_add_i = (f_opcode == `NCPU_OP_ADD_I);
   assign op_sub = (f_opcode == `NCPU_OP_SUB);

   generate
      if (CONFIG_ENABLE_MUL)
         assign op_mul = (f_opcode == `NCPU_OP_MUL) & enable_mul;
      else
         assign op_mul = 1'b0;
      if (CONFIG_ENABLE_DIV)
         assign op_div = (f_opcode == `NCPU_OP_DIV) & enable_div;
      else
         assign op_div = 1'b0;
      if (CONFIG_ENABLE_DIVU)
         assign op_divu = (f_opcode == `NCPU_OP_DIVU) & enable_divu;
      else
         assign op_divu = 1'b0;
      if (CONFIG_ENABLE_MOD)
         assign op_mod = (f_opcode == `NCPU_OP_MOD) & enable_mod;
      else
         assign op_mod = 1'b0;
      if (CONFIG_ENABLE_MODU)
         assign op_modu = (f_opcode == `NCPU_OP_MODU) & enable_modu;
      else
         assign op_modu = 1'b0;
      if (CONFIG_ENABLE_ASR)
         begin
            assign op_asr = (f_opcode == `NCPU_OP_ASR) & enable_asr;
            assign op_asr_i = (f_opcode == `NCPU_OP_ASR_I) & enable_asr_i;
         end
      else
         begin
            assign op_asr = 1'b0;
            assign op_asr_i = 1'b0;
         end
   endgenerate
   
   assign op_mhi = (f_opcode == `NCPU_OP_MHI);

   assign op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   assign op_jmp_lnk_i = (f_opcode == `NCPU_OP_JMP_LNK_I);
   assign op_jmpreg = (f_opcode == `NCPU_OP_JMP);
   assign op_beq = (f_opcode == `NCPU_OP_BEQ);
   assign op_bne = (f_opcode == `NCPU_OP_BNE);
   assign op_bgt = (f_opcode == `NCPU_OP_BGT);
   assign op_bgtu = (f_opcode == `NCPU_OP_BGTU);
   assign op_ble = (f_opcode == `NCPU_OP_BLE);
   assign op_bleu = (f_opcode == `NCPU_OP_BLEU);

   assign op_syscall = (f_opcode == `NCPU_OP_SYSCALL);
   assign op_ret = (f_opcode == `NCPU_OP_RET);

   assign op_wmsr = (f_opcode == `NCPU_OP_WMSR);
   assign op_rmsr = (f_opcode == `NCPU_OP_RMSR);

   // ALU opcodes
   assign alu_opc_bus[`NCPU_ALU_AND] = (op_and | op_and_i);
   assign alu_opc_bus[`NCPU_ALU_OR] = (op_or | op_or_i);
   assign alu_opc_bus[`NCPU_ALU_XOR] = (op_xor | op_xor_i);
   assign alu_opc_bus[`NCPU_ALU_LSL] = (op_lsl | op_lsl_i);
   assign alu_opc_bus[`NCPU_ALU_LSR] = (op_lsr | op_lsr_i);
   assign alu_opc_bus[`NCPU_ALU_ASR] = (op_asr | op_asr_i);

   assign alu_opc_bus[`NCPU_ALU_ADD] = (op_add | op_add_i);
   assign alu_opc_bus[`NCPU_ALU_SUB] = (op_sub);
   assign alu_opc_bus[`NCPU_ALU_MHI] = (op_mhi);

   assign bru_opc_bus[`NCPU_BRU_BEQ] = (op_beq);
   assign bru_opc_bus[`NCPU_BRU_BNE] = (op_bne);
   assign bru_opc_bus[`NCPU_BRU_BGT] = (op_bgt);
   assign bru_opc_bus[`NCPU_BRU_BGTU] = (op_bgtu);
   assign bru_opc_bus[`NCPU_BRU_BLE] = (op_ble);
   assign bru_opc_bus[`NCPU_BRU_BLEU] = (op_bleu);
   assign bru_opc_bus[`NCPU_BRU_JMPREL] = (op_jmp_lnk_i | op_jmp_i);
   assign bru_opc_bus[`NCPU_BRU_JMPREG] = op_jmpreg;
   assign bcc = (op_beq | op_bne | op_bgt | op_bgtu | op_ble | op_bleu);
   
   // LPU opcodes
   assign lpu_opc_bus[`NCPU_LPU_MUL] = op_mul;
   assign lpu_opc_bus[`NCPU_LPU_DIV] = op_div;
   assign lpu_opc_bus[`NCPU_LPU_DIVU] = op_divu;
   assign lpu_opc_bus[`NCPU_LPU_MOD] = op_mod;
   assign lpu_opc_bus[`NCPU_LPU_MODU] = op_modu;
   
   // AGU opcodes
   
   //
   // Target Size of Memory Access.
   // 0 = None operation
   // 1 = 8bit
   // 2 = 16bit
   // 3 = 32bit
   // 4 = 64bit
   assign lsu_store_size = op_stb ? 3'd1 : op_sth ? 3'd2 : op_stw ? 3'd3 : 3'd0;
   assign lsu_load_size = (op_ldb|op_ldbu) ? 3'd1 : (op_ldh|op_ldhu) ? 3'd2 : (op_ldwu) ? 3'd3 : 3'd0;

   assign lsu_sign_ext = (op_ldb | op_ldh);

   assign op_lsu_load = (op_ldb|op_ldbu|op_ldh|op_ldhu|op_ldwu);
   assign op_lsu_store = (op_stb|op_sth|op_stw);
   assign op_lsu_barr = (f_opcode == `NCPU_OP_MBARR);

   // EPU opcodes excluding EINSN 
   assign epu_opc_no_EINSN[`NCPU_EPU_WMSR] = op_wmsr;
   assign epu_opc_no_EINSN[`NCPU_EPU_RMSR] = op_rmsr;
   assign epu_opc_no_EINSN[`NCPU_EPU_ESYSCALL] = op_syscall;
   assign epu_opc_no_EINSN[`NCPU_EPU_ERET] = op_ret;
   assign epu_opc_no_EINSN[`NCPU_EPU_EITM] = (idu_EITM & ~idu_EIRQ);
   assign epu_opc_no_EINSN[`NCPU_EPU_EIPF] = (idu_EIPF & ~idu_EIRQ);
   assign epu_opc_no_EINSN[`NCPU_EPU_EIRQ] = idu_EIRQ;
   assign epu_opc_no_EINSN[`NCPU_EPU_EINSN] = 1'b0;

   // Insn is to be emulated
   assign epu_opc_bus[`NCPU_EPU_EINSN] =
      ~(
         // ALU opcodes
         (|alu_opc_bus) |
         // LPU opcodes
         (|lpu_opc_bus) |
         // BRU opcodes
         (|bru_opc_bus) |
         // LSU insns
         op_lsu_load | op_lsu_store | op_lsu_barr |
         // EPU opcodes
         (|epu_opc_no_EINSN)
      );
   // Assert 2104051343
   assign epu_opc_bus[`NCPU_EPU_EINSN-1:0] = epu_opc_no_EINSN[`NCPU_EPU_EINSN-1:0];

   // Insn that uses rs1 and imm15 as operand.
   assign insn_rs1_imm15 =
      (
         op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
         op_add_i |
         op_lsu_load |
         op_rmsr
      );
   // Insn that uses rs1, rs2 and imm15 as operand
   assign insn_rd_rs1_imm15 =
      (
         op_lsu_store |
         op_wmsr |
         bcc
      );
   // Insn that uses imm17 as operand.
   assign insn_uimm17 = op_mhi;
   // Insn that uses rel25 as operand
   assign insn_rel25 = (op_jmp_i | op_jmp_lnk_i);
   // Insn that requires signed imm15.
   assign imm15_signed = (op_xor_i | op_add_i | op_lsu_load | op_lsu_store);
   // Insns that have no register operands.
   assign insn_no_rops = (op_mhi | op_lsu_barr | op_syscall | op_ret | op_jmp_i | op_jmp_lnk_i);
   // Insns that do not writeback ARF
   assign insn_not_wb = (op_jmp_i | bcc | 
                        op_lsu_store | op_lsu_barr |
                        op_wmsr | epu_opc_bus[`NCPU_EPU_ESYSCALL] | epu_opc_bus[`NCPU_EPU_ERET] |
                        epu_opc_bus[`NCPU_EPU_EITM] | epu_opc_bus[`NCPU_EPU_EIPF] |
                        epu_opc_bus[`NCPU_EPU_EINSN] |
                        epu_opc_bus[`NCPU_EPU_EIRQ]);
   
   // Do not write r0 (nil)
   assign wb_regf = ~insn_not_wb & (|wb_reg_addr);
   assign wb_reg_addr = op_jmp_lnk_i ? `NCPU_REGNO_LNK : f_rd;


   assign read_rd_as_rs2 = (op_lsu_store | op_wmsr | bcc);

   // Request operand(s) from regfile when needed
   // Regfile could be considered as a stage of the pipeline
   assign rf_rs1_re = ~insn_no_rops;
   assign rf_rs1_addr = f_rs1;
   assign rf_rs2_re = ((~insn_rs1_imm15 & ~insn_uimm17 & ~insn_rel25 & ~insn_no_rops) | read_rd_as_rs2);
   assign rf_rs2_addr = read_rd_as_rs2 ? f_rd : f_rs2;

   // Sign-extended 15bit Integer
   assign simm15 = {{`NCPU_DW-15{f_imm15[14]}}, f_imm15[14:0]};
   // Zero-extended 15bit Integer
   assign uimm15 = {{`NCPU_DW-15{1'b0}}, f_imm15[14:0]};
   // Zero-extended 17bit Integer
   assign uimm17 = {{`NCPU_DW-17{1'b0}}, f_imm17[16:0]};
   // Immediate Operand Assert (2103281412)
   assign imm32 = ({`NCPU_DW{insn_rs1_imm15|insn_rd_rs1_imm15}} & (imm15_signed ? simm15 : uimm15)) |
                        ({`NCPU_DW{insn_rel25}} & {{`NCPU_DW-2-25{f_rel25[24]}}, f_rel25[24:0], 2'b00}) |
                        ({`NCPU_DW{insn_uimm17}} & uimm17);

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertion 2103281412
         if (count_1({insn_rs1_imm15, insn_rd_rs1_imm15, insn_uimm17, insn_rel25})>1)
            $fatal(1, "\n Bugs on insn type decoder\n");
      end
   initial
      begin
         // Assertion 2104051343
         if (`NCPU_EPU_EINSN != `NCPU_EPU_IOPW-1)
            $fatal(1, "\n Check `NCPU_EPU_EINSN, a particular value\n");
      end
`endif

`endif
   // synthesis translate_on
endmodule
