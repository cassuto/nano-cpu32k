/**@file
 * Cell - True Double-port Sync RAM
 * WRITE strategy (On the same port, dout is valid immediately when dout is written)
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

module ncpu32k_cell_tdpram_sclk
#(
   parameter AW = 32,
   parameter DW = 32,
   parameter CLEAR_ON_INIT = 1
)
(
   input                         clk,
   input                         rst_n,
   // Port A
   input [AW-1:0]                addr_a,
   input                         we_a,
   input [DW-1:0]                din_a,
   output [DW-1:0]               dout_a,
   // Port B
   input [AW-1:0]                addr_b,
   input                         we_b,
   input [DW-1:0]                din_b,
   output [DW-1:0]               dout_b
);
   reg [DW-1:0] mem_vector[(1<<AW)-1:0];
   
   // Initial block. For verification only.
   generate
      if(CLEAR_ON_INIT) begin :clear_on_init
         integer i;
         initial
            for(i=0; i < (1<<AW); i=i+1)
               mem_vector[i] = {DW{1'b0}};
      end
   endgenerate

   //
   // Read & Write Port A
   //
   reg [DW-1:0]     dout_a_r;

   always @(posedge clk) begin
      if (we_a) begin
         mem_vector[addr_a] <= din_a;
         dout_a_r <= din_a;
      end else begin
         dout_a_r <= mem_vector[addr_a];
      end
   end
   
   assign dout_a = dout_a_r;

   //
   // Read & Write Port B
   //
   reg [DW-1:0]     dout_b_r;

   always @(posedge clk) begin
      if (we_b) begin
         mem_vector[addr_b] <= din_b;
         dout_b_r <= din_b;
      end else begin
         dout_b_r <= mem_vector[addr_b];
      end
   end
   
   assign dout_b = dout_b_r;

endmodule
