/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module mDFF_r # (
   parameter DW = 1, // Data Width in bits
   parameter RST_VECTOR = {DW{1'b0}}
)
(
   input CLK,
   input RST,
   input [DW-1:0] D, // Data input
   output reg [DW-1:0] Q // Data output
);
`ifdef NCPU_RST_ASYNC
 `ifdef NCPU_RST_POS_POLARITY
   always @(posedge CLK or posedge RST) begin
 `else // neg polarity
   always @(posedge CLK or negedge RST) begin
 `endif
`else // synchronous
   always @(posedge CLK) begin
`endif
`ifdef NCPU_RST_POS_POLARITY
      if (RST)
`else // neg polarity
      if (~RST)
`endif
         Q <= RST_VECTOR;
      else
         Q <= D;
   end

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
`ifdef NCPU_CHECK_X
   always @(posedge CLK) begin
      if((^D) === 1'bx)
         $fatal ("\n DFF: uncertain state! \n");
   end
`endif
`endif

`endif
   // synthesis translate_on
endmodule
