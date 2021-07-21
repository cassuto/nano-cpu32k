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

module ncpu32k_bypass_op
(
   input                      clk,
   input                      en,
   input [`NCPU_REG_AW-1:0]   i_operand_rf_addr,
   input [`NCPU_DW-1:0]       i_operand,
   output [`NCPU_DW-1:0]      o_operand,
   output                     byp_op_stall,
   
   // From scheduler (LISTENING)
   input                      lsu_AVALID,
   input                      lsu_in_slot_1,

   // Stage 1 of backend: 1st slot (LISTENING)
   input                      s1i_slot_1_BVALID,
   input                      s1i_slot_1_rd_we,
   input [`NCPU_REG_AW-1:0]   s1i_slot_1_rd_addr,
   input [`NCPU_DW-1:0]       s1i_slot_1_dout,
   // Stage 1 of backend: 2rd slot (LISTENING)
   input                      s1i_slot_2_BVALID,
   input                      s1i_slot_2_rd_we,
   input [`NCPU_REG_AW-1:0]   s1i_slot_2_rd_addr,
   input [`NCPU_DW-1:0]       s1i_slot_2_dout,
   
   // Stage 2 of backend: 1st slot (LISTENING)
   input                      s2i_slot_1_BVALID,
   input                      s2i_slot_1_rd_we,
   input [`NCPU_REG_AW-1:0]   s2i_slot_1_rd_addr,
   input [`NCPU_DW-1:0]       s2i_slot_1_dout,
   // Stage 2 of backend: 2rd slot (LISTENING)
   input                      s2i_slot_2_BVALID,
   input                      s2i_slot_2_rd_we,
   input [`NCPU_REG_AW-1:0]   s2i_slot_2_rd_addr,
   input [`NCPU_DW-1:0]       s2i_slot_2_dout
);
   wire [3:0]                 bypass_r, bypass_nxt;
   wire [`NCPU_DW-1:0]        s1i_slot_1_dout_r;
   wire [`NCPU_DW-1:0]        s1i_slot_2_dout_r;
   wire [`NCPU_DW-1:0]        s2i_slot_1_dout_r;
   wire [`NCPU_DW-1:0]        s2i_slot_2_dout_r;
   wire [`NCPU_REG_AW-1:0]    rf_addr_r;

   // There is no bypass path from LSU, so if we have RAW dependency with LSU,
   // stall the insn issue
   assign byp_op_stall = en & (
                        (lsu_AVALID & ~lsu_in_slot_1 & s1i_slot_2_rd_we & (s1i_slot_2_rd_addr == i_operand_rf_addr)) |
                        (lsu_AVALID & lsu_in_slot_1 & s1i_slot_1_rd_we & (s1i_slot_1_rd_addr == i_operand_rf_addr)));
   
   // Slot #2 is prior to slot #1 in order to get the right value when there is WAW dependency.
   // Earlier stage is prior to the older stage, to get latest value when RAW
   assign bypass_nxt = (s1i_slot_2_BVALID & s1i_slot_2_rd_we & (s1i_slot_2_rd_addr == i_operand_rf_addr))
                           ? 4'b1000
                           : (s1i_slot_1_BVALID & s1i_slot_1_rd_we & (s1i_slot_1_rd_addr == i_operand_rf_addr))
                              ? 4'b0100
                              : (s2i_slot_2_BVALID & s2i_slot_2_rd_we & (s2i_slot_2_rd_addr == i_operand_rf_addr))
                                 ? 4'b0010
                                 : (s2i_slot_1_BVALID & s2i_slot_1_rd_we & (s2i_slot_1_rd_addr == i_operand_rf_addr))
                                    ? 4'b0001
                                    : 4'b0000;
   // Data path
   nDFF_l #(4) dff_s2i_slot_1_bypass_r
      (clk, en, bypass_nxt, bypass_r);

   nDFF_l #(`NCPU_REG_AW) dff_rf_addr_r
      (clk, en, i_operand_rf_addr, rf_addr_r);

   nDFF_l #(`NCPU_DW) dff_s1i_slot_1_dout_r
      (clk, en, s1i_slot_1_dout, s1i_slot_1_dout_r);
   nDFF_l #(`NCPU_DW) dff_s1i_slot_2_dout_r
      (clk, en, s1i_slot_2_dout, s1i_slot_2_dout_r);
   nDFF_l #(`NCPU_DW) dff_s2i_slot_1_dout_r
      (clk, en, s2i_slot_1_dout, s2i_slot_1_dout_r);
   nDFF_l #(`NCPU_DW) dff_s2i_slot_2_dout_r
      (clk, en, s2i_slot_2_dout, s2i_slot_2_dout_r);

   assign o_operand = (bypass_r[3])
                        ? s1i_slot_2_dout_r
                        : (bypass_r[2])
                           ? s1i_slot_1_dout_r
                           : (bypass_r[1])
                              ? s2i_slot_2_dout_r
                              : (bypass_r[0])
                                 ? s2i_slot_1_dout_r
                                 : i_operand;

endmodule
