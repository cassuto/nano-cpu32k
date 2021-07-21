/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_bru_s2
(
   // From stage 1
   input [`NCPU_BRU_IOPW-1:0] s1o_wb_bru_opc_bus,
   input [`NCPU_AW-3:0]       s1o_wb_bru_pc,
   input [`NCPU_DW-1:0]       s1o_wb_bru_operand1,
   input [`NCPU_DW-1:0]       s1o_wb_bru_operand2,
   input [14:0]               s1o_wb_bru_rel15,
   // To stage 2
   output                     s2i_bru_branch_taken,
   output [`NCPU_AW-3:0]      s2i_bru_branch_tgt
);
   wire                       cmp_eq;
   wire                       cmp_gt_s, cmp_gt_u;
   wire                       adder_carry_out;
   wire                       adder_overflow;
   wire [`NCPU_DW-1:0]        adder_op2;
   wire [`NCPU_DW-1:0]        adder_dout;
   wire                       bcc_taken;

   //
   // Comparator
   //

   // operand2 - operand1
   assign adder_op2 = ~s1o_wb_bru_operand1;
   assign {adder_carry_out, adder_dout} = s1o_wb_bru_operand2 + adder_op2 + {{`NCPU_DW-1{1'b0}}, 1'b1};
   assign adder_overflow = (s1o_wb_bru_operand2[`NCPU_DW-1] == adder_op2[`NCPU_DW-1]) &
                          (s1o_wb_bru_operand2[`NCPU_DW-1] ^ adder_dout[`NCPU_DW-1]);

   // equal
   assign cmp_eq = (s1o_wb_bru_operand1 == s1o_wb_bru_operand2);
   // greater
   assign cmp_gt_s = (adder_dout[`NCPU_DW-1] != adder_overflow);
   assign cmp_gt_u = ~adder_carry_out;

   assign bcc_taken = (s1o_wb_bru_opc_bus[`NCPU_BRU_BEQ] & cmp_eq) |
                        (s1o_wb_bru_opc_bus[`NCPU_BRU_BNE] & ~cmp_eq) |
                        (s1o_wb_bru_opc_bus[`NCPU_BRU_BGTU] & cmp_gt_u) |
                        (s1o_wb_bru_opc_bus[`NCPU_BRU_BGT] & cmp_gt_s) |
                        (s1o_wb_bru_opc_bus[`NCPU_BRU_BLEU] & ~cmp_gt_u) |
                        (s1o_wb_bru_opc_bus[`NCPU_BRU_BLE] & ~cmp_gt_s);

   assign s2i_bru_branch_tgt =
      // PC-relative 15b addressing
      ((s1o_wb_bru_pc + {{`NCPU_AW-2-15{s1o_wb_bru_rel15[14]}}, s1o_wb_bru_rel15[14:0]})  & {`NCPU_AW-2{bcc_taken}}) |
      // PC-relative 25b addressing
      ((s1o_wb_bru_pc + s1o_wb_bru_operand2[`NCPU_DW-1:2]) & {`NCPU_AW-2{s1o_wb_bru_opc_bus[`NCPU_BRU_JMPREL]}}) |
      // Absolute addressing (No align check)
      (s1o_wb_bru_operand1[`NCPU_AW-1:2] & {`NCPU_AW-2{s1o_wb_bru_opc_bus[`NCPU_BRU_JMPREG]}});

   assign s2i_bru_branch_taken = (bcc_taken | s1o_wb_bru_opc_bus[`NCPU_BRU_JMPREG] | s1o_wb_bru_opc_bus[`NCPU_BRU_JMPREL]);


endmodule
