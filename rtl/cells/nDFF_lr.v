/**@file
 * Cell - DFF (D Flip Flop) with sync Load and async Reset Port.
 */

/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module nDFF_lr # (
   parameter DW = 1, // Data Width in bits
   parameter RST_VECTOR = {DW{1'b0}}
)
(
   input CLK,
   input RST_n,
   input LOAD,
   input [DW-1:0] D, // Data input
`ifdef NCPU_NO_RST
   output reg [DW-1:0] Q = RST_VECTOR
`else
   output reg [DW-1:0] Q // Data output
`endif
);
`ifdef NCPU_NO_RST
   always @(posedge CLK) begin
      if (LOAD)
         `ifdef SYNTHESIS
         Q <= D;
         `else
         Q <= #1 D;
         `endif
   end
`else
   always @(posedge CLK or negedge RST_n) begin
      if (!RST_n)
         Q <= RST_VECTOR;
      else if (LOAD)
         `ifdef SYNTHESIS
         Q <= D;
         `else
         Q <= #1 D;
         `endif
   end
`endif

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
`ifdef NCPU_CHECK_X
   always @(posedge CLK) begin
      if((^D) === 1'bx)
         $fatal ("\n DFF: uncertain state! \n");
   end
`endif
`endif

`endif
   // synthesis translate_on
endmodule
