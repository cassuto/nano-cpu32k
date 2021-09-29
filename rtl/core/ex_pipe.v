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

module ex_pipe
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_DW = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
   parameter                           CONFIG_ENABLE_MUL = 0,
   parameter                           CONFIG_ENABLE_DIV = 0,
   parameter                           CONFIG_ENABLE_DIVU = 0,
   parameter                           CONFIG_ENABLE_MOD = 0,
   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EITM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_ESYSCALL_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EINSN_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIRQ_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDTM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EALIGN_VECTOR = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input                               ex_valid,
   input [`NCPU_ALU_IOPW-1:0]          ex_alu_opc_bus,
   input [`NCPU_LPU_IOPW-1:0]          ex_lpu_opc_bus,
   input [`NCPU_EPU_IOPW-1:0]          ex_epu_opc_bus,
   input [`NCPU_BRU_IOPW-1:0]          ex_bru_opc_bus,
   input [`NCPU_LSU_IOPW-1:0]          ex_lsu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] ex_bpu_upd,
   input [`PC_W-1:0]                   ex_pc,
   input [CONFIG_DW-1:0]               ex_imm,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_pfree,
   input [`NCPU_LRF_AW-1:0]            ex_prd,
   input                               ex_prd_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank,
   // To RS
   output                              ex_ready,
   // To EX
   output                              se_fail,
   output [`PC_W-1:0]                  se_tgt,
   output                              exc_flush,
   output [`PC_W-1:0]                  exc_flush_tgt,
   output                              b_taken,
   output                              b_cc, b_reg, b_rel,
   output [`PC_W-1:0]                  b_tgt,
   // To commit
   output [CONFIG_DW-1:0]              commit_rf_wdat,
   output [`NCPU_LRF_AW-1:0]           commit_rf_waddr,
   output                              commit_rf_we
);
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   wire [CONFIG_DW-1:0]                bru_dout;
   wire                                bru_dout_valid;
   
   wire                                ex_lsu_load0;
   wire                                add_s;
   wire [CONFIG_DW-1:0]                add_sum;
   wire                                add_carry;
   wire                                add_overflow;
   
   
   
   wire                                agu_en;
   // Stage 1 Input
   wire [CONFIG_DW-1:0]                s1i_rf_dout_1, s1i_rf_dout;
   wire                                s1i_rf_we;
   wire                                s1i_rf_dout_valid;
   wire [`PC_W-1:0]                    s1i_npc;
   // Stage 2 Input / Stage 1 Output
   wire [CONFIG_DW-1:0]                s1o_rf_dout;
   wire [`NCPU_LRF_AW-1:0]             s1o_rf_waddr;
   wire                                s1o_rf_we;
   // Stage 3 Input / Stage 2 Output
   wire [CONFIG_DW-1:0]                s2o_lsu_dout0;
   wire [CONFIG_DW-1:0]                s2o_rf_dout;
   wire [`NCPU_LRF_AW-1:0]             s2o_rf_waddr;
   wire                                s2o_rf_we;
   wire [CONFIG_DW-1:0]                s3i_rf_wdat;

   genvar i;
   integer j;

   mADD
      #(.DW(`PC_W))
   U_NPC
      (
         .a                            (ex_pc),
         .b                            ('b1),
         .s                            ('b0),
         .sum                          (s1i_npc)
      );
   
   mADD_c_o
      #(.DW(CONFIG_DW))
   U_ADD_AGU
      (
         .a                            (ex_operand1),
         .b                            ((agu_en) ? ex_imm : ex_operand2),
         .s                            (add_s),
         .sum                          (add_sum),
         .carry                        (add_carry),
         .overflow                     (add_overflow)
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
         .ex_alu_opc_bus               (ex_alu_opc_bus),
         .ex_operand1                  (ex_operand1),
         .ex_operand2                  (ex_operand2),
         .add_sum                      (add_sum),
         .alu_result                   (s1i_rf_dout_1)
      );
   
   ex_bru
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW))
   U_BRU
      (
         .ex_valid                     (ex_valid),
         .ex_bru_opc_bus               (ex_bru_opc_bus),
         .ex_pc                        (ex_pc),
         .ex_imm                       (ex_imm),
         .ex_operand1                  (ex_operand1),
         .ex_operand2                  (ex_operand2),
         .ex_rf_we                     (ex_rf_we),
         .npc                          (s1i_npc),
         .add_sum                      (add_sum),
         .add_carry                    (add_carry),
         .add_overflow                 (add_overflow),
         .b_taken                      (b_taken),
         .b_tgt                        (b_tgt),
         .is_bcc                       (b_cc),
         .is_breg                      (b_reg),
         .is_brel                      (b_rel),
         .bru_dout                     (bru_dout),
         .bru_dout_valid               (bru_dout_valid)
      );

   // BRU reused the adder of ALU
   assign add_s =
      (
         ex_alu_opc_bus[`NCPU_ALU_SUB] |
         ex_bru_opc_bus[`NCPU_BRU_BEQ] |
         ex_bru_opc_bus[`NCPU_BRU_BNE] |
         ex_bru_opc_bus[`NCPU_BRU_BGTU] |
         ex_bru_opc_bus[`NCPU_BRU_BGT] |
         ex_bru_opc_bus[`NCPU_BRU_BLEU] |
         ex_bru_opc_bus[`NCPU_BRU_BLE]
      );

   // MUX: switch the result of BRU/ALU (without LSU)
   assign s1i_rf_dout =
         (bru_dout_valid)
            ? bru_dout
            : s1i_rf_dout_1;
            
   assign s1i_rf_dout_valid = ~((|ex_epu_opc_bus) | (|ex_lsu_opc_bus));

   assign s1i_rf_we = (ex_valid & s1i_rf_dout_valid & ex_rf_we);
   
   assign se_fail = ex_valid & ((b_taken ^ ex_bpu_pred_taken) | (b_tgt != ex_bpu_pred_tgt)); // FAIL
   //ex_valid[0] & ((b_taken ^ ex_bpu_pred_taken) | (b_taken & (b_tgt != ex_bpu_pred_tgt))); // RIGHT
   assign se_tgt = (b_taken) ? b_tgt : s1i_npc;
   
   
   //
   // Pipeline stages
   //
   mDFF_l # (.DW(`NCPU_LRF_AW)) ff_s1o_rf_waddr (.CLK(clk), .LOAD(p_ce_s1), .D(ex_rf_waddr), .Q(s1o_rf_waddr) );
   mDFF_lr # (.DW(1)) ff_s1o_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush_s1), .D(s1i_rf_we & ~flush_s1), .Q(s1o_rf_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s1o_rf_dout (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_rf_dout), .Q(s1o_rf_dout) );

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../lib"
// )
// End:
