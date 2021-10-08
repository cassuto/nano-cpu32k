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
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_RS_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   output                              issue_rs_full,
   // From RN
   input [`NCPU_ALU_IOPW-1:0]          issue_alu_opc_bus,
//   input [`NCPU_LPU_IOPW-1:0]          issue_lpu_opc_bus,
   input                               issue_epu_op,
   input [`NCPU_BRU_IOPW-1:0]          issue_bru_opc_bus,
   input                               issue_lsu_op,
   input [`NCPU_FE_W-1:0]              issue_fe,
   input                               issue_bpu_pred_taken,
   input [`PC_W-1:0]                   issue_bpu_pred_tgt,
   input [`PC_W-1:0]                   issue_pc,
   input [CONFIG_DW-1:0]               issue_imm,
   input [`NCPU_PRF_AW-1:0]            issue_prs1,
   input                               issue_prs1_re,
   input [`NCPU_PRF_AW-1:0]            issue_prs2,
   input                               issue_prs2_re,
   input [`NCPU_PRF_AW-1:0]            issue_prd,
   input                               issue_prd_we,
   input [CONFIG_P_ROB_DEPTH-1:0]      issue_rob_id,
   input [CONFIG_P_COMMIT_WIDTH-1:0]   issue_rob_bank,
   input                               issue_push,
   // From busytable
   input [(1<<`NCPU_PRF_AW)-1:0]       busytable,
   // To EX
   output                              ro_valid,
   input                               ro_rs_pop,
   output [`NCPU_ALU_IOPW-1:0]         ro_alu_opc_bus,
//   output [`NCPU_LPU_IOPW-1:0]         ro_lpu_opc_bus,
   output                              ro_epu_op,
   output [`NCPU_BRU_IOPW-1:0]         ro_bru_opc_bus,
   output                              ro_bpu_pred_taken,
   output [`PC_W-1:0]                  ro_bpu_pred_tgt,
   output                              ro_lsu_op,
   output [`NCPU_FE_W-1:0]             ro_fe,
   output [`PC_W-1:0]                  ro_pc,
   output [CONFIG_DW-1:0]              ro_imm,
   output [`NCPU_PRF_AW-1:0]           ro_prs1,
   output                              ro_prs1_re,
   output [`NCPU_PRF_AW-1:0]           ro_prs2,
   output                              ro_prs2_re,
   output [`NCPU_PRF_AW-1:0]           ro_prd,
   output                              ro_prd_we,
   output [CONFIG_P_ROB_DEPTH-1:0]     ro_rob_id,
   output [CONFIG_P_COMMIT_WIDTH-1:0]  ro_rob_bank
);
   localparam RS_DEPTH                 = (1<<CONFIG_P_RS_DEPTH);
   localparam OPP_W                    = (`NCPU_ALU_IOPW +
                                          /*`NCPU_LPU_IOPW +*/
                                          1 +
                                          `NCPU_BRU_IOPW +
                                          1 +
                                          `NCPU_FE_W +
                                          1 +
                                          `PC_W +
                                          `PC_W +
                                          CONFIG_DW +
                                          `NCPU_PRF_AW +
                                          1 +
                                          CONFIG_P_ROB_DEPTH +
                                          CONFIG_P_COMMIT_WIDTH);
   localparam [RS_DEPTH-1:0] FL_1      = {{RS_DEPTH-1{1'b0}}, 1'b1};

   wire [OPP_W-1:0]                    opp_wdat, opp_rdat;
   wire [RS_DEPTH*`NCPU_PRF_AW-1:0]    prs1_rf;
   wire [RS_DEPTH*`NCPU_PRF_AW-1:0]    prs2_rf;
   wire [RS_DEPTH-1:0]                 prs1_re_rf;
   wire [RS_DEPTH-1:0]                 prs2_re_rf;
   wire [`NCPU_PRF_AW-1:0]             prs1_rf_mux [RS_DEPTH-1:0];
   wire [`NCPU_PRF_AW-1:0]             prs2_rf_mux [RS_DEPTH-1:0];
   wire [RS_DEPTH-1:0]                 free_vec_ff;
   reg [RS_DEPTH-1:0]                  free_vec_nxt, free_vec_ff_byp;
   wire                                has_free;
   wire [CONFIG_P_RS_DEPTH-1:0]        free_addr;
   wire [RS_DEPTH-1:0]                 rdy_vec;
   wire                                has_rdy, has_rdy_ff;
   wire [CONFIG_P_RS_DEPTH-1:0]        rdy_addr, rdy_addr_ff;
   genvar                              i;
   
   assign opp_wdat = {
      issue_alu_opc_bus,
//      issue_lpu_opc_bus,
      issue_epu_op,
      issue_bru_opc_bus,
      issue_lsu_op,
      issue_fe,
      issue_bpu_pred_taken,
      issue_bpu_pred_tgt,
      issue_pc,
      issue_imm,
      issue_prd,
      issue_prd_we,
      issue_rob_id,
      issue_rob_bank
   };
   
   `mRF_nwnr
      #(
         .DW   (OPP_W),
         .AW   (CONFIG_P_RS_DEPTH),
         .NUM_READ (1),
         .NUM_WRITE (1)
      )
   U_PAYLOAD
      (
         .CLK     (clk),
         `rst
         .RE      (has_rdy),
         .RADDR   (rdy_addr),
         .RDATA   (opp_rdat),
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (opp_wdat)
      );
   
   `mRF_nw_do
      #(
         .DW (`NCPU_PRF_AW),
         .AW (CONFIG_P_RS_DEPTH),
         .NUM_WRITE(1)
      )
   U_RF_RS1
      (
         .CLK     (clk),
         `rst
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (issue_prs1),
         .DO      (prs1_rf)
      );
   `mRF_nw_do
      #(
         .DW (`NCPU_PRF_AW),
         .AW (CONFIG_P_RS_DEPTH),
         .NUM_WRITE(1)
      )
   U_RF_RS2
      (
         .CLK     (clk),
         `rst
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (issue_prs2),
         .DO      (prs2_rf)
      );
      
   `mRF_nw_do
      #(
         .DW (1),
         .AW (CONFIG_P_RS_DEPTH),
         .NUM_WRITE(1)
      )
   U_RF_RS1_RE
      (
         .CLK     (clk),
         `rst
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (issue_prs1_re),
         .DO      (prs1_re_rf)
      );
   `mRF_nw_do
      #(
         .DW (1),
         .AW (CONFIG_P_RS_DEPTH),
         .NUM_WRITE(1)
      )
   U_RF_RS2_RE
      (
         .CLK     (clk),
         `rst
         .WE      (issue_push),
         .WADDR   (free_addr),
         .WDATA   (issue_prs2_re),
         .DO      (prs2_re_rf)
      );

   always @(*)
      begin
         free_vec_nxt = free_vec_ff;
         if (issue_push)
            free_vec_nxt = free_vec_nxt & ~(FL_1<<free_addr);
         if (ro_rs_pop)
            free_vec_nxt = free_vec_nxt | (FL_1<<rdy_addr_ff);
         if (flush)
            free_vec_nxt = {RS_DEPTH{1'b1}};
      end
   always @(*)
      begin
         free_vec_ff_byp = free_vec_ff;
         if (ro_rs_pop)
               free_vec_ff_byp = free_vec_ff_byp | (FL_1<<rdy_addr_ff);
      end

   mDFF_r #(.DW(RS_DEPTH), .RST_VECTOR({RS_DEPTH{1'b1}})) ff_free_vec (.CLK(clk), .RST(rst), .D(free_vec_nxt), .Q(free_vec_ff) );
   
   priority_encoder_gs #(.P_DW(CONFIG_P_RS_DEPTH)) penc_free (.din(free_vec_ff), .dout (free_addr), .gs(has_free) );
   
   assign issue_rs_full = ~has_free;
   
   generate for(i=0;i<RS_DEPTH;i=i+1)
      begin : gen_mux
         assign prs1_rf_mux[i] = prs1_rf[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
         assign prs2_rf_mux[i] = prs2_rf[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
      end
   endgenerate
   
   generate for(i=0;i<RS_DEPTH;i=i+1)
      begin : gen_rdy_vec
         assign rdy_vec[i] = ~free_vec_ff_byp[i] &
                              (~prs1_re_rf[i] | ~busytable[prs1_rf_mux[i]]) &
                              (~prs2_re_rf[i] | ~busytable[prs2_rf_mux[i]]);
      end
   endgenerate
   
   priority_encoder_gs #(.P_DW(CONFIG_P_RS_DEPTH)) penc_rdy (.din(rdy_vec), .dout(rdy_addr), .gs(has_rdy) );
   
   mDFF_r #(.DW(1)) ff_has_rdy (.CLK(clk), .RST(rst), .D(has_rdy & ~flush), .Q(has_rdy_ff) );
   `mDFF_l #(.DW(CONFIG_P_RS_DEPTH)) ff_rdy_addr (.CLK(clk),`rst .LOAD(has_rdy), .D(rdy_addr), .Q(rdy_addr_ff) );
   `mDFF_l #(.DW(`NCPU_PRF_AW)) ff_issue_prs1 (.CLK(clk),`rst .LOAD(has_rdy), .D(prs1_rf_mux[rdy_addr]), .Q(ro_prs1) );
   `mDFF_l #(.DW(`NCPU_PRF_AW)) ff_issue_prs2 (.CLK(clk),`rst .LOAD(has_rdy), .D(prs2_rf_mux[rdy_addr]), .Q(ro_prs2) );
   `mDFF_l #(.DW(1)) ff_issue_prs1_re (.CLK(clk),`rst .LOAD(has_rdy), .D(prs1_re_rf[rdy_addr]), .Q(ro_prs1_re) );
   `mDFF_l #(.DW(1)) ff_issue_prs2_re (.CLK(clk),`rst .LOAD(has_rdy), .D(prs2_re_rf[rdy_addr]), .Q(ro_prs2_re) );
   
   assign ro_valid = has_rdy_ff;

   assign {
      ro_alu_opc_bus,
//      ro_lpu_opc_bus,
      ro_epu_op,
      ro_bru_opc_bus,
      ro_lsu_op,
      ro_fe,
      ro_bpu_pred_taken,
      ro_bpu_pred_tgt,
      ro_pc,
      ro_imm,
      ro_prd,
      ro_prd_we,
      ro_rob_id,
      ro_rob_bank
   } = opp_rdat;
   
endmodule
