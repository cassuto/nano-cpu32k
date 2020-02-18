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
   output                     ie_au_ready_in, /* ops is accepted by ie_au */
   input                      ie_au_valid_in, /* ops is presented at ie_au's input */
   output [`NCPU_DW-1:0]      ieu_operand_1,
   output [`NCPU_DW-1:0]      ieu_operand_2,
   output [`NCPU_AU_IOPW-1:0] ieu_au_opc_bus,
);

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

endmodule
