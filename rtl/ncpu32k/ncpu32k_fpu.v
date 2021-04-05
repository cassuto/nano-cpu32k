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

module ncpu32k_fpu
#(
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   output                     fpu_AREADY,
   input                      fpu_AVALID,
   input [`NCPU_DW-1:0]       fpu_operand_1,
   input [`NCPU_DW-1:0]       fpu_operand_2,
   input [CONFIG_ROB_DEPTH_LOG2-1:0]      fpu_AID,
   input [`NCPU_FPU_IOPW-1:0] fpu_opc_bus,
   input                      fpu_BREADY,
   output                     fpu_BVALID,
   output [CONFIG_ROB_DEPTH_LOG2-1:0]     fpu_BID,
   output [`NCPU_DW-1:0]      fpu_BDATA
);

   // TODO
   assign fpu_AREADY = 1'b0;
   assign fpu_BVALID = 1'b0;
   assign fpu_BID = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
   assign fpu_BDATA = {`NCPU_DW{1'b0}};

endmodule
