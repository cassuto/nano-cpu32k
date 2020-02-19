/**@file
 * Cell - Pipe buffer
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

module ncpu32k_cell_pipebuf
# (
   parameter DW = 1, // Data Width in bits
   parameter ENABLE_BYPASS = 1 // bypass when popping
)
(
   input                      clk,
   input                      rst_n,
   input [DW-1:0]             din,
   output [DW-1:0]            dout,
   input                      in_valid,
   output                     in_ready,
   output                     out_valid,
   input                      out_ready
);

   wire push = (in_valid & in_ready);
   wire pop = (out_valid & out_ready);
   
   //
   // Equivalent to 1-slot FIFO
   //
   wire valid_nxt = (push | ~pop);
   
   ncpu32k_cell_dff_lr #(1) dff_out_valid
                   (clk,rst_n, (push | pop), valid_nxt, out_valid);
   
   ncpu32k_cell_dff_lr #(DW) dff_dout
                   (clk,rst_n, push, din, dout);
   
   generate
      if (ENABLE_BYPASS) begin :enable_bypass
         assign in_ready = ~out_valid | pop;
      end else begin
         assign in_ready = ~out_valid;
      end
   endgenerate
   
endmodule
