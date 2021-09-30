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

module hds_buf
#(
   parameter BYPASS = 1
)
(
   input clk,
   input rst,
   input flush,
   input A_en,    // enable AREADY output
   input AVALID,
   output AREADY,
   input B_en,    // enable BVALID output
   output BVALID,
   input BREADY,
   output p_ce
);
   wire push, pop;
   wire pending;
   wire valid_nxt;
   
   assign push = (AVALID & AREADY);
   assign pop = (BVALID & BREADY);

   //
   // Equivalent to 1-slot FIFO
   //
   assign valid_nxt = (push | ~pop) & ~flush;

   mDFF_lr #(.DW(1)) ff_pending (.CLK(clk),.RST(rst), .LOAD(push | pop | flush), .D(valid_nxt), .Q(pending) );

   assign BVALID = B_en & pending;

   generate
      if (BYPASS)
         assign AREADY = A_en & (~pending | pop);
      else
         assign AREADY = A_en & (~pending);
   endgenerate

   assign p_ce = push;

endmodule
