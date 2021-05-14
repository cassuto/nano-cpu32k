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

module ncpu32k_bypass_network
(
   input                      clk,
   input                      en,
   input [`NCPU_REG_AW-1:0]   i_operand_rf_addr,
   input [`NCPU_DW-1:0]       i_operand,
   output [`NCPU_DW-1:0]      o_operand,

   // WB 1st slot (LISTENING)
   input                      wb_slot_1_BVALID,
   input                      wb_slot_1_rd_we,
   input [`NCPU_REG_AW-1:0]   wb_slot_1_rd_addr,
   input [`NCPU_DW-1:0]       wb_slot_1_dout,
   // WB 2rd slot (LISTENING)
   input                      wb_slot_2_BVALID,
   input                      wb_slot_2_rd_we,
   input [`NCPU_REG_AW-1:0]   wb_slot_2_rd_addr,
   input [`NCPU_DW-1:0]       wb_slot_2_dout
);
   wire [1:0]                 bypass_r, bypass_nxt;
   wire [`NCPU_DW-1:0]        wb_slot_1_dout_r;
   wire [`NCPU_DW-1:0]        wb_slot_2_dout_r;
   wire [`NCPU_REG_AW-1:0] rf_addr_r;

   assign bypass_nxt = (wb_slot_2_BVALID & wb_slot_2_rd_we & (wb_slot_2_rd_addr == i_operand_rf_addr))
                           ? 2'b10
                           : (wb_slot_1_BVALID & wb_slot_1_rd_we & (wb_slot_1_rd_addr == i_operand_rf_addr))
                              ? 2'b01
                              : 2'b00;
   // Data path
   nDFF_l #(2) dff_wb_slot_1_bypass_r
      (clk, en, bypass_nxt, bypass_r);

   nDFF_l #(`NCPU_REG_AW) dff_rf_addr_r
      (clk, en, i_operand_rf_addr, rf_addr_r);

   nDFF_l #(`NCPU_DW) dff_wb_slot_1_dout_r
      (clk, en, wb_slot_1_dout, wb_slot_1_dout_r);
   nDFF_l #(`NCPU_DW) dff_wb_slot_2_dout_r
      (clk, en, wb_slot_2_dout, wb_slot_2_dout_r);

   // Slot #2 is prior to slot #1 in order to get the right value when there is WAW dependency.
   // Earlier stage is prior to the older stage, to get latest value when RAW

   assign o_operand = (wb_slot_2_BVALID & wb_slot_2_rd_we & (wb_slot_2_rd_addr == rf_addr_r))
                        ? wb_slot_2_dout
                        : (wb_slot_1_BVALID & wb_slot_1_rd_we & (wb_slot_1_rd_addr == rf_addr_r))
                           ? wb_slot_1_dout
                           : (bypass_r[1])
                              ? wb_slot_2_dout_r
                              : (bypass_r[0])
                                 ? wb_slot_1_dout_r
                                 : i_operand;

endmodule
