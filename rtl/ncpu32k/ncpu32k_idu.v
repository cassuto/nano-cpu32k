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

module ncpu32k_idu
#(
   parameter CONFIG_ENABLE_MUL,
   parameter CONFIG_ENABLE_DIV,
   parameter CONFIG_ENABLE_DIVU,
   parameter CONFIG_ENABLE_MOD,
   parameter CONFIG_ENABLE_MODU,
   parameter CONFIG_PIPEBUF_BYPASS
)
(
   input                      clk,
   input                      rst_n,
   output                     idu_AREADY,
   input                      idu_AVALID,
   input [`NCPU_IW-1:0]       idu_insn,
   input [`NCPU_AW-3:0]       idu_pc,
   input [2:0]                idu_exc,
   input                      idu_pred_branch,
   input [`NCPU_AW-3:0]       idu_pred_tgt,
   input                      disp_AREADY,
   output                     disp_AVALID,
   output [`NCPU_AW-3:0]      disp_pc,
   output                     disp_pred_branch,
   output [`NCPU_AW-3:0]      disp_pred_tgt,
   output [`NCPU_ALU_IOPW-1:0] disp_alu_opc_bus,
   output [`NCPU_LPU_IOPW-1:0] disp_lpu_opc_bus,
   output [`NCPU_EPU_IOPW-1:0] disp_epu_opc_bus,
   output                     disp_agu_load,
   output                     disp_agu_store,
   output                     disp_agu_sign_ext,
   output                     disp_agu_barr,
   output [2:0]               disp_agu_store_size,
   output [2:0]               disp_agu_load_size,
   output                     disp_rs1_re,
   output [`NCPU_REG_AW-1:0]  disp_rs1_addr,
   output                     disp_rs2_re,
   output [`NCPU_REG_AW-1:0]  disp_rs2_addr,
   output [`NCPU_DW-1:0]      disp_imm32,
   output [14:0]              disp_rel15,
   output                     disp_rd_we,
   output [`NCPU_REG_AW-1:0]  disp_rd_addr
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
   wire                       op_blt;
   wire                       op_bltu;
   wire                       op_bge;
   wire                       op_bgeu;
   wire                       op_syscall;
   wire                       op_ret;
   wire                       op_wmsr;
   wire                       op_rmsr;
   wire                       pipe_cke;
   wire                       emu_insn;
   wire                       insn_rs1_imm15;
   wire                       insn_rd_rs1_imm15;
   wire                       insn_rd_uimm17;
   wire                       imm15_signed;
   wire                       insn_no_rops;
   wire                       insn_not_wb;
   wire                       read_rd_as_rs2;
   wire                       wb_regf;
   wire [`NCPU_REG_AW-1:0]    wb_reg_addr;
   wire                       jmp_link;
   wire                       rs1_re_nxt;
   wire [`NCPU_REG_AW-1:0]    rs1_addr_nxt;
   wire                       rs2_re_nxt;
   wire [`NCPU_REG_AW-1:0]    rs2_addr_nxt;
   wire [`NCPU_DW-1:0]        simm15;
   wire [`NCPU_DW-1:0]        uimm15;
   wire [`NCPU_DW-1:0]        uimm17;
   wire [`NCPU_DW-1:0]        imm32_nxt;
   wire [`NCPU_ALU_IOPW-1:0]  alu_opc_bus;
   wire [`NCPU_LPU_IOPW-1:0]  lpu_opc_bus;
   wire [`NCPU_EPU_IOPW-1:0]  epu_opc_bus;
   wire [`NCPU_AW-3:0]        jmprel_offset;
   wire [2:0]                 agu_store_size;
   wire [2:0]                 agu_load_size;
   wire                       agu_sign_ext;
   wire                       bcc;
   wire                       op_agu_load;
   wire                       op_agu_store;
   wire                       op_agu_barr;

   // If IMMU exceptions raised, displace the insn with NOP.
   assign f_opcode = idu_insn[6:0] & {7{~|idu_exc}};
   assign f_rd = idu_insn[11:7];
   assign f_rs1 = idu_insn[16:12];
   assign f_rs2 = idu_insn[21:17];
   assign f_cond = idu_insn[25:22] & {4{~|idu_exc}};
   assign f_imm15 = idu_insn[31:17];
   assign f_imm17 = idu_insn[28:12];
   assign f_rel25 = idu_insn[31:7];

   // TODO: Dynamically power on or off functional units to optimize consumption
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

   assign op_and = (f_opcode == `NCPU_OP_AND);
   assign op_and_i = (f_opcode == `NCPU_OP_AND_I);
   assign op_or = (f_opcode == `NCPU_OP_OR);
   assign op_or_i = (f_opcode == `NCPU_OP_OR_I);
   assign op_xor = (f_opcode == `NCPU_OP_XOR);
   assign op_xor_i = (f_opcode == `NCPU_OP_XOR_I);
   assign op_lsl = (f_opcode == `NCPU_OP_LSL);
   assign op_lsl_i = (f_opcode == `NCPU_OP_LSL_I);
   assign op_lsr = (f_opcode == `NCPU_OP_LSR);
   assign op_lsr_i = (f_opcode == `NCPU_OP_LSR_I);
   assign op_asr = (f_opcode == `NCPU_OP_ASR) & enable_asr;
   assign op_asr_i = (f_opcode == `NCPU_OP_ASR_I) & enable_asr_i;

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
   endgenerate
   
   assign op_mhi = (f_opcode == `NCPU_OP_MHI);

   assign op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   assign op_jmp_lnk_i = (f_opcode == `NCPU_OP_JMP_LNK_I);
   assign op_jmpreg = (f_opcode == `NCPU_OP_JMP);
   assign op_beq = (f_opcode == `NCPU_OP_BEQ);
   assign op_bne = (f_opcode == `NCPU_OP_BNE);
   assign op_blt = (f_opcode == `NCPU_OP_BLT);
   assign op_bltu = (f_opcode == `NCPU_OP_BLTU);
   assign op_bge = (f_opcode == `NCPU_OP_BGE);
   assign op_bgeu = (f_opcode == `NCPU_OP_BGEU);

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

   assign alu_opc_bus[`NCPU_ALU_BEQ] = (op_beq);
   assign alu_opc_bus[`NCPU_ALU_BNE] = (op_bne);
   assign alu_opc_bus[`NCPU_ALU_BLT] = (op_blt);
   assign alu_opc_bus[`NCPU_ALU_BLTU] = (op_bltu);
   assign alu_opc_bus[`NCPU_ALU_BGE] = (op_bge);
   assign alu_opc_bus[`NCPU_ALU_BGEU] = (op_bgeu);
   assign alu_opc_bus[`NCPU_ALU_JMPREL] = op_jmp_lnk_i | op_jmp_i;
   assign alu_opc_bus[`NCPU_ALU_JMPREG] = op_jmpreg;
   assign bcc = (op_beq | op_bne | op_blt | op_bltu | op_bge | op_bgeu);
   
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
   assign agu_store_size = op_stb ? 3'd1 : op_sth ? 3'd2 : op_stw ? 3'd3 : 3'd0;
   assign agu_load_size = (op_ldb|op_ldbu) ? 3'd1 : (op_ldh|op_ldhu) ? 3'd2 : (op_ldwu) ? 3'd3 : 3'd0;

   assign agu_sign_ext = (op_ldb | op_ldh);

   assign op_agu_load = |agu_load_size;
   assign op_agu_store = |agu_store_size;
   assign op_agu_barr = (f_opcode == `NCPU_OP_MBARR);

   // EPU opcodes
   assign epu_opc_bus[`NCPU_EPU_WMSR] = op_wmsr;
   assign epu_opc_bus[`NCPU_EPU_RMSR] = op_rmsr;
   assign epu_opc_bus[`NCPU_EPU_ESYSCALL] = op_syscall;
   assign epu_opc_bus[`NCPU_EPU_ERET] = op_ret;
   assign epu_opc_bus[`NCPU_EPU_EITM] = idu_exc[0];
   assign epu_opc_bus[`NCPU_EPU_EIPF] = idu_exc[1];
   assign epu_opc_bus[`NCPU_EPU_EIRQ] = idu_exc[2];
   // Insn is to be emulated
   // Must filter out all the known insns, excluding EINSN itself.
   assign epu_opc_bus[`NCPU_EPU_EINSN] =
      ~(
         // ALU opcodes
         (|alu_opc_bus) |
         // LPU opcodes
         (|lpu_opc_bus) |
         // AGU insns
         op_agu_load | op_agu_store | op_agu_barr |
         // EPU opcodes
         (|epu_opc_bus[`NCPU_EPU_EINSN-1:0])
      );

   // Insn that uses rs1 and imm15 as operand.
   assign insn_rs1_imm15 =
      (
         op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
         op_add_i |
         op_agu_load |
         op_rmsr
      );
   // Insn that uses rs1, rs2 and imm15 as operand
   assign insn_rd_rs1_imm15 =
      (
         op_agu_store |
         op_wmsr
      );
   // Insn that uses rd and imm17 as operand.
   assign insn_rd_uimm17 = op_mhi;
   // Insn that uses rel25 as operand
   assign insn_rel25 = (op_jmp_i | op_jmp_lnk_i);
   // Insn that requires signed imm15.
   assign imm15_signed = (op_xor_i | op_add_i | op_agu_load | op_agu_store);
   // Insns that have no register operands.
   assign insn_no_rops = (op_agu_barr | op_syscall | op_ret | op_jmp_i | op_jmp_lnk_i);
   // Insns that do not writeback ARF
   assign insn_not_wb = (op_jmp_i | bcc | 
                        op_agu_store | op_agu_barr |
                        op_wmsr | epu_opc_bus[`NCPU_EPU_ESYSCALL] | epu_opc_bus[`NCPU_EPU_ERET] |
                        epu_opc_bus[`NCPU_EPU_EITM] | epu_opc_bus[`NCPU_EPU_EIPF] |
                        epu_opc_bus[`NCPU_EPU_EINSN] |
                        epu_opc_bus[`NCPU_EPU_EIRQ]);
   
   // Do not write r0 (nil)
   assign wb_regf = ~insn_not_wb & (|wb_reg_addr);
   assign wb_reg_addr = op_jmp_lnk_i ? `NCPU_REGNO_LNK : f_rd;

   // Pipeline
   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
      )
   pipebuf_ifu
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .A_en    (1'b1),
         .AVALID  (idu_AVALID),
         .AREADY  (idu_AREADY),
         .B_en    (1'b1),
         .BVALID  (disp_AVALID),
         .BREADY  (disp_AREADY),
         .cke     (pipe_cke),
         .pending ()
      );

   assign read_rd_as_rs2 = (op_agu_store | op_wmsr | bcc | insn_rd_uimm17);

   // Request operand(s) from regfile when needed
   assign rs1_re_nxt = ~insn_no_rops & ~insn_rd_uimm17;
   assign rs1_addr_nxt = f_rs1;
   assign rs2_re_nxt = (~insn_rs1_imm15 & ~insn_rel25 & ~insn_no_rops) | read_rd_as_rs2;
   assign rs2_addr_nxt = read_rd_as_rs2 ? f_rd : f_rs2;

   // Sign-extended 15bit Integer
   assign simm15 = {{`NCPU_DW-15{f_imm15[14]}}, f_imm15[14:0]};
   // Zero-extended 15bit Integer
   assign uimm15 = {{`NCPU_DW-15{1'b0}}, f_imm15[14:0]};
   // Zero-extended 17bit Integer
   assign uimm17 = {{`NCPU_DW-17{1'b0}}, f_imm17[16:0]};
   // PC-Relative address (sign-extended)
   assign jmprel_offset = {{`NCPU_AW-2-25{f_rel25[24]}}, f_rel25[24:0]};
   // Immediate Operand Assert (2103281412)
   assign imm32_nxt = ({`NCPU_DW{insn_rs1_imm15|insn_rd_rs1_imm15}} & (imm15_signed ? simm15 : uimm15)) |
                        ({`NCPU_DW{insn_rd_uimm17}} & uimm17) |
                        ({`NCPU_DW{insn_rel25}} & jmprel_offset);

   // Data path
   nDFF_l #(`NCPU_REG_AW) dff_disp_rs1_addr
      (clk, pipe_cke, rs1_addr_nxt, disp_rs1_addr);
   nDFF_l #(`NCPU_REG_AW) dff_disp_rs2_addr
      (clk, pipe_cke, rs2_addr_nxt, disp_rs2_addr);
   nDFF_l #(`NCPU_DW) dff_disp_imm32
      (clk, pipe_cke, imm32_nxt, disp_imm32);
   nDFF_l #(15) dff_disp_rel15
      (clk, pipe_cke, f_imm15, disp_rel15);

   nDFF_l #(3) dff_disp_agu_store_size
     (clk, pipe_cke, agu_store_size[2:0], disp_agu_store_size[2:0]);
   nDFF_l #(3) dff_disp_agu_load_size
     (clk, pipe_cke, agu_load_size[2:0], disp_agu_load_size[2:0]);

   nDFF_l #(`NCPU_AW-2) dff_disp_pc
      (clk, pipe_cke, idu_pc, disp_pc);
   nDFF_l #(`NCPU_AW-2) dff_disp_pred_tgt
      (clk, pipe_cke, idu_pred_tgt, disp_pred_tgt);
     
   nDFF_l #(`NCPU_REG_AW) dff_disp_rd_addr
     (clk, pipe_cke, wb_reg_addr[`NCPU_REG_AW-1:0], disp_rd_addr[`NCPU_REG_AW-1:0]);
   
   // Control path
   nDFF_lr #(`NCPU_ALU_IOPW) dff_disp_alu_opc_bus
     (clk,rst_n, pipe_cke, alu_opc_bus[`NCPU_ALU_IOPW-1:0], disp_alu_opc_bus[`NCPU_ALU_IOPW-1:0]);
   nDFF_lr #(`NCPU_LPU_IOPW) dff_disp_lpu_opc_bus
     (clk,rst_n, pipe_cke, lpu_opc_bus[`NCPU_LPU_IOPW-1:0], disp_lpu_opc_bus[`NCPU_LPU_IOPW-1:0]);
   nDFF_lr #(`NCPU_EPU_IOPW) dff_disp_epu_opc_bus
     (clk,rst_n, pipe_cke, epu_opc_bus[`NCPU_EPU_IOPW-1:0], disp_epu_opc_bus[`NCPU_EPU_IOPW-1:0]);

   nDFF_lr #(1) dff_disp_agu_load
     (clk,rst_n, pipe_cke, op_agu_load, disp_agu_load);
   nDFF_lr #(1) dff_disp_agu_store
     (clk,rst_n, pipe_cke, op_agu_store, disp_agu_store);
   nDFF_lr #(1) dff_disp_agu_barr
     (clk,rst_n, pipe_cke, op_agu_barr, disp_agu_barr);
   nDFF_lr #(1) dff_disp_agu_sign_ext
     (clk,rst_n, pipe_cke, agu_sign_ext, disp_agu_sign_ext);

   nDFF_lr #(1) dff_disp_pred_branch
      (clk,rst_n, pipe_cke, idu_pred_branch, disp_pred_branch);

   nDFF_lr #(1) dff_disp_rs1_re
      (clk,rst_n, pipe_cke, rs1_re_nxt, disp_rs1_re);
   nDFF_lr #(1) dff_disp_rs2_re
      (clk,rst_n, pipe_cke, rs2_re_nxt, disp_rs2_re);

   nDFF_lr #(1) dff_disp_wb_regf
     (clk,rst_n, pipe_cke, wb_regf, disp_rd_we);

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertion 2103281412
         if (count_1({insn_rs1_imm15, insn_rd_rs1_imm15, insn_rd_uimm17, insn_rel25})>1)
            $fatal("\n Bugs on insn type decoder\n");
      end
`endif

`endif
   // synthesis translate_on
endmodule
