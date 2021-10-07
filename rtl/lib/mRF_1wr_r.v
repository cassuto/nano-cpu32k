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

module mRF_1wr_r
#(
   parameter DW = 0,
   parameter AW = 0,
   parameter [DW*(1<<AW)-1:0] RST_VECTOR = 'b0
)
(
   input CLK,
   input RST,
   input [AW-1:0] ADDR,
   input RE,
   output [DW-1:0] RDATA,
   input WE,
   input [DW-1:0] WDATA
);
   reg [DW-1:0] regfile [(1<<AW)-1:0];
   reg [DW-1:0] ff_dout;
   integer j;
   
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
         begin
            for(j=0;j<(1<<AW);j=j+1)
               regfile[j] <= RST_VECTOR[j*DW +: DW];
         end
      else
         begin
            if (WE)
               regfile[ADDR] <= WDATA;
            if (RE)
               ff_dout <= regfile[ADDR];
         end
   end

   assign RDATA = ff_dout;

endmodule
