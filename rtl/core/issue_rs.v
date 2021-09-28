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

module issue_rs
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_RS_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   output                              issue_rs_full,
   // From RN
   input [`NCPU_ALU_IOPW-1:0]          issue_alu_opc_bus,
   input [`NCPU_LPU_IOPW-1:0]          issue_lpu_opc_bus,
   input [`NCPU_EPU_IOPW-1:0]          issue_epu_opc_bus,
   input [`NCPU_BRU_IOPW-1:0]          issue_bru_opc_bus,
   input [`NCPU_LSU_IOPW-1:0]          issue_lsu_opc_bus,
   input [`BPU_UPD_W-1:0]              issue_bpu_upd,
   input [`PC_W-1:0]                   issue_pc,
   input [CONFIG_DW-1:0]               issue_imm,
   input [`NCPU_PRF_AW-1:0]            issue_prs1,
   input                               issue_prs1_re,
   input [`NCPU_PRF_AW-1:0]            issue_prs2,
   input                               issue_prs2_re,
   input [`NCPU_PRF_AW-1:0]            issue_prd,
   input                               issue_prd_we,
   input [`NCPU_PRF_AW-1:0]            issue_pfree,
   input [CONFIG_P_ROB_DEPTH-1:0]      issue_rob_id,
   input                               issue_push,
   // From busytable
   input [(1<<`NCPU_PRF_AW)-1:0]       busytable,
   // To EX
   output                              ex_valid,
   input                               ex_rs_pop,
   output [`NCPU_ALU_IOPW-1:0]         ex_alu_opc_bus,
   output [`NCPU_LPU_IOPW-1:0]         ex_lpu_opc_bus,
   output [`NCPU_EPU_IOPW-1:0]         ex_epu_opc_bus,
   output [`NCPU_BRU_IOPW-1:0]         ex_bru_opc_bus,
   output [`NCPU_LSU_IOPW-1:0]         ex_lsu_opc_bus,
   output [`BPU_UPD_W-1:0]             ex_bpu_upd,
   output [`PC_W-1:0]                  ex_pc,
   output [CONFIG_DW-1:0]              ex_imm,
   output [`NCPU_PRF_AW-1:0]           ex_prs1,
   output                              ex_prs1_re,
   output [`NCPU_PRF_AW-1:0]           ex_prs2,
   output                              ex_prs2_re,
   output [`NCPU_PRF_AW-1:0]           ex_prd,
   output                              ex_prd_we,
   output [`NCPU_PRF_AW-1:0]           ex_pfree,
   output [CONFIG_P_ROB_DEPTH-1:0]     ex_rob_id
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam RS_DEPTH                 = (1<<CONFIG_P_RS_DEPTH);
   localparam OPP_W                    = (`NCPU_ALU_IOPW +
                                          `NCPU_LPU_IOPW +
                                          `NCPU_EPU_IOPW +
                                          `NCPU_BRU_IOPW +
                                          `NCPU_LSU_IOPW +
                                          `BPU_UPD_W +
                                          CONFIG_DW +
                                          `NCPU_PRF_AW +
                                          1 +
                                          `NCPU_PRF_AW +
                                          CONFIG_P_ROB_DEPTH);
   localparam FL_1[RS_DEPTH-1:0]       = {{RS_DEPTH-1{1'b0}}, 'b1};

   wire [OPP_W-1:0]                    opp_wdat, opp_rdat;
   reg [`NCPU_PRF_AW-1:0]              prs1_rf [RS_DEPTH-1:0];
   reg [`NCPU_PRF_AW-1:0]              prs2_rf [RS_DEPTH-1:0];
   reg                                 prs1_re_rf [RS_DEPTH-1:0];
   reg                                 prs2_re_rf [RS_DEPTH-1:0];
   wire [RS_DEPTH-1:0]                 free_vec_ff;
   reg [RS_DEPTH-1:0]                  free_vec_nxt;
   wire                                has_free;
   wire [CONFIG_P_RS_DEPTH-1:0]        free_addr;
   wire [RS_DEPTH-1:0]                 rdy_vec;
   wire                                has_rdy, has_rdy_ff;
   wire [CONFIG_P_RS_DEPTH-1:0]        rdy_addr, rdy_addr_ff;
   genvar                              i;
   
   assign opp_wdat = {
      issue_alu_opc_bus,
      issue_lpu_opc_bus,
      issue_epu_opc_bus,
      issue_bru_opc_bus,
      issue_lsu_opc_bus,
      issue_bpu_upd,
      issue_pc,
      issue_imm,
      issue_prd,
      issue_prd_we,
      issue_pfree,
      issue_rob_id
   };
   
   mRF_nwnr
      #(
         .DW   (OPP_W),
         .AW   (CONFIG_P_RS_DEPTH),
         .NUM_READ (1),
         .NUM_WRITE (1)
      )
   U_PAYLOAD
      (
         .CLK  (clk),
         .RE   (has_rdy),
         .RADDR   (rdy_addr),
         .RDATA   (opp_rdat),
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (opp_wdat)
      );
   
   always @(posedge clk)
      if (issue_push)
         begin
            prs1_rf[free_addr] <= issue_prs1;
            prs2_rf[free_addr] <= issue_prs2;
            prs1_re_rf[free_addr] <= issue_prs1_re;
            prs2_re_rf[free_addr] <= issue_prs2_re;
         end
   
   always @(*)
      begin
         free_vec_nxt = free_vec_ff;
         if (issue_push)
            free_vec_nxt = free_vec_nxt & ~(FL_1<<free_addr);
         if (ex_rs_pop)
            free_vec_nxt = free_vec_nxt | (FL_1<<rdy_addr_ff);
      end

   mDFF_r #(.DW(RS_DEPTH), .RST_VECTOR({RS_DEPTH{1'b1}})) ff_free_vec (.CLK(clk), .RST(rst), .D(free_vec_nxt), .Q(free_vec_ff) );
   
   priority_encoder_gs #(.P_DW(CONFIG_P_RS_DEPTH)) penc_free (.din(free_vec_ff), .dout (free_addr), .gs(has_free) );
   
   assign issue_rs_full = ~has_free;
   
   generate
      for(i=0;i<RS_DEPTH;i=i+1)
         assign rdy_vec[i] = (~prs1_re_rf[i] | ~busytable[prs1_rf[i]]) & (~prs2_re_rf[i] | ~busytable[prs2_rf[i]]);
   endgenerate
   
   priority_encoder_gs #(.P_DW(CONFIG_P_RS_DEPTH)) penc_rdy (.din(rdy_vec), .dout(rdy_addr), .gs(has_rdy) );

   mDFF_r #(.DW(1)) ff_has_rdy (.CLK(clk), .RST(rst), .D(has_rdy), .Q(has_rdy_ff) );
   mDFF_l #(.DW(CONFIG_P_RS_DEPTH)) ff_rdy_addr (.CLK(clk), .LOAD(has_rdy), .D(rdy_addr), .Q(rdy_addr_ff) );
   
   assign ex_valid = has_rdy_ff;

   assign {
      ex_alu_opc_bus,
      ex_lpu_opc_bus,
      ex_epu_opc_bus,
      ex_bru_opc_bus,
      ex_lsu_opc_bus,
      ex_bpu_upd,
      ex_pc,
      ex_imm,
      ex_prd,
      ex_prd_we,
      ex_pfree,
      ex_rob_id
   } = opp_rdat;
   
endmodule
