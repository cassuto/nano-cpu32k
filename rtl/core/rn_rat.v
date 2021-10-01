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

module rn_rat
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] we,
   input                               rollback,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0] lrs1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0] lrs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0] lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] lrd_we,
   // From FL
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd,
   // To SCH
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_pfree,
   // From ROB commit
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] cmt_lrd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] cmt_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we
);
   localparam N_LRF                    = (1<<`NCPU_LRF_AW);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   wire [N_LRF*`NCPU_PRF_AW-1:0]       rat_ff;
   wire [N_LRF*`NCPU_PRF_AW-1:0]       arat_ff;
   wire [`NCPU_PRF_AW-1:0]             rat_mux [N_LRF-1:0];
   wire [`NCPU_PRF_AW*CW-1:0]          prs1_nobyp;
   wire [`NCPU_PRF_AW*CW-1:0]          prs2_nobyp;
   wire [`NCPU_PRF_AW*CW-1:0]          pfree_nobyp;
   genvar i, k;
   integer x;
   
   mRF_nw_dio_r
      #(
         .DW (`NCPU_PRF_AW),
         .AW (`NCPU_LRF_AW),
         .RST_VECTOR ('b0),
         .NUM_WRITE (IW)
      )
   U_RAT
      (
         .CLK (clk),
         .RST (rst),
         .WE  (lrd_we & we),
         .WADDR (lrd),
         .WDATA (fl_prd),
         .REP (rollback),
         .DI  (arat_ff),
         .DO  (rat_ff)
      );
   
   mRF_nw_do_r
      #(
         .DW (`NCPU_PRF_AW),
         .AW (`NCPU_LRF_AW),
         .RST_VECTOR ('b0),
         .NUM_WRITE (IW)
      )
   U_aRAT
      (
         .CLK (clk),
         .RST (rst),
         .WE  (cmt_prd_we & cmt_fire),
         .WADDR (cmt_lrd),
         .WDATA (cmt_prd),
         .DO  (arat_ff)
      );
      
   generate
      for(i=0;i<N_LRF;i=i+1)
         assign rat_mux[i] = rat_ff[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   endgenerate

   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_readout
            assign prs1_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_mux[lrs1[i * `NCPU_LRF_AW +: `NCPU_LRF_AW]];
            assign prs2_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_mux[lrs2[i * `NCPU_LRF_AW +: `NCPU_LRF_AW]];
            assign pfree_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_mux[lrd[i * `NCPU_LRF_AW +: `NCPU_LRF_AW]];
         end
   endgenerate

   // Bypass for RAW and WAW hazard
   generate
      for(i=1;i<IW;i=i+1)
         begin
            reg [i-1:0] raw_rev;
            reg [i-1:0] waw_rev;
            wire [`NCPU_PRF_AW*i-1:0] fl_prd_rev;
            
            // Detect RAW hazard in the issue window
            always @(*)
               begin
                  raw_rev[i-1] = 'b0;
                  for(x=0;x<i;x=x+1)
                     raw_rev[i-x-1] = raw_rev[i-x-1] |
                                          (lrd_we[x] &
                                             ((lrs1[i*`NCPU_LRF_AW +:`NCPU_LRF_AW]==lrd[x*`NCPU_LRF_AW +:`NCPU_LRF_AW ]) |
                                                (lrs2[i*`NCPU_LRF_AW +:`NCPU_LRF_AW]==lrd[x*`NCPU_LRF_AW +:`NCPU_LRF_AW ])));
               end
            
            // Detect WAW hazard in the issue window
            always @(*)
               begin
                  waw_rev[i-1] = 'b0;
                  for(x=0;x<i;x=x+1)
                     waw_rev[i-x-1] = waw_rev[i-x-1] | (lrd_we[x] &
                                                ((lrd_we[i] & (lrd[i*`NCPU_LRF_AW +:`NCPU_LRF_AW]==lrd[x*`NCPU_LRF_AW +:`NCPU_LRF_AW]))));
               end
            
            for(k=0;k<i;k=k+1)
               assign fl_prd_rev[k * `NCPU_PRF_AW +: `NCPU_PRF_AW] = fl_prd[(i-k-1) * `NCPU_PRF_AW +: `NCPU_PRF_AW];
            
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_prs1 (
               .sel({1'b1, raw_rev}),
               .din({prs1_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_prs1[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_prs2 (
               .sel({1'b1, raw_rev}),
               .din({prs2_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_prs2[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_pfree (
               .sel({1'b1, waw_rev}),
               .din({pfree_nobyp[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            
         end
   endgenerate
   
   assign rat_prs1[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = prs1_nobyp[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign rat_prs2[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = prs2_nobyp[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign rat_pfree[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = pfree_nobyp[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];

`ifdef ENABLE_DIFFTEST
   // Maintain an inverse mapping table
   
   wire [`NCPU_LRF_AW*(1<<`NCPU_PRF_AW)-1:0] arat_inv_vec;
   wire [`NCPU_LRF_AW-1:0] arat_inv [(1<<`NCPU_PRF_AW)-1:0];
   
   mRF_nw_do_r
      #(
         .DW (`NCPU_LRF_AW),
         .AW (`NCPU_PRF_AW),
         .RST_VECTOR ('b0),
         .NUM_WRITE (IW)
      )
   dft_aRAT_inv
      (
         .CLK (clk),
         .RST (rst),
         .WE  (cmt_prd_we & cmt_fire),
         .WADDR (cmt_prd),
         .WDATA (cmt_lrd),
         .DO  (arat_inv_vec)
      );
   
   generate
      for(i=0;i<(1<<`NCPU_PRF_AW);i=i+1)
         assign arat_inv[i] = arat_inv_vec[i*`NCPU_LRF_AW +: `NCPU_LRF_AW];
   endgenerate
   
`endif

endmodule
