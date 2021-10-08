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

module ex
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
//   parameter                           CONFIG_ENABLE_MUL = 0,
//   parameter                           CONFIG_ENABLE_DIV = 0,
//   parameter                           CONFIG_ENABLE_DIVU = 0,
//   parameter                           CONFIG_ENABLE_MOD = 0,
//   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   // From RO
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_pred_taken,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_bpu_pred_tgt,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm,
   //input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0] ex_fe,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prd_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_ready,
   // To WB
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_valid,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] wb_rob_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] wb_rob_bank,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_fls,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_exc,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_opera,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_operb,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_fls_tgt,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WADDR_ex,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WDATA_ex,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WE_ex,
   // From WB
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_ready
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   genvar i;

   //
   // Pipelines
   //
   generate for(i=0;i<IW;i=i+1)
      begin : gen_FUs
         /* ex_pipe AUTO_TEMPLATE (
            .ex_ready               (ex_ready[i]),
            .wb_valid               (wb_valid[i]),
            .wb_rob_id              (wb_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
            .wb_rob_bank            (wb_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
            .prf_WE_ex              (prf_WE_ex[i]),
            .prf_WADDR_ex           (prf_WADDR_ex[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]),
            .prf_WDATA_ex           (prf_WDATA_ex[i * CONFIG_DW +: CONFIG_DW]),
            .wb_fls                 (wb_fls[i]),
            .wb_exc                 (wb_exc[i]),
            .wb_opera               (wb_opera[i * CONFIG_AW +: CONFIG_AW]),
            .wb_operb               (wb_operb[i * CONFIG_DW +: CONFIG_DW]),
            .wb_fls_tgt             (wb_fls_tgt[i * `PC_W +: `PC_W]),
            
            .ex_valid               (ex_valid[i]),
            .ex_alu_opc_bus         (ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
            .ex_lpu_opc_bus         (ex_lpu_opc_bus[i * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
            .ex_epu_op              (ex_epu_op[i]),
            .ex_lsu_op              (ex_lsu_op[i]),
            .ex_bru_opc_bus         (ex_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
            .ex_fe                  (ex_fe[i * `NCPU_FE_W +: `NCPU_FE_W]),
            .ex_bpu_pred_taken      (ex_bpu_pred_taken[i]),
            .ex_bpu_pred_tgt        (ex_bpu_pred_tgt[i * `PC_W +: `PC_W]),
            .ex_pc                  (ex_pc[i * `PC_W +: `PC_W]),
            .ex_imm                 (ex_imm[i * CONFIG_DW +: CONFIG_DW]),
            .ex_operand1            (ex_operand1[i * CONFIG_DW +: CONFIG_DW]),
            .ex_operand2            (ex_operand2[i * CONFIG_DW +: CONFIG_DW]),
            .ex_prd                 (ex_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]),
            .ex_prd_we              (ex_prd_we[i]),
            .ex_rob_id              (ex_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
            .ex_rob_bank            (ex_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
            .wb_ready               (wb_ready[i]),
          )*/
         ex_pipe
            #(/*AUTOINSTPARAM*/
              // Parameters
              .CONFIG_AW             (CONFIG_AW),
              .CONFIG_DW             (CONFIG_DW),
              .CONFIG_P_ROB_DEPTH    (CONFIG_P_ROB_DEPTH),
              .CONFIG_P_COMMIT_WIDTH (CONFIG_P_COMMIT_WIDTH),
              .CONFIG_ENABLE_ASR     (CONFIG_ENABLE_ASR))
         U_PIPE
            (/*AUTOINST*/
             // Outputs
             .ex_ready               (ex_ready[i]),           // Templated
             .wb_valid               (wb_valid[i]),           // Templated
             .wb_rob_id              (wb_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
             .wb_rob_bank            (wb_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
             .prf_WE_ex              (prf_WE_ex[i]),          // Templated
             .prf_WADDR_ex           (prf_WADDR_ex[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
             .prf_WDATA_ex           (prf_WDATA_ex[i * CONFIG_DW +: CONFIG_DW]), // Templated
             .wb_fls                 (wb_fls[i]),             // Templated
             .wb_exc                 (wb_exc[i]),             // Templated
             .wb_opera               (wb_opera[i * CONFIG_AW +: CONFIG_AW]), // Templated
             .wb_operb               (wb_operb[i * CONFIG_DW +: CONFIG_DW]), // Templated
             .wb_fls_tgt             (wb_fls_tgt[i * `PC_W +: `PC_W]), // Templated
             // Inputs
             .clk                    (clk),
             .rst                    (rst),
             .flush                  (flush),
             .ex_valid               (ex_valid[i]),           // Templated
             .ex_alu_opc_bus         (ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
             .ex_epu_op              (ex_epu_op[i]),          // Templated
             .ex_lsu_op              (ex_lsu_op[i]),          // Templated
             .ex_bru_opc_bus         (ex_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
             .ex_fe                  (ex_fe[i * `NCPU_FE_W +: `NCPU_FE_W]), // Templated
             .ex_bpu_pred_taken      (ex_bpu_pred_taken[i]),  // Templated
             .ex_bpu_pred_tgt        (ex_bpu_pred_tgt[i * `PC_W +: `PC_W]), // Templated
             .ex_pc                  (ex_pc[i * `PC_W +: `PC_W]), // Templated
             .ex_imm                 (ex_imm[i * CONFIG_DW +: CONFIG_DW]), // Templated
             .ex_operand1            (ex_operand1[i * CONFIG_DW +: CONFIG_DW]), // Templated
             .ex_operand2            (ex_operand2[i * CONFIG_DW +: CONFIG_DW]), // Templated
             .ex_prd                 (ex_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
             .ex_prd_we              (ex_prd_we[i]),          // Templated
             .ex_rob_id              (ex_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
             .ex_rob_bank            (ex_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
             .wb_ready               (wb_ready[i]));           // Templated
      end
   endgenerate

`ifdef ENABLE_DEBUG_SIM
   wire [31:0] dbg_ex_pc[IW-1:0];
   generate for(i=0;i<IW;i=i+1)  
      begin : gen_dbg
         assign dbg_ex_pc[i] = {ex_pc[i*`PC_W +: `PC_W], 2'b00};
      end
   endgenerate
`endif

endmodule
