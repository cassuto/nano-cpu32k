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

module freelist
#(
   parameter                           CONFIG_AW = 32,
   parameter                           CONFIG_PRF_AW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               pop,
   input                               rollback,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] lrd_we,
   output                              fl_stall_req,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd,
   // From ROB commit
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] commit_fl_push,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] commit_prd_we,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_pfree
   
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   localparam N_PRF                    = (1<<CONFIG_PRF_AW);
   localparam [N_PRF-1:0] FL_1         = {{N_PRF-1{1'b0}}, 1'b1};
   wire [N_PRF-1:0]                    fl_ff;
   reg [N_PRF-1:0]                     fl_nxt;
   wire [N_PRF-1:0]                    afl_ff;
   reg [N_PRF-1:0]                     afl_nxt;
   wire [N_PRF-1:0]                    fl                            [IW-1:0];
   wire                                gs                            [IW-1:0];
   reg                                 no_free;
   genvar i;
   integer j;

   // Select free PR
   always @(*)
      begin
         fl[0] = fl_ff;
         for(j=1;j<IW;j=j+1)
            fl[j] = fl[j-1] & ~(FL_1 << fl_prd[(j-1) * `NCPU_PRF_AW +: `NCPU_PRF_AW]);
      end
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_penc
            priority_encoder #(.P_DW(CONFIG_PRF_AW)) PENC_FL (
               .din     (fl[i]),
               .dout    (fl_prd[i* `NCPU_PRF_AW +: `NCPU_PRF_AW]),
               .gs      (gs[i])
            );
         end
   endgenerate
   
   // Check if there is no free physical register
   always @(*)
      begin
         no_free = 'b0;
         for(j=0;j<IW;j=j+1)
            no_free = fl_stall_req | (lrd_we[j] & ~gs[j]);
      end
   assign fl_stall_req = no_free;
      

   // Maintain the free list (FL)
   always @(*)
      begin
         fl_nxt = fl_ff;
         for(j=0;j<IW;j=j+1)
            if (pop & lrd_we[j])
               fl_nxt = fl_nxt & ~(FL_1<<fl_prd[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Allocate
               
         for(j=0;j<CW;j=j+1)   
            if (commit_fl_push[j] & commit_prd_we[j])
               fl_nxt = fl_nxt | (FL_1<<commit_pfree[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Free
      end

   mDFF_r #(.DW(N_PRF)) ff_fl (.CLK(clk), .RST(rst), .D(rollback ? afl_ff : fl_nxt), .Q(fl_ff) );

   // Maintain architectural free list (aFL)
   always @(*)
      begin
         afl_nxt = afl_ff;
         for(j=0;j<CW;j=j+1)
            if (commit_fl_push[j] & commit_prd_we[j])
               begin
                  afl_nxt = afl_nxt & ~(FL_1<<commit_prd[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Allocate
                  afl_nxt = afl_nxt | (FL_1<<commit_pfree[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Free
               end
      end
   
   mDFF_r #(.DW(N_PRF)) ff_afl (.CLK(clk), .RST(rst), .D(afl_nxt), .Q(afl_ff) );

endmodule
