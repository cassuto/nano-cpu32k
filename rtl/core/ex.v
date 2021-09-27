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
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid,
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_alu_opc_bus,
   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_imm,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand1,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand2,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_waddr,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_we,
   // To bypass
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_dout,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_dout,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_dout,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_wdat,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_we,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_waddr,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_waddr,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_waddr,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_waddr,
   output                              ro_ex_s1_load0,
   output                              ro_ex_s2_load0,
   output                              ro_ex_s3_load0,
   // To commit
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we,
   // To BPU
   output                              bpu_wb,
   output                              bpu_wb_is_bcc,
   output                              bpu_wb_is_breg,
   output                              bpu_wb_is_brel,
   output                              bpu_wb_taken,
   output [`PC_W-1:0]                  bpu_wb_pc,
   output [`PC_W-1:0]                  bpu_wb_npc_act,
   output [`BPU_UPD_W-1:0]             bpu_wb_upd,
   // IRQs
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              irq_async,
   output                              tsc_irq,
   // PSR
   output                              msr_psr_imme,
   output                              msr_psr_rm,
   output                              msr_psr_ice,
   // IMMID
   input [CONFIG_DW-1:0]               msr_immid,
   // ITLBL
   output [CONFIG_ITLB_P_SETS-1:0]     msr_imm_tlbl_idx,
   output [CONFIG_DW-1:0]              msr_imm_tlbl_nxt,
   output                              msr_imm_tlbl_we,
   // ITLBH
   output [CONFIG_ITLB_P_SETS-1:0]     msr_imm_tlbh_idx,
   output [CONFIG_DW-1:0]              msr_imm_tlbh_nxt,
   output                              msr_imm_tlbh_we,
   // ICID
   input [CONFIG_DW-1:0]               msr_icid,
   // ICINV
   output [CONFIG_DW-1:0]              msr_icinv_nxt,
   output                              msr_icinv_we,
   input                               msr_icinv_ready,
   // AXI Master (Cached access)
   input                               dbus_ARREADY,
   output                              dbus_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_ARADDR,
   output [2:0]                        dbus_ARPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_ARID,
   output [AXI_USER_WIDTH-1:0]         dbus_ARUSER,
   output [7:0]                        dbus_ARLEN,
   output [2:0]                        dbus_ARSIZE,
   output [1:0]                        dbus_ARBURST,
   output                              dbus_ARLOCK,
   output [3:0]                        dbus_ARCACHE,
   output [3:0]                        dbus_ARQOS,
   output [3:0]                        dbus_ARREGION,

   output                              dbus_RREADY,
   input                               dbus_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_RDATA,
   input  [1:0]                        dbus_RRESP,
   input                               dbus_RLAST,
   input  [AXI_ID_WIDTH-1:0]           dbus_RID,
   input  [AXI_USER_WIDTH-1:0]         dbus_RUSER,

   input                               dbus_AWREADY,
   output                              dbus_AWVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_AWADDR,
   output [2:0]                        dbus_AWPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_AWID,
   output [AXI_USER_WIDTH-1:0]         dbus_AWUSER,
   output [7:0]                        dbus_AWLEN,
   output [2:0]                        dbus_AWSIZE,
   output [1:0]                        dbus_AWBURST,
   output                              dbus_AWLOCK,
   output [3:0]                        dbus_AWCACHE,
   output [3:0]                        dbus_AWQOS,
   output [3:0]                        dbus_AWREGION,

   input                               dbus_WREADY,
   output                              dbus_WVALID,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_WDATA,
   output [(1<<AXI_P_DW_BYTES)-1:0]    dbus_WSTRB,
   output                              dbus_WLAST,
   output [AXI_USER_WIDTH-1:0]         dbus_WUSER,

   output                              dbus_BREADY,
   input                               dbus_BVALID,
   input [1:0]                         dbus_BRESP,
   input [AXI_ID_WIDTH-1:0]            dbus_BID,
   input [AXI_USER_WIDTH-1:0]          dbus_BUSER
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 exc_flush;              // From U_PIPE_U of ex_pipe_u.v
   wire [`PC_W-1:0]     exc_flush_tgt;          // From U_PIPE_U of ex_pipe_u.v
   wire                 icinv_stall_req;        // From U_PIPE_U of ex_pipe_u.v
   wire                 lsu_stall_req;          // From U_PIPE_U of ex_pipe_u.v
   wire                 pu_b_cc;                // From U_PIPE_U of ex_pipe_u.v
   wire                 pu_b_reg;               // From U_PIPE_U of ex_pipe_u.v
   wire                 pu_b_rel;               // From U_PIPE_U of ex_pipe_u.v
   wire                 pu_b_taken;             // From U_PIPE_U of ex_pipe_u.v
   wire                 pu_se_fail;             // From U_PIPE_U of ex_pipe_u.v
   wire [`PC_W-1:0]     pu_se_tgt;              // From U_PIPE_U of ex_pipe_u.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                flush_s1;               // To U_PIPE_V of ex_pipe_v.v
   wire                                flush_s2;               // To U_PIPE_V of ex_pipe_v.v
   wire [`PC_W*IW-1:0]                 ex_npc;
   wire                                p_ce_s1;                // To U_PIPE_U of ex_pipe_u.v, ...
   wire                                p_ce_s1_no_icinv_stall; // To U_PIPE_U of ex_pipe_u.v
   wire                                p_ce_s2;                // To U_PIPE_U of ex_pipe_u.v, ...
   wire                                p_ce_s3;                // To U_PIPE_U of ex_pipe_u.v, ...
   wire [IW-1:1]                       pv_se_fail;             // From U_PIPE_V of ex_pipe_v.v
   wire [`PC_W-1:0]                    pv_se_tgt [IW-1:1];     // From U_PIPE_V of ex_pipe_v.v
   reg [IW-1:0]                        cmt_valid_msk;
   wire                                se_flush;
   // Stage 1 Input
   wire [IW-1:0]                       s1i_cmt_valid;          // To U_PIPE_V of ex_pipe_v.v
   wire [IW-1:0]                       s1i_se_fail_vec;
   wire [`PC_W*IW-1:0]                 s1i_se_tgt_vec;
   wire                                s1i_se_fail;
   wire [`PC_W-1:0]                    s1i_se_tgt;
   // Stage 2 Input / Stage 1 Output
   wire                                s1o_se_flush;
   wire [`PC_W-1:0]                    s1o_se_flush_tgt;
   
   genvar i;
   integer j;

   //
   // U/V Pipelines
   //
   
   /* ex_pipe_u AUTO_TEMPLATE(
         .se_fail                      (pu_se_fail),
         .se_tgt                       (pu_se_tgt[]),
         .b_taken                      (pu_b_taken),
         .b_cc                         (pu_b_cc),
         .b_reg                        (pu_b_reg),
         .b_rel                        (pu_b_rel),
         .ro_ex_s1_rf_dout             (ro_ex_s1_rf_dout[0 * CONFIG_DW +: CONFIG_DW]),
         .ro_ex_s2_rf_dout             (ro_ex_s2_rf_dout[0 * CONFIG_DW +: CONFIG_DW]),
         .ro_ex_s3_rf_dout             (ro_ex_s3_rf_dout[0 * CONFIG_DW +: CONFIG_DW]),
         .ro_cmt_rf_wdat               (ro_cmt_rf_wdat[0 * CONFIG_DW +: CONFIG_DW]),
         .ro_ex_s1_rf_we               (ro_ex_s1_rf_we[0]),
         .ro_ex_s2_rf_we               (ro_ex_s2_rf_we[0]),
         .ro_ex_s3_rf_we               (ro_ex_s3_rf_we[0]),
         .ro_cmt_rf_we                 (ro_cmt_rf_we[0]),
         .ro_ex_s1_rf_waddr            (ro_ex_s1_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .ro_ex_s2_rf_waddr            (ro_ex_s2_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .ro_ex_s3_rf_waddr            (ro_ex_s3_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .ro_cmt_rf_waddr              (ro_cmt_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .commit_rf_wdat               (commit_rf_wdat[0 * CONFIG_DW +: CONFIG_DW]),
         .commit_rf_waddr              (commit_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .commit_rf_we                 (commit_rf_we[0]),
         
         .ex_cmt_valid                 (s1i_cmt_valid[0]),
         .ex_npc                       (ex_npc[0 * `PC_W +: `PC_W]),
         .ex_valid                     (ex_valid[0]),
         .ex_alu_opc_bus               (ex_alu_opc_bus[0 * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
         .ex_lpu_opc_bus               (ex_lpu_opc_bus[0 * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
         .ex_epu_opc_bus               (ex_epu_opc_bus[0 * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
         .ex_bru_opc_bus               (ex_bru_opc_bus[0 * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
         .ex_lsu_opc_bus               (ex_lsu_opc_bus[0 * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
         .ex_bpu_pred_taken            (ex_bpu_upd[0 * `BPU_UPD_W + `BPU_UPD_TAKEN]),
         .ex_bpu_pred_tgt              (ex_bpu_upd[`BPU_UPD_TGT]),
         .ex_pc                        (ex_pc[0 * `PC_W +: `PC_W]),
         .ex_imm                       (ex_imm[0 * CONFIG_DW +: CONFIG_DW]),
         .ex_operand1                  (ex_operand1[0 * CONFIG_DW +: CONFIG_DW]),
         .ex_operand2                  (ex_operand2[0 * CONFIG_DW +: CONFIG_DW]),
         .ex_rf_waddr                  (ex_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]),
         .ex_rf_we                     (ex_rf_we[0]),
      )
    */
   ex_pipe_u
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_ENABLE_MUL              (CONFIG_ENABLE_MUL),
        .CONFIG_ENABLE_DIV              (CONFIG_ENABLE_DIV),
        .CONFIG_ENABLE_DIVU             (CONFIG_ENABLE_DIVU),
        .CONFIG_ENABLE_MOD              (CONFIG_ENABLE_MOD),
        .CONFIG_ENABLE_MODU             (CONFIG_ENABLE_MODU),
        .CONFIG_ENABLE_ASR              (CONFIG_ENABLE_ASR),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_EITM_VECTOR             (CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIPF_VECTOR             (CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_ESYSCALL_VECTOR         (CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EINSN_VECTOR            (CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIRQ_VECTOR             (CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDTM_VECTOR             (CONFIG_EDTM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDPF_VECTOR             (CONFIG_EDPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EALIGN_VECTOR           (CONFIG_EALIGN_VECTOR[`EXCP_VECT_W-1:0]),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_PIPE_U
      (/*AUTOINST*/
       // Outputs
       .lsu_stall_req                   (lsu_stall_req),
       .icinv_stall_req                 (icinv_stall_req),
       .se_fail                         (pu_se_fail),            // Templated
       .se_tgt                          (pu_se_tgt[`PC_W-1:0]),  // Templated
       .exc_flush                       (exc_flush),
       .exc_flush_tgt                   (exc_flush_tgt[`PC_W-1:0]),
       .b_taken                         (pu_b_taken),            // Templated
       .b_cc                            (pu_b_cc),               // Templated
       .b_reg                           (pu_b_reg),              // Templated
       .b_rel                           (pu_b_rel),              // Templated
       .ro_ex_s1_rf_dout                (ro_ex_s1_rf_dout[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ro_ex_s2_rf_dout                (ro_ex_s2_rf_dout[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ro_ex_s3_rf_dout                (ro_ex_s3_rf_dout[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ro_cmt_rf_wdat                  (ro_cmt_rf_wdat[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ro_ex_s1_rf_we                  (ro_ex_s1_rf_we[0]),     // Templated
       .ro_ex_s2_rf_we                  (ro_ex_s2_rf_we[0]),     // Templated
       .ro_ex_s3_rf_we                  (ro_ex_s3_rf_we[0]),     // Templated
       .ro_cmt_rf_we                    (ro_cmt_rf_we[0]),       // Templated
       .ro_ex_s1_rf_waddr               (ro_ex_s1_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .ro_ex_s2_rf_waddr               (ro_ex_s2_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .ro_ex_s3_rf_waddr               (ro_ex_s3_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .ro_cmt_rf_waddr                 (ro_cmt_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .ro_ex_s1_load0                  (ro_ex_s1_load0),
       .ro_ex_s2_load0                  (ro_ex_s2_load0),
       .ro_ex_s3_load0                  (ro_ex_s3_load0),
       .commit_rf_wdat                  (commit_rf_wdat[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .commit_rf_waddr                 (commit_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .commit_rf_we                    (commit_rf_we[0]),       // Templated
       .irq_async                       (irq_async),
       .tsc_irq                         (tsc_irq),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ice                     (msr_psr_ice),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .dbus_ARVALID                    (dbus_ARVALID),
       .dbus_ARADDR                     (dbus_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .dbus_ARPROT                     (dbus_ARPROT[2:0]),
       .dbus_ARID                       (dbus_ARID[AXI_ID_WIDTH-1:0]),
       .dbus_ARUSER                     (dbus_ARUSER[AXI_USER_WIDTH-1:0]),
       .dbus_ARLEN                      (dbus_ARLEN[7:0]),
       .dbus_ARSIZE                     (dbus_ARSIZE[2:0]),
       .dbus_ARBURST                    (dbus_ARBURST[1:0]),
       .dbus_ARLOCK                     (dbus_ARLOCK),
       .dbus_ARCACHE                    (dbus_ARCACHE[3:0]),
       .dbus_ARQOS                      (dbus_ARQOS[3:0]),
       .dbus_ARREGION                   (dbus_ARREGION[3:0]),
       .dbus_RREADY                     (dbus_RREADY),
       .dbus_AWVALID                    (dbus_AWVALID),
       .dbus_AWADDR                     (dbus_AWADDR[AXI_ADDR_WIDTH-1:0]),
       .dbus_AWPROT                     (dbus_AWPROT[2:0]),
       .dbus_AWID                       (dbus_AWID[AXI_ID_WIDTH-1:0]),
       .dbus_AWUSER                     (dbus_AWUSER[AXI_USER_WIDTH-1:0]),
       .dbus_AWLEN                      (dbus_AWLEN[7:0]),
       .dbus_AWSIZE                     (dbus_AWSIZE[2:0]),
       .dbus_AWBURST                    (dbus_AWBURST[1:0]),
       .dbus_AWLOCK                     (dbus_AWLOCK),
       .dbus_AWCACHE                    (dbus_AWCACHE[3:0]),
       .dbus_AWQOS                      (dbus_AWQOS[3:0]),
       .dbus_AWREGION                   (dbus_AWREGION[3:0]),
       .dbus_WVALID                     (dbus_WVALID),
       .dbus_WDATA                      (dbus_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .dbus_WSTRB                      (dbus_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
       .dbus_WLAST                      (dbus_WLAST),
       .dbus_WUSER                      (dbus_WUSER[AXI_USER_WIDTH-1:0]),
       .dbus_BREADY                     (dbus_BREADY),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .p_ce_s1                         (p_ce_s1),
       .p_ce_s2                         (p_ce_s2),
       .p_ce_s3                         (p_ce_s3),
       .p_ce_s1_no_icinv_stall          (p_ce_s1_no_icinv_stall),
       .flush_s1                        (flush_s1),
       .flush_s2                        (flush_s2),
       .ex_cmt_valid                    (s1i_cmt_valid[0]),      // Templated
       .ex_npc                          (ex_npc[0 * `PC_W +: `PC_W]), // Templated
       .ex_valid                        (ex_valid[0]),           // Templated
       .ex_alu_opc_bus                  (ex_alu_opc_bus[0 * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
       .ex_lpu_opc_bus                  (ex_lpu_opc_bus[0 * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
       .ex_epu_opc_bus                  (ex_epu_opc_bus[0 * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]), // Templated
       .ex_bru_opc_bus                  (ex_bru_opc_bus[0 * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
       .ex_lsu_opc_bus                  (ex_lsu_opc_bus[0 * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]), // Templated
       .ex_bpu_pred_taken               (ex_bpu_upd[0 * `BPU_UPD_W + `BPU_UPD_TAKEN]), // Templated
       .ex_bpu_pred_tgt                 (ex_bpu_upd[`BPU_UPD_TGT]), // Templated
       .ex_pc                           (ex_pc[0 * `PC_W +: `PC_W]), // Templated
       .ex_imm                          (ex_imm[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ex_operand1                     (ex_operand1[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ex_operand2                     (ex_operand2[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .ex_rf_waddr                     (ex_rf_waddr[0 * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
       .ex_rf_we                        (ex_rf_we[0]),           // Templated
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .msr_icinv_ready                 (msr_icinv_ready),
       .dbus_ARREADY                    (dbus_ARREADY),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .dbus_RRESP                      (dbus_RRESP[1:0]),
       .dbus_RLAST                      (dbus_RLAST),
       .dbus_RID                        (dbus_RID[AXI_ID_WIDTH-1:0]),
       .dbus_RUSER                      (dbus_RUSER[AXI_USER_WIDTH-1:0]),
       .dbus_AWREADY                    (dbus_AWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_BRESP                      (dbus_BRESP[1:0]),
       .dbus_BID                        (dbus_BID[AXI_ID_WIDTH-1:0]),
       .dbus_BUSER                      (dbus_BUSER[AXI_USER_WIDTH-1:0]));
      
   generate
      for(i=1;i<IW;i=i+1)
         begin : gen_alus
            /* ex_pipe_v AUTO_TEMPLATE(
                  .se_fail             (pv_se_fail[i]),
                  .se_tgt              (pv_se_tgt[i]),
                  .ro_ex_s1_rf_dout    (ro_ex_s1_rf_dout[i * CONFIG_DW +: CONFIG_DW]),
                  .ro_ex_s2_rf_dout    (ro_ex_s2_rf_dout[i * CONFIG_DW +: CONFIG_DW]),
                  .ro_ex_s3_rf_dout    (ro_ex_s3_rf_dout[i * CONFIG_DW +: CONFIG_DW]),
                  .ro_cmt_rf_wdat      (ro_cmt_rf_wdat[i * CONFIG_DW +: CONFIG_DW]),
                  .ro_ex_s1_rf_we      (ro_ex_s1_rf_we[i]),
                  .ro_ex_s2_rf_we      (ro_ex_s2_rf_we[i]),
                  .ro_ex_s3_rf_we      (ro_ex_s3_rf_we[i]),
                  .ro_cmt_rf_we        (ro_cmt_rf_we[i]),
                  .ro_ex_s1_rf_waddr   (ro_ex_s1_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .ro_ex_s2_rf_waddr   (ro_ex_s2_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .ro_ex_s3_rf_waddr   (ro_ex_s3_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .ro_cmt_rf_waddr     (ro_cmt_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .commit_rf_wdat      (commit_rf_wdat[i * CONFIG_DW +: CONFIG_DW]),
                  .commit_rf_waddr     (commit_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .commit_rf_we        (commit_rf_we[i]),
                  .ex_cmt_valid        (s1i_cmt_valid[i]),
                  .ex_npc              (ex_npc[i * `PC_W +: `PC_W]),
                  .ex_valid            (ex_valid[i]),
                  .ex_alu_opc_bus      (ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ex_bpu_pred_taken   (ex_bpu_upd[i * `BPU_UPD_W + `BPU_UPD_TAKEN]),
                  .ex_operand1         (ex_operand1[i * CONFIG_DW +: CONFIG_DW]),
                  .ex_operand2         (ex_operand2[i * CONFIG_DW +: CONFIG_DW]),
                  .ex_rf_waddr         (ex_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]),
                  .ex_rf_we            (ex_rf_we[i]),
               )
             */
            ex_pipe_v
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW),
                 .CONFIG_AW             (CONFIG_AW),
                 .CONFIG_ENABLE_MUL     (CONFIG_ENABLE_MUL),
                 .CONFIG_ENABLE_DIV     (CONFIG_ENABLE_DIV),
                 .CONFIG_ENABLE_DIVU    (CONFIG_ENABLE_DIVU),
                 .CONFIG_ENABLE_MOD     (CONFIG_ENABLE_MOD),
                 .CONFIG_ENABLE_MODU    (CONFIG_ENABLE_MODU),
                 .CONFIG_ENABLE_ASR     (CONFIG_ENABLE_ASR))
            U_PIPE_V
               (/*AUTOINST*/
                // Outputs
                .se_fail                (pv_se_fail[i]),         // Templated
                .se_tgt                 (pv_se_tgt[i]),          // Templated
                .ro_ex_s1_rf_dout       (ro_ex_s1_rf_dout[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ro_ex_s2_rf_dout       (ro_ex_s2_rf_dout[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ro_ex_s3_rf_dout       (ro_ex_s3_rf_dout[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ro_cmt_rf_wdat         (ro_cmt_rf_wdat[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ro_ex_s1_rf_we         (ro_ex_s1_rf_we[i]),     // Templated
                .ro_ex_s2_rf_we         (ro_ex_s2_rf_we[i]),     // Templated
                .ro_ex_s3_rf_we         (ro_ex_s3_rf_we[i]),     // Templated
                .ro_cmt_rf_we           (ro_cmt_rf_we[i]),       // Templated
                .ro_ex_s1_rf_waddr      (ro_ex_s1_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .ro_ex_s2_rf_waddr      (ro_ex_s2_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .ro_ex_s3_rf_waddr      (ro_ex_s3_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .ro_cmt_rf_waddr        (ro_cmt_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .commit_rf_wdat         (commit_rf_wdat[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .commit_rf_waddr        (commit_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .commit_rf_we           (commit_rf_we[i]),       // Templated
                // Inputs
                .clk                    (clk),
                .rst                    (rst),
                .p_ce_s1                (p_ce_s1),
                .p_ce_s2                (p_ce_s2),
                .p_ce_s3                (p_ce_s3),
                .flush_s1               (flush_s1),
                .flush_s2               (flush_s2),
                .ex_cmt_valid           (s1i_cmt_valid[i]),      // Templated
                .ex_npc                 (ex_npc[i * `PC_W +: `PC_W]), // Templated
                .ex_valid               (ex_valid[i]),           // Templated
                .ex_alu_opc_bus         (ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .ex_bpu_pred_taken      (ex_bpu_upd[i * `BPU_UPD_W + `BPU_UPD_TAKEN]), // Templated
                .ex_operand1            (ex_operand1[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ex_operand2            (ex_operand2[i * CONFIG_DW +: CONFIG_DW]), // Templated
                .ex_rf_waddr            (ex_rf_waddr[i * `NCPU_REG_AW +: `NCPU_REG_AW]), // Templated
                .ex_rf_we               (ex_rf_we[i]));           // Templated
         end
   endgenerate

   // NPC address generator
   generate
      for(i=0;i<IW;i=i+1)
         mADD #(.DW(`PC_W)) U_NPC_GEN (.a(ex_pc[i*`PC_W +: `PC_W]), .b('b1), .s(1'b0), .sum(ex_npc[i * `PC_W +: `PC_W]) );
   endgenerate

   // Speculative execution check point
   assign s1i_se_fail_vec[0] = pu_se_fail;
   assign s1i_se_tgt_vec[0 +: `PC_W] = pu_se_tgt;
   generate
      for(i=1;i<IW;i=i+1)
         begin
            assign s1i_se_fail_vec[i] = pv_se_fail[i];
            assign s1i_se_tgt_vec[i*`PC_W +: `PC_W] = pv_se_tgt[i];
         end
   endgenerate

   pmux_v #(.SELW(IW), .DW(`PC_W)) pmux_se_tgt (.sel(s1i_se_fail_vec), .din(s1i_se_tgt_vec), .dout(s1i_se_tgt), .valid(s1i_se_fail) );

   always @(*)
      begin
         cmt_valid_msk[0] = 'b1;
         for(j=1;j<IW;j=j+1)
            cmt_valid_msk[j] = cmt_valid_msk[j-1] & ~s1i_se_fail_vec[j-1];
      end
   
   assign s1i_cmt_valid = (ex_valid & cmt_valid_msk);
   
   assign se_flush = (s1o_se_flush & p_ce_s2);

   // Write BPU
   assign bpu_wb = ex_valid[0];
   assign bpu_wb_is_bcc = pu_b_cc;
   assign bpu_wb_is_breg = pu_b_reg;
   assign bpu_wb_is_brel = pu_b_rel;
   assign bpu_wb_taken = pu_b_taken;
   assign bpu_wb_pc = ex_pc[0 +: `PC_W];
   assign bpu_wb_npc_act = s1i_se_tgt_vec[0 +: `PC_W];
   assign bpu_wb_upd = ex_bpu_upd[0*`BPU_UPD_W +: `BPU_UPD_W];

   // Stall signal generator
`ifdef NCPU_TEST_STALL
   localparam TEST_STALL_P = 0;
   wire test_stall;
   reg [TEST_STALL_P:0] test_stall_ff;
   
   always @(posedge clk)
      if (rst | flush_s1)
         test_stall_ff <= 'b0;
      else
         test_stall_ff <= test_stall_ff + 'b1;
   assign test_stall = test_stall_ff[TEST_STALL_P] & ~flush_s1;
   
   initial
      $display("=====\n[WARNING] Stall testing enabled (TEST_STALL_P=%d) \n=====\n", TEST_STALL_P);
`define test_stall test_stall
`else
`define test_stall 1'b0
`endif
   
   // Stall if ICINV is temporarily unavailable during access
   assign icinv_stall_req = (msr_icinv_we & ~msr_icinv_ready);
   
   //
   // Pipeline stall scope:
   // +---------------------+--------------------------------------+
   // | Signal              | Scope                                |
   // +---------------------+-------------+------------------------+
   // | icinv_stall_req     |  Frontend   | EX(s1)                 |
   // | lsu_stall_req       |  Frontend   | EX(s1,s2,s3)           |
   // +---------------------+-------------+------------------------+
   //
   assign stall = (lsu_stall_req | icinv_stall_req | `test_stall);
   assign p_ce_s1 = (p_ce_s1_no_icinv_stall & ~icinv_stall_req);
   assign p_ce_s1_no_icinv_stall = ~(lsu_stall_req | `test_stall);
   assign p_ce_s2 = ~(lsu_stall_req);
   assign p_ce_s3 = ~(lsu_stall_req);
   
   //
   // Pipeline flush scope:
   // +---------------------+--------------------------------------+
   // | Signal              | Scope                                |
   // +---------------------+----------------------+---------------+
   // | exc_flush           | (Output of) Frontend | ID & EX(s1,s2)|
   // | se_flush            | (Output of) Frontend | ID & EX(s1)   |
   // +---------------------+----------------------+---------------+
   //
   assign flush_s1 = (exc_flush | se_flush);
   assign flush_s2 = (exc_flush);
   
   assign flush = (exc_flush | se_flush);
   // Maintain the priority of exception or speculative execution failure
   // Highest - Exception
   // Lowest - Speculative execution failure
   assign flush_tgt = (exc_flush)
                        ? exc_flush_tgt
                        : s1o_se_flush_tgt; /* (se_flush) */
   
   //
   // Pipeline stages
   //
   mDFF_lr # (.DW(1)) ff_s1o_se_flush (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush_s1), .D(s1i_se_fail & ~flush_s1), .Q(s1o_se_flush) );
   mDFF_l # (.DW(`PC_W)) ff_s1o_se_flush_tgt (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_se_tgt), .Q(s1o_se_flush_tgt) );
   
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
