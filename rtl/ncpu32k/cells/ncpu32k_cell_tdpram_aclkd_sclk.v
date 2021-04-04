/**@file
 * Cell - True Double-port Async clock domain RAM
 * Write first mode
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
   parameter DW
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
   genvar i,j;
   reg [DW-1:0] mem_vector[(1<<AW)-1:0];

   // synthesis translate_off
`ifndef SYNTHESIS
   initial begin : ini
      integer k;
      for(k=0; k<(1<<AW); k=k+1) begin
         mem_vector[k] = {DW{1'b0}};
      end
   end
`endif
   // synthesis translate_on

   //
   // Read & Write Port A
   //
   reg [DW-1:0] dout_a_r = 0;

generate
   for(i=0;i<DW/8;i=i+1)
      always @(posedge clk_a)
         if(en_a & we_a[i])
            mem_vector[addr_a][(i+1)*8-1:i*8] <= din_a[(i+1)*8-1:i*8];
endgenerate
   always @(posedge clk_a)
      if (en_a & |we_a)
         dout_a_r <= din_a;
      else if(en_a)
         dout_a_r <= mem_vector[addr_a];

   //
   // Read & Write Port B
   //
   reg [DW-1:0] dout_b_r = 0;

generate
   for(j=0;j<DW/8;j=j+1)
      always @(posedge clk_b)
         if(en_b & we_b[j])
            mem_vector[addr_b][(j+1)*8-1:j*8] <= din_b[(j+1)*8-1:j*8];
endgenerate
   always @(posedge clk_b)
      if (en_b & |we_b)
         dout_b_r <= din_b;
      else if(en_b)
         dout_b_r <= mem_vector[addr_b];

   assign dout_a = dout_a_r;
   assign dout_b = dout_b_r;

endmodule
