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

module rn_fl
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] pop,
   input                               rollback,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] lrd_we,
   output                              fl_stall_req,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd,
   // From ROB commit
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] cmt_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] cmt_pfree
   
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   localparam N_PRF                    = (1<<`NCPU_PRF_AW);
   localparam [N_PRF-1:0] FL_1         = {{N_PRF-1{1'b0}}, 1'b1};
   wire [N_PRF-2:0]                    fl_ff;
   reg [N_PRF-1:0]                     fl_nxt;
   wire [N_PRF-2:0]                    afl_ff;
   reg [N_PRF-1:0]                     afl_nxt;
   wire                                gs                            [IW-1:0];
   reg                                 no_free;
   genvar i;
   integer j;

   // Select free PR
   generate
      //
      // The algorithm is:
      //
      // fl[0] = {fl_ff, 1'b0};
      // for(j=1;j<IW;j=j+1)
      //    fl[j] = fl[j-1] & ~(FL_1 << fl_prd[j-1]);
      //
      // for(i=1;i<IW;i=i+1)
      //    priority_encoder_gs #(.P_DW(`NCPU_PRF_AW)) PENC_FL (
      //       .din     (fl[i]),
      //       .dout    (fl_prd[i* `NCPU_PRF_AW +: `NCPU_PRF_AW]),
      //       .gs      (gs[i])
      //    );
      //
      // The above HDL generates an "unoptimizable feedback" in verilator
      // but there is not actually one, which may be a bug of the verilator.
      // Thus we expand the code manually...
      //
      if (IW==2)
         begin : gen_sel_2
            wire [`NCPU_PRF_AW-1:0] fl_prd_0, fl_prd_1;
            wire [N_PRF-1:0] fl_0, fl_1;
            wire gs_0, gs_1;
            
            assign fl_0 = {fl_ff, 1'b0};
            for(i=0;i<N_PRF;i=i+1)
               begin : gen_fl_1
                  assign fl_1[i] = fl_0[N_PRF-i-1]; // reverse fl_0, the encoders could be parallel
               end
            
            priority_encoder_gs #(.P_DW(`NCPU_PRF_AW)) PENC_FL_0 (
               .din     (fl_0),
               .dout    (fl_prd_0),
               .gs      (gs_0)
            );
            
            priority_encoder_rev_gs #(.P_DW(`NCPU_PRF_AW)) PENC_FL_1 (
               .din     (fl_1),
               .dout    (fl_prd_1),
               .gs      (gs_1)
            );
            
            assign gs[0] = (gs_0);
            assign gs[1] = (gs_1 & (fl_prd_1!=fl_prd_0));
            
            assign fl_prd = {fl_prd_1, fl_prd_0};
         end
`ifndef SYNTHESIS
      else
         $fatal(1, "Unimplemented");
`endif
   endgenerate
   
   // Check if there is no free physical register
   always @(*)
      begin
         no_free = 'b0;
         for(j=0;j<IW;j=j+1)
            no_free = no_free | (lrd_we[j] & ~gs[j]);
      end
   assign fl_stall_req = no_free;
      

   // Maintain the free list (FL)
   always @(*)
      begin
         fl_nxt = {fl_ff, 1'b0};
         for(j=0;j<IW;j=j+1)
            if (pop[j] & lrd_we[j])
               fl_nxt = fl_nxt & ~(FL_1<<fl_prd[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Allocate
               
         for(j=0;j<CW;j=j+1)   
            if (cmt_prd_we[j] & cmt_fire[j])
               fl_nxt = fl_nxt | (FL_1<<cmt_pfree[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Free
      end

   mDFF_r #(.DW(N_PRF-1), .RST_VECTOR({N_PRF-1{1'b1}})) ff_fl (.CLK(clk), .RST(rst), .D(rollback ? afl_ff : fl_nxt[N_PRF-1:1]), .Q(fl_ff) );

   // Maintain architectural free list (aFL)
   always @(*)
      begin
         afl_nxt = {afl_ff, 1'b0};
         for(j=0;j<CW;j=j+1)
            if (cmt_prd_we[j] & cmt_fire[j])
               begin
                  afl_nxt = afl_nxt & ~(FL_1<<cmt_prd[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Allocate
                  afl_nxt = afl_nxt | (FL_1<<cmt_pfree[j * `NCPU_PRF_AW +: `NCPU_PRF_AW]); // Free
               end
      end
   
   mDFF_r #(.DW(N_PRF-1), .RST_VECTOR({N_PRF-1{1'b1}})) ff_afl (.CLK(clk), .RST(rst), .D(afl_nxt[N_PRF-1:1]), .Q(afl_ff) );

`ifdef ENABLE_DEBUG_SIM
   wire [N_PRF-1:0] dbg_afl = {afl_ff, 1'b0};
`endif

endmodule
