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
   parameter [CONFIG_AW-1:0]           CONFIG_EITM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_ESYSCALL_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EINSN_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIRQ_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDTM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EALIGN_VECTOR = 0,
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
   // From I$
   input                               icop_stall_req,
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
   wire                 epu_EINSN;              // From U_EPU of ex_epu.v
   wire                 epu_EIPF;               // From U_EPU of ex_epu.v
   wire                 epu_EIRQ;               // From U_EPU of ex_epu.v
   wire                 epu_EITM;               // From U_EPU of ex_epu.v
   wire                 epu_ERET;               // From U_EPU of ex_epu.v
   wire                 epu_ESYSCALL;           // From U_EPU of ex_epu.v
   wire                 epu_E_FLUSH_TLB;        // From U_EPU of ex_epu.v
   wire [`PC_W-1:0]     epu_E_FLUSH_TLB_npc;    // From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] epu_dout;               // From U_EPU of ex_epu.v
   wire                 epu_dout_valid;         // From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] epu_wmsr_dat;           // From U_EPU of ex_epu.v
   wire [`NCPU_WMSR_WE_W-1:0] epu_wmsr_we;      // From U_EPU of ex_epu.v
   wire                 exc_flush;              // From U_EPU of ex_epu.v
   wire [`PC_W-1:0]     exc_flush_tgt;          // From U_EPU of ex_epu.v
   wire                 lsu_stall_req;          // From U_LSU of ex_lsu.v
   wire [CONFIG_DW-1:0] msr_coreid;             // From U_PSR of ex_psr.v
   wire [CONFIG_DW-1:0] msr_cpuid;              // From U_PSR of ex_psr.v
   wire [CONFIG_DW-1:0] msr_dcfls_nxt;          // From U_EPU of ex_epu.v
   wire                 msr_dcfls_we;           // From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] msr_dcid;               // From U_LSU of ex_lsu.v
   wire [CONFIG_DW-1:0] msr_dcinv_nxt;          // From U_EPU of ex_epu.v
   wire                 msr_dcinv_we;           // From U_EPU of ex_epu.v
   wire [CONFIG_DTLB_P_SETS-1:0] msr_dmm_tlbh_idx;// From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] msr_dmm_tlbh_nxt;       // From U_EPU of ex_epu.v
   wire                 msr_dmm_tlbh_we;        // From U_EPU of ex_epu.v
   wire [CONFIG_DTLB_P_SETS-1:0] msr_dmm_tlbl_idx;// From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] msr_dmm_tlbl_nxt;       // From U_EPU of ex_epu.v
   wire                 msr_dmm_tlbl_we;        // From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] msr_dmmid;              // From U_LSU of ex_lsu.v
   wire [CONFIG_DW-1:0] msr_elsa;               // From U_PSR of ex_psr.v
   wire [CONFIG_DW-1:0] msr_elsa_nxt;           // From U_EPU of ex_epu.v
   wire                 msr_elsa_we;            // From U_EPU of ex_epu.v
   wire [CONFIG_DW-1:0] msr_epc;                // From U_PSR of ex_psr.v
   wire [CONFIG_DW-1:0] msr_epc_nxt;            // From U_EPU of ex_epu.v
   wire                 msr_epc_we;             // From U_EPU of ex_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr;            // From U_PSR of ex_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nobyp;      // From U_PSR of ex_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nxt;        // From U_EPU of ex_epu.v
   wire                 msr_epsr_we;            // From U_EPU of ex_epu.v
   wire                 msr_exc_ent;            // From U_EPU of ex_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr;             // From U_PSR of ex_psr.v
   wire                 msr_psr_dce;            // From U_PSR of ex_psr.v
   wire                 msr_psr_dce_nxt;        // From U_EPU of ex_epu.v
   wire                 msr_psr_dce_we;         // From U_EPU of ex_epu.v
   wire                 msr_psr_dmme;           // From U_PSR of ex_psr.v
   wire                 msr_psr_dmme_nxt;       // From U_EPU of ex_epu.v
   wire                 msr_psr_dmme_we;        // From U_EPU of ex_epu.v
   wire                 msr_psr_ice_nxt;        // From U_EPU of ex_epu.v
   wire                 msr_psr_ice_we;         // From U_EPU of ex_epu.v
   wire                 msr_psr_imme_nxt;       // From U_EPU of ex_epu.v
   wire                 msr_psr_imme_we;        // From U_EPU of ex_epu.v
   wire                 msr_psr_ire;            // From U_PSR of ex_psr.v
   wire                 msr_psr_ire_nxt;        // From U_EPU of ex_epu.v
   wire                 msr_psr_ire_we;         // From U_EPU of ex_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr_nold;        // From U_PSR of ex_psr.v
   wire                 msr_psr_rm_nxt;         // From U_EPU of ex_epu.v
   wire                 msr_psr_rm_we;          // From U_EPU of ex_epu.v
   wire [CONFIG_DW*`NCPU_SR_NUM-1:0] msr_sr;    // From U_PSR of ex_psr.v
   wire [CONFIG_DW-1:0] msr_sr_nxt;             // From U_EPU of ex_epu.v
   wire [`NCPU_SR_NUM-1:0] msr_sr_we;           // From U_EPU of ex_epu.v
   // End of automatics
   /*AUTOINPUT*/
   wire [CONFIG_DW-1:0]                bru_dout;
   wire                                bru_dout_valid;
   wire                                p_ce;
   wire                                ex_lsu_load0;
   wire                                add_s                         [IW-1:0];
   wire [CONFIG_DW-1:0]                add_sum                       [IW-1:0];
   wire                                add_carry                     [IW-1:0];
   wire                                add_overflow                  [IW-1:0];
   wire                                b_taken;
   wire [`PC_W-1:0]                    b_tgt;
   wire                                is_bcc, is_breg, is_brel;
   wire                                agu_en;
   wire [`BPU_UPD_W-1:0]               ex_bpu_upd_unpacked           [IW-1:0];
   wire [`PC_W-1:0]                    npc                           [IW-1:0];
   reg [IW-1:0]                        valid_msk;
   wire [IW-1:0]                       se_fail_vec;
   wire [`PC_W*IW-1:0]                 se_tgt_vec;
   wire                                se_fail;
   wire [`PC_W-1:0]                    se_tgt;
   wire  [`PC_W-1:0]                   commit_epc;
   wire [`PC_W-1:0]                    commit_nepc;
   wire                                commit_EDTM;
   wire                                commit_EDPF;
   wire                                commit_EALIGN;
   wire  [CONFIG_AW-1:0]               commit_LSA;
   wire                                commit_ERET;
   wire                                commit_ESYSCALL;
   wire                                commit_EINSN;
   wire                                commit_EIPF;
   wire                                commit_EITM;
   wire                                commit_EIRQ;
   wire                                commit_E_FLUSH_TLB;
   wire [`PC_W-1:0]                    commit_E_FLUSH_TLB_npc;
   wire  [`NCPU_WMSR_WE_W-1:0]         commit_wmsr_we;
   wire  [CONFIG_DW-1:0]               commit_wmsr_dat;
   wire                                se_flush;
   wire                                flush_s1;
   wire                                flush_s2;
   // Stage 1 Input
   wire [IW-1:0]                       s1i_valid;
   wire [CONFIG_DW*IW-1:0]             s1i_rf_dout_1, s1i_rf_dout;
   wire [IW-1:0]                       s1i_rf_we;
   // Stage 2 Input / Stage 1 Output
   wire [CONFIG_DW*IW-1:0]             s1o_rf_dout;
   wire [`NCPU_REG_AW*IW-1:0]          s1o_rf_waddr;
   wire [IW-1:0]                       s1o_rf_we;
   wire                                s1o_lsu_load0;
   wire                                s1o_se_flush;
   wire [`PC_W-1:0]                    s1o_se_flush_tgt;
   // Stage 3 Input / Stage 2 Output
   wire [CONFIG_DW-1:0]                s2o_lsu_dout0;
   wire                                s2o_lsu_load0;
   wire [CONFIG_DW*IW-1:0]             s2o_rf_dout;
   wire [`NCPU_REG_AW*IW-1:0]          s2o_rf_waddr;
   wire [IW-1:0]                       s2o_rf_we;
   wire [CONFIG_DW*IW-1:0]             s3i_rf_wdat;
   genvar i;
   integer j;

   //
   // U/V Pipelines
   //
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_alus
            assign ex_bpu_upd_unpacked[i] = ex_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W];

            ex_add
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW))
            U_ADD
               (
                  .a                   (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                  .b                   (((i==0) & agu_en) ? ex_imm[i*CONFIG_DW +: CONFIG_DW] : ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                  .s                   (add_s[i]),
                  .sum                 (add_sum[i]),
                  .carry               (add_carry[i]),
                  .overflow            (add_overflow[i])
               );

            ex_alu
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW),
                 .CONFIG_ENABLE_MUL     (CONFIG_ENABLE_MUL),
                 .CONFIG_ENABLE_DIV     (CONFIG_ENABLE_DIV),
                 .CONFIG_ENABLE_DIVU    (CONFIG_ENABLE_DIVU),
                 .CONFIG_ENABLE_MOD     (CONFIG_ENABLE_MOD),
                 .CONFIG_ENABLE_MODU    (CONFIG_ENABLE_MODU),
                 .CONFIG_ENABLE_ASR     (CONFIG_ENABLE_ASR))
            U_ALU
               (
                  .ex_alu_opc_bus      (ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ex_operand1         (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                  .ex_operand2         (ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                  .add_sum             (add_sum[i]),
                  .alu_result          (s1i_rf_dout_1[i*CONFIG_DW +: CONFIG_DW])
               );

            if (i > 0) // The last n-1 FUs
               begin
                  assign add_s[i] = ex_alu_opc_bus[i*`NCPU_ALU_IOPW + `NCPU_ALU_SUB];
                  assign s1i_rf_dout[i*CONFIG_DW +: CONFIG_DW] = s1i_rf_dout_1[i*CONFIG_DW +: CONFIG_DW];
               end
         end
   endgenerate

   //
   // U Pipeline
   //
   
   ex_bru
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW))
   U_BRU
      (
         .ex_valid         (ex_valid[0]),
         .ex_bru_opc_bus   (ex_bru_opc_bus[0*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
         .ex_pc            (ex_pc[0*`PC_W +: `PC_W]),
         .ex_imm           (ex_imm[0*CONFIG_DW +: CONFIG_DW]),
         .ex_operand1      (ex_operand1[0*CONFIG_DW +: CONFIG_DW]),
         .ex_operand2      (ex_operand2[0*CONFIG_DW +: CONFIG_DW]),
         .ex_rf_we         (ex_rf_we[0]),
         .npc              (npc[0]),
         .add_sum          (add_sum[0]),
         .add_carry        (add_carry[0]),
         .add_overflow     (add_overflow[0]),
         .b_taken          (b_taken),
         .b_tgt            (b_tgt),
         .is_bcc           (is_bcc),
         .is_breg          (is_breg),
         .is_brel          (is_brel),
         .bru_dout         (bru_dout),
         .bru_dout_valid   (bru_dout_valid)
      );

   /* ex_epu AUTO_TEMPLATE (
         .ex_valid         (ex_valid[0]),
         .ex_pc            (ex_pc[0*`PC_W +: `PC_W]),
         .ex_npc           (npc[0]),
         .ex_epu_opc_bus   (ex_epu_opc_bus[0*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
         .ex_operand1      (ex_operand1[0*CONFIG_DW +: CONFIG_DW]),
         .ex_operand2      (ex_operand2[0*CONFIG_DW +: CONFIG_DW]),
         .ex_imm           (ex_imm[0*CONFIG_DW +: CONFIG_DW]),
      ) */
   ex_epu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_EITM_VECTOR             (CONFIG_EITM_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EIPF_VECTOR             (CONFIG_EIPF_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_ESYSCALL_VECTOR         (CONFIG_ESYSCALL_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EINSN_VECTOR            (CONFIG_EINSN_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EIRQ_VECTOR             (CONFIG_EIRQ_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EDTM_VECTOR             (CONFIG_EDTM_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EDPF_VECTOR             (CONFIG_EDPF_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EALIGN_VECTOR           (CONFIG_EALIGN_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ))
   U_EPU
      (/*AUTOINST*/
       // Outputs
       .epu_dout                        (epu_dout[CONFIG_DW-1:0]),
       .epu_dout_valid                  (epu_dout_valid),
       .epu_wmsr_dat                    (epu_wmsr_dat[CONFIG_DW-1:0]),
       .epu_wmsr_we                     (epu_wmsr_we[`NCPU_WMSR_WE_W-1:0]),
       .epu_ERET                        (epu_ERET),
       .epu_ESYSCALL                    (epu_ESYSCALL),
       .epu_EINSN                       (epu_EINSN),
       .epu_EIPF                        (epu_EIPF),
       .epu_EITM                        (epu_EITM),
       .epu_EIRQ                        (epu_EIRQ),
       .epu_E_FLUSH_TLB                 (epu_E_FLUSH_TLB),
       .epu_E_FLUSH_TLB_npc             (epu_E_FLUSH_TLB_npc[`PC_W-1:0]),
       .exc_flush                       (exc_flush),
       .exc_flush_tgt                   (exc_flush_tgt[`PC_W-1:0]),
       .irq_async                       (irq_async),
       .tsc_irq                         (tsc_irq),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_exc_ent                     (msr_exc_ent),
       .msr_psr_ice_nxt                 (msr_psr_ice_nxt),
       .msr_psr_ice_we                  (msr_psr_ice_we),
       .msr_psr_dce_nxt                 (msr_psr_dce_nxt),
       .msr_psr_dce_we                  (msr_psr_dce_we),
       .msr_epc_nxt                     (msr_epc_nxt[CONFIG_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[CONFIG_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[CONFIG_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[CONFIG_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we),
       .msr_sr_nxt                      (msr_sr_nxt[CONFIG_DW-1:0]),
       .msr_sr_we                       (msr_sr_we[`NCPU_SR_NUM-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .stall                           (stall),
       .ex_pc                           (ex_pc[0*`PC_W +: `PC_W]), // Templated
       .ex_npc                          (npc[0]),                // Templated
       .ex_valid                        (ex_valid[0]),           // Templated
       .ex_epu_opc_bus                  (ex_epu_opc_bus[0*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]), // Templated
       .ex_operand1                     (ex_operand1[0*CONFIG_DW +: CONFIG_DW]), // Templated
       .ex_operand2                     (ex_operand2[0*CONFIG_DW +: CONFIG_DW]), // Templated
       .ex_imm                          (ex_imm[0*CONFIG_DW +: CONFIG_DW]), // Templated
       .commit_epc                      (commit_epc[`PC_W-1:0]),
       .commit_nepc                     (commit_nepc[`PC_W-1:0]),
       .commit_EDTM                     (commit_EDTM),
       .commit_EDPF                     (commit_EDPF),
       .commit_EALIGN                   (commit_EALIGN),
       .commit_E_FLUSH_TLB              (commit_E_FLUSH_TLB),
       .commit_LSA                      (commit_LSA[CONFIG_AW-1:0]),
       .commit_ERET                     (commit_ERET),
       .commit_ESYSCALL                 (commit_ESYSCALL),
       .commit_EINSN                    (commit_EINSN),
       .commit_EIPF                     (commit_EIPF),
       .commit_EITM                     (commit_EITM),
       .commit_EIRQ                     (commit_EIRQ),
       .commit_wmsr_we                  (commit_wmsr_we[`NCPU_WMSR_WE_W-1:0]),
       .commit_wmsr_dat                 (commit_wmsr_dat[CONFIG_DW-1:0]),
       .commit_E_FLUSH_TLB_npc          (commit_E_FLUSH_TLB_npc[`PC_W-1:0]),
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_cpuid                       (msr_cpuid[CONFIG_DW-1:0]),
       .msr_epc                         (msr_epc[CONFIG_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epsr_nobyp                  (msr_epsr_nobyp[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[CONFIG_DW-1:0]),
       .msr_coreid                      (msr_coreid[CONFIG_DW-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_dmmid                       (msr_dmmid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .msr_dcid                        (msr_dcid[CONFIG_DW-1:0]),
       .msr_sr                          (msr_sr[CONFIG_DW*`NCPU_SR_NUM-1:0]));

   // BRU reused the adder of ALU
   assign add_s[0] =
      (
         ex_alu_opc_bus[0*`NCPU_ALU_IOPW + `NCPU_ALU_SUB] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BEQ] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BNE] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BGTU] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BGT] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BLEU] |
         ex_bru_opc_bus[0*`NCPU_BRU_IOPW + `NCPU_BRU_BLE]
      );

   // MUX: switch the result of EPU/BRU/ALU (without LSU)
   assign s1i_rf_dout[0*CONFIG_DW +: CONFIG_DW] =
      (epu_dout_valid)
         ? epu_dout
         : (bru_dout_valid)
            ? bru_dout
            : s1i_rf_dout_1[0*CONFIG_DW +: CONFIG_DW];


   /* ex_lsu AUTO_TEMPLATE (
         .ex_valid         (ex_valid[0]),
         .ex_lsu_opc_bus   (ex_lsu_opc_bus[0*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
         .add_sum          (add_sum[0]),
         .ex_operand2      (ex_operand2[0*CONFIG_DW +: CONFIG_DW]),
         .lsu_EDTM         (commit_EDTM),
         .lsu_EDPF         (commit_EDPF),
         .lsu_EALIGN       (commit_EALIGN),
         .lsu_vaddr        (commit_LSA),
         .lsu_dout         (s2o_lsu_dout0),
      ) */
   ex_lsu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_LSU
      (/*AUTOINST*/
       // Outputs
       .lsu_stall_req                   (lsu_stall_req),
       .agu_en                          (agu_en),
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
       .lsu_EDTM                        (commit_EDTM),           // Templated
       .lsu_EDPF                        (commit_EDPF),           // Templated
       .lsu_EALIGN                      (commit_EALIGN),         // Templated
       .lsu_vaddr                       (commit_LSA),            // Templated
       .lsu_dout                        (s2o_lsu_dout0),         // Templated
       .msr_dmmid                       (msr_dmmid[CONFIG_DW-1:0]),
       .msr_dcid                        (msr_dcid[CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .stall                           (stall),
       .flush_s1                        (flush_s1),
       .ex_valid                        (ex_valid[0]),           // Templated
       .ex_lsu_opc_bus                  (ex_lsu_opc_bus[0*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]), // Templated
       .add_sum                         (add_sum[0]),            // Templated
       .ex_operand2                     (ex_operand2[0*CONFIG_DW +: CONFIG_DW]), // Templated
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
       .dbus_BUSER                      (dbus_BUSER[AXI_USER_WIDTH-1:0]),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_dce                     (msr_psr_dce),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[CONFIG_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[CONFIG_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we));
   
   ex_psr
      #(
        .CONFIG_DW                      (CONFIG_DW),
        .CPUID_VER                      (1),
        .CPUID_REV                      (0),
        .CPUID_FIMM                     (1),
        .CPUID_FDMM                     (1),
        .CPUID_FICA                     (1),
        .CPUID_FDCA                     (1),
        .CPUID_FDBG                     (0),
        .CPUID_FFPU                     (0),
        .CPUID_FIRQC                    (1),
        .CPUID_FTSC                     (1)
     )
   U_PSR
      (/*AUTOINST*/
       // Outputs
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_ice                     (msr_psr_ice),
       .msr_psr_dce                     (msr_psr_dce),
       .msr_cpuid                       (msr_cpuid[CONFIG_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epsr_nobyp                  (msr_epsr_nobyp[`NCPU_PSR_DW-1:0]),
       .msr_epc                         (msr_epc[CONFIG_DW-1:0]),
       .msr_elsa                        (msr_elsa[CONFIG_DW-1:0]),
       .msr_coreid                      (msr_coreid[CONFIG_DW-1:0]),
       .msr_sr                          (msr_sr[CONFIG_DW*`NCPU_SR_NUM-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .msr_exc_ent                     (msr_exc_ent),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ice_nxt                 (msr_psr_ice_nxt),
       .msr_psr_ice_we                  (msr_psr_ice_we),
       .msr_psr_dce_nxt                 (msr_psr_dce_nxt),
       .msr_psr_dce_we                  (msr_psr_dce_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_epc_nxt                     (msr_epc_nxt[CONFIG_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[CONFIG_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
       .msr_sr_nxt                      (msr_sr_nxt[CONFIG_DW-1:0]),
       .msr_sr_we                       (msr_sr_we[`NCPU_SR_NUM-1:0]));

   // NPC adders
   generate
      for(i=0;i<IW;i=i+1)
         assign npc[i] = (ex_pc[i*`PC_W +: `PC_W]+'b1);
   endgenerate

   // Speculative execution check point
   assign se_fail_vec[0] = ex_valid[0] & ((b_taken ^ ex_bpu_upd_unpacked[0][`BPU_UPD_TAKEN]) | (b_tgt != ex_bpu_upd_unpacked[0][`BPU_UPD_TGT])); // FAIL
   //ex_valid[0] & ((b_taken ^ ex_bpu_upd_unpacked[0][`BPU_UPD_TAKEN]) | (b_taken & (b_tgt != ex_bpu_upd_unpacked[0][`BPU_UPD_TGT]))); // RIGHT
   assign se_tgt_vec[0 +: `PC_W] = (b_taken) ? b_tgt : npc[0];
   generate
      for(i=1;i<IW;i=i+1)
         begin
            assign se_fail_vec[i] = ex_valid[i] & (1'b0 ^ ex_bpu_upd_unpacked[i][`BPU_UPD_TAKEN]);
            assign se_tgt_vec[i*`PC_W +: `PC_W] = npc[i];
         end
   endgenerate

   pmux_v #(.SELW(IW), .DW(`PC_W)) pmux_se_tgt (.sel(se_fail_vec), .din(se_tgt_vec), .dout(se_tgt), .valid(se_fail) );

   always @(*)
      begin
         valid_msk[0] = 'b1;
         for(j=1;j<IW;j=j+1)
            valid_msk[j] = valid_msk[j-1] & ~se_fail_vec[j-1];
      end
   
   assign s1i_valid = (ex_valid & valid_msk);

   // Write BPU
   assign bpu_wb = ex_valid[0];
   assign bpu_wb_is_bcc = is_bcc;
   assign bpu_wb_is_breg = is_breg;
   assign bpu_wb_is_brel = is_brel;
   assign bpu_wb_taken = b_taken;
   assign bpu_wb_pc = ex_pc[0 +: `PC_W];
   assign bpu_wb_npc_act = se_tgt_vec[0 +: `PC_W];
   assign bpu_wb_upd = ex_bpu_upd[0*`BPU_UPD_W +: `BPU_UPD_W];
   
   assign s1i_rf_we = (s1i_valid & ex_rf_we);

   // MUX for ARF write data
   assign s3i_rf_wdat[0 +: CONFIG_DW] = (s2o_lsu_load0)
                                          ? s2o_lsu_dout0
                                          : s2o_rf_dout[0 +: CONFIG_DW];
   generate
      for(i=1;i<IW;i=i+1)
         assign s3i_rf_wdat[i*CONFIG_DW +: CONFIG_DW] = s2o_rf_dout[i*CONFIG_DW +: CONFIG_DW];
   endgenerate

   assign ex_lsu_load0 = ex_lsu_opc_bus[0*`NCPU_LSU_IOPW + `NCPU_LSU_LOAD];

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
   assign ro_ex_s1_load0 = ex_lsu_load0;
   assign ro_ex_s2_load0 = s1o_lsu_load0;
   assign ro_ex_s3_load0 = s2o_lsu_load0;

   assign stall = (lsu_stall_req | icop_stall_req);
   
   assign p_ce = (~stall);
   
   assign se_flush = (p_ce & s1o_se_flush);
   
   assign flush = (exc_flush | se_flush);
   // Maintain the priority of exception or speculative execution failure
   // Highest - Exception
   // Lowest - Speculative execution failure
   assign flush_tgt = (exc_flush)
                        ? exc_flush_tgt
                        : s1o_se_flush_tgt; /* (se_flush) */ 
   
   //
   // Pipeline flush scope table:
   // exc_flush:  (Output of) Frontend & ID & EX(s1,s2)
   // se_flush:   (Output of) Frontend & ID & EX(s1)
   //
   assign flush_s1 = (exc_flush | se_flush);
   assign flush_s2 = (exc_flush);
   
   //
   // Pipeline stages
   //
   mDFF_lr # (.DW(1)) ff_s1o_se_flush (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(se_fail & ~flush_s1), .Q(s1o_se_flush) );
   mDFF_l # (.DW(`PC_W)) ff_s1o_se_flush_tgt (.CLK(clk), .LOAD(p_ce), .D(se_tgt), .Q(s1o_se_flush_tgt) );
   mDFF_l # (.DW(`NCPU_REG_AW*IW)) ff_s1o_rf_waddr (.CLK(clk), .LOAD(p_ce), .D(ex_rf_waddr), .Q(s1o_rf_waddr) );
   mDFF_lr # (.DW(IW)) ff_s1o_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(s1i_rf_we & {IW{~flush_s1}}), .Q(s1o_rf_we) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_s1o_rf_dout (.CLK(clk), .LOAD(p_ce), .D(s1i_rf_dout), .Q(s1o_rf_dout) );
   mDFF_lr # (.DW(1)) ff_s1o_lsu_load (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(ex_lsu_load0 & ~flush_s1), .Q(s1o_lsu_load0) );
   mDFF_l # (.DW(`PC_W)) ff_commit_epc (.CLK(clk), .LOAD(p_ce), .D(ex_pc[0 +: `PC_W]), .Q(commit_epc) );
   mDFF_l # (.DW(`PC_W)) ff_commit_nepc (.CLK(clk), .LOAD(p_ce), .D(npc[0]), .Q(commit_nepc) );
   mDFF_lr # (.DW(1)) ff_commit_ERET (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_ERET & ~flush_s1), .Q(commit_ERET) );
   mDFF_lr # (.DW(1)) ff_commit_ESYSCALL (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_ESYSCALL & ~flush_s1), .Q(commit_ESYSCALL) );
   mDFF_lr # (.DW(1)) ff_commit_EINSN (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_EINSN & ~flush_s1), .Q(commit_EINSN) );
   mDFF_lr # (.DW(1)) ff_commit_EIPF (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_EIPF & ~flush_s1), .Q(commit_EIPF) );
   mDFF_lr # (.DW(1)) ff_commit_EITM (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_EITM & ~flush_s1), .Q(commit_EITM) );
   mDFF_lr # (.DW(1)) ff_commit_EIRQ (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_EIRQ & ~flush_s1), .Q(commit_EIRQ) );
   mDFF_lr # (.DW(1)) ff_commit_E_FLUSH_TLB (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_E_FLUSH_TLB & ~flush_s1), .Q(commit_E_FLUSH_TLB) );
   mDFF_lr # (.DW(`NCPU_WMSR_WE_W)) ff_commit_wmsr_we (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(epu_wmsr_we  & {`NCPU_WMSR_WE_W{~flush_s1}}), .Q(commit_wmsr_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_commit_wmsr_dat (.CLK(clk), .LOAD(p_ce), .D(epu_wmsr_dat), .Q(commit_wmsr_dat) );
   mDFF_l # (.DW(`PC_W)) ff_commit_E_FLUSH_TLB_npc (.CLK(clk), .LOAD(p_ce), .D(epu_E_FLUSH_TLB_npc), .Q(commit_E_FLUSH_TLB_npc) );
   
   mDFF_l # (.DW(`NCPU_REG_AW*IW)) ff_s2o_rf_waddr (.CLK(clk), .LOAD(p_ce), .D(s1o_rf_waddr), .Q(s2o_rf_waddr) );
   mDFF_lr # (.DW(IW)) ff_s2o_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s2), .D(s1o_rf_we & {IW{~flush_s2}}), .Q(s2o_rf_we) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_s2o_rf_dout (.CLK(clk), .LOAD(p_ce), .D(s1o_rf_dout), .Q(s2o_rf_dout) );
   mDFF_l # (.DW(1)) ff_s2o_lsu_load (.CLK(clk), .LOAD(p_ce), .D(s1o_lsu_load0), .Q(s2o_lsu_load0) );

   mDFF_l # (.DW(`NCPU_REG_AW*IW)) ff_commit_rf_waddr (.CLK(clk), .LOAD(p_ce), .D(s2o_rf_waddr), .Q(commit_rf_waddr) );
   mDFF_lr # (.DW(IW)) ff_commit_rf_we (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s2o_rf_we), .Q(commit_rf_we) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_commit_rf_wdat (.CLK(clk), .LOAD(p_ce), .D(s3i_rf_wdat), .Q(commit_rf_wdat) );
   
`ifdef ENABLE_DIFFTEST
   //
   // Signals used for difftest
   //
   wire [IW-1:0]                       s1o_valid;
   wire [IW-1:0]                       s2o_valid;
   wire                                s2o_exc;
   wire [`PC_W*IW-1:0]                 s1o_pc;
   wire [`PC_W*IW-1:0]                 s2o_pc;
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_valid;
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_pc;
   wire                                commit_exc;

   mDFF_lr # (.DW(IW)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s1), .D(s1i_valid & {IW{~flush_s1}}), .Q(s1o_valid) );
   
   // Once the first channel induced an exception, the remaining channels would be invalidated.
   // However, the first channel should be committed to difftest, with architectural state unchanged.
   mDFF_lr # (.DW(1)) ff_s2o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_valid[0]), .Q(s2o_valid[0]) );
   mDFF_lr # (.DW(IW-1)) ff_s2o_valid2 (.CLK(clk), .RST(rst), .LOAD(p_ce|flush_s2), .D(s1o_valid[IW-1:1] & {IW-1{~flush_s2}}), .Q(s2o_valid[IW-1:1]) );
   
   mDFF_lr # (.DW(1)) ff_s2o_exc (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(exc_flush), .Q(s2o_exc) );
   mDFF_l # (.DW(`PC_W*IW)) ff_s1o_pc (.CLK(clk), .LOAD(p_ce), .D(ex_pc), .Q(s1o_pc) );
   mDFF_l # (.DW(`PC_W*IW)) ff_s2o_pc (.CLK(clk), .LOAD(p_ce), .D(s1o_pc), .Q(s2o_pc) );
   mDFF_lr # (.DW(IW)) ff_commit_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s2o_valid), .Q(commit_valid) );
   mDFF_l # (.DW(`PC_W*IW)) ff_commit_pc (.CLK(clk), .LOAD(p_ce), .D(s2o_pc), .Q(commit_pc) );
   mDFF_lr # (.DW(1)) ff_commit_exc (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s2o_exc), .Q(commit_exc) );
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
