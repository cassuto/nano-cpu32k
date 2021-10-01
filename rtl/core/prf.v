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

module prf
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_WRITEBACK_WIDTH = 0
)
(
   input                               clk,
   
   // From RO
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] prf_RE,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_PRF_AW-1:0] prf_RADDR,
   // To RO
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] prf_RDATA,
   
   // From WB
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WE,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WADDR,
   input [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WDATA
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam WW                       = (1<<CONFIG_P_WRITEBACK_WIDTH);
   wire [IW*2-1:0]                     prf_RADDR_zero_ff;
   wire [IW*2*CONFIG_DW-1:0]           prf_RDATA_1;
   genvar i;
   
   mRF_nwnr
      #(
         .DW                           (CONFIG_DW),
         .AW                           (`NCPU_PRF_AW),
         .NUM_READ                     (2*IW), // Each instruction has a maximum of 2 register operands
         .NUM_WRITE                    (IW)
      )
   U_PRF
      (
         .CLK                          (clk),
         .RE                           (prf_RE),
         .RADDR                        (prf_RADDR),
         .RDATA                        (prf_RDATA_1),
         .WE                           (prf_WE),
         .WADDR                        (prf_WADDR),
         .WDATA                        (prf_WDATA)
      );
   
   // r0 read as zero
   generate
      for(i=0;i<IW*2;i=i+1)
         begin : gen_zero_dec
            mDFF_l #(.DW(1)) ff_prf_zero_RADDR (.CLK(clk), .LOAD(prf_RE[i]), .D(|prf_RADDR[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), .Q(prf_RADDR_zero_ff[i]) );
   
            assign prf_RDATA[i*CONFIG_DW +: CONFIG_DW] =
               (prf_RDATA_1[i*CONFIG_DW +: CONFIG_DW] & {CONFIG_DW{prf_RADDR_zero_ff[i]}});
         end
   endgenerate

`ifdef ENABLE_DIFFTEST
   wire [`NCPU_PRF_AW-1:0] dbg_waddr[WW-1:0];
   generate
      for(i=0;i<WW;i=i+1)  
         begin
            assign dbg_waddr[i] = prf_WADDR[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
         end
   endgenerate
`endif

endmodule
