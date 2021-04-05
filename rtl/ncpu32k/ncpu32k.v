/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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
    parameter CONFIG_ENABLE_IMMU = 1,
    parameter CONFIG_ENABLE_DMMU = 1,
    parameter CONFIG_ITLB_NSETS_LOG2 = 7,
    parameter CONFIG_DTLB_NSETS_LOG2 = 7,
    parameter CONFIG_ENABLE_ICACHE = 0,
    parameter CONFIG_ENABLE_DCACHE = 0,
    parameter CONFIG_PIPEBUF_BYPASS = 1,
    parameter CONFIG_IBUS_OUTSTANTING_LOG2 = 2,
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
    parameter CONFIG_ENABLE_MUL = 0,
    parameter CONFIG_ENABLE_DIV = 0,
    parameter CONFIG_ENABLE_DIVU = 0,
    parameter CONFIG_ENABLE_MOD = 0,
    parameter CONFIG_ENABLE_MODU = 0,
    parameter CONFIG_ENABLE_FPU = 0,
    parameter CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2 = 2,
    parameter CONFIG_ALU_INSERT_REG = 0,
    parameter CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2 = 2,
    parameter CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2 = 2,
    parameter CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2 = 2,
    parameter CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2 = 2,
    parameter CONFIG_ROB_DEPTH_LOG2 = 3
    )
   (
    input                   clk,
    input                   rst_n,
    // Frontend I-Bus master
    input                   fb_ibus_BVALID,
    output                  fb_ibus_BREADY,
    input [`NCPU_IW-1:0]    fb_ibus_BDATA,
    input [1:0]             fb_ibus_BEXC,
    input                   fb_ibus_AREADY,
    output                  fb_ibus_AVALID,
    output [`NCPU_AW-1:0]   fb_ibus_AADDR,
    output [1:0]            fb_ibus_AEXC,
    // Frontend D-Bus master
    input                   fb_dbus_BVALID,
    output                  fb_dbus_BREADY,
    input [`NCPU_DW-1:0]    fb_dbus_BDATA,
    input [1:0]             fb_dbus_BEXC,
    output [`NCPU_DW-1:0]   fb_dbus_ADATA,
    input                   fb_dbus_AREADY,
    output                  fb_dbus_AVALID,
    output [`NCPU_AW-1:0]   fb_dbus_AADDR,
    output [`NCPU_DW/8-1:0] fb_dbus_AWMSK,
    output [1:0]            fb_dbus_AEXC,
    // IRQs
    input [`NCPU_NIRQ-1:0]  fb_irqs
    );
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_AW-1:0]  dbus_AADDR;             // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  dbus_ADATA;             // From CORE of ncpu32k_core.v
   wire                 dbus_AREADY;            // From D_MMU of ncpu32k_dmmu.v
   wire                 dbus_AVALID;            // From CORE of ncpu32k_core.v
   wire [`NCPU_DW/8-1:0] dbus_AWMSK;            // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  dbus_BDATA;             // From D_CACHE of ncpu32k_dcache.v
   wire [1:0]           dbus_BEXC;              // From D_CACHE of ncpu32k_dcache.v
   wire                 dbus_BREADY;            // From CORE of ncpu32k_core.v
   wire                 dbus_BVALID;            // From D_CACHE of ncpu32k_dcache.v
   wire [`NCPU_AW-1:0]  dcache_AADDR;           // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_DW-1:0]  dcache_ADATA;           // From D_MMU of ncpu32k_dmmu.v
   wire [1:0]           dcache_AEXC;            // From D_MMU of ncpu32k_dmmu.v
   wire                 dcache_AREADY;          // From D_CACHE of ncpu32k_dcache.v
   wire                 dcache_AVALID;          // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_DW/8-1:0] dcache_AWMSK;          // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_AW-1:0]  ibus_AADDR;             // From CORE of ncpu32k_core.v
   wire                 ibus_AREADY;            // From I_MMU of ncpu32k_immu.v
   wire                 ibus_AVALID;            // From CORE of ncpu32k_core.v
   wire [`NCPU_IW-1:0]  ibus_BDATA;             // From I_CACHE of ncpu32k_icache.v
   wire [1:0]           ibus_BEXC;              // From I_CACHE of ncpu32k_icache.v
   wire                 ibus_BREADY;            // From CORE of ncpu32k_core.v
   wire                 ibus_BVALID;            // From I_CACHE of ncpu32k_icache.v
   wire [`NCPU_AW-1:0]  icache_AADDR;           // From I_MMU of ncpu32k_immu.v
   wire [1:0]           icache_AEXC;            // From I_MMU of ncpu32k_immu.v
   wire                 icache_AREADY;          // From I_CACHE of ncpu32k_icache.v
   wire                 icache_AVALID;          // From I_MMU of ncpu32k_immu.v
   wire                 irqc_intr_sync;         // From IRQC of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbh;           // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbh_idx;    // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbh_nxt;       // From CORE of ncpu32k_core.v
   wire                 msr_dmm_tlbh_we;        // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbl;           // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbl_idx;    // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbl_nxt;       // From CORE of ncpu32k_core.v
   wire                 msr_dmm_tlbl_we;        // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmmid;              // From D_MMU of ncpu32k_dmmu.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbh;           // From I_MMU of ncpu32k_immu.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbh_idx;    // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbh_nxt;       // From CORE of ncpu32k_core.v
   wire                 msr_imm_tlbh_we;        // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbl;           // From I_MMU of ncpu32k_immu.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbl_idx;    // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbl_nxt;       // From CORE of ncpu32k_core.v
   wire                 msr_imm_tlbl_we;        // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_immid;              // From I_MMU of ncpu32k_immu.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr;           // From IRQC of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr_nxt;       // From CORE of ncpu32k_core.v
   wire                 msr_irqc_imr_we;        // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_irqc_irr;           // From IRQC of ncpu32k_irqc.v
   wire                 msr_psr_dmme;           // From CORE of ncpu32k_core.v
   wire                 msr_psr_imme;           // From CORE of ncpu32k_core.v
   wire                 msr_psr_ire;            // From CORE of ncpu32k_core.v
   wire                 msr_psr_rm;             // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr;            // From TSC of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr_nxt;        // From CORE of ncpu32k_core.v
   wire                 msr_tsc_tcr_we;         // From CORE of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr;            // From TSC of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr_nxt;        // From CORE of ncpu32k_core.v
   wire                 msr_tsc_tsr_we;         // From CORE of ncpu32k_core.v
   wire                 tsc_irq;                // From TSC of ncpu32k_tsc.v
   // End of automatics
   wire [`NCPU_NIRQ-1:0] irqs_lvl_i;

   /************************************************************
    * I-MMU
    ************************************************************/
   generate
      if (CONFIG_ENABLE_IMMU)
        begin
           ncpu32k_immu
             #(
               .CONFIG_ITLB_NSETS_LOG2    (CONFIG_ITLB_NSETS_LOG2),
               .CONFIG_PIPEBUF_BYPASS     (CONFIG_PIPEBUF_BYPASS),
               .CONFIG_EITM_VECTOR        (CONFIG_EITM_VECTOR),
               .CONFIG_EIPF_VECTOR        (CONFIG_EIPF_VECTOR)
               )
           I_MMU
             (/*AUTOINST*/
              // Outputs
              .ibus_AREADY              (ibus_AREADY),
              .icache_AVALID            (icache_AVALID),
              .icache_AADDR             (icache_AADDR[`NCPU_AW-1:0]),
              .icache_AEXC              (icache_AEXC[1:0]),
              .msr_immid                (msr_immid[`NCPU_DW-1:0]),
              .msr_imm_tlbl             (msr_imm_tlbl[`NCPU_DW-1:0]),
              .msr_imm_tlbh             (msr_imm_tlbh[`NCPU_DW-1:0]),
              // Inputs
              .clk                      (clk),
              .rst_n                    (rst_n),
              .ibus_AVALID              (ibus_AVALID),
              .ibus_AADDR               (ibus_AADDR[`NCPU_AW-1:0]),
              .icache_AREADY            (icache_AREADY),
              .msr_psr_imme             (msr_psr_imme),
              .msr_psr_rm               (msr_psr_rm),
              .msr_imm_tlbl_idx         (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
              .msr_imm_tlbl_nxt         (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
              .msr_imm_tlbl_we          (msr_imm_tlbl_we),
              .msr_imm_tlbh_idx         (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
              .msr_imm_tlbh_nxt         (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
              .msr_imm_tlbh_we          (msr_imm_tlbh_we));
        end
      else
        begin : gen_no_immu
           assign ibus_AREADY = icache_AREADY;
           assign icache_AVALID = ibus_AVALID;
           assign icache_AADDR = ibus_AADDR;
           assign icache_AEXC = 2'b0; 
           assign msr_immid = {`NCPU_DW{1'b0}};
           assign msr_imm_tlbl = {`NCPU_DW{1'b0}};
           assign msr_imm_tlbh = {`NCPU_DW{1'b0}};
        end
   endgenerate

   /************************************************************
    * D-MMU
    ************************************************************/
   generate
      if (CONFIG_ENABLE_DMMU)
        begin
           ncpu32k_dmmu
             #(
               .CONFIG_DTLB_NSETS_LOG2    (CONFIG_DTLB_NSETS_LOG2),
               .CONFIG_PIPEBUF_BYPASS     (CONFIG_PIPEBUF_BYPASS)
               )
           D_MMU
             (/*AUTOINST*/
              // Outputs
              .dbus_AREADY              (dbus_AREADY),
              .dcache_AVALID            (dcache_AVALID),
              .dcache_AADDR             (dcache_AADDR[`NCPU_AW-1:0]),
              .dcache_AWMSK             (dcache_AWMSK[`NCPU_DW/8-1:0]),
              .dcache_ADATA             (dcache_ADATA[`NCPU_DW-1:0]),
              .dcache_AEXC              (dcache_AEXC[1:0]),
              .msr_dmmid                (msr_dmmid[`NCPU_DW-1:0]),
              .msr_dmm_tlbl             (msr_dmm_tlbl[`NCPU_DW-1:0]),
              .msr_dmm_tlbh             (msr_dmm_tlbh[`NCPU_DW-1:0]),
              // Inputs
              .clk                      (clk),
              .rst_n                    (rst_n),
              .dbus_AVALID              (dbus_AVALID),
              .dbus_AADDR               (dbus_AADDR[`NCPU_AW-1:0]),
              .dbus_AWMSK               (dbus_AWMSK[`NCPU_DW/8-1:0]),
              .dbus_ADATA               (dbus_ADATA[`NCPU_DW-1:0]),
              .dcache_AREADY            (dcache_AREADY),
              .msr_psr_dmme             (msr_psr_dmme),
              .msr_psr_rm               (msr_psr_rm),
              .msr_dmm_tlbl_idx         (msr_dmm_tlbl_idx[`NCPU_TLB_AW-1:0]),
              .msr_dmm_tlbl_nxt         (msr_dmm_tlbl_nxt[`NCPU_DW-1:0]),
              .msr_dmm_tlbl_we          (msr_dmm_tlbl_we),
              .msr_dmm_tlbh_idx         (msr_dmm_tlbh_idx[`NCPU_TLB_AW-1:0]),
              .msr_dmm_tlbh_nxt         (msr_dmm_tlbh_nxt[`NCPU_DW-1:0]),
              .msr_dmm_tlbh_we          (msr_dmm_tlbh_we));
        end
      else
        begin
           assign dbus_AREADY = dcache_AREADY;
           assign dcache_AVALID = dbus_AVALID;
           assign dcache_AADDR = dbus_AADDR;
           assign dcache_AWMSK = dbus_AWMSK;
           assign dcache_ADATA = dbus_ADATA;
           assign dcache_AEXC = 2'b0;
           assign msr_dmmid = {`NCPU_DW{1'b0}};
           assign msr_dmm_tlbl = {`NCPU_DW{1'b0}};
           assign msr_dmm_tlbh = {`NCPU_DW{1'b0}};
        end
   endgenerate


   /************************************************************
    * I-Cache
    ************************************************************/
   generate
      if (CONFIG_ENABLE_ICACHE)
        begin
           /* ncpu32k_icache AUTO_TEMPLATE (
            .icache_BREADY                   (ibus_BREADY),
            .icache_BVALID                   (ibus_BVALID),
            .icache_BDATA                    (ibus_BDATA[`NCPU_IW-1:0]),
            .icache_BEXC                     (ibus_BEXC[1:0]),
            )
            */
           ncpu32k_icache I_CACHE
             (/*AUTOINST*/
              // Outputs
              .icache_AREADY            (icache_AREADY),
              .icache_BVALID            (ibus_BVALID),           // Templated
              .icache_BDATA             (ibus_BDATA[`NCPU_IW-1:0]), // Templated
              .icache_BEXC              (ibus_BEXC[1:0]),        // Templated
              .fb_ibus_AVALID           (fb_ibus_AVALID),
              .fb_ibus_AADDR            (fb_ibus_AADDR[`NCPU_AW-1:0]),
              .fb_ibus_AEXC             (fb_ibus_AEXC[1:0]),
              .fb_ibus_BREADY           (fb_ibus_BREADY),
              // Inputs
              .clk                      (clk),
              .rst_n                    (rst_n),
              .icache_AVALID            (icache_AVALID),
              .icache_AADDR             (icache_AADDR[`NCPU_AW-1:0]),
              .icache_AEXC              (icache_AEXC[1:0]),
              .icache_BREADY            (ibus_BREADY),           // Templated
              .fb_ibus_AREADY           (fb_ibus_AREADY),
              .fb_ibus_BVALID           (fb_ibus_BVALID),
              .fb_ibus_BDATA            (fb_ibus_BDATA[`NCPU_IW-1:0]),
              .fb_ibus_BEXC             (fb_ibus_BEXC[1:0]));

        end
      else
        begin
           assign ibus_BVALID = fb_ibus_BVALID;
           assign ibus_BDATA = fb_ibus_BDATA;
           assign ibus_BEXC = fb_ibus_BEXC;
           assign icache_AREADY = fb_ibus_AREADY;
           assign fb_ibus_BREADY = ibus_BREADY;
           assign fb_ibus_AVALID = icache_AVALID;
           assign fb_ibus_AADDR = icache_AADDR;
           assign fb_ibus_AEXC = icache_AEXC;
        end
   endgenerate

   /************************************************************
    * D-Cache
    ************************************************************/
   generate
      if (CONFIG_ENABLE_DCACHE)
        begin
           /* ncpu32k_dcache AUTO_TEMPLATE (
            .dcache_BREADY                   (dbus_BREADY),
            .dcache_BVALID                   (dbus_BVALID),
            .dcache_BDATA                    (dbus_BDATA[`NCPU_DW-1:0]),
            .dcache_BEXC                     (dbus_BEXC[1:0]),
            )
            */
           ncpu32k_dcache D_CACHE
             (/*AUTOINST*/
              // Outputs
              .dcache_BVALID            (dbus_BVALID),           // Templated
              .dcache_BDATA             (dbus_BDATA[`NCPU_DW-1:0]), // Templated
              .dcache_BEXC              (dbus_BEXC[1:0]),        // Templated
              .dcache_AREADY            (dcache_AREADY),
              .fb_dbus_BREADY           (fb_dbus_BREADY),
              .fb_dbus_ADATA            (fb_dbus_ADATA[`NCPU_DW-1:0]),
              .fb_dbus_AVALID           (fb_dbus_AVALID),
              .fb_dbus_AADDR            (fb_dbus_AADDR[`NCPU_AW-1:0]),
              .fb_dbus_AWMSK            (fb_dbus_AWMSK[`NCPU_DW/8-1:0]),
              .fb_dbus_AEXC             (fb_dbus_AEXC[1:0]),
              // Inputs
              .clk                      (clk),
              .rst_n                    (rst_n),
              .dcache_BREADY            (dbus_BREADY),           // Templated
              .dcache_ADATA             (dcache_ADATA[`NCPU_DW-1:0]),
              .dcache_AVALID            (dcache_AVALID),
              .dcache_AADDR             (dcache_AADDR[`NCPU_AW-1:0]),
              .dcache_AWMSK             (dcache_AWMSK[`NCPU_DW/8-1:0]),
              .dcache_AEXC              (dcache_AEXC[1:0]),
              .fb_dbus_BVALID           (fb_dbus_BVALID),
              .fb_dbus_BDATA            (fb_dbus_BDATA[`NCPU_DW-1:0]),
              .fb_dbus_BEXC             (fb_dbus_BEXC[1:0]),
              .fb_dbus_AREADY           (fb_dbus_AREADY));
        end
      else
        begin
           assign dbus_BVALID = fb_dbus_BVALID;
           assign dbus_BDATA = fb_dbus_BDATA;
           assign dbus_BEXC = fb_dbus_BEXC;
           assign dcache_AREADY = fb_dbus_AREADY;
           assign fb_dbus_BREADY = dbus_BREADY;
           assign fb_dbus_ADATA = dcache_ADATA;
           assign fb_dbus_AVALID = dcache_AVALID;
           assign fb_dbus_AADDR = dcache_AADDR;
           assign fb_dbus_AWMSK = dcache_AWMSK;
           assign fb_dbus_AEXC = dcache_AEXC;
        end
   endgenerate

   /************************************************************
    * IRQC
    ************************************************************/

   ncpu32k_irqc IRQC
     (/*AUTOINST*/
      // Outputs
      .irqc_intr_sync                   (irqc_intr_sync),
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
         assign irqs_lvl_i[CONFIG_IRQ_LINENO_TSC-1:0] = fb_irqs[CONFIG_IRQ_LINENO_TSC-1:0];
      assign irqs_lvl_i[`NCPU_NIRQ-1:CONFIG_IRQ_LINENO_TSC+1] = fb_irqs[`NCPU_NIRQ-1:CONFIG_IRQ_LINENO_TSC+1];
      assign irqs_lvl_i[CONFIG_IRQ_LINENO_TSC] = tsc_irq | fb_irqs[CONFIG_IRQ_LINENO_TSC];
   endgenerate

   /************************************************************
    * CPU Core
    ************************************************************/

   ncpu32k_core
     #(
       .CONFIG_HAVE_IMMU             (CONFIG_ENABLE_IMMU),
       .CONFIG_HAVE_DMMU             (CONFIG_ENABLE_DMMU),
       .CONFIG_HAVE_ICACHE           (CONFIG_ENABLE_ICACHE),
       .CONFIG_HAVE_DCACHE           (CONFIG_ENABLE_DCACHE),
       .CONFIG_HAVE_IRQC             (1),
       .CONFIG_HAVE_TSC              (1),
       .CONFIG_IBUS_OUTSTANTING_LOG2 (CONFIG_IBUS_OUTSTANTING_LOG2),
       .CONFIG_ERST_VECTOR           (CONFIG_ERST_VECTOR),
       .CONFIG_EDTM_VECTOR           (CONFIG_EDTM_VECTOR),
       .CONFIG_EDPF_VECTOR           (CONFIG_EDPF_VECTOR),
       .CONFIG_EALIGN_VECTOR         (CONFIG_EALIGN_VECTOR),
       .CONFIG_EITM_VECTOR           (CONFIG_EITM_VECTOR),
       .CONFIG_EIPF_VECTOR           (CONFIG_EIPF_VECTOR),
       .CONFIG_ESYSCALL_VECTOR       (CONFIG_ESYSCALL_VECTOR),
       .CONFIG_EINSN_VECTOR          (CONFIG_EINSN_VECTOR),
       .CONFIG_EIRQ_VECTOR           (CONFIG_EIRQ_VECTOR),
       .CONFIG_ENABLE_MUL            (CONFIG_ENABLE_MUL),
       .CONFIG_ENABLE_DIV            (CONFIG_ENABLE_DIV),
       .CONFIG_ENABLE_DIVU           (CONFIG_ENABLE_DIVU),
       .CONFIG_ENABLE_MOD            (CONFIG_ENABLE_MOD),
       .CONFIG_ENABLE_MODU           (CONFIG_ENABLE_MODU),
       .CONFIG_ENABLE_FPU            (CONFIG_ENABLE_FPU),
       .CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2),
       .CONFIG_ALU_INSERT_REG        (CONFIG_ALU_INSERT_REG),
       .CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2),
       .CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2),
       .CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2),
       .CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2),
       .CONFIG_ROB_DEPTH_LOG2        (CONFIG_ROB_DEPTH_LOG2),
       .CONFIG_PIPEBUF_BYPASS        (CONFIG_PIPEBUF_BYPASS)
       )
   CORE
     (/*AUTOINST*/
      // Outputs
      .dbus_AVALID                      (dbus_AVALID),
      .dbus_AADDR                       (dbus_AADDR[`NCPU_AW-1:0]),
      .dbus_AWMSK                       (dbus_AWMSK[`NCPU_DW/8-1:0]),
      .dbus_ADATA                       (dbus_ADATA[`NCPU_DW-1:0]),
      .dbus_BREADY                      (dbus_BREADY),
      .ibus_AVALID                      (ibus_AVALID),
      .ibus_AADDR                       (ibus_AADDR[`NCPU_AW-1:0]),
      .ibus_BREADY                      (ibus_BREADY),
      .msr_psr_imme                     (msr_psr_imme),
      .msr_psr_dmme                     (msr_psr_dmme),
      .msr_psr_rm                       (msr_psr_rm),
      .msr_psr_ire                      (msr_psr_ire),
      .msr_imm_tlbl_idx                 (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
      .msr_imm_tlbl_nxt                 (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
      .msr_imm_tlbl_we                  (msr_imm_tlbl_we),
      .msr_imm_tlbh_idx                 (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
      .msr_imm_tlbh_nxt                 (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
      .msr_imm_tlbh_we                  (msr_imm_tlbh_we),
      .msr_dmm_tlbl_idx                 (msr_dmm_tlbl_idx[`NCPU_TLB_AW-1:0]),
      .msr_dmm_tlbl_nxt                 (msr_dmm_tlbl_nxt[`NCPU_DW-1:0]),
      .msr_dmm_tlbl_we                  (msr_dmm_tlbl_we),
      .msr_dmm_tlbh_idx                 (msr_dmm_tlbh_idx[`NCPU_TLB_AW-1:0]),
      .msr_dmm_tlbh_nxt                 (msr_dmm_tlbh_nxt[`NCPU_DW-1:0]),
      .msr_dmm_tlbh_we                  (msr_dmm_tlbh_we),
      .msr_irqc_imr_nxt                 (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
      .msr_irqc_imr_we                  (msr_irqc_imr_we),
      .msr_tsc_tsr_nxt                  (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
      .msr_tsc_tsr_we                   (msr_tsc_tsr_we),
      .msr_tsc_tcr_nxt                  (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
      .msr_tsc_tcr_we                   (msr_tsc_tcr_we),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .dbus_AREADY                      (dbus_AREADY),
      .dbus_BDATA                       (dbus_BDATA[`NCPU_DW-1:0]),
      .dbus_BVALID                      (dbus_BVALID),
      .dbus_BEXC                        (dbus_BEXC[1:0]),
      .ibus_AREADY                      (ibus_AREADY),
      .ibus_BVALID                      (ibus_BVALID),
      .ibus_BDATA                       (ibus_BDATA[`NCPU_IW-1:0]),
      .ibus_BEXC                        (ibus_BEXC[1:0]),
      .irqc_intr_sync                   (irqc_intr_sync),
      .msr_immid                        (msr_immid[`NCPU_DW-1:0]),
      .msr_imm_tlbl                     (msr_imm_tlbl[`NCPU_DW-1:0]),
      .msr_imm_tlbh                     (msr_imm_tlbh[`NCPU_DW-1:0]),
      .msr_dmmid                        (msr_dmmid[`NCPU_DW-1:0]),
      .msr_dmm_tlbl                     (msr_dmm_tlbl[`NCPU_DW-1:0]),
      .msr_dmm_tlbh                     (msr_dmm_tlbh[`NCPU_DW-1:0]),
      .msr_irqc_imr                     (msr_irqc_imr[`NCPU_DW-1:0]),
      .msr_irqc_irr                     (msr_irqc_irr[`NCPU_DW-1:0]),
      .msr_tsc_tsr                      (msr_tsc_tsr[`NCPU_DW-1:0]),
      .msr_tsc_tcr                      (msr_tsc_tcr[`NCPU_DW-1:0]));

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "./mmu"
//  "./cache"
// )
// End:
