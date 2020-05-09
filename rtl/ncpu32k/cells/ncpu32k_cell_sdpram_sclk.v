/**@file
 * Cell - Simple Double-port Sync RAM
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

`include "ncpu32k_config.h"

module ncpu32k_cell_sdpram_sclk
#(
   parameter AW=-1,
   parameter DW=-1,
   parameter ENABLE_BYPASS=-1
)
(
   input                         clk,
   input                         rst_n,
   input [AW-1:0]                raddr,
   input                         re,
   input [AW-1:0]                waddr,
   input                         we,
   input [DW-1:0]                din,
   output [DW-1:0]               dout
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

   reg [DW-1:0] dout_r = 0;
   // Bypass
   reg bypass;
   reg [DW-1:0] din_r;
generate
   if (ENABLE_BYPASS) begin : bypass_on
      assign dout = bypass ? din_r : dout_r;

      always @(posedge clk or negedge rst_n)
         if(~rst_n)
            din_r <= {DW{1'b0}};
         else if (re)
            din_r <= din;

      // Bypass FSM
      always @(posedge clk or negedge rst_n)
         if (~rst_n)
            bypass <= 0;
         else if (waddr == raddr & we & re)
            bypass <= 1;
         else if (re) // Keep bypass valid till the next Read
            bypass <= 0;
   end else begin : bypass_off
      assign dout = dout_r;
   end
endgenerate

   // SRAM block
   // Write & Read
   always @(posedge clk) begin
      if (we)
         mem_vector[waddr] <= din;
      if (re)
         dout_r <= mem_vector[raddr];
   end

endmodule
