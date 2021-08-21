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

module mRF_1w1r
#(
   parameter DW = 0,
   parameter AW = 0
)
(
   input CLK,
   input RE,
   input [AW-1:0] RADDR,
   output [DW-1:0] RDATA,
   input WE,
   input [AW-1:0] WADDR,
   input [DW-1:0] WDATA
);
   reg [DW-1:0] regfile [(1<<AW)-1:0];
   reg ff_dout;
   
   always @(posedge CLK)
      begin
         if (RE)
            ff_dout <= regfile[RADDR];
         if (WE)
            regfile[WADDR] <= WDATA;
      end

   assign RDATA = ff_dout;
   
endmodule
