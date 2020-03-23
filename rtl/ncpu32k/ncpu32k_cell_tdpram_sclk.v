/**@file
 * Cell - True Double-port Sync RAM
 * Timing info:
 * 1. WRITE first strategy (On the same port, dout is valid immediately when din is
 *       written and dout is enabled)
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
   parameter AW=-1,
   parameter DW=-1,
   parameter ENABLE_BYPASS_B2A=-1
)
(
   input                         clk,
   input                         rst_n,
   // Port A
   input [AW-1:0]                addr_a,
   input                         we_a,
   input [DW-1:0]                din_a,
   output [DW-1:0]               dout_a,
   input                         en_a,
   // Port B
   input [AW-1:0]                addr_b,
   input                         we_b,
   input [DW-1:0]                din_b,
   output [DW-1:0]               dout_b,
   input                         en_b
);

   reg [DW-1:0] mem_vector[(1<<AW)-1:0];
   
   // synthesis translate_off
`ifndef SYNTHESIS 
   initial begin : ini
      integer i;
      for(i=0; i < (1<<AW); i=i+1)
         mem_vector[i] = {DW{1'b0}};
   end
`endif
   // synthesis translate_on

   //
   // Read & Write Port A
   //
   reg [DW-1:0] dout_a_r = 0;

   always @(posedge clk) begin
      if (en_a & we_a) begin
         mem_vector[addr_a] <= din_a;
         dout_a_r <= din_a;
      end else if (en_a) begin
         dout_a_r <= mem_vector[addr_a];
      end
   end
   
   //
   // Read & Write Port B
   //
   reg [DW-1:0] dout_b_r = 0;

   always @(posedge clk) begin
      if (en_b & we_b) begin
         mem_vector[addr_b] <= din_b;
         dout_b_r <= din_b;
      end else if (en_b) begin
         dout_b_r <= mem_vector[addr_b];
      end
   end

   // Bypass
generate
   if (ENABLE_BYPASS_B2A) begin : bypass_on
      reg bypass;
      reg [DW-1:0] din_b_r;
      assign dout_a = bypass ? din_b_r : dout_a_r;

      always @(posedge clk or negedge rst_n)
         if (~rst_n)
            din_b_r <= {DW{1'b0}};
         else if (en_a)
            din_b_r <= din_b;

      // Bypass FSM
      always @(posedge clk or negedge rst_n)
         if (~rst_n)
            bypass <= 0;
         else if (addr_a == addr_b & en_b&we_b & en_a)
            bypass <= 1;
         else if (en_a) // Keep bypass valid till the next Read
            bypass <= 0;
            
   end else begin : bypass_off
      assign dout_a = dout_a_r;
   end
endgenerate

   assign dout_b = dout_b_r;

   // synthesis translate_off
`ifndef SYNTHESIS 
   
   // Assertions 03060725
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if(en_a&we_a & en_b&we_b & addr_a==addr_b) begin
         $fatal ("\n DPEAM accessing conflict.\n");
      end
   end
`endif
   
`endif
   // synthesis translate_on
   
endmodule
