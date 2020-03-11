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

module ncpu32k_ie_au(         
   input                      clk,
   input                      rst_n,
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_AU_IOPW-1:0]  ieu_au_opc_bus,
   input                      ieu_au_cmp_eq,
   input                      ieu_au_cmp_signed,
   output                     au_op_adder,
   output [`NCPU_DW-1:0]      au_adder,
   output                     au_op_mhi,
   output [`NCPU_DW-1:0]      au_mhi,
   output                     au_cc_we,
   output                     au_cc_nxt,
   output [`NCPU_DW-1:0]      au_mul,
   output [`NCPU_DW-1:0]      au_div
);
   
   // Full Adder
   wire [`NCPU_DW-1:0] adder_operand2_com;
   wire                adder_sub;
   wire                adder_carry_in;
   wire                adder_carry_out;
   wire                adder_overflow;
   
   assign adder_sub = ieu_au_opc_bus[`NCPU_AU_SUB] | ieu_au_opc_bus[`NCPU_AU_CMP];
   assign adder_carry_in = adder_sub;
   assign adder_operand2_com = adder_sub ? ~ieu_operand_2 : ieu_operand_2;

   assign {adder_carry_out, au_adder} = ieu_operand_1 + adder_operand2_com + {{`NCPU_DW-1{1'b0}}, adder_carry_in};

   assign adder_overflow = (ieu_operand_1[`NCPU_DW-1] == adder_operand2_com[`NCPU_DW-1]) &
                          (ieu_operand_1[`NCPU_DW-1] ^ au_adder[`NCPU_DW-1]);

   assign au_op_adder = ieu_au_opc_bus[`NCPU_AU_ADD] | ieu_au_opc_bus[`NCPU_AU_SUB];

   // Comparator
   assign au_cc_we = ieu_au_opc_bus[`NCPU_AU_CMP];
   // equal
   wire cmp_eq = ieu_operand_1 == ieu_operand_2;
   // greater
   wire cmp_gt_s = (au_adder[`NCPU_DW-1] == adder_overflow) & ~cmp_eq;
   wire cmp_gt_u = adder_carry_out & ~cmp_eq;
   
   assign au_cc_nxt = (ieu_au_cmp_eq & cmp_eq) |
                     (~ieu_au_cmp_eq & ~ieu_au_cmp_signed & cmp_gt_u) |
                     (~ieu_au_cmp_eq & ieu_au_cmp_signed & cmp_gt_s);

   // Multiplier
`ifdef ENABLE_MUL
`endif

   // Divider
`ifdef ENABLE_DIV
`endif
`ifdef ENABLE_DIVU
`endif
`ifdef ENABLE_MOD
`endif
`ifdef ENABLE_MODU
`endif

   // Move HI18
   assign au_op_mhi = ieu_au_opc_bus[`NCPU_AU_MHI];
   assign au_mhi = {ieu_operand_2[17:0], 14'b0};

endmodule
