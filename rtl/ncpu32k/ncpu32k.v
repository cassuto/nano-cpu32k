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
   parameter IRQ_N_TSC = 0 /* IRQ Line No of TSC*/
)
(
   input                   clk,
   input                   rst_n,
   // Frontend I-Bus
   input                   fb_ibus_valid,
   output                  fb_ibus_ready,
   input [`NCPU_IW-1:0]    fb_ibus_dout,
   input                   fb_ibus_cmd_ready,
   output                  fb_ibus_cmd_valid,
   output [`NCPU_AW-1:0]   fb_ibus_cmd_addr,
   // Frontend D-Bus
   input                   fb_dbus_valid,
   output                  fb_dbus_ready,
   input [`NCPU_IW-1:0]    fb_dbus_dout,
   output [`NCPU_DW-1:0]   fb_dbus_din,
   input                   fb_dbus_cmd_ready,
   output                  fb_dbus_cmd_valid,
   output [`NCPU_AW-1:0]   fb_dbus_cmd_addr,
   output [2:0]            fb_dbus_cmd_size,
   output                  fb_dbus_cmd_we,
   // IRQs
   input [`NCPU_NIRQ-1:0]  fb_irqs
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_AW-1:0]  dbus_cmd_addr;          // From core of ncpu32k_core.v
   wire                 dbus_cmd_ready;         // From d_mmu of ncpu32k_d_mmu.v
   wire [2:0]           dbus_cmd_size;          // From core of ncpu32k_core.v
   wire                 dbus_cmd_valid;         // From core of ncpu32k_core.v
   wire                 dbus_cmd_we;            // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  dbus_din;               // From core of ncpu32k_core.v
   wire [`NCPU_IW-1:0]  dbus_dout;              // From d_mmu of ncpu32k_d_mmu.v
   wire                 dbus_ready;             // From core of ncpu32k_core.v
   wire                 dbus_valid;             // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_AW-1:0]  dcache_cmd_addr;        // From d_mmu of ncpu32k_d_mmu.v
   wire                 dcache_cmd_ready;       // From d_cache of ncpu32k_d_cache.v
   wire [2:0]           dcache_cmd_size;        // From d_mmu of ncpu32k_d_mmu.v
   wire                 dcache_cmd_valid;       // From d_mmu of ncpu32k_d_mmu.v
   wire                 dcache_cmd_we;          // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_DW-1:0]  dcache_din;             // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_IW-1:0]  dcache_dout;            // From d_cache of ncpu32k_d_cache.v
   wire                 dcache_ready;           // From d_mmu of ncpu32k_d_mmu.v
   wire                 dcache_valid;           // From d_cache of ncpu32k_d_cache.v
   wire                 exp_dmm_page_fault;     // From d_mmu of ncpu32k_d_mmu.v
   wire                 exp_dmm_tlb_miss;       // From d_mmu of ncpu32k_d_mmu.v
   wire                 exp_imm_page_fault;     // From i_mmu of ncpu32k_i_mmu.v
   wire                 exp_imm_tlb_miss;       // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_AW-1:0]  ibus_cmd_addr;          // From core of ncpu32k_core.v
   wire                 ibus_cmd_ready;         // From i_mmu of ncpu32k_i_mmu.v
   wire                 ibus_cmd_valid;         // From core of ncpu32k_core.v
   wire [`NCPU_IW-1:0]  ibus_dout;              // From i_mmu of ncpu32k_i_mmu.v
   wire                 ibus_flush_ack;         // From i_mmu of ncpu32k_i_mmu.v
   wire                 ibus_flush_req;         // From core of ncpu32k_core.v
   wire [`NCPU_AW-1:0]  ibus_out_id;            // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_AW-1:0]  ibus_out_id_nxt;        // From i_mmu of ncpu32k_i_mmu.v
   wire                 ibus_ready;             // From core of ncpu32k_core.v
   wire                 ibus_valid;             // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_AW-1:0]  icache_cmd_addr;        // From i_mmu of ncpu32k_i_mmu.v
   wire                 icache_cmd_ready;       // From i_cache of ncpu32k_i_cache.v
   wire                 icache_cmd_valid;       // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_IW-1:0]  icache_dout;            // From i_cache of ncpu32k_i_cache.v
   wire                 icache_ready;           // From i_mmu of ncpu32k_i_mmu.v
   wire                 icache_valid;           // From i_cache of ncpu32k_i_cache.v
   wire                 irqc_intr_sync;         // From irqc of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbh;           // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbh_idx;    // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbh_nxt;       // From core of ncpu32k_core.v
   wire                 msr_dmm_tlbh_we;        // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbl;           // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbl_idx;    // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbl_nxt;       // From core of ncpu32k_core.v
   wire                 msr_dmm_tlbl_we;        // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_dmmid;              // From d_mmu of ncpu32k_d_mmu.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbh;           // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbh_idx;    // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbh_nxt;       // From core of ncpu32k_core.v
   wire                 msr_imm_tlbh_we;        // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbl;           // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_TLB_AW-1:0] msr_imm_tlbl_idx;    // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_imm_tlbl_nxt;       // From core of ncpu32k_core.v
   wire                 msr_imm_tlbl_we;        // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_immid;              // From i_mmu of ncpu32k_i_mmu.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr;           // From irqc of ncpu32k_irqc.v
   wire [`NCPU_DW-1:0]  msr_irqc_imr_nxt;       // From core of ncpu32k_core.v
   wire                 msr_irqc_imr_we;        // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_irqc_irr;           // From irqc of ncpu32k_irqc.v
   wire                 msr_psr_dmme;           // From core of ncpu32k_core.v
   wire                 msr_psr_imme;           // From core of ncpu32k_core.v
   wire                 msr_psr_ire;            // From core of ncpu32k_core.v
   wire                 msr_psr_rm;             // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr;            // From tsc of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tcr_nxt;        // From core of ncpu32k_core.v
   wire                 msr_tsc_tcr_we;         // From core of ncpu32k_core.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr;            // From tsc of ncpu32k_tsc.v
   wire [`NCPU_DW-1:0]  msr_tsc_tsr_nxt;        // From core of ncpu32k_core.v
   wire                 msr_tsc_tsr_we;         // From core of ncpu32k_core.v
   wire                 tsc_irq;                // From tsc of ncpu32k_tsc.v
   // End of automatics
   wire [`NCPU_NIRQ-1:0] irqs_lvl_i;
   
   /************************************************************
    * I-MMU
    ************************************************************/

    ncpu32k_i_mmu i_mmu
      (/*AUTOINST*/
       // Outputs
       .ibus_valid                      (ibus_valid),
       .ibus_dout                       (ibus_dout[`NCPU_IW-1:0]),
       .ibus_cmd_ready                  (ibus_cmd_ready),
       .ibus_flush_ack                  (ibus_flush_ack),
       .ibus_out_id                     (ibus_out_id[`NCPU_AW-1:0]),
       .ibus_out_id_nxt                 (ibus_out_id_nxt[`NCPU_AW-1:0]),
       .icache_ready                    (icache_ready),
       .icache_cmd_valid                (icache_cmd_valid),
       .icache_cmd_addr                 (icache_cmd_addr[`NCPU_AW-1:0]),
       .exp_imm_tlb_miss                (exp_imm_tlb_miss),
       .exp_imm_page_fault              (exp_imm_page_fault),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_imm_tlbl                    (msr_imm_tlbl[`NCPU_DW-1:0]),
       .msr_imm_tlbh                    (msr_imm_tlbh[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ibus_ready                      (ibus_ready),
       .ibus_cmd_valid                  (ibus_cmd_valid),
       .ibus_cmd_addr                   (ibus_cmd_addr[`NCPU_AW-1:0]),
       .ibus_flush_req                  (ibus_flush_req),
       .icache_valid                    (icache_valid),
       .icache_dout                     (icache_dout[`NCPU_IW-1:0]),
       .icache_cmd_ready                (icache_cmd_ready),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we));
   
   /************************************************************
    * D-MMU
    ************************************************************/
   
   ncpu32k_d_mmu d_mmu
      (/*AUTOINST*/
       // Outputs
       .dbus_valid                      (dbus_valid),
       .dbus_dout                       (dbus_dout[`NCPU_IW-1:0]),
       .dbus_cmd_ready                  (dbus_cmd_ready),
       .dcache_ready                    (dcache_ready),
       .dcache_din                      (dcache_din[`NCPU_DW-1:0]),
       .dcache_cmd_valid                (dcache_cmd_valid),
       .dcache_cmd_addr                 (dcache_cmd_addr[`NCPU_AW-1:0]),
       .dcache_cmd_size                 (dcache_cmd_size[2:0]),
       .dcache_cmd_we                   (dcache_cmd_we),
       .exp_dmm_tlb_miss                (exp_dmm_tlb_miss),
       .exp_dmm_page_fault              (exp_dmm_page_fault),
       .msr_dmmid                       (msr_dmmid[`NCPU_DW-1:0]),
       .msr_dmm_tlbl                    (msr_dmm_tlbl[`NCPU_DW-1:0]),
       .msr_dmm_tlbh                    (msr_dmm_tlbh[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dbus_ready                      (dbus_ready),
       .dbus_din                        (dbus_din[`NCPU_IW-1:0]),
       .dbus_cmd_valid                  (dbus_cmd_valid),
       .dbus_cmd_addr                   (dbus_cmd_addr[`NCPU_AW-1:0]),
       .dbus_cmd_size                   (dbus_cmd_size[2:0]),
       .dbus_cmd_we                     (dbus_cmd_we),
       .dcache_valid                    (dcache_valid),
       .dcache_dout                     (dcache_dout[`NCPU_IW-1:0]),
       .dcache_cmd_ready                (dcache_cmd_ready),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we));
   
   
   /************************************************************
    * I-Cache
    ************************************************************/
    
   ncpu32k_i_cache i_cache
      (/*AUTOINST*/
       // Outputs
       .icache_valid                    (icache_valid),
       .icache_dout                     (icache_dout[`NCPU_IW-1:0]),
       .icache_cmd_ready                (icache_cmd_ready),
       .fb_ibus_ready                   (fb_ibus_ready),
       .fb_ibus_cmd_valid               (fb_ibus_cmd_valid),
       .fb_ibus_cmd_addr                (fb_ibus_cmd_addr[`NCPU_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .icache_ready                    (icache_ready),
       .icache_cmd_valid                (icache_cmd_valid),
       .icache_cmd_addr                 (icache_cmd_addr[`NCPU_AW-1:0]),
       .fb_ibus_valid                   (fb_ibus_valid),
       .fb_ibus_dout                    (fb_ibus_dout[`NCPU_IW-1:0]),
       .fb_ibus_cmd_ready               (fb_ibus_cmd_ready),
       .msr_psr_icae                    (msr_psr_icae));
    
   /************************************************************
    * D-Cache
    ************************************************************/
    
   ncpu32k_d_cache d_cache
      (/*AUTOINST*/
       // Outputs
       .dcache_valid                    (dcache_valid),
       .dcache_dout                     (dcache_dout[`NCPU_IW-1:0]),
       .dcache_cmd_ready                (dcache_cmd_ready),
       .fb_dbus_ready                   (fb_dbus_ready),
       .fb_dbus_din                     (fb_dbus_din[`NCPU_DW-1:0]),
       .fb_dbus_cmd_valid               (fb_dbus_cmd_valid),
       .fb_dbus_cmd_addr                (fb_dbus_cmd_addr[`NCPU_AW-1:0]),
       .fb_dbus_cmd_size                (fb_dbus_cmd_size[2:0]),
       .fb_dbus_cmd_we                  (fb_dbus_cmd_we),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dcache_ready                    (dcache_ready),
       .dcache_din                      (dcache_din[`NCPU_DW-1:0]),
       .dcache_cmd_valid                (dcache_cmd_valid),
       .dcache_cmd_addr                 (dcache_cmd_addr[`NCPU_AW-1:0]),
       .dcache_cmd_size                 (dcache_cmd_size[2:0]),
       .dcache_cmd_we                   (dcache_cmd_we),
       .fb_dbus_valid                   (fb_dbus_valid),
       .fb_dbus_dout                    (fb_dbus_dout[`NCPU_IW-1:0]),
       .fb_dbus_cmd_ready               (fb_dbus_cmd_ready),
       .msr_psr_dcae                    (msr_psr_dcae));
   
   
   /************************************************************
    * IRQC
    ************************************************************/
   
   ncpu32k_irqc irqc
      (/*AUTOINST*/
       // Outputs
       .irqc_intr_sync                  (irqc_intr_sync),
       .msr_irqc_imr                    (msr_irqc_imr[`NCPU_DW-1:0]),
       .msr_irqc_irr                    (msr_irqc_irr[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .irqs_lvl_i                      (irqs_lvl_i[`NCPU_NIRQ-1:0]),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_irqc_imr_nxt                (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
       .msr_irqc_imr_we                 (msr_irqc_imr_we));
   
   /************************************************************
    * TSC
    ************************************************************/
   
   ncpu32k_tsc tsc
      (/*AUTOINST*/
       // Outputs
       .tsc_irq                         (tsc_irq),
       .msr_tsc_tsr                     (msr_tsc_tsr[`NCPU_DW-1:0]),
       .msr_tsc_tcr                     (msr_tsc_tcr[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .msr_tsc_tsr_nxt                 (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tsr_we                  (msr_tsc_tsr_we),
       .msr_tsc_tcr_nxt                 (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tcr_we                  (msr_tsc_tcr_we));

   assign irqs_lvl_i[IRQ_N_TSC] = tsc_irq | fb_irqs[IRQ_N_TSC];
   assign irqs_lvl_i[`NCPU_NIRQ-1:1] = fb_irqs[`NCPU_NIRQ-1:1];
   
   /************************************************************
    * CPU Core
    ************************************************************/
   
   ncpu32k_core core
      (/*AUTOINST*/
       // Outputs
       .dbus_cmd_valid                  (dbus_cmd_valid),
       .dbus_cmd_addr                   (dbus_cmd_addr[`NCPU_AW-1:0]),
       .dbus_cmd_size                   (dbus_cmd_size[2:0]),
       .dbus_cmd_we                     (dbus_cmd_we),
       .dbus_ready                      (dbus_ready),
       .dbus_din                        (dbus_din[`NCPU_DW-1:0]),
       .ibus_cmd_valid                  (ibus_cmd_valid),
       .ibus_cmd_addr                   (ibus_cmd_addr[`NCPU_AW-1:0]),
       .ibus_ready                      (ibus_ready),
       .ibus_flush_req                  (ibus_flush_req),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_irqc_imr_nxt                (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
       .msr_irqc_imr_we                 (msr_irqc_imr_we),
       .msr_tsc_tsr_nxt                 (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tsr_we                  (msr_tsc_tsr_we),
       .msr_tsc_tcr_nxt                 (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tcr_we                  (msr_tsc_tcr_we),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dbus_cmd_ready                  (dbus_cmd_ready),
       .dbus_dout                       (dbus_dout[`NCPU_DW-1:0]),
       .dbus_valid                      (dbus_valid),
       .exp_dmm_tlb_miss                (exp_dmm_tlb_miss),
       .exp_dmm_page_fault              (exp_dmm_page_fault),
       .ibus_cmd_ready                  (ibus_cmd_ready),
       .ibus_valid                      (ibus_valid),
       .ibus_dout                       (ibus_dout[`NCPU_IW-1:0]),
       .ibus_out_id                     (ibus_out_id[`NCPU_AW-1:0]),
       .ibus_out_id_nxt                 (ibus_out_id_nxt[`NCPU_AW-1:0]),
       .ibus_flush_ack                  (ibus_flush_ack),
       .exp_imm_tlb_miss                (exp_imm_tlb_miss),
       .exp_imm_page_fault              (exp_imm_page_fault),
       .irqc_intr_sync                  (irqc_intr_sync),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_imm_tlbl                    (msr_imm_tlbl[`NCPU_DW-1:0]),
       .msr_imm_tlbh                    (msr_imm_tlbh[`NCPU_DW-1:0]),
       .msr_dmmid                       (msr_dmmid[`NCPU_DW-1:0]),
       .msr_dmm_tlbl                    (msr_dmm_tlbl[`NCPU_DW-1:0]),
       .msr_dmm_tlbh                    (msr_dmm_tlbh[`NCPU_DW-1:0]),
       .msr_irqc_imr                    (msr_irqc_imr[`NCPU_DW-1:0]),
       .msr_irqc_irr                    (msr_irqc_irr[`NCPU_DW-1:0]),
       .msr_tsc_tsr                     (msr_tsc_tsr[`NCPU_DW-1:0]),
       .msr_tsc_tcr                     (msr_tsc_tcr[`NCPU_DW-1:0]));
   
endmodule
