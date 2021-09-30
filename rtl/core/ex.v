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
   parameter                           CONFIG_P_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
   parameter                           CONFIG_ENABLE_MUL = 0,
   parameter                           CONFIG_ENABLE_DIV = 0,
   parameter                           CONFIG_ENABLE_DIVU = 0,
   parameter                           CONFIG_ENABLE_MOD = 0,
   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0,
   parameter                           CONFIG_NUM_IRQ = 0,
   parameter                           CONFIG_DC_P_WAYS = 0,
   parameter                           CONFIG_DC_P_SETS = 0,
   parameter                           CONFIG_DC_P_LINE = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_DMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_ITLB_P_SETS = 0,
   parameter                           CONFIG_DTLB_P_SETS = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EITM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_ESYSCALL_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EINSN_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIRQ_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDTM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EALIGN_VECTOR = 0,
   parameter                           AXI_P_DW_BYTES    = 0,
   parameter                           AXI_ADDR_WIDTH    = 0,
   parameter                           AXI_ID_WIDTH      = 0,
   parameter                           AXI_USER_WIDTH    = 0
)
(
   input                               clk,
   input                               rst,
   output                              stall,
   output                              flush,
   output [`PC_W-1:0]                  flush_tgt,
   // From RO
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_pred_taken,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_bpu_pred_tgt,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0] ex_fe,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_pfree,
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
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WADDR,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WDATA,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WE,
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
   generate
      for(i=0;i<IW;i=i+1)
         begin gen_FUs
            /* ex_pipe AUTO_TEMPLATE (
               .ex_ready               (ex_ready[i]),
               .wb_valid               (wb_valid[i]),
               .wb_rob_id              (wb_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
               .wb_rob_bank            (wb_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
               .prf_WE                 (prf_WE[i]),
               .prf_WADDR              (prf_WADDR[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]),
               .prf_WDATA              (prf_WDATA[i * CONFIG_DW +: CONFIG_DW]),
               .wb_fls                 (wb_fls[i]),
               .wb_fls_tgt             (wb_fls_tgt[i * `PC_W +: `PC_W]),
               .wb_exc                 (wb_exc[i]),
               .wb_opera               (wb_opera[i * CONFIG_AW +: CONFIG_AW]),
               .wb_operb               (wb_operb[i * CONFIG_DW +: CONFIG_DW]),

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
               .ex_prd                 (ex_prd[i * `NCPU_LRF_AW +: `NCPU_LRF_AW]),
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
                 .CONFIG_P_DW           (CONFIG_P_DW),
                 .CONFIG_PHT_P_NUM      (CONFIG_PHT_P_NUM),
                 .CONFIG_BTB_P_NUM      (CONFIG_BTB_P_NUM),
                 .CONFIG_ENABLE_MUL     (CONFIG_ENABLE_MUL),
                 .CONFIG_ENABLE_DIV     (CONFIG_ENABLE_DIV),
                 .CONFIG_ENABLE_DIVU    (CONFIG_ENABLE_DIVU),
                 .CONFIG_ENABLE_MOD     (CONFIG_ENABLE_MOD),
                 .CONFIG_ENABLE_MODU    (CONFIG_ENABLE_MODU),
                 .CONFIG_ENABLE_ASR     (CONFIG_ENABLE_ASR),
                 .CONFIG_EITM_VECTOR    (CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EIPF_VECTOR    (CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_ESYSCALL_VECTOR(CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EINSN_VECTOR   (CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EIRQ_VECTOR    (CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EDTM_VECTOR    (CONFIG_EDTM_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EDPF_VECTOR    (CONFIG_EDPF_VECTOR[`EXCP_VECT_W-1:0]),
                 .CONFIG_EALIGN_VECTOR  (CONFIG_EALIGN_VECTOR[`EXCP_VECT_W-1:0]))
            U_PIPE
               (/*AUTOINST*/
                // Outputs
                .ex_ready               (ex_ready[i]),           // Templated
                .wb_valid               (wb_valid[i]),           // Templated
                .wb_rob_id              (wb_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .wb_rob_bank            (wb_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
                .prf_WE                 (prf_WE[i]),             // Templated
                .prf_WADDR              (prf_WADDR[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .prf_WDATA              (prf_WDATA[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .wb_fls                 (wb_fls[i]),             // Templated
                .wb_exc                 (wb_exc[i]),             // Templated
                .wb_opera               (wb_opera[i * CONFIG_AW +: CONFIG_AW]), // Templated
                .wb_operb               (wb_operb[i * CONFIG_DW +: CONFIG_DW]), // Templated
                // Inputs
                .clk                    (clk),
                .rst                    (rst),
                .flush                  (flush),
                .ex_valid               (ex_valid[i]),           // Templated
                .ex_alu_opc_bus         (ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .ex_lpu_opc_bus         (ex_lpu_opc_bus[i * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
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
                .ex_prd                 (ex_prd[i * `NCPU_LRF_AW +: `NCPU_LRF_AW]), // Templated
                .ex_prd_we              (ex_prd_we[i]),          // Templated
                .ex_rob_id              (ex_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .ex_rob_bank            (ex_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
                .wb_ready               (wb_ready[i]));           // Templated
         end
   endgenerate
   
`ifdef ENABLE_DIFFTEST
   //
   // Signals used for difftest
   //
   wire [IW-1:0]                       s1o_valid;
   wire [IW-1:0]                       s2o_valid;
   wire                                s2o_excp;
   wire [`PC_W-1:0]                    s2o_excp_vect;
   wire [`PC_W*IW-1:0]                 s1o_pc;
   wire [`PC_W*IW-1:0]                 s2o_pc;
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_valid_ff, commit_valid;
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_pc;
   wire                                commit_excp;
   wire [`PC_W-1:0]                    commit_excp_vect;
   wire [CONFIG_NUM_IRQ-1:0]           commit_irq_no;

   wire s1i_dft_stall_req = (icinv_stall_req | `test_stall); // Stall req from s1
   wire s1o_dft_stall_req;
   wire s3i_dft_stall_req = (lsu_stall_req); // Stall req from s3
   
   mDFF_r #(.DW(1)) ff_s1o_dft_stall_req (.CLK(clk), .RST(rst), .D(s1i_dft_stall_req), .Q(s1o_dft_stall_req) );
   
   mDFF_lr #(.DW(IW)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush_s1), .D(s1i_cmt_valid & {IW{~flush_s1}}), .Q(s1o_valid) );
   
   // Once the first channel induced an exception, the remaining channels would be invalidated.
   // However, the first channel that causes the exception should notify difftest to synchronize architectural event.
   mDFF_lr # (.DW(1)) ff_s2o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s2), .D(s1o_valid[0] & ~s1o_dft_stall_req), .Q(s2o_valid[0]) );
   mDFF_lr # (.DW(IW-1)) ff_s2o_valid2 (.CLK(clk), .RST(rst), .LOAD(p_ce_s2|flush_s2), .D(s1o_valid[IW-1:1] & {IW-1{~flush_s2 & ~s1o_dft_stall_req}}), .Q(s2o_valid[IW-1:1]) );
   
   mDFF_lr # (.DW(1)) ff_s2o_excp (.CLK(clk), .RST(rst), .LOAD(p_ce_s2), .D(exc_flush), .Q(s2o_excp) );
   mDFF_l # (.DW(`PC_W)) ff_s2o_excp_vect (.CLK(clk), .LOAD(p_ce_s2), .D(exc_flush_tgt), .Q(s2o_excp_vect) );
   mDFF_l # (.DW(`PC_W*IW)) ff_s1o_pc (.CLK(clk), .LOAD(p_ce_s1), .D(ex_pc), .Q(s1o_pc) );
   mDFF_l # (.DW(`PC_W*IW)) ff_s2o_pc (.CLK(clk), .LOAD(p_ce_s2), .D(s1o_pc), .Q(s2o_pc) );
   mDFF_lr # (.DW(IW)) ff_commit_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s3), .D(s2o_valid), .Q(commit_valid_ff) );
   mDFF_l # (.DW(`PC_W*IW)) ff_commit_pc (.CLK(clk), .LOAD(p_ce_s3), .D(s2o_pc), .Q(commit_pc) );
   mDFF_lr # (.DW(1)) ff_commit_excp (.CLK(clk), .RST(rst), .LOAD(p_ce_s3), .D(s2o_excp), .Q(commit_excp) );
   mDFF_l # (.DW(`PC_W)) ff_commit_exc_vect (.CLK(clk), .LOAD(p_ce_s3), .D(s2o_excp_vect), .Q(commit_excp_vect) );
   
   assign commit_valid = (commit_valid_ff & {IW{~s3i_dft_stall_req}});
`endif

`ifdef ENABLE_DIFFTEST
   wire [31:0] dbg_ex_pc[IW-1:0];
   wire [31:0] dbg_s1o_pc[IW-1:0];
   wire [31:0] dbg_s2o_pc[IW-1:0];
   generate
      for(i=0;i<IW;i=i+1)  
         begin
            assign dbg_ex_pc[i] = {ex_pc[i*`PC_W +: `PC_W], 2'b00};
            assign dbg_s1o_pc[i] = {s1o_pc[i*`PC_W +: `PC_W], 2'b00};
            assign dbg_s2o_pc[i] = {s2o_pc[i*`PC_W +: `PC_W], 2'b00};
         end
   endgenerate
`endif

endmodule
