/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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
   parameter CONFIG_ENABLE_MUL `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIV `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIVU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MOD `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MODU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   output                     lpu_AREADY,
   input                      lpu_AVALID,
   input [`NCPU_DW-1:0]       lpu_operand_1,
   input [`NCPU_DW-1:0]       lpu_operand_2,
   input [CONFIG_ROB_DEPTH_LOG2-1:0]      lpu_AID,
   input [`NCPU_LPU_IOPW-1:0] lpu_opc_bus,
   input                      lpu_BREADY,
   output                     lpu_BVALID,
   output [CONFIG_ROB_DEPTH_LOG2-1:0]     lpu_BID,
   output [`NCPU_DW-1:0]      lpu_BDATA
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
   assign lpu_AREADY = 1'b0;
   assign lpu_BVALID = 1'b0;
   assign lpu_BID = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
   assign lpu_BDATA = {`NCPU_DW{1'b0}};

endmodule
