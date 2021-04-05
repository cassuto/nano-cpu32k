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
   parameter AW `PARAM_NOT_SPECIFIED ,
   parameter DW `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS `PARAM_NOT_SPECIFIED
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

   //
   // SDPRAM block
   //
   // @Input we         Write Enable
   // @Input sram_re    Read Enable
   // @Input waddr      Write address
   // @Input raddr      Read address
   // @Input din        Data input
   // @Output dout_r    Data output
   //
   wire sram_re;
   reg [DW-1:0] mem_vector[(1<<AW)-1:0];
   reg [DW-1:0] dout_r;
   always @(posedge clk) begin
      if (we)
         mem_vector[waddr] <= din;
      if (sram_re)
         dout_r <= mem_vector[raddr];
   end

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
   // Bypass logic
   //
generate
   if (ENABLE_BYPASS) begin : bypass_on
      wire bypass_r;
      wire [DW-1:0] din_r;
      wire conflict = (waddr == raddr & we & re);

      // Bypass FSM
      nDFF_lr #(1, 1'b0) dff_bypass_r
        (clk,rst_n, conflict|re, (conflict | ~re), bypass_r); // Keep bypass_r valid till the next Read
      // Latch din
      nDFF_l #(DW) dff_din_r
        (clk, re, din[DW-1:0], din_r[DW-1:0]);

      assign sram_re = re & ~conflict;
      assign dout = bypass_r ? din_r : dout_r;

   end else begin : bypass_off
      assign sram_re = re;
      assign dout = dout_r;
   end
endgenerate

endmodule
