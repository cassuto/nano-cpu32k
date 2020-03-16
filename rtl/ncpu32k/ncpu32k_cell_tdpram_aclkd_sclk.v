/**@file
 * Cell - True Double-port Async clock domain RAM
 * Read first mode
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

module ncpu32k_cell_tdpram_aclkd_sclk
#(
   parameter AW,
   parameter DW,
   parameter CLEAR_ON_INIT = 1
)
(
   // Port A
   input                         clk_a,
   input [AW-1:0]                addr_a,
   input [DW/8-1:0]              we_a,
   input [DW-1:0]                din_a,
   output [DW-1:0]               dout_a,
   input                         en_a,
   // Port B
   input                         clk_b,
   input [AW-1:0]                addr_b,
   input [DW/8-1:0]              we_b,
   input [DW-1:0]                din_b,
   output [DW-1:0]               dout_b,
   input                         en_b
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
   reg [DW-1:0]     dout_a_r = 0;

generate
   genvar i;
   for(i=0;i<DW/8;i=i+1) begin
      always @(posedge clk_a)
         if(en_a & we_a[i])
            mem_vector[addr_a][i*8-1:(i-1)*8] <= din_a[(i+1)*8-1:i*8];
   end
endgenerate
   always @(posedge clk_a)
      if (en_a)
         dout_a_r <= mem_vector[addr_a];
   
   //
   // Read & Write Port B
   //
   reg [DW-1:0]     dout_b_r = 0;

generate
   for(i=0;i<DW/8;i=i+1) begin
      always @(posedge clk_b)
         if(en_b & we_b[i])
            mem_vector[addr_b][i*8-1:(i-1)*8] <= din_b[(i+1)*8-1:i*8];
   end
endgenerate
   always @(posedge clk_b)
      if (en_b)
         dout_b_r <= mem_vector[addr_b];
   
   assign dout_a = dout_a_r;
   assign dout_b = dout_b_r;

endmodule
