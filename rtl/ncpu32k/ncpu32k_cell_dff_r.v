/**@file
 * Cell - DFF (Data Flip Flop) with Reset Port
 */

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

module ncpu32k_cell_dff_r # (
   parameter DW = 1, // Data Width in bits
   parameter RST_VECTOR = {DW{1'b0}}
)
(
   input CLK,
   input RST_n,
   input [DW-1:0] D, // Data input
   output reg [DW-1:0] Q // Data output
);
   always @(posedge CLK or negedge RST_n) begin
     if (!RST_n)
       Q <= RST_VECTOR;
     else
       Q <= #1 D;
   end
endmodule