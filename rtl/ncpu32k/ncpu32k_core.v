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

module ncpu32k_core
#(
   parameter CONFIG_HAVE_IMMU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_HAVE_DMMU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_HAVE_ICACHE `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_HAVE_DCACHE `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_HAVE_IRQC `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_HAVE_TSC `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_OUTSTANTING_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ERST_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDTM_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDPF_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EALIGN_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ESYSCALL_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EINSN_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIRQ_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MUL `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIV `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIVU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MOD `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MODU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_FPU `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ALU_INSERT_REG `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_BPU_STRATEGY `PARAM_NOT_SPECIFIED
)
(
   input                   clk,
   input                   rst_n,
   input                   dbus_AREADY,
   output                  dbus_AVALID,
   output [`NCPU_AW-1:0]   dbus_AADDR,
   output [`NCPU_DW/8-1:0] dbus_AWMSK,
   output [`NCPU_DW-1:0]   dbus_ADATA,
   input [`NCPU_DW-1:0]    dbus_BDATA,
   input                   dbus_BVALID,
   output                  dbus_BREADY,
   input [1:0]             dbus_BEXC,
   input                   ibus_AREADY,
   output                  ibus_AVALID,
   output [`NCPU_AW-1:0]   ibus_AADDR,
   input                   ibus_BVALID,
   output                  ibus_BREADY,
   input [`NCPU_IW-1:0]    ibus_BDATA,
   input [1:0]             ibus_BEXC,
   input                   irqc_intr_sync,
   output                  msr_psr_imme,
   output                  msr_psr_dmme,
   output                  msr_psr_rm,
   output                  msr_psr_ire,
   input [`NCPU_DW-1:0]    msr_immid,
   input [`NCPU_DW-1:0]    msr_imm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]   msr_imm_tlbl_nxt,
   output                  msr_imm_tlbl_we,
   input [`NCPU_DW-1:0]    msr_imm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]   msr_imm_tlbh_nxt,
   output                  msr_imm_tlbh_we,
   input [`NCPU_DW-1:0]    msr_dmmid,
   input [`NCPU_DW-1:0]    msr_dmm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbl_idx,
   output [`NCPU_DW-1:0]   msr_dmm_tlbl_nxt,
   output                  msr_dmm_tlbl_we,
   input [`NCPU_DW-1:0]    msr_dmm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbh_idx,
   output [`NCPU_DW-1:0]   msr_dmm_tlbh_nxt,
   output                  msr_dmm_tlbh_we,
   input [`NCPU_DW-1:0]    msr_irqc_imr,
   output [`NCPU_DW-1:0]   msr_irqc_imr_nxt,
   output                  msr_irqc_imr_we,
   input [`NCPU_DW-1:0]    msr_irqc_irr,
   input [`NCPU_DW-1:0]    msr_tsc_tsr,
   output [`NCPU_DW-1:0]   msr_tsc_tsr_nxt,
   output                  msr_tsc_tsr_we,
   input [`NCPU_DW-1:0]    msr_tsc_tcr,
   output [`NCPU_DW-1:0]   msr_tsc_tcr_nxt,
   output                  msr_tsc_tcr_we
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  arf_din;                // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_REG_AW-1:0] arf_din_addr;        // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_REG_AW-1:0] arf_rs1_addr;        // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  arf_rs1_dout;           // From ARF of ncpu32k_regfile.v
   wire                 arf_rs1_re;             // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_REG_AW-1:0] arf_rs2_addr;        // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  arf_rs2_dout;           // From ARF of ncpu32k_regfile.v
   wire                 arf_rs2_re;             // From DISP of ncpu32k_dispatch.v
   wire                 arf_we;                 // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_AW-3:0]  bpu_insn_pc;            // From IFU of ncpu32k_ifu.v
   wire                 bpu_pred_taken;         // From bpu of ncpu32k_bpu.v
   wire [`NCPU_AW-3:0]  bpu_pred_tgt;           // From bpu of ncpu32k_bpu.v
   wire                 bpu_wb;                 // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_AW-3:0]  bpu_wb_insn_pc;         // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 bpu_wb_taken;           // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_AW-3:0]  bpu_wb_tgt;             // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_DW-1:0]  byp_BDATA;              // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 byp_BVALID;             // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_REG_AW-1:0] byp_rd_addr;         // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 byp_rd_we;              // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 disp_AREADY;            // From DISP of ncpu32k_dispatch.v
   wire                 disp_AVALID;            // From IDU of ncpu32k_idu.v
   wire                 disp_agu_barr;          // From IDU of ncpu32k_idu.v
   wire                 disp_agu_load;          // From IDU of ncpu32k_idu.v
   wire [2:0]           disp_agu_load_size;     // From IDU of ncpu32k_idu.v
   wire                 disp_agu_sign_ext;      // From IDU of ncpu32k_idu.v
   wire                 disp_agu_store;         // From IDU of ncpu32k_idu.v
   wire [2:0]           disp_agu_store_size;    // From IDU of ncpu32k_idu.v
   wire [`NCPU_ALU_IOPW-1:0] disp_alu_opc_bus;  // From IDU of ncpu32k_idu.v
   wire [`NCPU_EPU_IOPW-1:0] disp_epu_opc_bus;  // From IDU of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  disp_imm32;             // From IDU of ncpu32k_idu.v
   wire [`NCPU_LPU_IOPW-1:0] disp_lpu_opc_bus;  // From IDU of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  disp_pc;                // From IDU of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  disp_pred_tgt;          // From IDU of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] disp_rd_addr;        // From IDU of ncpu32k_idu.v
   wire                 disp_rd_we;             // From IDU of ncpu32k_idu.v
   wire [14:0]          disp_rel15;             // From IDU of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] disp_rs1_addr;       // From IDU of ncpu32k_idu.v
   wire                 disp_rs1_re;            // From IDU of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] disp_rs2_addr;       // From IDU of ncpu32k_idu.v
   wire                 disp_rs2_re;            // From IDU of ncpu32k_idu.v
   wire                 epu_commit_EALIGN;      // From AGU of ncpu32k_pipeline_agu.v
   wire                 epu_commit_EDPF;        // From AGU of ncpu32k_pipeline_agu.v
   wire                 epu_commit_EDTM;        // From AGU of ncpu32k_pipeline_agu.v
   wire [`NCPU_AW-1:0]  epu_commit_LSA;         // From AGU of ncpu32k_pipeline_agu.v
   wire                 flush;                  // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_AW-3:0]  flush_tgt;              // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 idu_AREADY;             // From IDU of ncpu32k_idu.v
   wire                 idu_AVALID;             // From IFU of ncpu32k_ifu.v
   wire [2:0]           idu_exc;                // From IFU of ncpu32k_ifu.v
   wire [`NCPU_IW-1:0]  idu_insn;               // From IFU of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  idu_pc;                 // From IFU of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  idu_pred_tgt;           // From IFU of ncpu32k_ifu.v
   wire                 issue_agu_AREADY;       // From AGU of ncpu32k_pipeline_agu.v
   wire                 issue_agu_AVALID;       // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_AGU_UOPW-1:0] issue_agu_uop;     // From DISP of ncpu32k_dispatch.v
   wire                 issue_alu_AREADY;       // From ALU of ncpu32k_pipeline_alu.v
   wire                 issue_alu_AVALID;       // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_ALU_UOPW-1:0] issue_alu_uop;     // From DISP of ncpu32k_dispatch.v
   wire                 issue_epu_AREADY;       // From EPU of ncpu32k_pipeline_epu.v
   wire                 issue_epu_AVALID;       // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_EPU_UOPW-1:0] issue_epu_uop;     // From DISP of ncpu32k_dispatch.v
   wire                 issue_fpu_AREADY;       // From FPU of ncpu32k_pipeline_fpu.v
   wire                 issue_fpu_AVALID;       // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_FPU_UOPW-1:0] issue_fpu_uop;     // From DISP of ncpu32k_dispatch.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] issue_id;   // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  issue_imm32;            // From DISP of ncpu32k_dispatch.v
   wire                 issue_lpu_AREADY;       // From LPU of ncpu32k_pipeline_lpu.v
   wire                 issue_lpu_AVALID;       // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_LPU_UOPW-1:0] issue_lpu_uop;     // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_REG_AW-1:0] issue_rs1_addr;      // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  issue_rs1_dat;          // From DISP of ncpu32k_dispatch.v
   wire                 issue_rs1_rdy;          // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_REG_AW-1:0] issue_rs2_addr;      // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  issue_rs2_dat;          // From DISP of ncpu32k_dispatch.v
   wire                 issue_rs2_rdy;          // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  msr_coreid;             // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_cpuid;              // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_elsa;               // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_elsa_nxt;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_elsa_we;            // From EPU of ncpu32k_pipeline_epu.v
   wire [`NCPU_DW-1:0]  msr_epc;                // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_epc_nxt;            // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_epc_we;             // From EPU of ncpu32k_pipeline_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr;            // From PSR of ncpu32k_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nxt;        // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_epsr_we;            // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_exc_ent;            // From EPU of ncpu32k_pipeline_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr;             // From PSR of ncpu32k_psr.v
   wire                 msr_psr_dmme_nxt;       // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_dmme_we;        // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_imme_nxt;       // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_imme_we;        // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_ire_nxt;        // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_ire_we;         // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_rm_nxt;         // From EPU of ncpu32k_pipeline_epu.v
   wire                 msr_psr_rm_we;          // From EPU of ncpu32k_pipeline_epu.v
   wire [`NCPU_AW-3:0]  rob_commit_pc;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] rob_commit_ptr;// From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_AREADY;        // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_AVALID;        // From DISP of ncpu32k_dispatch.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] rob_disp_id;// From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_AW-3:0]  rob_disp_pc;            // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_AW-3:0]  rob_disp_pred_tgt;      // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_REG_AW-1:0] rob_disp_rd_addr;    // From DISP of ncpu32k_dispatch.v
   wire                 rob_disp_rd_we;         // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_REG_AW-1:0] rob_disp_rs1_addr;   // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  rob_disp_rs1_dat;       // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_rs1_in_ARF;    // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_rs1_in_ROB;    // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_REG_AW-1:0] rob_disp_rs2_addr;   // From DISP of ncpu32k_dispatch.v
   wire [`NCPU_DW-1:0]  rob_disp_rs2_dat;       // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_rs2_in_ARF;    // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 rob_disp_rs2_in_ROB;    // From WB_COMMIT of ncpu32k_wb_commit.v
   wire [`NCPU_DW-1:0]  wb_agu_BDATA;           // From AGU of ncpu32k_pipeline_agu.v
   wire                 wb_agu_BEALIGN;         // From AGU of ncpu32k_pipeline_agu.v
   wire                 wb_agu_BEDPF;           // From AGU of ncpu32k_pipeline_agu.v
   wire                 wb_agu_BEDTM;           // From AGU of ncpu32k_pipeline_agu.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] wb_agu_BID; // From AGU of ncpu32k_pipeline_agu.v
   wire                 wb_agu_BREADY;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 wb_agu_BVALID;          // From AGU of ncpu32k_pipeline_agu.v
   wire                 wb_alu_BBRANCH_OP;      // From ALU of ncpu32k_pipeline_alu.v
   wire                 wb_alu_BBRANCH_REG_TAKEN;// From ALU of ncpu32k_pipeline_alu.v
   wire                 wb_alu_BBRANCH_REL_TAKEN;// From ALU of ncpu32k_pipeline_alu.v
   wire [`NCPU_DW-1:0]  wb_alu_BDATA;           // From ALU of ncpu32k_pipeline_alu.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] wb_alu_BID; // From ALU of ncpu32k_pipeline_alu.v
   wire                 wb_alu_BREADY;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 wb_alu_BVALID;          // From ALU of ncpu32k_pipeline_alu.v
   wire [`NCPU_DW-1:0]  wb_epu_BDATA;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BEINSN;          // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BEIPF;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BEIRQ;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BEITM;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BERET;           // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BESYSCALL;       // From EPU of ncpu32k_pipeline_epu.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] wb_epu_BID; // From EPU of ncpu32k_pipeline_epu.v
   wire                 wb_epu_BREADY;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 wb_epu_BVALID;          // From EPU of ncpu32k_pipeline_epu.v
   wire [`NCPU_DW-1:0]  wb_fpu_BDATA;           // From FPU of ncpu32k_pipeline_fpu.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] wb_fpu_BID; // From FPU of ncpu32k_pipeline_fpu.v
   wire                 wb_fpu_BREADY;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 wb_fpu_BVALID;          // From FPU of ncpu32k_pipeline_fpu.v
   wire [`NCPU_DW-1:0]  wb_lpu_BDATA;           // From LPU of ncpu32k_pipeline_lpu.v
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] wb_lpu_BID; // From LPU of ncpu32k_pipeline_lpu.v
   wire                 wb_lpu_BREADY;          // From WB_COMMIT of ncpu32k_wb_commit.v
   wire                 wb_lpu_BVALID;          // From LPU of ncpu32k_pipeline_lpu.v
   // End of automatics

   /////////////////////////////////////////////////////////////////////////////
   // Regfile
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_regfile ARF
      (/*AUTOINST*/
       // Outputs
       .arf_rs1_dout                    (arf_rs1_dout[`NCPU_DW-1:0]),
       .arf_rs2_dout                    (arf_rs2_dout[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .arf_rs1_addr                    (arf_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_rs2_addr                    (arf_rs2_addr[`NCPU_REG_AW-1:0]),
       .arf_rs1_re                      (arf_rs1_re),
       .arf_rs2_re                      (arf_rs2_re),
       .arf_din_addr                    (arf_din_addr[`NCPU_REG_AW-1:0]),
       .arf_din                         (arf_din[`NCPU_DW-1:0]),
       .arf_we                          (arf_we));

   ncpu32k_psr
      #(
         .CPUID_VER                       (1),
         .CPUID_REV                       (0),
         .CPUID_FIMM                      (CONFIG_HAVE_IMMU),
         .CPUID_FDMM                      (CONFIG_HAVE_DMMU),
         .CPUID_FICA                      (CONFIG_HAVE_ICACHE),
         .CPUID_FDCA                      (CONFIG_HAVE_DCACHE),
         .CPUID_FDBG                      (0),
         .CPUID_FFPU                      (CONFIG_ENABLE_FPU),
         .CPUID_FIRQC                     (CONFIG_HAVE_IRQC),
         .CPUID_FTSC                      (CONFIG_HAVE_TSC)
      )
   PSR
      (/*AUTOINST*/
       // Outputs
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .msr_exc_ent                     (msr_exc_ent),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_epc_nxt                     (msr_epc_nxt[`NCPU_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[`NCPU_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we));

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1: Fetch
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_ifu
      #(
         .CONFIG_ERST_VECTOR           (CONFIG_ERST_VECTOR),
         .CONFIG_IBUS_OUTSTANTING_LOG2 (CONFIG_IBUS_OUTSTANTING_LOG2)
      )
   IFU
      (/*AUTOINST*/
       // Outputs
       .ibus_AVALID                     (ibus_AVALID),
       .ibus_AADDR                      (ibus_AADDR[`NCPU_AW-1:0]),
       .ibus_BREADY                     (ibus_BREADY),
       .idu_AVALID                      (idu_AVALID),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_pc                          (idu_pc[`NCPU_AW-3:0]),
       .idu_exc                         (idu_exc[2:0]),
       .idu_pred_tgt                    (idu_pred_tgt[`NCPU_AW-3:0]),
       .bpu_insn_pc                     (bpu_insn_pc[`NCPU_AW-3:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ibus_AREADY                     (ibus_AREADY),
       .ibus_BVALID                     (ibus_BVALID),
       .ibus_BDATA                      (ibus_BDATA[`NCPU_IW-1:0]),
       .ibus_BEXC                       (ibus_BEXC[1:0]),
       .irqc_intr_sync                  (irqc_intr_sync),
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`NCPU_AW-3:0]),
       .idu_AREADY                      (idu_AREADY),
       .bpu_pred_taken                  (bpu_pred_taken),
       .bpu_pred_tgt                    (bpu_pred_tgt[`NCPU_AW-3:0]));

   ncpu32k_bpu
      #(
         .CONFIG_BPU_STRATEGY          (CONFIG_BPU_STRATEGY)
      )
   BPU
      (/*AUTOINST*/
       // Outputs
       .bpu_pred_taken                  (bpu_pred_taken),
       .bpu_pred_tgt                    (bpu_pred_tgt[`NCPU_AW-3:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .bpu_insn_pc                     (bpu_insn_pc[`NCPU_AW-3:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_insn_pc                  (bpu_wb_insn_pc[`NCPU_AW-3:0]),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_tgt                      (bpu_wb_tgt[`NCPU_AW-3:0]));

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 2: Decode
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_idu
      #(
         .CONFIG_ENABLE_MUL            (CONFIG_ENABLE_MUL),
         .CONFIG_ENABLE_DIV            (CONFIG_ENABLE_DIV),
         .CONFIG_ENABLE_DIVU           (CONFIG_ENABLE_DIVU),
         .CONFIG_ENABLE_MOD            (CONFIG_ENABLE_MOD),
         .CONFIG_ENABLE_MODU           (CONFIG_ENABLE_MODU),
         .CONFIG_PIPEBUF_BYPASS        (CONFIG_PIPEBUF_BYPASS)
      )
   IDU
      (/*AUTOINST*/
       // Outputs
       .idu_AREADY                      (idu_AREADY),
       .disp_AVALID                     (disp_AVALID),
       .disp_pc                         (disp_pc[`NCPU_AW-3:0]),
       .disp_pred_tgt                   (disp_pred_tgt[`NCPU_AW-3:0]),
       .disp_alu_opc_bus                (disp_alu_opc_bus[`NCPU_ALU_IOPW-1:0]),
       .disp_lpu_opc_bus                (disp_lpu_opc_bus[`NCPU_LPU_IOPW-1:0]),
       .disp_epu_opc_bus                (disp_epu_opc_bus[`NCPU_EPU_IOPW-1:0]),
       .disp_agu_load                   (disp_agu_load),
       .disp_agu_store                  (disp_agu_store),
       .disp_agu_sign_ext               (disp_agu_sign_ext),
       .disp_agu_barr                   (disp_agu_barr),
       .disp_agu_store_size             (disp_agu_store_size[2:0]),
       .disp_agu_load_size              (disp_agu_load_size[2:0]),
       .disp_rs1_re                     (disp_rs1_re),
       .disp_rs1_addr                   (disp_rs1_addr[`NCPU_REG_AW-1:0]),
       .disp_rs2_re                     (disp_rs2_re),
       .disp_rs2_addr                   (disp_rs2_addr[`NCPU_REG_AW-1:0]),
       .disp_imm32                      (disp_imm32[`NCPU_DW-1:0]),
       .disp_rel15                      (disp_rel15[14:0]),
       .disp_rd_we                      (disp_rd_we),
       .disp_rd_addr                    (disp_rd_addr[`NCPU_REG_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .idu_AVALID                      (idu_AVALID),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_pc                          (idu_pc[`NCPU_AW-3:0]),
       .idu_exc                         (idu_exc[2:0]),
       .idu_pred_tgt                    (idu_pred_tgt[`NCPU_AW-3:0]),
       .disp_AREADY                     (disp_AREADY));


   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3: Rename and Dispatch
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_dispatch
      #(
         .CONFIG_ROB_DEPTH_LOG2        (CONFIG_ROB_DEPTH_LOG2),
         .CONFIG_PIPEBUF_BYPASS        (CONFIG_PIPEBUF_BYPASS)
      )
   DISP
      (/*AUTOINST*/
       // Outputs
       .disp_AREADY                     (disp_AREADY),
       .rob_disp_AVALID                 (rob_disp_AVALID),
       .rob_disp_pc                     (rob_disp_pc[`NCPU_AW-3:0]),
       .rob_disp_pred_tgt               (rob_disp_pred_tgt[`NCPU_AW-3:0]),
       .rob_disp_rd_we                  (rob_disp_rd_we),
       .rob_disp_rd_addr                (rob_disp_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs1_addr               (rob_disp_rs1_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs2_addr               (rob_disp_rs2_addr[`NCPU_REG_AW-1:0]),
       .arf_rs1_re                      (arf_rs1_re),
       .arf_rs1_addr                    (arf_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_rs2_re                      (arf_rs2_re),
       .arf_rs2_addr                    (arf_rs2_addr[`NCPU_REG_AW-1:0]),
       .issue_alu_AVALID                (issue_alu_AVALID),
       .issue_alu_uop                   (issue_alu_uop[`NCPU_ALU_UOPW-1:0]),
       .issue_lpu_AVALID                (issue_lpu_AVALID),
       .issue_lpu_uop                   (issue_lpu_uop[`NCPU_LPU_UOPW-1:0]),
       .issue_agu_AVALID                (issue_agu_AVALID),
       .issue_agu_uop                   (issue_agu_uop[`NCPU_AGU_UOPW-1:0]),
       .issue_fpu_AVALID                (issue_fpu_AVALID),
       .issue_fpu_uop                   (issue_fpu_uop[`NCPU_FPU_UOPW-1:0]),
       .issue_epu_AVALID                (issue_epu_AVALID),
       .issue_epu_uop                   (issue_epu_uop[`NCPU_EPU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .issue_imm32                     (issue_imm32[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .disp_AVALID                     (disp_AVALID),
       .disp_pc                         (disp_pc[`NCPU_AW-3:0]),
       .disp_pred_tgt                   (disp_pred_tgt[`NCPU_AW-3:0]),
       .disp_alu_opc_bus                (disp_alu_opc_bus[`NCPU_ALU_IOPW-1:0]),
       .disp_lpu_opc_bus                (disp_lpu_opc_bus[`NCPU_LPU_IOPW-1:0]),
       .disp_epu_opc_bus                (disp_epu_opc_bus[`NCPU_EPU_IOPW-1:0]),
       .disp_agu_load                   (disp_agu_load),
       .disp_agu_store                  (disp_agu_store),
       .disp_agu_sign_ext               (disp_agu_sign_ext),
       .disp_agu_barr                   (disp_agu_barr),
       .disp_agu_store_size             (disp_agu_store_size[2:0]),
       .disp_agu_load_size              (disp_agu_load_size[2:0]),
       .disp_rs1_re                     (disp_rs1_re),
       .disp_rs1_addr                   (disp_rs1_addr[`NCPU_REG_AW-1:0]),
       .disp_rs2_re                     (disp_rs2_re),
       .disp_rs2_addr                   (disp_rs2_addr[`NCPU_REG_AW-1:0]),
       .disp_imm32                      (disp_imm32[`NCPU_DW-1:0]),
       .disp_rel15                      (disp_rel15[14:0]),
       .disp_rd_we                      (disp_rd_we),
       .disp_rd_addr                    (disp_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_AREADY                 (rob_disp_AREADY),
       .rob_disp_rs1_in_ROB             (rob_disp_rs1_in_ROB),
       .rob_disp_rs1_in_ARF             (rob_disp_rs1_in_ARF),
       .rob_disp_rs1_dat                (rob_disp_rs1_dat[`NCPU_DW-1:0]),
       .rob_disp_rs2_in_ROB             (rob_disp_rs2_in_ROB),
       .rob_disp_rs2_in_ARF             (rob_disp_rs2_in_ARF),
       .rob_disp_rs2_dat                (rob_disp_rs2_dat[`NCPU_DW-1:0]),
       .rob_disp_id                     (rob_disp_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .arf_rs1_dout                    (arf_rs1_dout[`NCPU_DW-1:0]),
       .arf_rs2_dout                    (arf_rs2_dout[`NCPU_DW-1:0]),
       .issue_alu_AREADY                (issue_alu_AREADY),
       .issue_lpu_AREADY                (issue_lpu_AREADY),
       .issue_agu_AREADY                (issue_agu_AREADY),
       .issue_fpu_AREADY                (issue_fpu_AREADY),
       .issue_epu_AREADY                (issue_epu_AREADY));

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 4-5: Issue and Execute
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_pipeline_alu
      #(
         .CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_ALU_ISSUE_QUEUE_DEPTH_LOG2),
         .CONFIG_ALU_INSERT_REG  (CONFIG_ALU_INSERT_REG),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS),
         .CONFIG_ROB_DEPTH_LOG2  (CONFIG_ROB_DEPTH_LOG2)
      )
   ALU
      (/*AUTOINST*/
       // Outputs
       .issue_alu_AREADY                (issue_alu_AREADY),
       .wb_alu_BVALID                   (wb_alu_BVALID),
       .wb_alu_BDATA                    (wb_alu_BDATA[`NCPU_DW-1:0]),
       .wb_alu_BID                      (wb_alu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_alu_BBRANCH_REG_TAKEN        (wb_alu_BBRANCH_REG_TAKEN),
       .wb_alu_BBRANCH_REL_TAKEN        (wb_alu_BBRANCH_REL_TAKEN),
       .wb_alu_BBRANCH_OP               (wb_alu_BBRANCH_OP),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .issue_alu_AVALID                (issue_alu_AVALID),
       .issue_alu_uop                   (issue_alu_uop[`NCPU_ALU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .wb_alu_BREADY                   (wb_alu_BREADY));

   ncpu32k_pipeline_lpu
      #(
         .CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_LPU_ISSUE_QUEUE_DEPTH_LOG2),
         .CONFIG_ENABLE_MUL   (CONFIG_ENABLE_MUL),
         .CONFIG_ENABLE_DIV   (CONFIG_ENABLE_DIV),
         .CONFIG_ENABLE_DIVU  (CONFIG_ENABLE_DIVU),
         .CONFIG_ENABLE_MOD   (CONFIG_ENABLE_MOD),
         .CONFIG_ENABLE_MODU  (CONFIG_ENABLE_MODU),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS),
         .CONFIG_ROB_DEPTH_LOG2  (CONFIG_ROB_DEPTH_LOG2)
      )
   LPU
      (/*AUTOINST*/
       // Outputs
       .issue_lpu_AREADY                (issue_lpu_AREADY),
       .wb_lpu_BVALID                   (wb_lpu_BVALID),
       .wb_lpu_BDATA                    (wb_lpu_BDATA[`NCPU_DW-1:0]),
       .wb_lpu_BID                      (wb_lpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .issue_lpu_AVALID                (issue_lpu_AVALID),
       .issue_lpu_uop                   (issue_lpu_uop[`NCPU_LPU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .wb_lpu_BREADY                   (wb_lpu_BREADY));

   ncpu32k_pipeline_epu
      #(
         .CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2  (CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS),
         .CONFIG_ROB_DEPTH_LOG2  (CONFIG_ROB_DEPTH_LOG2)
      )
   EPU
      (/*AUTOINST*/
       // Outputs
       .issue_epu_AREADY                (issue_epu_AREADY),
       .wb_epu_BVALID                   (wb_epu_BVALID),
       .wb_epu_BDATA                    (wb_epu_BDATA[`NCPU_DW-1:0]),
       .wb_epu_BID                      (wb_epu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_epu_BERET                    (wb_epu_BERET),
       .wb_epu_BESYSCALL                (wb_epu_BESYSCALL),
       .wb_epu_BEINSN                   (wb_epu_BEINSN),
       .wb_epu_BEIPF                    (wb_epu_BEIPF),
       .wb_epu_BEITM                    (wb_epu_BEITM),
       .wb_epu_BEIRQ                    (wb_epu_BEIRQ),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_exc_ent                     (msr_exc_ent),
       .msr_epc_nxt                     (msr_epc_nxt[`NCPU_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[`NCPU_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
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
       .flush                           (flush),
       .issue_epu_AVALID                (issue_epu_AVALID),
       .issue_epu_uop                   (issue_epu_uop[`NCPU_EPU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .issue_imm32                     (issue_imm32[`NCPU_DW-1:0]),
       .rob_commit_ptr                  (rob_commit_ptr[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .rob_commit_pc                   (rob_commit_pc[`NCPU_AW-3:0]),
       .epu_commit_EDTM                 (epu_commit_EDTM),
       .epu_commit_EDPF                 (epu_commit_EDPF),
       .epu_commit_EALIGN               (epu_commit_EALIGN),
       .epu_commit_LSA                  (epu_commit_LSA[`NCPU_AW-1:0]),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .wb_epu_BREADY                   (wb_epu_BREADY),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
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

   ncpu32k_pipeline_agu
      #(
         .CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2  (CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS),
         .CONFIG_ROB_DEPTH_LOG2  (CONFIG_ROB_DEPTH_LOG2)
      )
   AGU
      (/*AUTOINST*/
       // Outputs
       .issue_agu_AREADY                (issue_agu_AREADY),
       .dbus_AVALID                     (dbus_AVALID),
       .dbus_AADDR                      (dbus_AADDR[`NCPU_AW-1:0]),
       .dbus_AWMSK                      (dbus_AWMSK[`NCPU_DW/8-1:0]),
       .dbus_ADATA                      (dbus_ADATA[`NCPU_DW-1:0]),
       .dbus_BREADY                     (dbus_BREADY),
       .wb_agu_BVALID                   (wb_agu_BVALID),
       .wb_agu_BDATA                    (wb_agu_BDATA[`NCPU_DW-1:0]),
       .wb_agu_BID                      (wb_agu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_agu_BEDTM                    (wb_agu_BEDTM),
       .wb_agu_BEDPF                    (wb_agu_BEDPF),
       .wb_agu_BEALIGN                  (wb_agu_BEALIGN),
       .epu_commit_EDTM                 (epu_commit_EDTM),
       .epu_commit_EDPF                 (epu_commit_EDPF),
       .epu_commit_EALIGN               (epu_commit_EALIGN),
       .epu_commit_LSA                  (epu_commit_LSA[`NCPU_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .issue_agu_AVALID                (issue_agu_AVALID),
       .issue_agu_uop                   (issue_agu_uop[`NCPU_AGU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .issue_imm32                     (issue_imm32[`NCPU_DW-1:0]),
       .dbus_AREADY                     (dbus_AREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_BDATA                      (dbus_BDATA[`NCPU_DW-1:0]),
       .dbus_BEXC                       (dbus_BEXC[1:0]),
       .rob_commit_ptr                  (rob_commit_ptr[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .wb_agu_BREADY                   (wb_agu_BREADY));

   ncpu32k_pipeline_fpu
      #(
         .CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2 (CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2),
         .CONFIG_ENABLE_FPU      (CONFIG_ENABLE_FPU),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS),
         .CONFIG_ROB_DEPTH_LOG2  (CONFIG_ROB_DEPTH_LOG2)
      )
   FPU
      (/*AUTOINST*/
       // Outputs
       .issue_fpu_AREADY                (issue_fpu_AREADY),
       .wb_fpu_BVALID                   (wb_fpu_BVALID),
       .wb_fpu_BDATA                    (wb_fpu_BDATA[`NCPU_DW-1:0]),
       .wb_fpu_BID                      (wb_fpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .issue_fpu_AVALID                (issue_fpu_AVALID),
       .issue_fpu_uop                   (issue_fpu_uop[`NCPU_FPU_UOPW-1:0]),
       .issue_id                        (issue_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .issue_rs1_rdy                   (issue_rs1_rdy),
       .issue_rs1_dat                   (issue_rs1_dat[`NCPU_DW-1:0]),
       .issue_rs1_addr                  (issue_rs1_addr[`NCPU_REG_AW-1:0]),
       .issue_rs2_rdy                   (issue_rs2_rdy),
       .issue_rs2_dat                   (issue_rs2_dat[`NCPU_DW-1:0]),
       .issue_rs2_addr                  (issue_rs2_addr[`NCPU_REG_AW-1:0]),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .wb_fpu_BREADY                   (wb_fpu_BREADY));

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 6-7: Writeback and Commit
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_wb_commit
      #(
         .CONFIG_ROB_DEPTH_LOG2        (CONFIG_ROB_DEPTH_LOG2),
         .CONFIG_EDTM_VECTOR           (CONFIG_EDTM_VECTOR),
         .CONFIG_EDPF_VECTOR           (CONFIG_EDPF_VECTOR),
         .CONFIG_EALIGN_VECTOR         (CONFIG_EALIGN_VECTOR),
         .CONFIG_EITM_VECTOR           (CONFIG_EITM_VECTOR),
         .CONFIG_EIPF_VECTOR           (CONFIG_EIPF_VECTOR),
         .CONFIG_ESYSCALL_VECTOR       (CONFIG_ESYSCALL_VECTOR),
         .CONFIG_EINSN_VECTOR          (CONFIG_EINSN_VECTOR),
         .CONFIG_EIRQ_VECTOR           (CONFIG_EIRQ_VECTOR)
      )
   WB_COMMIT
      (/*AUTOINST*/
       // Outputs
       .wb_alu_BREADY                   (wb_alu_BREADY),
       .wb_lpu_BREADY                   (wb_lpu_BREADY),
       .wb_fpu_BREADY                   (wb_fpu_BREADY),
       .wb_agu_BREADY                   (wb_agu_BREADY),
       .wb_epu_BREADY                   (wb_epu_BREADY),
       .rob_commit_ptr                  (rob_commit_ptr[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .rob_commit_pc                   (rob_commit_pc[`NCPU_AW-3:0]),
       .arf_din_addr                    (arf_din_addr[`NCPU_REG_AW-1:0]),
       .arf_din                         (arf_din[`NCPU_DW-1:0]),
       .arf_we                          (arf_we),
       .byp_BVALID                      (byp_BVALID),
       .byp_BDATA                       (byp_BDATA[`NCPU_DW-1:0]),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`NCPU_AW-3:0]),
       .rob_disp_AREADY                 (rob_disp_AREADY),
       .rob_disp_rs1_in_ROB             (rob_disp_rs1_in_ROB),
       .rob_disp_rs1_in_ARF             (rob_disp_rs1_in_ARF),
       .rob_disp_rs1_dat                (rob_disp_rs1_dat[`NCPU_DW-1:0]),
       .rob_disp_rs2_in_ROB             (rob_disp_rs2_in_ROB),
       .rob_disp_rs2_in_ARF             (rob_disp_rs2_in_ARF),
       .rob_disp_rs2_dat                (rob_disp_rs2_dat[`NCPU_DW-1:0]),
       .rob_disp_id                     (rob_disp_id[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_insn_pc                  (bpu_wb_insn_pc[`NCPU_AW-3:0]),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_tgt                      (bpu_wb_tgt[`NCPU_AW-3:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .wb_alu_BVALID                   (wb_alu_BVALID),
       .wb_alu_BDATA                    (wb_alu_BDATA[`NCPU_DW-1:0]),
       .wb_alu_BID                      (wb_alu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_alu_BBRANCH_REG_TAKEN        (wb_alu_BBRANCH_REG_TAKEN),
       .wb_alu_BBRANCH_REL_TAKEN        (wb_alu_BBRANCH_REL_TAKEN),
       .wb_alu_BBRANCH_OP               (wb_alu_BBRANCH_OP),
       .wb_lpu_BVALID                   (wb_lpu_BVALID),
       .wb_lpu_BDATA                    (wb_lpu_BDATA[`NCPU_DW-1:0]),
       .wb_lpu_BID                      (wb_lpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_fpu_BVALID                   (wb_fpu_BVALID),
       .wb_fpu_BDATA                    (wb_fpu_BDATA[`NCPU_DW-1:0]),
       .wb_fpu_BID                      (wb_fpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_agu_BVALID                   (wb_agu_BVALID),
       .wb_agu_BDATA                    (wb_agu_BDATA[`NCPU_DW-1:0]),
       .wb_agu_BID                      (wb_agu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_agu_BEDTM                    (wb_agu_BEDTM),
       .wb_agu_BEDPF                    (wb_agu_BEDPF),
       .wb_agu_BEALIGN                  (wb_agu_BEALIGN),
       .wb_epu_BVALID                   (wb_epu_BVALID),
       .wb_epu_BDATA                    (wb_epu_BDATA[`NCPU_DW-1:0]),
       .wb_epu_BID                      (wb_epu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .wb_epu_BERET                    (wb_epu_BERET),
       .wb_epu_BESYSCALL                (wb_epu_BESYSCALL),
       .wb_epu_BEINSN                   (wb_epu_BEINSN),
       .wb_epu_BEIPF                    (wb_epu_BEIPF),
       .wb_epu_BEITM                    (wb_epu_BEITM),
       .wb_epu_BEIRQ                    (wb_epu_BEIRQ),
       .rob_disp_AVALID                 (rob_disp_AVALID),
       .rob_disp_pc                     (rob_disp_pc[`NCPU_AW-3:0]),
       .rob_disp_pred_tgt               (rob_disp_pred_tgt[`NCPU_AW-3:0]),
       .rob_disp_rd_we                  (rob_disp_rd_we),
       .rob_disp_rd_addr                (rob_disp_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs1_addr               (rob_disp_rs1_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs2_addr               (rob_disp_rs2_addr[`NCPU_REG_AW-1:0]));

endmodule
