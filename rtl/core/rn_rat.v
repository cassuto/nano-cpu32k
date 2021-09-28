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
   input                               we,
   input                               rollback,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] lrs1,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] lrs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_REG_AW-1:0] lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] lrd_we,
   // From FL
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd,
   // To SCH
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_pfree,
   // From ROB commit
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] commit_lrd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] commit_prd_we
);
   localparam N_LRF                    = (1<<`NCPU_REG_AW);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   reg [`NCPU_PRF_AW-1:0]              rat_ff [N_LRF-1:0];
   reg [`NCPU_PRF_AW-1:0]              arat_ff [N_LRF-1:0];
   wire [`NCPU_PRF_AW-1:0]             prs1_nobyp [CW-1:0];
   wire [`NCPU_PRF_AW-1:0]             prs2_nobyp [CW-1:0];
   wire [`NCPU_PRF_AW-1:0]             pfree_nobpy [CW-1:0];
   wire [IW*`NCPU_PRF_AW-1:0]          fl_prd_rev;
   genvar i;
   integer x;
   
   // Maintain RAT (Register Alias Table)
   always @(posedge clk)
      begin
         if (rollback)
            for(x=0;x<N_LRF;x=x+1)
               rat_ff[x] <= arat_ff[x];
               
         else if (we)
            for(x=0;x<IW;x=x+1) // This generates a priority MUX to resolve WAW hazard
               if(lrd_we[x])
                  rat_ff[lrd[x * `NCPU_REG_AW +: `NCPU_REG_AW]] <= fl_prd[x * `NCPU_PRF_AW +: `NCPU_PRF_AW];
      end
      

   // Maintain ARAT (Architectural Register Alias Table)
   always @(posedge clk)
      for(x=0;x<CW;x=x+1)
         if (commit_prd_we[x]) // This generates a priority MUX to resolve WAW hazard
            arat_ff[commit_lrd[x * `NCPU_REG_AW +: `NCPU_REG_AW]] <= commit_prd[x * `NCPU_PRF_AW +: `NCPU_PRF_AW];

   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_readout
            assign prs1_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_ff[lrs1[x * `NCPU_REG_AW +: `NCPU_REG_AW]];
            assign prs2_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_ff[lrs2[x * `NCPU_REG_AW +: `NCPU_REG_AW]];
            assign pfree_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = rat_ff[lrd[x * `NCPU_REG_AW +: `NCPU_REG_AW]];
         end
   endgenerate

   generate
      for(i=0;i<IW;i=i+1)
         assign fl_prd_rev[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] = fl_prd[(IW-i-1) * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   endgenerate
   
   // Bypass for RAW and WAW hazard
   generate
      for(i=1;i<IW;i=i+1)
         begin
            reg [i-1:0] raw_rev;
            reg [i-1:0] waw_rev;
            
            // Detect RAW hazard in the issue window
            always @(*)
               begin
                  raw_rev[i-1] = 'b0;
                  for(x=0;x<i;x=x+1)
                     raw_rev[i-x-1] = raw_rev[i-x-1] |
                                          (lrd_we[x] &
                                             ((lrs1[i]==lrd[x*`NCPU_REG_AW +:`NCPU_REG_AW ]) |
                                                (lrs2[i]==lrd[x*`NCPU_REG_AW +:`NCPU_REG_AW ])));
               end
            
            // Detect WAW hazard in the issue window
            always @(*)
               begin
                  waw_rev[i-1] = 'b0;
                  for(x=0;x<i;x=x+1)
                     waw_rev[i-x-1] = waw_rev[i-x-1] | (lrd_we[x] &
                                                ((lrd_we[i] & (lrd[i]==lrd[x*`NCPU_REG_AW +:`NCPU_REG_AW ]))));
               end
            
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_prs1 (
               .sel({1'b1, raw_rev}),
               .din({prs1_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_prs1[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_prs2 (
               .sel({1'b1, raw_rev}),
               .din({prs2_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_prs2[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            pmux #(.SELW(i+1), .DW(`NCPU_PRF_AW)) pmux_pfree (
               .sel({1'b1, waw_rev}),
               .din({pfree_nobpy[i * `NCPU_PRF_AW +: `NCPU_PRF_AW], fl_prd_rev[0 +: i*`NCPU_PRF_AW]}),
               .dout(rat_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW])
            );
            
         end
   endgenerate
   
   assign rat_prs1[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = prs1_nobpy[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign rat_prs2[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = prs2_nobpy[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign rat_pfree[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW] = pfree_nobpy[0 * `NCPU_PRF_AW +: `NCPU_PRF_AW];


endmodule
