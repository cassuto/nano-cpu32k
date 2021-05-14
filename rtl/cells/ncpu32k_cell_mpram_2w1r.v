/**@file
 * Cell - Multi-port Static RAM
 */

/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
/*  See this repo: https://github.com/cassuto/ramfile for details.         */
/*                                                                         */
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

module ncpu32k_cell_mpram_2w1r
#(
   parameter AW
   `PARAM_NOT_SPECIFIED ,
   parameter DW
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W1
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W2
   `PARAM_NOT_SPECIFIED
)
(
   input                         clk,
   input                         rst_n,
   input                         we1,
   input [AW-1:0]                waddr1,
   input [DW-1:0]                wdata1,
   input                         we2,
   input [AW-1:0]                waddr2,
   input [DW-1:0]                wdata2,
   input                         re,
   input [AW-1:0]                raddr,
   output [DW-1:0]               rdata
);
   //
   // FPGA timing optimized version
   //
   
   wire [DW-1:0]                 dout;
   wire [DW-1:0]                 dout0;
   wire [DW-1:0]                 dout1;
   reg                           sel_map[(1<<AW)-1:0];
   reg                           sel_map_out;

   // instance of sync dpram #0
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS (0)
      )
   BANK_0
      (
         .clk          (clk),
         .rst_n        (rst_n),
         .dout         (dout0),
         .raddr        (raddr),
         .re           (re),
         .waddr        (waddr1),
         .we           (we1),
         .din          (wdata1)
      );
   // instance of sync dpram #1
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS (0)
      )
   BANK_1
      (
         .clk          (clk),
         .rst_n        (rst_n),
         .dout         (dout1),
         .raddr        (raddr),
         .re           (re),
         .waddr        (waddr2),
         .we           (we2),
         .din          (wdata2)
      );
      
   always @(posedge clk)
      if (re)
         sel_map_out <= sel_map[raddr];

   // mux
   assign dout = sel_map_out ? dout1 : dout0;

   /*
   Read
   */
   generate
      if (ENABLE_BYPASS_W1 || ENABLE_BYPASS_W2)
         begin : bypass_gen
            wire bypass_r;
            wire [DW-1:0] din_r;
            wire [DW-1:0] din_nxt;
            wire [1:0] conflict;
            
            if (ENABLE_BYPASS_W2)
               assign conflict[1] = we2 && (raddr==waddr2);
            else
               assign conflict[1] = 1'b0;
            if (ENABLE_BYPASS_W1)
               assign conflict[0] = we1 && (raddr==waddr1);
            else
               assign conflict[0] = 1'b0;

            assign din_nxt = conflict[1] ? wdata2 : wdata1;

            // Bypass FSM
            nDFF_lr #(1, 1'b0) dff_bypass_r
               (clk,rst_n, (|conflict)|re, ((|conflict) | ~re), bypass_r); // Keep bypass_r valid till the next Read
            // Latch din
            nDFF_l #(DW) dff_din_r
               (clk, re, din_nxt[DW-1:0], din_r[DW-1:0]);

            assign rdata = bypass_r ? din_r : dout;
         end
      else
         begin
            assign rdata = dout;
         end
   endgenerate
      
   /*
   Process selection map
   */
   always @(posedge clk)
      begin
         if (we1)
               sel_map[waddr1] <= 'd0;
         if (we2)
               sel_map[waddr2] <= 'd1;
      end

endmodule
