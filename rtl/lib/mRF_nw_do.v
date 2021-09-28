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

module mRF_nw_do
#(
   parameter DW = 0,
   parameter AW = 0,
   parameter NUM_WRITE = 0
)
(
   input CLK,
   input [NUM_WRITE-1:0] WE,
   input [AW*NUM_WRITE-1:0] WADDR,
   input [DW*NUM_WRITE-1:0] WDATA,
   output [DW*(1<<AW)-1:0] DO
);
   reg [DW-1:0] regfile [(1<<AW)-1:0];
   genvar i;
   integer j;
   
   always @(posedge CLK)
      for(j=0;j<NUM_WRITE;j=j+1) // This generates a priority MUX to resolve WAW hazard, if we have multiple write ports.
         if (WE[j])
            regfile[WADDR[j*AW +: AW]] <= WDATA[j*DW +: DW];
   
   generate
      for(i=0;i<(1<<AW);i=i+1)
         assign DO[i * DW +: DW] = regfile[i];
   endgenerate
   
endmodule
