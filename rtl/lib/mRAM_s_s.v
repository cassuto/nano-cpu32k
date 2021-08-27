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

/** @brief RAM block: Single Port & Synchronous (latency = 1)
 * Parameters:
 *       DW      Data width (bits), which indicates the word length.
 *       AW      Address width (bits)
 * Ports:
 *       [in]  CLK     Clock
 *       [in]  ADDR    Address
 *       [in]  RE      Read Enable (High active)
 *       [out] DOUT    Read data
 *       [in]  WE      Write Enable
 *       [in]  DIN     Write Data
 */
module mRAM_s_s
#(
   parameter DW = 0,
   parameter AW = 0
)
(
   input CLK,
   input [AW-1:0] ADDR,
   input RE,
   output [DW-1:0] DOUT,
   input WE,
   input [DW-1:0] DIN
);

`ifdef NCPU_USE_TECHLIB
   // TODO
   
`else
   // General RTL
   reg [DW-1:0] mem_vector [(1<<AW)-1:0];
   reg [DW-1:0] dff_rdat;
   genvar i;
   
   always @(posedge CLK)
      if (RE)
         dff_rdat <= mem_vector[ADDR];
   assign DOUT = dff_rdat;
         
   always @(posedge CLK)
      if (WE)
         mem_vector[ADDR] <= DIN;
`endif

endmodule
