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

module rn_busytable
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] lrd_we,
   // From writeback
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] wb_lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_lrd_we,
   // Output
   output [(1<<`NCPU_PRF_AW)-1:0]      busytable
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam N_PRF                    = (1<<`NCPU_PRF_AW);
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_busytable
            mDFF_lr #(.DW(1)) ff_busy (.CLK(clk), .RST(rst), .LOAD(lrd_we[i] | wb_lrd_we[i]), .D(lrd_we[i] | ~wb_lrd_we[i]), .Q(busytable[i]) );
         end
   endgenerate

endmodule
