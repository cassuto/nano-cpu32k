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

module ncpu32k_bru
(
   // From scheduler
   input                      bru_AVALID,
   input [`NCPU_AW-3:0]       bru_pc,
   input [`NCPU_BRU_IOPW-1:0] bru_opc_bus,
   input [`NCPU_DW-1:0]       bru_operand1,
   input [`NCPU_DW-1:0]       bru_operand2,
   input [14:0]               bru_rel15,
   input                      bru_in_slot_1,
   // To WB
   output                     wb_bru_AVALID,
   output [`NCPU_DW-1:0]      wb_bru_dout,
   output                     wb_bru_branch_taken,
   output [`NCPU_AW-3:0]      wb_bru_branch_tgt,
   output                     wb_bru_is_bcc,
   output                     wb_bru_is_breg,
   output                     wb_bru_in_slot_1
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
   assign adder_op2 = ~bru_operand1;
   assign {adder_carry_out, adder_dout} = bru_operand2 + adder_op2 + {{`NCPU_DW-1{1'b0}}, 1'b1};
   assign adder_overflow = (bru_operand2[`NCPU_DW-1] == adder_op2[`NCPU_DW-1]) &
                          (bru_operand2[`NCPU_DW-1] ^ adder_dout[`NCPU_DW-1]);

   // equal
   assign cmp_eq = (bru_operand1 == bru_operand2);
   // greater
   assign cmp_gt_s = (adder_dout[`NCPU_DW-1] != adder_overflow);
   assign cmp_gt_u = ~adder_carry_out;

   assign bcc_taken = (bru_opc_bus[`NCPU_BRU_BEQ] & cmp_eq) |
                        (bru_opc_bus[`NCPU_BRU_BNE] & ~cmp_eq) |
                        (bru_opc_bus[`NCPU_BRU_BGTU] & cmp_gt_u) |
                        (bru_opc_bus[`NCPU_BRU_BGT] & cmp_gt_s) |
                        (bru_opc_bus[`NCPU_BRU_BLEU] & ~cmp_gt_u) |
                        (bru_opc_bus[`NCPU_BRU_BLE] & ~cmp_gt_s);

   assign wb_bru_branch_tgt =
      // PC-relative 15b addressing
      ((bru_pc + {{`NCPU_AW-2-15{bru_rel15[14]}}, bru_rel15[14:0]})  & {`NCPU_AW-2{bcc_taken}}) |
      // PC-relative 25b addressing
      ((bru_pc + bru_operand2[`NCPU_DW-1:2]) & {`NCPU_AW-2{bru_opc_bus[`NCPU_BRU_JMPREL]}}) |
      // Absolute addressing (No align check)
      (bru_operand1[`NCPU_AW-1:2] & {`NCPU_AW-2{bru_opc_bus[`NCPU_BRU_JMPREG]}});

   assign wb_bru_branch_taken = (bcc_taken | bru_opc_bus[`NCPU_BRU_JMPREG] | bru_opc_bus[`NCPU_BRU_JMPREL]);

   assign wb_bru_is_bcc = (bru_opc_bus[`NCPU_BRU_BEQ] |
                           bru_opc_bus[`NCPU_BRU_BNE] |
                           bru_opc_bus[`NCPU_BRU_BGTU] |
                           bru_opc_bus[`NCPU_BRU_BGT] |
                           bru_opc_bus[`NCPU_BRU_BLEU] |
                           bru_opc_bus[`NCPU_BRU_BLE]);
   
   assign wb_bru_is_breg = bru_opc_bus[`NCPU_BRU_JMPREG];

   assign wb_bru_AVALID = bru_AVALID;

   assign wb_bru_dout = {(bru_pc + 1'b1), 2'b00}; // Link addr

   assign wb_bru_in_slot_1 = bru_in_slot_1;

endmodule
