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

module cmt
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0
)
(
   input                               clk,
   input                               stall,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we,
   // ARF
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] arf_RE,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_REG_AW-1:0] arf_RADDR,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] arf_RDATA
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   
   mRF_nwnr
      #(
         .DW                           (CONFIG_DW),
         .AW                           (`NCPU_REG_AW),
         .NUM_READ                     (2*IW), // Each instruction has a maximum of 2 register operands
         .NUM_WRITE                    (IW)
      )
   U_ARF
      (
         .CLK                          (clk),
         .RE                           (arf_RE),
         .RADDR                        (arf_RADDR),
         .RDATA                        (arf_RDATA),
         .WE                           (commit_rf_we),
         .WADDR                        (commit_rf_waddr),
         .WDATA                        (commit_rf_wdat)
      );

endmodule
