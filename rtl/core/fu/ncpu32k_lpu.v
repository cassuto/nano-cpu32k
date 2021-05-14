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

module ncpu32k_lpu
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
   `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   output                     lpu_stall,
   // From scheduler
   input                      lpu_AVALID,
   input [`NCPU_LPU_IOPW-1:0] lpu_opc_bus,
   input [`NCPU_DW-1:0]       lpu_operand1,
   input [`NCPU_DW-1:0]       lpu_operand2,
   input                      lpu_in_slot_1,
   // To WB
   output                     wb_lpu_AVALID,
   output [`NCPU_DW-1:0]      wb_lpu_dout,
   output                     wb_lpu_in_slot_1
);

   //
   // Multiplier
   //
`ifdef ENABLE_MUL
`endif

   //
   // Divider
   //
`ifdef ENABLE_DIV
`endif
`ifdef ENABLE_DIVU
`endif
`ifdef ENABLE_MOD
`endif
`ifdef ENABLE_MODU
`endif

   // TODO
   assign lpu_stall = 1'b0;
   assign wb_lpu_AVALID = 1'b0;
   assign wb_lpu_dout = {`NCPU_DW{1'b0}};
   assign wb_lpu_in_slot_1 = lpu_in_slot_1;

endmodule
