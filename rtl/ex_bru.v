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

module ex_bru
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0
)
(
   input                               ex_valid,
   input [`NCPU_BRU_IOPW-1:0]          ex_bru_opc_bus,
   input [`PC_W-1:0]                   ex_pc,
   input [CONFIG_DW-1:0]               ex_imm,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   input                               ex_rf_we,
   // From ex_add
   input [CONFIG_DW-1:0]               add_sum,
   input                               add_carry,
   input                               add_overflow,
   // Result
   output                              b_taken,
   output [`PC_W-1:0]                  b_tgt,
   output                              b_lnk,
   output                              is_bcc,
   output                              is_breg,
   output                              is_brel
);
   wire                                cmp_eq;
   wire                                cmp_gt_s;
   wire                                cmp_gt_u;
   wire                                bcc_taken;
   
   // equal
   assign cmp_eq = (ex_operand1 == ex_operand2);
   // greater
   assign cmp_gt_s = (add_sum[CONFIG_DW-1] ^ add_overflow);
   assign cmp_gt_u = ~add_carry;

   assign is_bcc = (ex_bru_opc_bus[`NCPU_BRU_BEQ] |
                     ex_bru_opc_bus[`NCPU_BRU_BNE] |
                     ex_bru_opc_bus[`NCPU_BRU_BGTU] |
                     ex_bru_opc_bus[`NCPU_BRU_BGT] |
                     ex_bru_opc_bus[`NCPU_BRU_BLEU] |
                     ex_bru_opc_bus[`NCPU_BRU_BLE]);
   assign is_breg = (ex_bru_opc_bus[`NCPU_BRU_JMPREG]);
   assign is_brel = (ex_bru_opc_bus[`NCPU_BRU_JMPREL]);
   
   assign bcc_taken = (ex_bru_opc_bus[`NCPU_BRU_BEQ] & cmp_eq) |
                        (ex_bru_opc_bus[`NCPU_BRU_BNE] & ~cmp_eq) |
                        (ex_bru_opc_bus[`NCPU_BRU_BGTU] & cmp_gt_u) |
                        (ex_bru_opc_bus[`NCPU_BRU_BGT] & cmp_gt_s) |
                        (ex_bru_opc_bus[`NCPU_BRU_BLEU] & ~cmp_gt_u) |
                        (ex_bru_opc_bus[`NCPU_BRU_BLE] & ~cmp_gt_s);

   assign b_taken = (ex_valid & (bcc_taken | ex_bru_opc_bus[`NCPU_BRU_JMPREG] | ex_bru_opc_bus[`NCPU_BRU_JMPREL]));

   assign b_tgt =
      // PC-relative 15b addressing
      ({`PC_W{bcc_taken}} & (ex_pc + ex_imm)) |
      // PC-relative 25b addressing
      ({`PC_W{ex_bru_opc_bus[`NCPU_BRU_JMPREL]}} & (ex_pc + ex_operand2[CONFIG_AW-1:`NCPU_P_INSN_LEN])) |
      // Absolute addressing FIXME: alignment check
      ({`PC_W{ex_bru_opc_bus[`NCPU_BRU_JMPREG]}} & ex_operand1[CONFIG_AW-1:`NCPU_P_INSN_LEN]);

   assign b_lnk = ((ex_bru_opc_bus[`NCPU_BRU_JMPREL] | ex_bru_opc_bus[`NCPU_BRU_JMPREG]) & ex_rf_we);

endmodule
