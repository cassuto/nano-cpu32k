/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module ncpu32k
#(
   parameter CONFIG_IRQ_LINENO_TSC = 0, // IRQ Line number of TSC
   parameter [`NCPU_AW-1:0] CONFIG_ERST_VECTOR = `NCPU_ERST_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EDTM_VECTOR = `NCPU_EDTM_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EDPF_VECTOR = `NCPU_EDPF_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EALIGN_VECTOR = `NCPU_EALIGN_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR = `NCPU_EITM_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR = `NCPU_EIPF_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_ESYSCALL_VECTOR = `NCPU_ESYSCALL_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EINSN_VECTOR = `NCPU_EINSN_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EIRQ_VECTOR = `NCPU_EIRQ_VECTOR,
   parameter CONFIG_IBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ICACHE_P_LINE
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ICACHE_P_SETS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ICACHE_P_WAYS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ITLB_NSETS_LOG2
   `PARAM_NOT_SPECIFIED , // (2^CONFIG_ITLB_NSETS_LOG2) entries
   parameter CONFIG_IMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED , // = log2(Size of page in bytes)
   parameter CONFIG_GSHARE_PHT_NUM_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_BTB_NUM_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MUL
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIV
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIVU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MOD
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MODU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_ASR
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_DBUS_DW/8) */
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DMMU_ENABLE_UNCACHED_SEG
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DTLB_NSETS_LOG2
   `PARAM_NOT_SPECIFIED , // (2^CONFIG_DTLB_NSETS_LOG2) entries
   parameter CONFIG_DCACHE_P_LINE
   `PARAM_NOT_SPECIFIED , /* = log2(Size of a line) */
   parameter CONFIG_DCACHE_P_SETS
   `PARAM_NOT_SPECIFIED , /* = log2(Number of sets) */
   parameter CONFIG_DCACHE_P_WAYS
   `PARAM_NOT_SPECIFIED /* = log2(Number of ways) */
) (
   input                               clk,
   input                               rst_n,
   // I-Bus Master
   input                               ibus_ARREADY,
   output                              ibus_ARVALID,
   output [CONFIG_IBUS_AW-1:0]         ibus_ARADDR,
   output                              ibus_RREADY,
   input                               ibus_RVALID,
   input [CONFIG_IBUS_DW-1:0]          ibus_RDATA,
   // D-Bus Master
   input                               dbus_ARWREADY,
   output                              dbus_ARWVALID,
   output [CONFIG_DBUS_AW-1:0]         dbus_ARWADDR,
   output                              dbus_AWE,
   input                               dbus_WREADY,
   output                              dbus_WVALID,
   output [CONFIG_DBUS_DW-1:0]         dbus_WDATA,
   input                               dbus_BVALID,
   output                              dbus_BREADY,
   input                               dbus_RVALID,
   output                              dbus_RREADY,
   input [CONFIG_DBUS_DW-1:0]          dbus_RDATA,
   // Sync Uncached D-Bus master
   input                               uncached_dbus_AREADY,
   output                              uncached_dbus_AVALID,
   output [`NCPU_AW-1:0]               uncached_dbus_AADDR,
   output [`NCPU_DW/8-1:0]             uncached_dbus_AWMSK,
   output [`NCPU_DW-1:0]               uncached_dbus_ADATA,
   input                               uncached_dbus_BVALID,
   output                              uncached_dbus_BREADY,
   input [`NCPU_DW-1:0]                uncached_dbus_BDATA,
   // IRQs
   input [`NCPU_NIRQ-1:0]              irqs
);
   localparam BPU_UPD_DW = (CONFIG_GSHARE_PHT_NUM_LOG2 + CONFIG_BTB_NUM_LOG2 + 4);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bpu_wb;                 // From BACKEND of ncpu32k_backend.v
   wire                 bpu_wb_is_bcc;          // From BACKEND of ncpu32k_backend.v
   wire                 bpu_wb_is_breg;         // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_AW-3:0]  bpu_wb_pc;              // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_AW-3:0]  bpu_wb_pc_nxt_act;      // From BACKEND of ncpu32k_backend.v
   wire                 bpu_wb_taken;           // From BACKEND of ncpu32k_backend.v
   wire [BPU_UPD_DW-1:0] bpu_wb_upd;            // From BACKEND of ncpu32k_backend.v
   wire                 flush;                  // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_AW-3:0]  flush_tgt;              // From BACKEND of ncpu32k_backend.v
   wire                 icinv_stall;            // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_1_EIPF;             // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_1_EITM;             // From FRONTEND of ncpu32k_frontend.v
   wire [BPU_UPD_DW-1:0] idu_1_bpu_upd;         // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_IW-1:0]  idu_1_insn;             // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_1_insn_vld;         // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_AW-3:0]  idu_1_pc;               // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_AW-3:0]  idu_1_pc_4;             // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_2_EIPF;             // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_2_EITM;             // From FRONTEND of ncpu32k_frontend.v
   wire [BPU_UPD_DW-1:0] idu_2_bpu_upd;         // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_IW-1:0]  idu_2_insn;             // From FRONTEND of ncpu32k_frontend.v
   wire                 idu_2_insn_vld;         // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_AW-3:0]  idu_2_pc;               // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_AW-3:0]  idu_2_pc_4;             // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_AW-3:0]  idu_bpu_pc_nxt;         // From FRONTEND of ncpu32k_frontend.v
   wire                 irq_sync;               // From IRQC of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_icid;               // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_DW-1:0]  msr_icinv_nxt;          // From BACKEND of ncpu32k_backend.v
   wire                 msr_icinv_we;           // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbh_idx;    // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbh_nxt;       // From BACKEND of ncpu32k_backend.v
   wire                 msr_imm_tlbh_we;        // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbl_idx;    // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbl_nxt;       // From BACKEND of ncpu32k_backend.v
   wire                 msr_imm_tlbl_we;        // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_immid;              // From FRONTEND of ncpu32k_frontend.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr;           // From IRQC of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr_nxt;       // From BACKEND of ncpu32k_backend.v
   wire                 msr_irqc_imr_we;        // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_irqc_irr;           // From IRQC of ncpu32k_irqc.v
   wire                 msr_psr_imme;           // From BACKEND of ncpu32k_backend.v
   wire                 msr_psr_ire;            // From BACKEND of ncpu32k_backend.v
   wire                 msr_psr_rm;             // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr;            // From TSC of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr_nxt;        // From BACKEND of ncpu32k_backend.v
   wire                 msr_tsc_tcr_we;         // From BACKEND of ncpu32k_backend.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr;            // From TSC of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr_nxt;        // From BACKEND of ncpu32k_backend.v
   wire                 msr_tsc_tsr_we;         // From BACKEND of ncpu32k_backend.v
   wire                 stall_fnt;              // From BACKEND of ncpu32k_backend.v
   wire                 tsc_irq;                // From TSC of ncpu32k_tsc.v
   // End of automatics
   /*AUTOINPUT*/
   /*Internals*/
   wire [`NCPU_NIRQ-1:0] irqs_lvl_i;

   /************************************************************
    * IRQC
    ************************************************************/

   ncpu32k_irqc IRQC
     (/*AUTOINST*/
      // Outputs
      .irq_sync                         (irq_sync),
      .msr_irqc_imr                     (msr_irqc_imr[`NCPU_DW-1:0]),
      .msr_irqc_irr                     (msr_irqc_irr[`NCPU_DW-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .irqs_lvl_i                       (irqs_lvl_i[`NCPU_NIRQ-1:0]),
      .msr_psr_ire                      (msr_psr_ire),
      .msr_irqc_imr_nxt                 (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
      .msr_irqc_imr_we                  (msr_irqc_imr_we));

   /************************************************************
    * TSC
    ************************************************************/

   ncpu32k_tsc TSC
     (/*AUTOINST*/
      // Outputs
      .tsc_irq                          (tsc_irq),
      .msr_tsc_tsr                      (msr_tsc_tsr[`NCPU_DW-1:0]),
      .msr_tsc_tcr                      (msr_tsc_tcr[`NCPU_DW-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .msr_tsc_tsr_nxt                  (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
      .msr_tsc_tsr_we                   (msr_tsc_tsr_we),
      .msr_tsc_tcr_nxt                  (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
      .msr_tsc_tcr_we                   (msr_tsc_tcr_we));

   // Select an IRQ line to send TSC interrupt
   generate
      if (CONFIG_IRQ_LINENO_TSC != 0)
         assign irqs_lvl_i[CONFIG_IRQ_LINENO_TSC-1:0] = irqs[CONFIG_IRQ_LINENO_TSC-1:0];
      assign irqs_lvl_i[`NCPU_NIRQ-1:CONFIG_IRQ_LINENO_TSC+1] = irqs[`NCPU_NIRQ-1:CONFIG_IRQ_LINENO_TSC+1];
      assign irqs_lvl_i[CONFIG_IRQ_LINENO_TSC] = tsc_irq | irqs[CONFIG_IRQ_LINENO_TSC];
   endgenerate

   /************************************************************
    * CPU Frontend
    ************************************************************/

   ncpu32k_frontend
      #(
         .CONFIG_ERST_VECTOR           (CONFIG_ERST_VECTOR),
         .CONFIG_IBUS_AW               (CONFIG_IBUS_AW),
         .CONFIG_IBUS_DW               (CONFIG_IBUS_DW),
         .CONFIG_IBUS_BYTES_LOG2       (CONFIG_IBUS_BYTES_LOG2),
         .CONFIG_ICACHE_P_LINE         (CONFIG_ICACHE_P_LINE),
         .CONFIG_ICACHE_P_SETS         (CONFIG_ICACHE_P_SETS),
         .CONFIG_ICACHE_P_WAYS         (CONFIG_ICACHE_P_WAYS),
         .CONFIG_ITLB_NSETS_LOG2       (CONFIG_ITLB_NSETS_LOG2),
         .CONFIG_IMMU_PAGE_SIZE_LOG2   (CONFIG_IMMU_PAGE_SIZE_LOG2),
         .CONFIG_GSHARE_PHT_NUM_LOG2   (CONFIG_GSHARE_PHT_NUM_LOG2),
         .CONFIG_BTB_NUM_LOG2          (CONFIG_BTB_NUM_LOG2),
         .BPU_UPD_DW                   (BPU_UPD_DW)
      )
   FRONTEND
      (/*AUTOINST*/
       // Outputs
       .ibus_ARVALID                    (ibus_ARVALID),
       .ibus_ARADDR                     (ibus_ARADDR[CONFIG_IBUS_AW-1:0]),
       .ibus_RREADY                     (ibus_RREADY),
       .icinv_stall                     (icinv_stall),
       .idu_1_insn_vld                  (idu_1_insn_vld),
       .idu_1_insn                      (idu_1_insn[`NCPU_IW-1:0]),
       .idu_1_pc                        (idu_1_pc[`NCPU_AW-3:0]),
       .idu_1_pc_4                      (idu_1_pc_4[`NCPU_AW-3:0]),
       .idu_1_bpu_upd                   (idu_1_bpu_upd[BPU_UPD_DW-1:0]),
       .idu_1_EITM                      (idu_1_EITM),
       .idu_1_EIPF                      (idu_1_EIPF),
       .idu_2_insn_vld                  (idu_2_insn_vld),
       .idu_2_insn                      (idu_2_insn[`NCPU_IW-1:0]),
       .idu_2_pc                        (idu_2_pc[`NCPU_AW-3:0]),
       .idu_2_pc_4                      (idu_2_pc_4[`NCPU_AW-3:0]),
       .idu_2_bpu_upd                   (idu_2_bpu_upd[BPU_UPD_DW-1:0]),
       .idu_2_EITM                      (idu_2_EITM),
       .idu_2_EIPF                      (idu_2_EIPF),
       .idu_bpu_pc_nxt                  (idu_bpu_pc_nxt[`NCPU_AW-3:0]),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_icid                        (msr_icid[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ibus_ARREADY                    (ibus_ARREADY),
       .ibus_RVALID                     (ibus_RVALID),
       .ibus_RDATA                      (ibus_RDATA[CONFIG_IBUS_DW-1:0]),
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`NCPU_AW-3:0]),
       .stall_fnt                       (stall_fnt),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_is_bcc                   (bpu_wb_is_bcc),
       .bpu_wb_is_breg                  (bpu_wb_is_breg),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_pc                       (bpu_wb_pc[`NCPU_AW-3:0]),
       .bpu_wb_pc_nxt_act               (bpu_wb_pc_nxt_act[`NCPU_AW-3:0]),
       .bpu_wb_upd                      (bpu_wb_upd[BPU_UPD_DW-1:0]),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[`NCPU_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we));

   /************************************************************
    * CPU Backend
    ************************************************************/
    
   ncpu32k_backend
      #(
         .CONFIG_ENABLE_MUL            (CONFIG_ENABLE_MUL),
         .CONFIG_ENABLE_DIV            (CONFIG_ENABLE_DIV),
         .CONFIG_ENABLE_DIVU           (CONFIG_ENABLE_DIVU),
         .CONFIG_ENABLE_MOD            (CONFIG_ENABLE_MOD),
         .CONFIG_ENABLE_MODU           (CONFIG_ENABLE_MODU),
         .CONFIG_ENABLE_ASR            (CONFIG_ENABLE_ASR),
         .BPU_UPD_DW                   (BPU_UPD_DW),
         .CPUID_VER                    (1),
         .CPUID_REV                    (0),
         .CPUID_FIMM                   (1),
         .CPUID_FDMM                   (1),
         .CPUID_FICA                   (0),
         .CPUID_FDCA                   (0),
         .CPUID_FDBG                   (0),
         .CPUID_FFPU                   (0),
         .CPUID_FIRQC                  (1),
         .CPUID_FTSC                   (1),
         .CONFIG_ERST_VECTOR           (CONFIG_ERST_VECTOR),
         .CONFIG_EDTM_VECTOR           (CONFIG_EDTM_VECTOR),
         .CONFIG_EDPF_VECTOR           (CONFIG_EDPF_VECTOR),
         .CONFIG_EALIGN_VECTOR         (CONFIG_EALIGN_VECTOR),
         .CONFIG_EITM_VECTOR           (CONFIG_EITM_VECTOR),
         .CONFIG_EIPF_VECTOR           (CONFIG_EIPF_VECTOR),
         .CONFIG_ESYSCALL_VECTOR       (CONFIG_ESYSCALL_VECTOR),
         .CONFIG_EINSN_VECTOR          (CONFIG_EINSN_VECTOR),
         .CONFIG_EIRQ_VECTOR           (CONFIG_EIRQ_VECTOR),
         .CONFIG_DBUS_DW               (CONFIG_DBUS_DW),
         .CONFIG_DBUS_BYTES_LOG2       (CONFIG_DBUS_BYTES_LOG2),
         .CONFIG_DBUS_AW               (CONFIG_DBUS_AW),
         .CONFIG_DMMU_PAGE_SIZE_LOG2   (CONFIG_DMMU_PAGE_SIZE_LOG2),
         .CONFIG_DMMU_ENABLE_UNCACHED_SEG (CONFIG_DMMU_ENABLE_UNCACHED_SEG),
         .CONFIG_DTLB_NSETS_LOG2       (CONFIG_DTLB_NSETS_LOG2),
         .CONFIG_DCACHE_P_LINE         (CONFIG_DCACHE_P_LINE),
         .CONFIG_DCACHE_P_SETS         (CONFIG_DCACHE_P_SETS),
         .CONFIG_DCACHE_P_WAYS         (CONFIG_DCACHE_P_WAYS)
      )
   BACKEND
      (/*AUTOINST*/
       // Outputs
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`NCPU_AW-3:0]),
       .stall_fnt                       (stall_fnt),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_is_bcc                   (bpu_wb_is_bcc),
       .bpu_wb_is_breg                  (bpu_wb_is_breg),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_pc                       (bpu_wb_pc[`NCPU_AW-3:0]),
       .bpu_wb_pc_nxt_act               (bpu_wb_pc_nxt_act[`NCPU_AW-3:0]),
       .bpu_wb_upd                      (bpu_wb_upd[BPU_UPD_DW-1:0]),
       .dbus_ARWVALID                   (dbus_ARWVALID),
       .dbus_ARWADDR                    (dbus_ARWADDR[CONFIG_DBUS_AW-1:0]),
       .dbus_AWE                        (dbus_AWE),
       .dbus_WVALID                     (dbus_WVALID),
       .dbus_WDATA                      (dbus_WDATA[CONFIG_DBUS_DW-1:0]),
       .dbus_BREADY                     (dbus_BREADY),
       .dbus_RREADY                     (dbus_RREADY),
       .uncached_dbus_AVALID            (uncached_dbus_AVALID),
       .uncached_dbus_AADDR             (uncached_dbus_AADDR[`NCPU_AW-1:0]),
       .uncached_dbus_AWMSK             (uncached_dbus_AWMSK[`NCPU_DW/8-1:0]),
       .uncached_dbus_ADATA             (uncached_dbus_ADATA[`NCPU_DW-1:0]),
       .uncached_dbus_BREADY            (uncached_dbus_BREADY),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_irqc_imr_nxt                (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
       .msr_irqc_imr_we                 (msr_irqc_imr_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[`NCPU_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .msr_tsc_tsr_nxt                 (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tsr_we                  (msr_tsc_tsr_we),
       .msr_tsc_tcr_nxt                 (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tcr_we                  (msr_tsc_tcr_we),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_rm                      (msr_psr_rm),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .irq_sync                        (irq_sync),
       .icinv_stall                     (icinv_stall),
       .idu_1_insn_vld                  (idu_1_insn_vld),
       .idu_1_insn                      (idu_1_insn[`NCPU_IW-1:0]),
       .idu_1_pc                        (idu_1_pc[`NCPU_AW-3:0]),
       .idu_1_pc_4                      (idu_1_pc_4[`NCPU_AW-3:0]),
       .idu_1_bpu_upd                   (idu_1_bpu_upd[BPU_UPD_DW-1:0]),
       .idu_1_EITM                      (idu_1_EITM),
       .idu_1_EIPF                      (idu_1_EIPF),
       .idu_2_insn_vld                  (idu_2_insn_vld),
       .idu_2_insn                      (idu_2_insn[`NCPU_IW-1:0]),
       .idu_2_pc                        (idu_2_pc[`NCPU_AW-3:0]),
       .idu_2_pc_4                      (idu_2_pc_4[`NCPU_AW-3:0]),
       .idu_2_bpu_upd                   (idu_2_bpu_upd[BPU_UPD_DW-1:0]),
       .idu_2_EITM                      (idu_2_EITM),
       .idu_2_EIPF                      (idu_2_EIPF),
       .idu_bpu_pc_nxt                  (idu_bpu_pc_nxt[`NCPU_AW-3:0]),
       .dbus_ARWREADY                   (dbus_ARWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[CONFIG_DBUS_DW-1:0]),
       .uncached_dbus_AREADY            (uncached_dbus_AREADY),
       .uncached_dbus_BVALID            (uncached_dbus_BVALID),
       .uncached_dbus_BDATA             (uncached_dbus_BDATA[`NCPU_DW-1:0]),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_irqc_imr                    (msr_irqc_imr[`NCPU_DW-1:0]),
       .msr_icid                        (msr_icid[`NCPU_DW-1:0]),
       .msr_irqc_irr                    (msr_irqc_irr[`NCPU_DW-1:0]),
       .msr_tsc_tsr                     (msr_tsc_tsr[`NCPU_DW-1:0]),
       .msr_tsc_tcr                     (msr_tsc_tcr[`NCPU_DW-1:0]));

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
// )
// End:
