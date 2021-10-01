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

module wb_mux
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_WRITEBACK_WIDTH = 0
)
(
   // From EX
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WE_ex,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WADDR_ex,
   input [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WDATA_ex,
   // From LSU/EPU
   input                               prf_WE_lsu_epu,
   input [`NCPU_PRF_AW-1:0]            prf_WADDR_lsu_epu,
   input [CONFIG_DW-1:0]               prf_WDATA_lsu_epu,
   
   // To WB
   output [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_ready,
   
   // To PRF
   output [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WE,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WADDR,
   output [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WDATA
);
   localparam WW                       = (1<<CONFIG_P_WRITEBACK_WIDTH);
   genvar i;
   
   
   // Arbiter between `ex_pipe[0]` and `lsu_epu`
   // `lsu_epu` has the highest priority
   assign wb_ready[0] = (~prf_WE_lsu_epu);
   assign prf_WE[0] = (prf_WE_lsu_epu) ? 1'b1 : prf_WE_ex[0];
   assign prf_WADDR[0*`NCPU_PRF_AW +: `NCPU_PRF_AW] = (prf_WE_lsu_epu)
                                                            ? prf_WADDR_lsu_epu
                                                            : prf_WADDR_ex[0*`NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign prf_WDATA[0*CONFIG_DW +: CONFIG_DW] = (prf_WE_lsu_epu)
                                                      ? prf_WDATA_lsu_epu
                                                      : prf_WDATA_ex[0*CONFIG_DW +: CONFIG_DW];
   
   generate
      for(i=1;i<WW;i=i+1)
         begin : gen_bundle
            assign wb_ready[i] = 'b1;
            assign prf_WE[i] = prf_WE_ex[i];
            assign prf_WADDR[i*`NCPU_PRF_AW +: `NCPU_PRF_AW] = prf_WADDR_ex[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign prf_WDATA[i*CONFIG_DW +: CONFIG_DW] = prf_WDATA_ex[i*CONFIG_DW +: CONFIG_DW];
         end
   endgenerate

endmodule
