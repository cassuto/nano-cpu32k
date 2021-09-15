/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

/////////////////////////////////////////////////////////////////////////////
// ISA GROUP - BASE
/////////////////////////////////////////////////////////////////////////////
`define NCPU_OP_AND 7'h0
`define NCPU_OP_AND_I 7'h1
`define NCPU_OP_OR 7'h2
`define NCPU_OP_OR_I 7'h3
`define NCPU_OP_XOR 7'h4
`define NCPU_OP_XOR_I 7'h5
`define NCPU_OP_LSL 7'h6
`define NCPU_OP_LSL_I 7'h7
`define NCPU_OP_LSR 7'h8
`define NCPU_OP_LSR_I 7'h9
`define NCPU_OP_ADD 7'ha
`define NCPU_OP_ADD_I 7'hb
`define NCPU_OP_SUB 7'hc
`define NCPU_OP_JMP 7'hd
`define NCPU_OP_JMP_I 7'he
`define NCPU_OP_JMP_LNK_I 7'hf
`define NCPU_OP_BEQ 7'h10
`define NCPU_OP_BNE 7'h11
`define NCPU_OP_BGT 7'h12
`define NCPU_OP_BGTU 7'h13
`define NCPU_OP_BLE 7'h14
`define NCPU_OP_BLEU 7'h15

`define NCPU_OP_LDWU 7'h17
`define NCPU_OP_STW 7'h18
`define NCPU_OP_LDHU 7'h19
`define NCPU_OP_LDH 7'h1a
`define NCPU_OP_STH 7'h1b
`define NCPU_OP_LDBU 7'h1c
`define NCPU_OP_LDB 7'h1d
`define NCPU_OP_STB 7'h1e

`define NCPU_OP_MBARR 7'h20
`define NCPU_OP_SYSCALL 7'h21
`define NCPU_OP_RET 7'h22
`define NCPU_OP_WMSR 7'h23
`define NCPU_OP_RMSR 7'h24


/////////////////////////////////////////////////////////////////////////////
// ISA GROUP - VIRT:
/////////////////////////////////////////////////////////////////////////////
`define NCPU_OP_ASR 7'h30
`define NCPU_OP_ASR_I 7'h31
`define NCPU_OP_MUL 7'h32
`define NCPU_OP_DIV 7'h33
`define NCPU_OP_DIVU 7'h34
`define NCPU_OP_MOD 7'h35
`define NCPU_OP_MODU 7'h36
`define NCPU_OP_MHI 7'h37

`define NCPU_OP_FADDS 7'h40
`define NCPU_OP_FSUBS 7'h41
`define NCPU_OP_FMULS 7'h42
`define NCPU_OP_FDIVS 7'h43
`define NCPU_OP_FCMPS 7'h44
`define NCPU_OP_FITFS 7'h45
`define NCPU_OP_FFTIS 7'h46

module id_dec
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_ENABLE_MUL = 0,
   parameter                           CONFIG_ENABLE_DIV = 0,
   parameter                           CONFIG_ENABLE_DIVU = 0,
   parameter                           CONFIG_ENABLE_MOD = 0,
   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0
)
(
   input                               id_valid,
   input [`NCPU_INSN_DW-1:0]           id_ins,
   input [`FNT_EXC_W-1:0]              id_exc,
   input                               irq_async,
   output                              single_fu,
   output [`NCPU_ALU_IOPW-1:0]         alu_opc_bus,
   output [`NCPU_LPU_IOPW-1:0]         lpu_opc_bus,
   output [`NCPU_EPU_IOPW-1:0]         epu_opc_bus,
   output [`NCPU_BRU_IOPW-1:0]         bru_opc_bus,
   output [`NCPU_LSU_IOPW-1:0]         lsu_opc_bus,
   output [CONFIG_DW-1:0]              imm,
   output                              rf_we,
   output [`NCPU_REG_AW-1:0]           rf_waddr,
   output                              rf_rs1_re,
   output [`NCPU_REG_AW-1:0]           rf_rs1_addr,
   output                              rf_rs2_re,
   output [`NCPU_REG_AW-1:0]           rf_rs2_addr
);
   wire                                msk;
   wire [6:0]                          f_opcode;
   wire [4:0]                          f_rd;
   wire [4:0]                          f_rs1;
   wire [4:0]                          f_rs2;
   wire [14:0]                         f_imm15;
   wire [16:0]                         f_imm17;
   wire [14:0]                         f_rel15;
   wire [24:0]                         f_rel25;
   wire                                enable_asr;
   wire                                enable_asr_i;
   wire                                enable_mul;
   wire                                enable_div;
   wire                                enable_divu;
   wire                                enable_mod;
   wire                                enable_modu;
   wire                                op_ldb;
   wire                                op_ldbu;
   wire                                op_ldh;
   wire                                op_ldhu;
   wire                                op_ldwu;
   wire                                op_stb;
   wire                                op_sth;
   wire                                op_stw;
   wire                                op_and;
   wire                                op_and_i;
   wire                                op_or;
   wire                                op_or_i;
   wire                                op_xor;
   wire                                op_xor_i;
   wire                                op_lsl;
   wire                                op_lsl_i;
   wire                                op_lsr;
   wire                                op_lsr_i;
   wire                                op_asr;
   wire                                op_asr_i;
   wire                                op_add;
   wire                                op_add_i;
   wire                                op_sub;
   wire                                op_mul;
   wire                                op_div;
   wire                                op_divu;
   wire                                op_mod;
   wire                                op_modu;
   wire                                op_mhi;
   wire                                op_jmp_i;
   wire                                op_jmp_lnk_i;
   wire                                op_jmpreg;
   wire                                op_beq;
   wire                                op_bne;
   wire                                op_bgt;
   wire                                op_bgtu;
   wire                                op_ble;
   wire                                op_bleu;
   wire                                op_syscall;
   wire                                op_ret;
   wire                                op_wmsr;
   wire                                op_rmsr;
   wire                                is_bcc;
   wire                                insn_rs1_imm15;
   wire                                insn_rd_rs1_imm15;
   wire                                insn_rd_rs1_rel15;
   wire                                insn_uimm17;
   wire                                insn_rel25;
   wire                                insn_no_rops;
   wire                                use_simm15;
   wire                                not_wb;
   wire                                read_rd_as_rs2;
   wire [CONFIG_DW-1:0]                imm15;
   wire [CONFIG_DW-1:0]                uimm17;
   wire [CONFIG_DW-1:0]                rel15;
   wire [CONFIG_DW-1:0]                rel25;
   wire [`NCPU_EPU_IOPW-1:0]           epu_opc_no_EINSN;
   
   assign msk = ((~|id_exc) & id_valid);
   
   assign f_opcode = id_ins[6:0] & {7{msk}}; // 7'b000000 is `add r0,r0,r0`, i.e., NOP.
   assign f_rd = id_ins[11:7];
   assign f_rs1 = id_ins[16:12];
   assign f_rs2 = id_ins[21:17];
   assign f_imm15 = id_ins[31:17];
   assign f_imm17 = id_ins[28:12];
   assign f_rel15 = id_ins[31:17];
   assign f_rel25 = id_ins[31:7];

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
   assign is_bcc = (op_beq | op_bne | op_bgt | op_bgtu | op_ble | op_bleu);
   
   // LPU opcodes
   assign lpu_opc_bus[`NCPU_LPU_MUL] = op_mul;
   assign lpu_opc_bus[`NCPU_LPU_DIV] = op_div;
   assign lpu_opc_bus[`NCPU_LPU_DIVU] = op_divu;
   assign lpu_opc_bus[`NCPU_LPU_MOD] = op_mod;
   assign lpu_opc_bus[`NCPU_LPU_MODU] = op_modu;
   
   //
   // Target Size of Memory Access.
   // 0 = None operation
   // 1 = 8bit
   // 2 = 16bit
   // 3 = 32bit
   // 4 = 64bit
   assign lsu_opc_bus[`NCPU_LSU_SIZE] = (op_ldb|op_ldbu|op_stb)
                                          ? 3'd1
                                          : (op_ldh|op_ldhu|op_sth)
                                             ? 3'd2
                                             : (op_ldwu|op_stw)
                                                ? 3'd3
                                                : 3'd0;

   assign lsu_opc_bus[`NCPU_LSU_SIGN_EXT] = (op_ldb | op_ldh);

   assign lsu_opc_bus[`NCPU_LSU_LOAD] = (op_ldb|op_ldbu|op_ldh|op_ldhu|op_ldwu);
   assign lsu_opc_bus[`NCPU_LSU_STORE] = (op_stb|op_sth|op_stw);
   assign lsu_opc_bus[`NCPU_LSU_BARR] = (f_opcode == `NCPU_OP_MBARR);

   // EPU opcodes excluding EINSN 
   assign epu_opc_no_EINSN[`NCPU_EPU_WMSR] = op_wmsr;
   assign epu_opc_no_EINSN[`NCPU_EPU_RMSR] = op_rmsr;
   assign epu_opc_no_EINSN[`NCPU_EPU_ESYSCALL] = op_syscall;
   assign epu_opc_no_EINSN[`NCPU_EPU_ERET] = op_ret;
   assign epu_opc_no_EINSN[`NCPU_EPU_EITM] = (id_exc[`FNT_EXC_EITM] & ~irq_async);
   assign epu_opc_no_EINSN[`NCPU_EPU_EIPF] = (id_exc[`FNT_EXC_EIPF] & ~irq_async);
   assign epu_opc_no_EINSN[`NCPU_EPU_EIRQ] = irq_async;
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
         (lsu_opc_bus[`NCPU_LSU_LOAD] | lsu_opc_bus[`NCPU_LSU_STORE] | lsu_opc_bus[`NCPU_LSU_BARR]) |
         // EPU opcodes
         (|epu_opc_no_EINSN)
      );
   assign epu_opc_bus[`NCPU_EPU_EINSN-1:0] = epu_opc_no_EINSN[`NCPU_EPU_EINSN-1:0];

   // Insn that has only one FU
   assign single_fu =
      (
         // LPU opcodes
         (|lpu_opc_bus) |
         // BRU opcodes
         (|bru_opc_bus) |
         // LSU insns
         (lsu_opc_bus[`NCPU_LSU_LOAD] | lsu_opc_bus[`NCPU_LSU_STORE] | lsu_opc_bus[`NCPU_LSU_BARR]) |
         // EPU opcodes
         (|epu_opc_bus)
      );
   
   // Insn that uses rs1 and imm15 as operands.
   assign insn_rs1_imm15 =
      (
         op_and_i | op_or_i | op_xor_i | op_lsl_i | op_lsr_i | op_asr_i |
         op_add_i |
         lsu_opc_bus[`NCPU_LSU_LOAD] |
         op_rmsr
      );
   // Insn that uses rs1, rs2 and imm15 as operands
   assign insn_rd_rs1_imm15 =
      (
         lsu_opc_bus[`NCPU_LSU_STORE] |
         op_wmsr
      );
   // Insn that uses rs1, rs2 and rel15 as operands
   assign insn_rd_rs1_rel15 = is_bcc;
   // Insn that uses imm17 as operand.
   assign insn_uimm17 = op_mhi;
   // Insn that uses rel25 as operand
   assign insn_rel25 = (op_jmp_i | op_jmp_lnk_i);
   // Insn that requires signed imm15.
   assign use_simm15 = (op_xor_i | op_add_i | lsu_opc_bus[`NCPU_LSU_LOAD] | lsu_opc_bus[`NCPU_LSU_STORE]);
   // Insns that have no register operands.
   assign insn_no_rops = (op_mhi | lsu_opc_bus[`NCPU_LSU_BARR] | op_syscall | op_ret | op_jmp_i | op_jmp_lnk_i);
   // Insns that do not writeback ARF
   assign not_wb =
      (
         op_jmp_i | is_bcc | 
         lsu_opc_bus[`NCPU_LSU_STORE] | lsu_opc_bus[`NCPU_LSU_BARR] |
         op_wmsr | epu_opc_bus[`NCPU_EPU_ESYSCALL] | epu_opc_bus[`NCPU_EPU_ERET] |
         epu_opc_bus[`NCPU_EPU_EITM] | epu_opc_bus[`NCPU_EPU_EIPF] |
         epu_opc_bus[`NCPU_EPU_EINSN] |
         epu_opc_bus[`NCPU_EPU_EIRQ]
      );

   // Do not write r0 (nil)
   assign rf_we = ~not_wb & (|rf_waddr);
   assign rf_waddr = (op_jmp_lnk_i) ? `NCPU_REGNO_LNK : f_rd;

   assign read_rd_as_rs2 = (lsu_opc_bus[`NCPU_LSU_STORE] | op_wmsr | is_bcc);

   // Request operand(s) from regfile when needed
   assign rf_rs1_re = ~insn_no_rops;
   assign rf_rs1_addr = f_rs1;
   assign rf_rs2_re = ((~insn_rs1_imm15 & ~insn_uimm17 & ~insn_rel25 & ~insn_no_rops) | read_rd_as_rs2);
   assign rf_rs2_addr = read_rd_as_rs2 ? f_rd : f_rs2;

   // Sign-extended / zero-extended 15bit integer
   assign imm15 = {{CONFIG_DW-15{use_simm15 & f_imm15[14]}}, f_imm15[14:0]};
   // Zero-extended 17bit integer
   assign uimm17 = {{CONFIG_DW-17{1'b0}}, f_imm17[16:0]};
   // Sign-extended 15bit pcrel
   assign rel15 = {{CONFIG_DW-2-15{f_rel15[14]}}, f_rel15[14:0], 2'b00};
   // Sign-extended 25bit pcrel
   assign rel25 = {{CONFIG_DW-2-25{f_rel25[24]}}, f_rel25[24:0], 2'b00};
   // Immediate Operand
   assign imm = ({CONFIG_DW{insn_rs1_imm15|insn_rd_rs1_imm15}} & imm15) |
                  ({CONFIG_DW{insn_rd_rs1_rel15}} & rel15) |
                  ({CONFIG_DW{insn_rel25}} & rel25) |
                  ({CONFIG_DW{insn_uimm17}} & uimm17);

   // synthesis translate_off
`ifndef SYNTHESIS
//`ifdef NCPU_ENABLE_ASSERT

   initial
      begin
         if (`NCPU_EPU_EINSN != `NCPU_EPU_IOPW-1)
            $fatal(1, "\n Check `NCPU_EPU_EINSN, a particular value\n");
      end

//`endif
`endif
   // synthesis translate_on

endmodule
