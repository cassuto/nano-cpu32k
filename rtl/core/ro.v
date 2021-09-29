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

module ro
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_RS_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   // A
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] a_ex_alu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] a_ex_bpu_upd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] a_ex_bru_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_EPU_IOPW-1:0] a_ex_epu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] a_ex_imm,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] a_ex_lpu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LSU_IOPW-1:0] a_ex_lsu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] a_ex_pc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] a_ex_pfree,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] a_ex_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] a_ex_prd_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] a_ex_prs1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] a_ex_prs1_re,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] a_ex_prs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] a_ex_prs2_re,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] a_ex_rob_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] a_ex_rob_bank,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] a_ex_valid,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] a_ex_ready,
   // To PRF
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] prf_RE,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_LRF_AW-1:0] prf_RADDR,
   // From PRF
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] prf_RDATA,
   // B
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] ex_bpu_upd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_EPU_IOPW-1:0] ex_epu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LSU_IOPW-1:0] ex_lsu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prd_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_ready
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam PIPEBUF_BYPASS           = 1;
   wire                                push, pop;
   wire                                p_ce;

   //
   // Equivalent to 1-slot FIFO
   //
   assign push = (a_ex_valid & a_ex_ready);
   assign pop = (ex_valid & ex_ready);

   mDFF_lr #(.DW(1)) ff_pending (.CLK(clk), .RST(rst), .LOAD(push | pop | flush), .D((push | ~pop) & ~flush), .Q(ex_valid) );

   generate
      if (PIPEBUF_BYPASS)
         assign a_ex_ready = (~ex_valid | pop);
      else
         assign a_ex_ready = (~ex_valid);
   endgenerate
   
   assign p_ce = push;
   
   //
   // Pipeline stage
   //
   mDFF_l # (.DW(`NCPU_ALU_IOPW*IW)) ff_ex_alu_opc_bus (.CLK(clk), .LOAD(p_ce), .D(a_ex_alu_opc_bus), .Q(ex_alu_opc_bus) );
   mDFF_l # (.DW(`NCPU_LPU_IOPW*IW)) ff_ex_lpu_opc_bus (.CLK(clk), .LOAD(p_ce), .D(a_ex_lpu_opc_bus), .Q(ex_lpu_opc_bus) );
   mDFF_l # (.DW(`NCPU_EPU_IOPW*IW)) ff_ex_epu_opc_bus (.CLK(clk), .LOAD(p_ce), .D(a_ex_epu_opc_bus), .Q(ex_epu_opc_bus) );
   mDFF_l # (.DW(`NCPU_BRU_IOPW*IW)) ff_ex_bru_opc_bus (.CLK(clk), .LOAD(p_ce), .D(a_ex_bru_opc_bus), .Q(ex_bru_opc_bus) );
   mDFF_l # (.DW(`NCPU_LSU_IOPW*IW)) ff_ex_lsu_opc_bus (.CLK(clk), .LOAD(p_ce), .D(a_ex_lsu_opc_bus), .Q(ex_lsu_opc_bus) );
   mDFF_l # (.DW(`BPU_UPD_W*IW)) ff_ex_bpu_upd (.CLK(clk), .LOAD(p_ce), .D(a_ex_bpu_upd), .Q(ex_bpu_upd) );
   mDFF_l # (.DW(`PC_W*IW)) ff_ex_pc (.CLK(clk), .LOAD(p_ce), .D(a_ex_pc), .Q(ex_pc) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_ex_imm (.CLK(clk), .LOAD(p_ce), .D(a_ex_imm), .Q(ex_imm) );
   mDFF_l # (.DW(IW)) ff_ex_prd_we (.CLK(clk), .LOAD(p_ce), .D(a_ex_prd_we), .Q(ex_prd_we) );
   mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_ex_prd (.CLK(clk), .LOAD(p_ce), .D(a_ex_prd), .Q(ex_prd) );
   mDFF_l # (.DW(CONFIG_P_ROB_DEPTH*IW)) ff_ex_rob_id (.CLK(clk), .LOAD(p_ce), .D(a_ex_rob_id), .Q(ex_rob_id) );
   mDFF_l # (.DW(CONFIG_P_COMMIT_WIDTH*IW)) ff_ex_rob_bank (.CLK(clk), .LOAD(p_ce), .D(a_ex_rob_bank), .Q(ex_rob_bank) );
   
   // PRF could be considered as a pipeline stage
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_prf_addr
            assign prf_RE[(i<<1)] = (p_ce & a_ex_prs1_re[i]);
            assign prf_RE[(i<<1)+1] = (p_ce & a_ex_prs2_re[i]);
            assign prf_RADDR[(i<<1)*`NCPU_PRF_AW +: `NCPU_PRF_AW] = a_ex_prs1[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign prf_RADDR[((i<<1)+1)*`NCPU_PRF_AW +: `NCPU_PRF_AW] = a_ex_prs2[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
            
            assign ex_operand1[(i<<1)*CONFIG_DW +: CONFIG_DW] = prf_RDATA[(i<<1)*CONFIG_DW +: CONFIG_DW];
            assign ex_operand2[((i<<1)+1)*CONFIG_DW +: CONFIG_DW] = prf_RDATA[((i<<1)+1)*CONFIG_DW +: CONFIG_DW];
         end
   endgenerate

endmodule
