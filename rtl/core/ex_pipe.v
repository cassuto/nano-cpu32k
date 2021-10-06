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
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
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
   input                               flush,
   input                               ex_valid,
   input [`NCPU_ALU_IOPW-1:0]          ex_alu_opc_bus,
   input [`NCPU_LPU_IOPW-1:0]          ex_lpu_opc_bus,
   input                               ex_epu_op,
   input                               ex_lsu_op,
   input [`NCPU_BRU_IOPW-1:0]          ex_bru_opc_bus,
   input [`NCPU_FE_W-1:0]              ex_fe,
   input                               ex_bpu_pred_taken,
   input [`PC_W-1:0]                   ex_bpu_pred_tgt,
   input [`PC_W-1:0]                   ex_pc,
   input [CONFIG_DW-1:0]               ex_imm,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   input [`NCPU_PRF_AW-1:0]            ex_prd,
   input                               ex_prd_we,
   input [CONFIG_P_ROB_DEPTH-1:0]      ex_rob_id,
   input [CONFIG_P_COMMIT_WIDTH-1:0]   ex_rob_bank,
   // To RS
   output                              ex_ready,
   // From WB
   input                               wb_ready,
   // To WB
   output                              wb_valid,
   output [CONFIG_P_ROB_DEPTH-1:0]     wb_rob_id,
   output [CONFIG_P_COMMIT_WIDTH-1:0]  wb_rob_bank,
   output                              prf_WE_ex,
   output [`NCPU_PRF_AW-1:0]           prf_WADDR_ex,
   output [CONFIG_DW-1:0]              prf_WDATA_ex,
   output                              wb_fls,
   output                              wb_exc,
   output [CONFIG_AW-1:0]              wb_opera,
   output [CONFIG_DW-1:0]              wb_operb,
   output [`PC_W-1:0]                  wb_fls_tgt
);
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   wire                                p_ce;
   wire [CONFIG_DW-1:0]                bru_dout;
   wire                                bru_dout_valid;
   wire                                add_s;
   wire [CONFIG_DW-1:0]                add_sum;
   wire                                add_carry;
   wire                                add_overflow;
   wire                                b_taken;
   wire                                b_cc, b_reg, b_rel;
   wire [`PC_W-1:0]                    b_tgt;
   wire                                agu_en;
   // Stage 1 Input
   wire [CONFIG_DW-1:0]                s1i_op1, s1i_op2;
   wire                                s1i_se_fail;
   wire [`PC_W-1:0]                    s1i_se_tgt;
   wire                                s1i_wb_fls;
   wire                                s1i_wb_exc;
   wire [CONFIG_AW-1:0]                s1i_wb_lsa;
   wire [CONFIG_DW-1:0]                s1i_wb_opera, s1i_wb_operb;
   wire [CONFIG_DW-1:0]                alu_dout;
   wire [CONFIG_DW-1:0]                s1i_rf_dout;
   wire                                s1i_prf_we;
   wire                                s1i_prf_wdat_valid;
   wire [`PC_W-1:0]                    s1i_npc;
   // Stage 1 Output
   wire                                s1o_prf_we;
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
         .alu_result                   (alu_dout)
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
         .ex_rf_we                     (ex_prd_we),
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
      
   ex_agu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW))
   U_AGU
      (
         .ex_lsu_op                    (ex_lsu_op),
         .ex_epu_op                    (ex_epu_op),
         .agu_en                       (agu_en),
         .add_sum                      (add_sum),
         .wb_lsa                       (s1i_wb_lsa)
      );

   // +-----+--------------+
   // | FU  | opera        |
   // +-----+--------------+
   // | EPU | operand1+imm |
   // | LSU | operand1+imm |
   // |(EH) | FE           |
   // +-----+--------------+
   assign s1i_wb_opera = (s1i_wb_exc)
                           ? {{CONFIG_DW-`NCPU_FE_W{1'b0}}, ex_fe}
                           : s1i_wb_lsa;
      
   // +-----+-------------+
   // | FU  | operb       |
   // +-----+-------------+
   // | EPU | operand2    |
   // | LSU | operand2    |
   // +-----+-------------+
   assign s1i_wb_operb = ex_operand2;
   
      
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

   // MUX for ALU/BRU (without LSU and EPU)
   assign s1i_rf_dout =
         (bru_dout_valid)
            ? bru_dout
            : alu_dout;
       
   // The execution of LSU and EPU is delayed to ROB committing, thus
   // the result is invalid.
   assign s1i_prf_wdat_valid = ex_valid & ~(ex_epu_op | ex_lsu_op);

   assign s1i_prf_we = (s1i_prf_wdat_valid & ex_prd_we);
   
   // Speculative execution check point
   assign s1i_se_fail = ((b_taken ^ ex_bpu_pred_taken) | (b_taken & (b_tgt != ex_bpu_pred_tgt))); // RIGHT
   // ((b_taken ^ ex_bpu_pred_taken) | (b_tgt != ex_bpu_pred_tgt)); // FAIL
   assign s1i_se_tgt = (b_taken) ? b_tgt : s1i_npc;
   
   assign s1i_wb_fls = (ex_valid & s1i_se_fail);
   assign s1i_wb_exc = (ex_valid & (|ex_fe));
   
   hds_buf
      #(.BYPASS(1))
   U_BUF
      (
         .clk  (clk),
         .rst  (rst),
         .flush (flush),
         .A_en (1'b1),    // enable AREADY output
         .AVALID (ex_valid),
         .AREADY (ex_ready),
         .B_en (1'b1),    // enable BVALID output
         .BVALID (wb_valid),
         .BREADY (wb_ready),
         .p_ce (p_ce)
      );

   //
   // Pipeline stages
   //
   mDFF_l # (.DW(CONFIG_P_ROB_DEPTH)) ff_wb_rob_id (.CLK(clk), .LOAD(p_ce), .D(ex_rob_id), .Q(wb_rob_id) );
   mDFF_l # (.DW(CONFIG_P_COMMIT_WIDTH)) ff_wb_rob_bank (.CLK(clk), .LOAD(p_ce), .D(ex_rob_bank), .Q(wb_rob_bank) );
   mDFF_l # (.DW(`NCPU_PRF_AW)) ff_prf_WADDR_ex (.CLK(clk), .LOAD(p_ce), .D(ex_prd), .Q(prf_WADDR_ex) );
   mDFF_lr # (.DW(1)) ff_prf_WE_ex (.CLK(clk), .RST(rst), .LOAD(p_ce|flush), .D(s1i_prf_we & ~flush), .Q(s1o_prf_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_prf_WDATA_ex (.CLK(clk), .LOAD(p_ce), .D(s1i_rf_dout), .Q(prf_WDATA_ex) );
   mDFF_l # (.DW(1)) ff_wb_fls (.CLK(clk), .LOAD(p_ce|flush), .D(s1i_wb_fls), .Q(wb_fls) );
   mDFF_l # (.DW(1)) ff_wb_exc (.CLK(clk), .LOAD(p_ce|flush), .D(s1i_wb_exc), .Q(wb_exc) );
   mDFF_l # (.DW(CONFIG_AW)) ff_wb_opera (.CLK(clk), .LOAD(p_ce), .D(s1i_wb_opera), .Q(wb_opera) );
   mDFF_l # (.DW(CONFIG_DW)) ff_wb_operb (.CLK(clk), .LOAD(p_ce), .D(s1i_wb_operb), .Q(wb_operb) );
   mDFF_l # (.DW(`PC_W)) ff_wb_se_tgt (.CLK(clk), .LOAD(p_ce), .D(s1i_se_tgt), .Q(wb_fls_tgt) );
   
   assign prf_WE_ex = (s1o_prf_we & wb_valid);
   
endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../lib"
// )
// End:
