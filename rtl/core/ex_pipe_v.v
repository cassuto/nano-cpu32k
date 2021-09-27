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

module ex_pipe_v
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_ENABLE_MUL = 0,
   parameter                           CONFIG_ENABLE_DIV = 0,
   parameter                           CONFIG_ENABLE_DIVU = 0,
   parameter                           CONFIG_ENABLE_MOD = 0,
   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0
)
(
   input                               clk,
   input                               rst,
   input                               p_ce_s1,
   input                               p_ce_s2,
   input                               p_ce_s3,
   input                               flush_s1,
   input                               flush_s2,
   input                               ex_cmt_valid,
   input [`PC_W-1:0]                   ex_npc,
   output                              se_fail,
   output [`PC_W-1:0]                  se_tgt,
   input                               ex_valid,
   input [`NCPU_ALU_IOPW-1:0]          ex_alu_opc_bus,
   input                               ex_bpu_pred_taken,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   input [`NCPU_REG_AW-1:0]            ex_rf_waddr,
   input                               ex_rf_we,
   // To bypass
   output [CONFIG_DW-1:0]              ro_ex_s1_rf_dout,
   output [CONFIG_DW-1:0]              ro_ex_s2_rf_dout,
   output [CONFIG_DW-1:0]              ro_ex_s3_rf_dout,
   output [CONFIG_DW-1:0]              ro_cmt_rf_wdat,
   output                              ro_ex_s1_rf_we,
   output                              ro_ex_s2_rf_we,
   output                              ro_ex_s3_rf_we,
   output                              ro_cmt_rf_we,
   output [`NCPU_REG_AW-1:0]           ro_ex_s1_rf_waddr,
   output [`NCPU_REG_AW-1:0]           ro_ex_s2_rf_waddr,
   output [`NCPU_REG_AW-1:0]           ro_ex_s3_rf_waddr,
   output [`NCPU_REG_AW-1:0]           ro_cmt_rf_waddr,
   // To commit
   output [CONFIG_DW-1:0]              commit_rf_wdat,
   output [`NCPU_REG_AW-1:0]           commit_rf_waddr,
   output                              commit_rf_we
);
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   wire                                add_s;
   wire [CONFIG_DW-1:0]                add_sum;
   // Stage 1 Input
   wire [CONFIG_DW-1:0]                s1i_rf_dout_1, s1i_rf_dout;
   wire                                s1i_rf_we;
   // Stage 2 Input / Stage 1 Output
   wire [CONFIG_DW-1:0]                s1o_rf_dout;
   wire [`NCPU_REG_AW-1:0]             s1o_rf_waddr;
   wire                                s1o_rf_we;
   // Stage 3 Input / Stage 2 Output
   wire [CONFIG_DW-1:0]                s2o_rf_dout;
   wire [`NCPU_REG_AW-1:0]             s2o_rf_waddr;
   wire                                s2o_rf_we;
   wire [CONFIG_DW-1:0]                s3i_rf_wdat;
   genvar i;
   integer j;

   mADD
      #(.DW (CONFIG_DW))
   U_ADD
      (
         .a                   (ex_operand1),
         .b                   (ex_operand2),
         .s                   (add_s),
         .sum                 (add_sum)
      );

   ex_alu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_ENABLE_MUL              (CONFIG_ENABLE_MUL),
        .CONFIG_ENABLE_DIV              (CONFIG_ENABLE_DIV),
        .CONFIG_ENABLE_DIVU             (CONFIG_ENABLE_DIVU),
        .CONFIG_ENABLE_MOD              (CONFIG_ENABLE_MOD),
        .CONFIG_ENABLE_MODU             (CONFIG_ENABLE_MODU),
        .CONFIG_ENABLE_ASR              (CONFIG_ENABLE_ASR))
   U_ALU
      (
         .ex_alu_opc_bus      (ex_alu_opc_bus),
         .ex_operand1         (ex_operand1),
         .ex_operand2         (ex_operand2),
         .add_sum             (add_sum),
         .alu_result          (s1i_rf_dout_1)
      );

   assign add_s = ex_alu_opc_bus[`NCPU_ALU_SUB];
   
   assign s1i_rf_dout = s1i_rf_dout_1;

   assign s1i_rf_we = (ex_cmt_valid & ex_rf_we);

   assign s3i_rf_wdat = s2o_rf_dout;

   // Bypass
   assign ro_ex_s1_rf_dout = s1i_rf_dout;
   assign ro_ex_s2_rf_dout = s1o_rf_dout;
   assign ro_ex_s3_rf_dout = s2o_rf_dout;
   assign ro_cmt_rf_wdat = commit_rf_wdat;
   assign ro_ex_s1_rf_we = s1i_rf_we;
   assign ro_ex_s2_rf_we = s1o_rf_we;
   assign ro_ex_s3_rf_we = s2o_rf_we;
   assign ro_cmt_rf_we = commit_rf_we;
   assign ro_ex_s1_rf_waddr = ex_rf_waddr;
   assign ro_ex_s2_rf_waddr = s1o_rf_waddr;
   assign ro_ex_s3_rf_waddr = s2o_rf_waddr;
   assign ro_cmt_rf_waddr = commit_rf_waddr;
   
   assign se_fail = ex_valid & (1'b0 ^ ex_bpu_pred_taken);
   assign se_tgt = ex_npc;
   
   //
   // Pipeline stages
   //
   mDFF_l # (.DW(`NCPU_REG_AW)) ff_s1o_rf_waddr (.CLK(clk), .LOAD(p_ce_s1), .D(ex_rf_waddr), .Q(s1o_rf_waddr) );
   mDFF_lr # (.DW(1)) ff_s1o_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush_s1), .D(s1i_rf_we & ~flush_s1), .Q(s1o_rf_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s1o_rf_dout (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_rf_dout), .Q(s1o_rf_dout) );
   
   mDFF_l # (.DW(`NCPU_REG_AW)) ff_s2o_rf_waddr (.CLK(clk), .LOAD(p_ce_s2), .D(s1o_rf_waddr), .Q(s2o_rf_waddr) );
   mDFF_lr # (.DW(1)) ff_s2o_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce_s2|flush_s2), .D(s1o_rf_we & ~flush_s2), .Q(s2o_rf_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s2o_rf_dout (.CLK(clk), .LOAD(p_ce_s2), .D(s1o_rf_dout), .Q(s2o_rf_dout) );

   mDFF_l # (.DW(`NCPU_REG_AW)) ff_commit_rf_waddr (.CLK(clk), .LOAD(p_ce_s3), .D(s2o_rf_waddr), .Q(commit_rf_waddr) );
   mDFF_lr # (.DW(1)) ff_commit_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce_s3), .D(s2o_rf_we), .Q(commit_rf_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_commit_rf_wdat (.CLK(clk), .LOAD(p_ce_s3), .D(s3i_rf_wdat), .Q(commit_rf_wdat) );

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../lib"
// )
// End:
