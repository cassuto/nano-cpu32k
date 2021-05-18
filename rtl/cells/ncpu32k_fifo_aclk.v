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

module ncpu32k_fifo_aclk
#(
   parameter DW `PARAM_NOT_SPECIFIED , // Data bits
   parameter AW `PARAM_NOT_SPECIFIED  // Address bits
)
(
   input wclk,
   input wrst_n,
   input rclk,
   input rrst_n,
   input [DW-1:0] din,
   input push,
   input pop,
   output [DW-1:0] dout,
   output reg full,
   output reg empty
);

   reg [AW:0] rptr_b, wptr_b;
   reg [AW:0] rptr_g, wptr_g;

   // Generate read pointer
   wire [AW:0] rptr_b_nxt = ~empty ? rptr_b + {{AW-1{1'b0}}, pop} : rptr_b;
   wire [AW:0] rptr_g_nxt = {1'b0,rptr_b_nxt[AW:1]} ^ rptr_b_nxt; // binary-to-gray encoder
   always @(posedge rclk or negedge rrst_n)
      if (~rrst_n) {rptr_b, rptr_g} <= 0;
      else {rptr_b, rptr_g} <= {rptr_b_nxt, rptr_g_nxt};

   // Generate write pointer
   wire [AW:0] wptr_b_nxt = ~full ? wptr_b + {{AW-1{1'b0}}, push} : wptr_b;
   wire [AW:0] wptr_g_nxt = {1'b0, wptr_b_nxt[AW:1]} ^ wptr_b_nxt;   // binary-to-gray encoder
   always @(posedge wclk or negedge wrst_n)
      if (~wrst_n) {wptr_b, wptr_g} <= 0;
      else {wptr_b, wptr_g} <= {wptr_b_nxt, wptr_g_nxt};

   (* ASYNC_REG = "TRUE" *) reg [AW:0] rptr_g_r [1:0], wptr_g_r [1:0];

   // Sync read poiner
   always @(posedge rclk or negedge rrst_n)
      if(~rrst_n) {wptr_g_r[1],wptr_g_r[0]} <= 0;
      else {wptr_g_r[1],wptr_g_r[0]} <= {wptr_g_r[0],wptr_g};

   // Sync write pointer
   always @(posedge wclk or negedge wrst_n)
      if (~wrst_n) {rptr_g_r[1],rptr_g_r[0]} <= 0;
      else {rptr_g_r[1],rptr_g_r[0]} <= {rptr_g_r[0],rptr_g};

   // Generate empty flag
   always @(posedge rclk or negedge rrst_n)
      if (~rrst_n) empty <= 1'b1;
      else empty <= (rptr_g_nxt == wptr_g_r[1]);

   // Generate full flag
   always @(posedge wclk or negedge wrst_n)
      if (~wrst_n) full <= 1'b0;
      else full <= wptr_g_nxt=={~rptr_g_r[1][AW:AW-1], rptr_g_r[1][AW-2:0]};

   //
   // True DPRAM
   //
   reg [DW-1:0] mem[0:(1<<AW)-1];
	reg [AW-1:0] ra;

	// Read
	always @(posedge rclk)
	  if (pop & ~empty)
	    ra <= rptr_b[AW-1:0];
	assign dout = mem[ra];

	// Write
	always@(posedge wclk)
		if (push & ~full)
			mem[wptr_b[AW-1:0]] <= din;

   // synthesis translate_off
`ifndef SYNTHESIS
   initial begin : ini
      integer i;
      for(i=0; i < (1<<AW); i=i+1)
         mem[i] = {DW{1'b0}};
   end
`endif
   // synthesis translate_on

endmodule
