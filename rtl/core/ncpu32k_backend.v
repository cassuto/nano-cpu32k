/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_backend
#(
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
   parameter BPU_UPD_DW
   `PARAM_NOT_SPECIFIED ,
   parameter [7:0] CPUID_VER
   `PARAM_NOT_SPECIFIED ,
   parameter [9:0] CPUID_REV
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FIMM
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FDMM
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FICA
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FDCA
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FDBG
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FFPU
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FIRQC
   `PARAM_NOT_SPECIFIED ,
   parameter [0:0] CPUID_FTSC
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ERST_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDTM_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDPF_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EALIGN_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ESYSCALL_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EINSN_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIRQ_VECTOR
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
)
(
   input                               clk,
   input                               rst_n,
   output                              flush,
   output [`NCPU_AW-3:0]               flush_tgt,
   output                              stall_fnt,
   // IRQ
   input                               irq_sync,
   // From icache
   input                               icinv_stall,
   // From the frontend
   input                               idu_1_insn_vld,
   input [`NCPU_IW-1:0]                idu_1_insn,
   input [`NCPU_AW-3:0]                idu_1_pc,
   input [`NCPU_AW-3:0]                idu_1_pc_4,
   input [BPU_UPD_DW-1:0]              idu_1_bpu_upd,
   input                               idu_1_EITM,
   input                               idu_1_EIPF,
   input                               idu_2_insn_vld,
   input [`NCPU_IW-1:0]                idu_2_insn,
   input [`NCPU_AW-3:0]                idu_2_pc,
   input [`NCPU_AW-3:0]                idu_2_pc_4,
   input [BPU_UPD_DW-1:0]              idu_2_bpu_upd,
   input                               idu_2_EITM,
   input                               idu_2_EIPF,
   input [`NCPU_AW-3:0]                idu_bpu_pc_nxt,
   // To BPU
   output                              bpu_wb,
   output                              bpu_wb_is_bcc,
   output                              bpu_wb_is_breg,
   output                              bpu_wb_taken,
   output [`NCPU_AW-3:0]               bpu_wb_pc,
   output [`NCPU_AW-3:0]               bpu_wb_pc_nxt_act,
   output [BPU_UPD_DW-1:0]             bpu_wb_upd,
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
   // IMMID
   input [`NCPU_DW-1:0]                msr_immid,
   // ITLBL
   output [`NCPU_TLB_AW-1:0]           msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]               msr_imm_tlbl_nxt,
   output                              msr_imm_tlbl_we,
   // ITLBH
   output [`NCPU_TLB_AW-1:0]           msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]               msr_imm_tlbh_nxt,
   output                              msr_imm_tlbh_we,
   // IMR
   input [`NCPU_DW-1:0]                msr_irqc_imr,
   output [`NCPU_DW-1:0]               msr_irqc_imr_nxt,
   output                              msr_irqc_imr_we,
   // ICID
   input [`NCPU_DW-1:0]                msr_icid,
   // ICINV
   output [`NCPU_DW-1:0]               msr_icinv_nxt,
   output                              msr_icinv_we,
   // IRR
   input [`NCPU_DW-1:0]                msr_irqc_irr,
   // TSR
   input [`NCPU_DW-1:0]                msr_tsc_tsr,
   output [`NCPU_DW-1:0]               msr_tsc_tsr_nxt,
   output                              msr_tsc_tsr_we,
   // TCR
   input [`NCPU_DW-1:0]                msr_tsc_tcr,
   output [`NCPU_DW-1:0]               msr_tsc_tcr_nxt,
   output                              msr_tsc_tcr_we,
   // PSR
   output                              msr_psr_imme,
   output                              msr_psr_ire,
   output                              msr_psr_rm
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 alu_1_AVALID;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_ALU_IOPW-1:0] alu_1_opc_bus;     // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  alu_1_operand1;         // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  alu_1_operand2;         // From SCHEDULER of ncpu32k_scheduler.v
   wire                 alu_2_AVALID;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_ALU_IOPW-1:0] alu_2_opc_bus;     // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  alu_2_operand1;         // From SCHEDULER of ncpu32k_scheduler.v
   wire                 alu_2_operand1_frm_alu_1;// From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  alu_2_operand2;         // From SCHEDULER of ncpu32k_scheduler.v
   wire                 alu_2_operand2_frm_alu_1;// From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  arf_1_rs1_dout;         // From REGFILE of ncpu32k_regfile.v
   wire [`NCPU_DW-1:0]  arf_1_rs2_dout;         // From REGFILE of ncpu32k_regfile.v
   wire [`NCPU_DW-1:0]  arf_2_rs1_dout;         // From REGFILE of ncpu32k_regfile.v
   wire [`NCPU_DW-1:0]  arf_2_rs2_dout;         // From REGFILE of ncpu32k_regfile.v
   wire                 bru_AVALID;             // From SCHEDULER of ncpu32k_scheduler.v
   wire                 bru_in_slot_1;          // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_BRU_IOPW-1:0] bru_opc_bus;       // From SCHEDULER of ncpu32k_scheduler.v
   wire                 bru_operand1_frm_alu_1; // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  bru_operand1_nobyp;     // From SCHEDULER of ncpu32k_scheduler.v
   wire                 bru_operand2_frm_alu_1; // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  bru_operand2_nobyp;     // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  bru_pc;                 // From SCHEDULER of ncpu32k_scheduler.v
   wire [14:0]          bru_rel15;              // From SCHEDULER of ncpu32k_scheduler.v
   wire                 epu_AVALID;             // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  epu_imm32;              // From SCHEDULER of ncpu32k_scheduler.v
   wire                 epu_in_slot_1;          // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_EPU_IOPW-1:0] epu_opc_bus;       // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  epu_operand1;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  epu_operand2;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  epu_pc;                 // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lpu_AVALID;             // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lpu_in_slot_1;          // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_LPU_IOPW-1:0] lpu_opc_bus;       // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  lpu_operand1;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  lpu_operand2;           // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lpu_stall;              // From LPU of ncpu32k_lpu.v
   wire                 lsu_AVALID_before_inv;  // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_barr;               // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  lsu_imm32;              // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_in_slot_1;          // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_load;               // From SCHEDULER of ncpu32k_scheduler.v
   wire [2:0]           lsu_load_size;          // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_operand1_frm_alu_1; // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  lsu_operand1_nobyp;     // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_operand2_frm_alu_1; // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  lsu_operand2_nobyp;     // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  lsu_pc;                 // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_sign_ext;           // From SCHEDULER of ncpu32k_scheduler.v
   wire                 lsu_stall;              // From LSU of ncpu32k_lsu.v
   wire                 lsu_store;              // From SCHEDULER of ncpu32k_scheduler.v
   wire [2:0]           lsu_store_size;         // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_DW-1:0]  msr_coreid;             // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_cpuid;              // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_dcfls_nxt;          // From EPU of ncpu32k_epu.v
   wire                 msr_dcfls_we;           // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  msr_dcid;               // From LSU of ncpu32k_lsu.v
   wire [`NCPU_DW-1:0]  msr_dcinv_nxt;          // From EPU of ncpu32k_epu.v
   wire                 msr_dcinv_we;           // From EPU of ncpu32k_epu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbh_idx;    // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbh_nxt;       // From EPU of ncpu32k_epu.v
   wire                 msr_dmm_tlbh_we;        // From EPU of ncpu32k_epu.v
   wire [`NCPU_TLB_AW-1:0] msr_dmm_tlbl_idx;    // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  msr_dmm_tlbl_nxt;       // From EPU of ncpu32k_epu.v
   wire                 msr_dmm_tlbl_we;        // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  msr_dmmid;              // From LSU of ncpu32k_lsu.v
   wire [`NCPU_DW-1:0]  msr_elsa;               // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_elsa_nxt;           // From EPU of ncpu32k_epu.v
   wire                 msr_elsa_we;            // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  msr_epc;                // From PSR of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_epc_nxt;            // From EPU of ncpu32k_epu.v
   wire                 msr_epc_we;             // From EPU of ncpu32k_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr;            // From PSR of ncpu32k_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nobyp;      // From PSR of ncpu32k_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nxt;        // From EPU of ncpu32k_epu.v
   wire                 msr_epsr_we;            // From EPU of ncpu32k_epu.v
   wire                 msr_exc_ent;            // From EPU of ncpu32k_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr;             // From PSR of ncpu32k_psr.v
   wire                 msr_psr_dmme;           // From PSR of ncpu32k_psr.v
   wire                 msr_psr_dmme_nxt;       // From EPU of ncpu32k_epu.v
   wire                 msr_psr_dmme_we;        // From EPU of ncpu32k_epu.v
   wire                 msr_psr_imme_nxt;       // From EPU of ncpu32k_epu.v
   wire                 msr_psr_imme_we;        // From EPU of ncpu32k_epu.v
   wire                 msr_psr_ire_nxt;        // From EPU of ncpu32k_epu.v
   wire                 msr_psr_ire_we;         // From EPU of ncpu32k_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr_nold;        // From PSR of ncpu32k_psr.v
   wire                 msr_psr_rm_nxt;         // From EPU of ncpu32k_epu.v
   wire                 msr_psr_rm_we;          // From EPU of ncpu32k_epu.v
   wire                 sch_stall;              // From SCHEDULER of ncpu32k_scheduler.v
   wire [BPU_UPD_DW-1:0] slot_1_bpu_upd;        // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  slot_1_pc;              // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  slot_1_pc_4;            // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_REG_AW-1:0] slot_1_rd_addr;      // From SCHEDULER of ncpu32k_scheduler.v
   wire                 slot_1_rd_we;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [BPU_UPD_DW-1:0] slot_2_bpu_upd;        // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  slot_2_pc;              // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  slot_2_pc_4;            // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_REG_AW-1:0] slot_2_rd_addr;      // From SCHEDULER of ncpu32k_scheduler.v
   wire                 slot_2_rd_we;           // From SCHEDULER of ncpu32k_scheduler.v
   wire [`NCPU_AW-3:0]  slot_bpu_pc_nxt;        // From SCHEDULER of ncpu32k_scheduler.v
   wire                 wb_EINSN;               // From EPU of ncpu32k_epu.v
   wire                 wb_EIPF;                // From EPU of ncpu32k_epu.v
   wire                 wb_EIRQ;                // From EPU of ncpu32k_epu.v
   wire                 wb_EITM;                // From EPU of ncpu32k_epu.v
   wire                 wb_ERET;                // From EPU of ncpu32k_epu.v
   wire                 wb_ESYSCALL;            // From EPU of ncpu32k_epu.v
   wire                 wb_E_FLUSH_TLB;         // From EPU of ncpu32k_epu.v
   wire                 wb_bru_AVALID;          // From BRU of ncpu32k_bru.v
   wire                 wb_bru_branch_taken;    // From BRU of ncpu32k_bru.v
   wire [`NCPU_AW-3:0]  wb_bru_branch_tgt;      // From BRU of ncpu32k_bru.v
   wire [`NCPU_DW-1:0]  wb_bru_dout;            // From BRU of ncpu32k_bru.v
   wire                 wb_bru_in_slot_1;       // From BRU of ncpu32k_bru.v
   wire                 wb_bru_is_bcc;          // From BRU of ncpu32k_bru.v
   wire                 wb_bru_is_breg;         // From BRU of ncpu32k_bru.v
   wire                 wb_epu_AVALID;          // From EPU of ncpu32k_epu.v
   wire [`NCPU_DW-1:0]  wb_epu_dout;            // From EPU of ncpu32k_epu.v
   wire                 wb_epu_exc;             // From EPU of ncpu32k_epu.v
   wire [`NCPU_AW-3:0]  wb_epu_exc_vec;         // From EPU of ncpu32k_epu.v
   wire                 wb_epu_in_slot_1;       // From EPU of ncpu32k_epu.v
   wire [`NCPU_AW-3:0]  wb_epu_pc;              // From EPU of ncpu32k_epu.v
   wire                 wb_lpu_AVALID;          // From LPU of ncpu32k_lpu.v
   wire [`NCPU_DW-1:0]  wb_lpu_dout;            // From LPU of ncpu32k_lpu.v
   wire                 wb_lpu_in_slot_1;       // From LPU of ncpu32k_lpu.v
   wire                 wb_lsu_AVALID;          // From LSU of ncpu32k_lsu.v
   wire                 wb_lsu_EALIGN;          // From LSU of ncpu32k_lsu.v
   wire                 wb_lsu_EDPF;            // From LSU of ncpu32k_lsu.v
   wire                 wb_lsu_EDTM;            // From LSU of ncpu32k_lsu.v
   wire [`NCPU_AW-1:0]  wb_lsu_LSA;             // From LSU of ncpu32k_lsu.v
   wire [`NCPU_DW-1:0]  wb_lsu_dout;            // From LSU of ncpu32k_lsu.v
   wire                 wb_lsu_in_slot_1;       // From LSU of ncpu32k_lsu.v
   wire [`NCPU_AW-3:0]  wb_lsu_pc;              // From LSU of ncpu32k_lsu.v
   wire [`NCPU_DW-1:0]  wb_wmsr_dat;            // From EPU of ncpu32k_epu.v
   wire [`NCPU_WMSR_WE_DW-1:0] wb_wmsr_we;      // From EPU of ncpu32k_epu.v
   // End of automatics
   /*AUTOINPUT*/
   /*Internals*/
   wire                       stall_bck;
   wire [`NCPU_DW-1:0]        arf_1_rs1_dout_bypass;
   wire [`NCPU_DW-1:0]        arf_1_rs2_dout_bypass;
   wire [`NCPU_DW-1:0]        arf_2_rs1_dout_bypass;
   wire [`NCPU_DW-1:0]        arf_2_rs2_dout_bypass;
   wire [`NCPU_DW-1:0]        bru_operand1;           // To BRU of ncpu32k_bru.v
   wire [`NCPU_DW-1:0]        bru_operand2;           // To BRU of ncpu32k_bru.v
   wire [`NCPU_DW-1:0]        lsu_operand1;           // To LSU of ncpu32k_lsu.v
   wire [`NCPU_DW-1:0]        lsu_operand2;           // To LSU of ncpu32k_lsu.v
   wire                       stall_bck_nolsu;        // To LSU of ncpu32k_lsu.v
   wire                       slot_2_inv;             // To SCHEDULER of ncpu32k_scheduler.v
   wire                       s1_pipe_cke;
   wire                       wb_alu_1_AVALID;
   wire [`NCPU_DW-1:0]        wb_alu_1_dout;
   wire                       wb_epu_AVALID_nxt;
   wire                       s1i_slot_BVALID_nxt [2:1];
   wire                       s1_before_inv_slot_AVALID [2:1];
   wire [`NCPU_DW-1:0]        s1i_slot_dout [2:1];
   wire [`NCPU_AW-3:0]        s1i_slot_pc_nxt_act [2:1];
   wire [`NCPU_DW-1:0]        s1i_alu_2_operand1;
   wire [`NCPU_DW-1:0]        s1i_alu_2_operand2;
   wire                       s1i_slot_BVALID [2:1];
   reg                        s1i_inv_slot [2:1];
   wire                       bpu_wb_nxt;
   wire                       s1o_noflush;
   wire                       s1o_slot_rd_we [2:1];
   wire [`NCPU_REG_AW-1:0]    s1o_slot_rd_addr [2:1];
   wire                       s1o_slot_BVALID [2:1];
   wire [`NCPU_DW-1:0]        s1o_slot_dout [2:1];
`ifdef NCPU_ENABLE_TRACER
   wire [`NCPU_AW-3:0]        trace_s1o_slot_pc [2:1];
`endif
   wire [`NCPU_AW-3:0]        s1o_slot_pc_nxt_act [2:1];
   wire                       s1o_wb_epu_AVALID;
   wire                       s1o_wb_epu_exc;
   wire [`NCPU_AW-3:0]        s1o_wb_epu_exc_vec;
   wire                       s1o_wb_epu_in_slot_1;
   wire [`NCPU_AW-3:0]        s1o_wb_epu_pc;
    wire [`NCPU_AW-3:0]       s1o_wb_epu_pc_4;
   wire [`NCPU_DW-1:0]        commit_wmsr_dat;        // To EPU of ncpu32k_epu.v
   wire [`NCPU_WMSR_WE_DW-1:0] commit_wmsr_we; // To EPU of ncpu32k_epu.v
   wire                       fu_flush;
   wire                       wb_lsu_rd_we, wb_lsu_rd_we_nxt;
   wire [`NCPU_REG_AW-1:0]    wb_lsu_rd_addr, wb_lsu_rd_addr_nxt;
`ifdef NCPU_ENABLE_TRACER
   wire                       trace_wb_lsu_load;
   wire                       trace_wb_lsu_store;
   wire [2:0]                 trace_wb_lsu_size;
`endif
   wire                       wb_alu_2_AVALID;
   wire [`NCPU_DW-1:0]        wb_alu_2_dout;
   wire                       s2_inv_slot_1;
   wire                       s2_inv_slot_2;
   wire                       s2o_slot_BVALID [2:1];
   wire [`NCPU_AW-1:0]        s2o_slot_dout [2:1];
   wire                       s2o_slot_rd_we [2:1];
   wire [`NCPU_REG_AW-1:0]    s2o_slot_rd_addr [2:1];
   wire [`NCPU_REG_AW-1:0]    arf_1_rs1_addr;
   wire [`NCPU_REG_AW-1:0]    arf_1_rs2_addr;
   wire                       arf_1_rs1_re;
   wire                       arf_1_rs2_re;
   wire [`NCPU_REG_AW-1:0]    arf_2_rs1_addr;
   wire [`NCPU_REG_AW-1:0]    arf_2_rs2_addr;
   wire                       arf_2_rs1_re;
   wire                       arf_2_rs2_re;
   wire [`NCPU_REG_AW-1:0]    arf_1_waddr;
   wire [`NCPU_DW-1:0]        arf_1_wdat;
   wire                       arf_1_we;
   wire [`NCPU_REG_AW-1:0]    arf_2_waddr;
   wire [`NCPU_DW-1:0]        arf_2_wdat;
   wire                       arf_2_we;
   wire                       commit_EALIGN;          // To EPU of ncpu32k_epu.v
   wire                       commit_EDPF;            // To EPU of ncpu32k_epu.v
   wire                       commit_EDTM;            // To EPU of ncpu32k_epu.v
   wire                       commit_EINSN;           // To EPU of ncpu32k_epu.v
   wire                       commit_EIPF;            // To EPU of ncpu32k_epu.v
   wire                       commit_EIRQ;            // To EPU of ncpu32k_epu.v
   wire                       commit_EITM;            // To EPU of ncpu32k_epu.v
   wire                       commit_ERET;            // To EPU of ncpu32k_epu.v
   wire                       commit_ESYSCALL;        // To EPU of ncpu32k_epu.v
   wire                       commit_E_FLUSH_TLB; // To EPU of ncpu32k_epu.v
   wire [`NCPU_AW-1:0]        commit_LSA;             // To EPU of ncpu32k_epu.v
   wire [`NCPU_AW-3:0]        commit_pc;              // To EPU of ncpu32k_epu.v
   wire                       lsu_AVALID;             // To LSU of ncpu32k_lsu.v
   wire                       commit_EALIGN_slot1, commit_EALIGN_slot2;
   wire                       commit_EDPF_slot1, commit_EDPF_slot2;
   wire                       commit_EDTM_slot1, commit_EDTM_slot2;
   wire                       commit_EINSN_slot1, commit_EINSN_slot2;
   wire                       commit_EIPF_slot1, commit_EIPF_slot2;
   wire                       commit_EIRQ_slot1, commit_EIRQ_slot2;
   wire                       commit_EITM_slot1, commit_EITM_slot2;
   wire                       commit_ERET_slot1, commit_ERET_slot2;
   wire                       commit_ESYSCALL_slot1, commit_ESYSCALL_slot2;
   wire                       commit_E_FLUSH_TLB_slot1, commit_E_FLUSH_TLB_slot2;
   wire                       commit_exc_slot1;
   reg                        s1_se_flush;
   reg [`NCPU_AW-3:0]         s1_se_flush_tgt;
   wire                       s2_flush;
   wire [`NCPU_AW-3:0]        s2_flush_tgt;
   genvar i;

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1 (of backend)
   /////////////////////////////////////////////////////////////////////////////

   /* ncpu32k_scheduler AUTO_TEMPLATE (
         .arf_1_rs1_dout      (arf_1_rs1_dout_bypass[`NCPU_DW-1:0]),
         .arf_1_rs2_dout      (arf_1_rs2_dout_bypass[`NCPU_DW-1:0]),
         .arf_2_rs1_dout      (arf_2_rs1_dout_bypass[`NCPU_DW-1:0]),
         .arf_2_rs2_dout      (arf_2_rs2_dout_bypass[`NCPU_DW-1:0]),
         .bru_operand1        (bru_operand1_nobyp[`NCPU_DW-1:0]),
         .bru_operand2        (bru_operand2_nobyp[`NCPU_DW-1:0]),
         .lsu_operand1        (lsu_operand1_nobyp[`NCPU_DW-1:0]),
         .lsu_operand2        (lsu_operand2_nobyp[`NCPU_DW-1:0]),
         .lsu_AVALID          (lsu_AVALID_before_inv),
      )
   */
   ncpu32k_scheduler
      #(
         .CONFIG_ENABLE_MUL   (CONFIG_ENABLE_MUL),
         .CONFIG_ENABLE_DIV   (CONFIG_ENABLE_DIV),
         .CONFIG_ENABLE_DIVU  (CONFIG_ENABLE_DIVU),
         .CONFIG_ENABLE_MOD   (CONFIG_ENABLE_MOD),
         .CONFIG_ENABLE_MODU  (CONFIG_ENABLE_MODU),
         .CONFIG_ENABLE_ASR   (CONFIG_ENABLE_ASR),
         .BPU_UPD_DW          (BPU_UPD_DW)
      )
   SCHEDULER
      (/*AUTOINST*/
       // Outputs
       .sch_stall                       (sch_stall),
       .slot_1_rd_we                    (slot_1_rd_we),
       .slot_1_rd_addr                  (slot_1_rd_addr[`NCPU_REG_AW-1:0]),
       .slot_1_pc                       (slot_1_pc[`NCPU_AW-3:0]),
       .slot_1_pc_4                     (slot_1_pc_4[`NCPU_AW-3:0]),
       .slot_1_bpu_upd                  (slot_1_bpu_upd[BPU_UPD_DW-1:0]),
       .slot_2_rd_we                    (slot_2_rd_we),
       .slot_2_rd_addr                  (slot_2_rd_addr[`NCPU_REG_AW-1:0]),
       .slot_2_pc                       (slot_2_pc[`NCPU_AW-3:0]),
       .slot_2_pc_4                     (slot_2_pc_4[`NCPU_AW-3:0]),
       .slot_2_bpu_upd                  (slot_2_bpu_upd[BPU_UPD_DW-1:0]),
       .slot_bpu_pc_nxt                 (slot_bpu_pc_nxt[`NCPU_AW-3:0]),
       .alu_1_AVALID                    (alu_1_AVALID),
       .alu_1_opc_bus                   (alu_1_opc_bus[`NCPU_ALU_IOPW-1:0]),
       .alu_1_operand1                  (alu_1_operand1[`NCPU_DW-1:0]),
       .alu_1_operand2                  (alu_1_operand2[`NCPU_DW-1:0]),
       .alu_2_AVALID                    (alu_2_AVALID),
       .alu_2_opc_bus                   (alu_2_opc_bus[`NCPU_ALU_IOPW-1:0]),
       .alu_2_operand1                  (alu_2_operand1[`NCPU_DW-1:0]),
       .alu_2_operand1_frm_alu_1        (alu_2_operand1_frm_alu_1),
       .alu_2_operand2                  (alu_2_operand2[`NCPU_DW-1:0]),
       .alu_2_operand2_frm_alu_1        (alu_2_operand2_frm_alu_1),
       .lpu_AVALID                      (lpu_AVALID),
       .lpu_opc_bus                     (lpu_opc_bus[`NCPU_LPU_IOPW-1:0]),
       .lpu_operand1                    (lpu_operand1[`NCPU_DW-1:0]),
       .lpu_operand2                    (lpu_operand2[`NCPU_DW-1:0]),
       .lpu_in_slot_1                   (lpu_in_slot_1),
       .bru_AVALID                      (bru_AVALID),
       .bru_pc                          (bru_pc[`NCPU_AW-3:0]),
       .bru_opc_bus                     (bru_opc_bus[`NCPU_BRU_IOPW-1:0]),
       .bru_operand1                    (bru_operand1_nobyp[`NCPU_DW-1:0]), // Templated
       .bru_operand1_frm_alu_1          (bru_operand1_frm_alu_1),
       .bru_operand2                    (bru_operand2_nobyp[`NCPU_DW-1:0]), // Templated
       .bru_operand2_frm_alu_1          (bru_operand2_frm_alu_1),
       .bru_rel15                       (bru_rel15[14:0]),
       .bru_in_slot_1                   (bru_in_slot_1),
       .epu_AVALID                      (epu_AVALID),
       .epu_pc                          (epu_pc[`NCPU_AW-3:0]),
       .epu_opc_bus                     (epu_opc_bus[`NCPU_EPU_IOPW-1:0]),
       .epu_operand1                    (epu_operand1[`NCPU_DW-1:0]),
       .epu_operand2                    (epu_operand2[`NCPU_DW-1:0]),
       .epu_imm32                       (epu_imm32[`NCPU_DW-1:0]),
       .epu_in_slot_1                   (epu_in_slot_1),
       .lsu_AVALID                      (lsu_AVALID_before_inv), // Templated
       .lsu_load                        (lsu_load),
       .lsu_store                       (lsu_store),
       .lsu_sign_ext                    (lsu_sign_ext),
       .lsu_barr                        (lsu_barr),
       .lsu_store_size                  (lsu_store_size[2:0]),
       .lsu_load_size                   (lsu_load_size[2:0]),
       .lsu_operand1                    (lsu_operand1_nobyp[`NCPU_DW-1:0]), // Templated
       .lsu_operand1_frm_alu_1          (lsu_operand1_frm_alu_1),
       .lsu_operand2                    (lsu_operand2_nobyp[`NCPU_DW-1:0]), // Templated
       .lsu_operand2_frm_alu_1          (lsu_operand2_frm_alu_1),
       .lsu_imm32                       (lsu_imm32[`NCPU_DW-1:0]),
       .lsu_pc                          (lsu_pc[`NCPU_AW-3:0]),
       .lsu_in_slot_1                   (lsu_in_slot_1),
       .arf_1_rs1_re                    (arf_1_rs1_re),
       .arf_1_rs1_addr                  (arf_1_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_1_rs2_re                    (arf_1_rs2_re),
       .arf_1_rs2_addr                  (arf_1_rs2_addr[`NCPU_REG_AW-1:0]),
       .arf_2_rs1_re                    (arf_2_rs1_re),
       .arf_2_rs1_addr                  (arf_2_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_2_rs2_re                    (arf_2_rs2_re),
       .arf_2_rs2_addr                  (arf_2_rs2_addr[`NCPU_REG_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .stall_fnt                       (stall_fnt),
       .stall_bck                       (stall_bck),
       .flush                           (flush),
       .irq_sync                        (irq_sync),
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
       .slot_2_inv                      (slot_2_inv),
       .arf_1_rs1_dout                  (arf_1_rs1_dout_bypass[`NCPU_DW-1:0]), // Templated
       .arf_1_rs2_dout                  (arf_1_rs2_dout_bypass[`NCPU_DW-1:0]), // Templated
       .arf_2_rs1_dout                  (arf_2_rs1_dout_bypass[`NCPU_DW-1:0]), // Templated
       .arf_2_rs2_dout                  (arf_2_rs2_dout_bypass[`NCPU_DW-1:0])); // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated) // Templated)

   `define BYPASS_NETWORK_PORTS \
      .wb_slot_1_BVALID             (s2o_slot_BVALID[1]), \
      .wb_slot_1_rd_we              (s2o_slot_rd_we[1]), \
      .wb_slot_1_rd_addr            (s2o_slot_rd_addr[1]), \
      .wb_slot_1_dout               (s2o_slot_dout[1]), \
      .wb_slot_2_BVALID             (s2o_slot_BVALID[2]), \
      .wb_slot_2_rd_we              (s2o_slot_rd_we[2]), \
      .wb_slot_2_rd_addr            (s2o_slot_rd_addr[2]), \
      .wb_slot_2_dout               (s2o_slot_dout[2])

   ncpu32k_bypass_network BYPASS_NET_1
      (
         .clk                          (clk),
         .en                           (arf_1_rs1_re),
         .i_operand_rf_addr            (arf_1_rs1_addr),
         .i_operand                    (arf_1_rs1_dout),
         .o_operand                    (arf_1_rs1_dout_bypass),
         `BYPASS_NETWORK_PORTS
      );
   ncpu32k_bypass_network BYPASS_NET_2
      (
         .clk                          (clk),
         .en                           (arf_1_rs2_re),
         .i_operand_rf_addr            (arf_1_rs2_addr),
         .i_operand                    (arf_1_rs2_dout),
         .o_operand                    (arf_1_rs2_dout_bypass),
         `BYPASS_NETWORK_PORTS
      );
   ncpu32k_bypass_network BYPASS_NET_3
      (
         .clk                          (clk),
         .en                           (arf_2_rs1_re),
         .i_operand_rf_addr            (arf_2_rs1_addr),
         .i_operand                    (arf_2_rs1_dout),
         .o_operand                    (arf_2_rs1_dout_bypass),
         `BYPASS_NETWORK_PORTS
      );
   ncpu32k_bypass_network BYPASS_NET_4
      (
         .clk                          (clk),
         .en                           (arf_2_rs2_re),
         .i_operand_rf_addr            (arf_2_rs2_addr),
         .i_operand                    (arf_2_rs2_dout),
         .o_operand                    (arf_2_rs2_dout_bypass),
         `BYPASS_NETWORK_PORTS
      );

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 2 (of backend)
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_alu
      #(
         .CONFIG_ENABLE_ASR               (CONFIG_ENABLE_ASR)
      )
   ALU_1
      (
         // Outputs
         .wb_alu_AVALID                   (wb_alu_1_AVALID),
         .wb_alu_dout                     (wb_alu_1_dout[`NCPU_DW-1:0]),
         // Inputs
`ifdef NCPU_ENABLE_ASSERT
         .clk                             (clk),
`endif
         .alu_AVALID                      (alu_1_AVALID),
         .alu_opc_bus                     (alu_1_opc_bus[`NCPU_ALU_IOPW-1:0]),
         .alu_operand1                    (alu_1_operand1[`NCPU_DW-1:0]),
         .alu_operand2                    (alu_1_operand2[`NCPU_DW-1:0])
      );

   ncpu32k_alu
      #(
         .CONFIG_ENABLE_ASR               (CONFIG_ENABLE_ASR)
      )
   ALU_2
      (
         // Outputs
         .wb_alu_AVALID                   (wb_alu_2_AVALID),
         .wb_alu_dout                     (wb_alu_2_dout[`NCPU_DW-1:0]),
         // Inputs
`ifdef NCPU_ENABLE_ASSERT
         .clk                             (clk),
`endif
         .alu_AVALID                      (alu_2_AVALID),
         .alu_opc_bus                     (alu_2_opc_bus[`NCPU_ALU_IOPW-1:0]),
         .alu_operand1                    (s1i_alu_2_operand1[`NCPU_DW-1:0]),
         .alu_operand2                    (s1i_alu_2_operand2[`NCPU_DW-1:0])
      );

   ncpu32k_bru BRU
      (/*AUTOINST*/
       // Outputs
       .wb_bru_AVALID                   (wb_bru_AVALID),
       .wb_bru_dout                     (wb_bru_dout[`NCPU_DW-1:0]),
       .wb_bru_branch_taken             (wb_bru_branch_taken),
       .wb_bru_branch_tgt               (wb_bru_branch_tgt[`NCPU_AW-3:0]),
       .wb_bru_is_bcc                   (wb_bru_is_bcc),
       .wb_bru_is_breg                  (wb_bru_is_breg),
       .wb_bru_in_slot_1                (wb_bru_in_slot_1),
       // Inputs
       .bru_AVALID                      (bru_AVALID),
       .bru_pc                          (bru_pc[`NCPU_AW-3:0]),
       .bru_opc_bus                     (bru_opc_bus[`NCPU_BRU_IOPW-1:0]),
       .bru_operand1                    (bru_operand1[`NCPU_DW-1:0]),
       .bru_operand2                    (bru_operand2[`NCPU_DW-1:0]),
       .bru_rel15                       (bru_rel15[14:0]),
       .bru_in_slot_1                   (bru_in_slot_1));

   ncpu32k_lpu
      #(
         .CONFIG_ENABLE_MUL            (CONFIG_ENABLE_MUL),
         .CONFIG_ENABLE_DIV            (CONFIG_ENABLE_DIV),
         .CONFIG_ENABLE_DIVU           (CONFIG_ENABLE_DIVU),
         .CONFIG_ENABLE_MOD            (CONFIG_ENABLE_MOD),
         .CONFIG_ENABLE_MODU           (CONFIG_ENABLE_MODU)
      )
   LPU
      (/*AUTOINST*/
       // Outputs
       .lpu_stall                       (lpu_stall),
       .wb_lpu_AVALID                   (wb_lpu_AVALID),
       .wb_lpu_dout                     (wb_lpu_dout[`NCPU_DW-1:0]),
       .wb_lpu_in_slot_1                (wb_lpu_in_slot_1),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .lpu_AVALID                      (lpu_AVALID),
       .lpu_opc_bus                     (lpu_opc_bus[`NCPU_LPU_IOPW-1:0]),
       .lpu_operand1                    (lpu_operand1[`NCPU_DW-1:0]),
       .lpu_operand2                    (lpu_operand2[`NCPU_DW-1:0]),
       .lpu_in_slot_1                   (lpu_in_slot_1));

   ncpu32k_epu
      #(
         .CONFIG_EITM_VECTOR           (CONFIG_EITM_VECTOR),
         .CONFIG_EIPF_VECTOR           (CONFIG_EIPF_VECTOR),
         .CONFIG_ESYSCALL_VECTOR       (CONFIG_ESYSCALL_VECTOR),
         .CONFIG_EINSN_VECTOR          (CONFIG_EINSN_VECTOR),
         .CONFIG_EIRQ_VECTOR           (CONFIG_EIRQ_VECTOR)
      )
   EPU
      (/*AUTOINST*/
       // Outputs
       .wb_epu_AVALID                   (wb_epu_AVALID),
       .wb_epu_dout                     (wb_epu_dout[`NCPU_DW-1:0]),
       .wb_epu_in_slot_1                (wb_epu_in_slot_1),
       .wb_epu_exc                      (wb_epu_exc),
       .wb_epu_exc_vec                  (wb_epu_exc_vec[`NCPU_AW-3:0]),
       .wb_wmsr_dat                     (wb_wmsr_dat[`NCPU_DW-1:0]),
       .wb_wmsr_we                      (wb_wmsr_we[`NCPU_WMSR_WE_DW-1:0]),
       .wb_ERET                         (wb_ERET),
       .wb_ESYSCALL                     (wb_ESYSCALL),
       .wb_EINSN                        (wb_EINSN),
       .wb_EIPF                         (wb_EIPF),
       .wb_EITM                         (wb_EITM),
       .wb_EIRQ                         (wb_EIRQ),
       .wb_E_FLUSH_TLB                  (wb_E_FLUSH_TLB),
       .wb_epu_pc                       (wb_epu_pc[`NCPU_AW-3:0]),
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
       .msr_icinv_nxt                   (msr_icinv_nxt[`NCPU_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[`NCPU_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[`NCPU_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we),
       .msr_irqc_imr_nxt                (msr_irqc_imr_nxt[`NCPU_DW-1:0]),
       .msr_irqc_imr_we                 (msr_irqc_imr_we),
       .msr_tsc_tsr_nxt                 (msr_tsc_tsr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tsr_we                  (msr_tsc_tsr_we),
       .msr_tsc_tcr_nxt                 (msr_tsc_tcr_nxt[`NCPU_DW-1:0]),
       .msr_tsc_tcr_we                  (msr_tsc_tcr_we),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .epu_AVALID                      (epu_AVALID),
       .epu_pc                          (epu_pc[`NCPU_AW-3:0]),
       .epu_opc_bus                     (epu_opc_bus[`NCPU_EPU_IOPW-1:0]),
       .epu_operand1                    (epu_operand1[`NCPU_DW-1:0]),
       .epu_operand2                    (epu_operand2[`NCPU_DW-1:0]),
       .epu_imm32                       (epu_imm32[`NCPU_DW-1:0]),
       .epu_in_slot_1                   (epu_in_slot_1),
       .commit_pc                       (commit_pc[`NCPU_AW-3:0]),
       .commit_EDTM                     (commit_EDTM),
       .commit_EDPF                     (commit_EDPF),
       .commit_EALIGN                   (commit_EALIGN),
       .commit_LSA                      (commit_LSA[`NCPU_AW-1:0]),
       .commit_ERET                     (commit_ERET),
       .commit_ESYSCALL                 (commit_ESYSCALL),
       .commit_EINSN                    (commit_EINSN),
       .commit_EIPF                     (commit_EIPF),
       .commit_EITM                     (commit_EITM),
       .commit_EIRQ                     (commit_EIRQ),
       .commit_wmsr_we                  (commit_wmsr_we[`NCPU_WMSR_WE_DW-1:0]),
       .commit_wmsr_dat                 (commit_wmsr_dat[`NCPU_DW-1:0]),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epsr_nobyp                  (msr_epsr_nobyp[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_dmmid                       (msr_dmmid[`NCPU_DW-1:0]),
       .msr_icid                        (msr_icid[`NCPU_DW-1:0]),
       .msr_dcid                        (msr_dcid[`NCPU_DW-1:0]),
       .msr_irqc_imr                    (msr_irqc_imr[`NCPU_DW-1:0]),
       .msr_irqc_irr                    (msr_irqc_irr[`NCPU_DW-1:0]),
       .msr_tsc_tsr                     (msr_tsc_tsr[`NCPU_DW-1:0]),
       .msr_tsc_tcr                     (msr_tsc_tcr[`NCPU_DW-1:0]));

   // NOTE: signals named wb_lsu_* are located in 2rd stage.
   /* ncpu32k_lsu AUTO_TEMPLATE (
         .lsu_flush                    (fu_flush),
      )
   */
   ncpu32k_lsu
      #(
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
   LSU
      (/*AUTOINST*/
       // Outputs
       .lsu_stall                       (lsu_stall),
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
       .wb_lsu_AVALID                   (wb_lsu_AVALID),
       .wb_lsu_EDTM                     (wb_lsu_EDTM),
       .wb_lsu_EDPF                     (wb_lsu_EDPF),
       .wb_lsu_EALIGN                   (wb_lsu_EALIGN),
       .wb_lsu_dout                     (wb_lsu_dout[`NCPU_DW-1:0]),
       .wb_lsu_pc                       (wb_lsu_pc[`NCPU_AW-3:0]),
       .wb_lsu_in_slot_1                (wb_lsu_in_slot_1),
       .wb_lsu_LSA                      (wb_lsu_LSA[`NCPU_AW-1:0]),
       .msr_dmmid                       (msr_dmmid[`NCPU_DW-1:0]),
       .msr_dcid                        (msr_dcid[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .stall_bck                       (stall_bck),
       .stall_bck_nolsu                 (stall_bck_nolsu),
       .lsu_flush                       (fu_flush),              // Templated
       .lsu_AVALID                      (lsu_AVALID),
       .lsu_load                        (lsu_load),
       .lsu_store                       (lsu_store),
       .lsu_sign_ext                    (lsu_sign_ext),
       .lsu_barr                        (lsu_barr),
       .lsu_store_size                  (lsu_store_size[2:0]),
       .lsu_load_size                   (lsu_load_size[2:0]),
       .lsu_operand1                    (lsu_operand1[`NCPU_DW-1:0]),
       .lsu_operand2                    (lsu_operand2[`NCPU_DW-1:0]),
       .lsu_imm32                       (lsu_imm32[`NCPU_DW-1:0]),
       .lsu_pc                          (lsu_pc[`NCPU_AW-3:0]),
       .lsu_in_slot_1                   (lsu_in_slot_1),
       .dbus_ARWREADY                   (dbus_ARWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[CONFIG_DBUS_DW-1:0]),
       .uncached_dbus_AREADY            (uncached_dbus_AREADY),
       .uncached_dbus_BVALID            (uncached_dbus_BVALID),
       .uncached_dbus_BDATA             (uncached_dbus_BDATA[`NCPU_DW-1:0]),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[`NCPU_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[`NCPU_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we));
   
   // Assert (2105041412)
   assign s1_before_inv_slot_AVALID[1] = wb_alu_1_AVALID |
                              (wb_bru_AVALID & wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & wb_epu_in_slot_1) |
                              (lsu_AVALID_before_inv & lsu_in_slot_1);

   // Assert (2105041434)
   assign s1_before_inv_slot_AVALID[2] = alu_2_AVALID |
                              (wb_bru_AVALID & ~wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & ~wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & ~wb_epu_in_slot_1) |
                              (lsu_AVALID_before_inv & ~lsu_in_slot_1);

   // Describe which FUs could output the result in this stage here
   assign s1i_slot_BVALID[1] = wb_alu_1_AVALID |
                              (wb_bru_AVALID & wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & wb_epu_in_slot_1);
   assign s1i_slot_BVALID[2] = wb_alu_2_AVALID |
                              (wb_bru_AVALID & ~wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & ~wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & ~wb_epu_in_slot_1);

   // Result MUX for the 1st slot
   assign s1i_slot_dout[1] = 
      (wb_alu_1_dout & {`NCPU_DW{wb_alu_1_AVALID}}) |
      (wb_bru_dout & {`NCPU_DW{wb_bru_AVALID & wb_bru_in_slot_1}}) |
      (wb_lpu_dout & {`NCPU_DW{wb_lpu_AVALID & wb_lpu_in_slot_1}}) |
      (wb_epu_dout & {`NCPU_DW{wb_epu_AVALID & wb_epu_in_slot_1}});

   // Result MUX for the 2rd slot
   assign s1i_slot_dout[2] =
      (wb_alu_2_dout & {`NCPU_DW{wb_alu_2_AVALID}}) |
      (wb_bru_dout & {`NCPU_DW{wb_bru_AVALID & ~wb_bru_in_slot_1}}) |
      (wb_lpu_dout & {`NCPU_DW{wb_lpu_AVALID & ~wb_lpu_in_slot_1}}) |
      (wb_epu_dout & {`NCPU_DW{wb_epu_AVALID & ~wb_epu_in_slot_1}});
   
   assign s1i_slot_pc_nxt_act[1] =
      (wb_bru_AVALID & wb_bru_in_slot_1 & wb_bru_branch_taken)
         ? wb_bru_branch_tgt
         : slot_1_pc_4;

   assign s1i_slot_pc_nxt_act[2] =
      (wb_bru_AVALID & ~wb_bru_in_slot_1 & wb_bru_branch_taken)
         ? wb_bru_branch_tgt
         : slot_2_pc_4;

   //
   // Speculative execution check point
   //
   always @(*)
      begin
         s1i_inv_slot[1] = 1'b0;
         s1i_inv_slot[2] = 1'b0;
         s1_se_flush = 1'b0;
         s1_se_flush_tgt = 'b0;

         // Do not check speculative execution while stalling.
         //
         // The stalling is asserted by the previous insn related to PC of backend,
         // which means that the previous insn is not completed. Thus, insn in backend
         // may not get its correct operand(s) and produce wrong result while stalling.
         // We should wait until the previous insn is completed, i.e., `stall_bck` is asserted high.
         //
         if (~stall_bck)
            begin // [1]
               if (s1_before_inv_slot_AVALID[1])
                  begin
                     if (s1i_slot_pc_nxt_act[1] == slot_2_pc)
                        begin
                           if (s1_before_inv_slot_AVALID[2] & (s1i_slot_pc_nxt_act[2] != slot_bpu_pc_nxt))
                              begin
                                 s1i_inv_slot[1] = 1'b0;
                                 s1i_inv_slot[2] = 1'b0;
                                 s1_se_flush = 1'b1; // The predication is wrong
                                 s1_se_flush_tgt = s1i_slot_pc_nxt_act[2];
                              end
                        end
                     else
                        begin
                           if (s1i_slot_pc_nxt_act[1] == slot_bpu_pc_nxt)
                              begin
                                 s1i_inv_slot[1] = 1'b0;
                                 s1i_inv_slot[2] = 1'b1; // slot #2 is in wrong path
                                 s1_se_flush = 1'b0; // The predication is right, do not flush.
                              end
                           else
                              begin
                                 s1i_inv_slot[1] = 1'b0;
                                 s1i_inv_slot[2] = 1'b1;
                                 s1_se_flush = 1'b1; // The predication is wrong
                                 s1_se_flush_tgt = s1i_slot_pc_nxt_act[1];
                              end
                        end
                  end

               // Slot 1 is prior to the slot 2
               if (s1_before_inv_slot_AVALID[2] & ~s1i_inv_slot[2] & ~s1_se_flush)
                  begin
                     s1i_inv_slot[2] = 1'b0;
                     s1_se_flush = (s1i_slot_pc_nxt_act[2] != slot_bpu_pc_nxt);
                     s1_se_flush_tgt = s1i_slot_pc_nxt_act[2];
                  end

            end //[1]
      end

   // To schedule
   // Invalidate the 2rd insn when single issue
   assign slot_2_inv = s1i_inv_slot[2];

   assign wb_lsu_rd_we_nxt = lsu_in_slot_1 ? slot_1_rd_we : slot_2_rd_we;
   assign wb_lsu_rd_addr_nxt = lsu_in_slot_1 ? slot_1_rd_addr : slot_2_rd_addr;

   //
   // *** Bypass path: ALU1->ALU2 ***
   // Assert (2105051653)
   //
   assign s1i_alu_2_operand1 = alu_2_operand1_frm_alu_1 ? wb_alu_1_dout : alu_2_operand1;
   assign s1i_alu_2_operand2 = alu_2_operand2_frm_alu_1 ? wb_alu_1_dout : alu_2_operand2;

   //
   // *** Bypass path: ALU1->BRU ***
   // Assert (2105051653)
   //
   assign bru_operand1 = bru_operand1_frm_alu_1 ? wb_alu_1_dout : bru_operand1_nobyp;
   assign bru_operand2 = bru_operand2_frm_alu_1 ? wb_alu_1_dout : bru_operand2_nobyp;

   //
   // *** Bypass path: ALU1->LSU ***
   // Assert (2105051655)
   //
   assign lsu_operand1 = lsu_operand1_frm_alu_1 ? wb_alu_1_dout : lsu_operand1_nobyp;
   assign lsu_operand2 = lsu_operand2_frm_alu_1 ? wb_alu_1_dout : lsu_operand2_nobyp;

   // Invalidate the output or opcodes of the corresponding slot(s)
   assign s1i_slot_BVALID_nxt[1] = (s1i_slot_BVALID[1] & ~s1i_inv_slot[1]);
   assign s1i_slot_BVALID_nxt[2] = (s1i_slot_BVALID[2] & ~s1i_inv_slot[2]);
   assign wb_epu_AVALID_nxt = (wb_epu_AVALID & ~(wb_epu_in_slot_1 ? s1i_inv_slot[1] : s1i_inv_slot[2]));

   // Write back BPU (only for BCC and JMPREG insns)
   assign bpu_wb_nxt = (wb_bru_AVALID &
                        // Check if this branch insn is not invalidated
                        (~wb_bru_in_slot_1|~s1i_inv_slot[1]) & (wb_bru_in_slot_1|~s1i_inv_slot[2]) &
                        // JMP REL is handled by pre decoder, do not affect BPU
                        ~bru_opc_bus[`NCPU_BRU_JMPREL]);

   assign s1_pipe_cke = ~stall_bck;


   // We have two sources of flushing: `s1_se_flush` and `s2_flush`.
   // If `s1_se_flush` is asserted high, all the flushing caused by SE is handled properly by `s1i_inv_slot`.
   // However, at this point all the exceptions are not handled. We should pass s1 to s2 to handle exceptions
   // although `s1_se_flush` is high. Thus `s1_se_flush` shouldn't be appeared in `s1o_noflush`.
   // If `s2_flush` is asserted high, insns at s1 are in wrong path, flush them.
   assign s1o_noflush = ~s2_flush;

   // LSU outputs the result in the next stage.
   // If LSU insn is resolved to be invalidated, don't send any request to LSU.
   assign lsu_AVALID = lsu_AVALID_before_inv & ~(lsu_in_slot_1 ? s1i_inv_slot[1] : s1i_inv_slot[2]);

   generate
      for(i=1;i<=2;i=i+1)
         begin : gen_DFFs
            // Data path
            nDFF_l #(`NCPU_DW) dff_s1o_slot_dout
               (clk, s1_pipe_cke, s1i_slot_dout[i], s1o_slot_dout[i]);
            nDFF_l #(`NCPU_AW-2) dff_s1o_slot_pc_nxt_act
               (clk, s1_pipe_cke, s1i_slot_pc_nxt_act[i], s1o_slot_pc_nxt_act[i]);

            // Control path
            nDFF_lr #(1) dff_s1o_slot_BVALID
               (clk, rst_n, s1_pipe_cke, (s1o_noflush & s1i_slot_BVALID_nxt[i]), s1o_slot_BVALID[i]);
         end
   endgenerate

   // Control path
   nDFF_lr #(1) dff_s1o_wb_epu_AVALID
      (clk, rst_n, s1_pipe_cke, s1o_noflush & wb_epu_AVALID_nxt, s1o_wb_epu_AVALID);
   nDFF_lr #(`NCPU_WMSR_WE_DW) dff_commit_wmsr_we
      (clk, rst_n, s1_pipe_cke, {`NCPU_WMSR_WE_DW{s1o_noflush &  wb_epu_AVALID_nxt}} & wb_wmsr_we, commit_wmsr_we);
   nDFF_lr #(1) dff_commit_E_FLUSH_TLB_slot1
      (clk, rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_E_FLUSH_TLB & wb_epu_in_slot_1), commit_E_FLUSH_TLB_slot1);
   nDFF_lr #(1) dff_commit_ERET_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_ERET & wb_epu_in_slot_1), commit_ERET_slot1);
   nDFF_lr #(1) dff_commit_ESYSCALL_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_ESYSCALL & wb_epu_in_slot_1), commit_ESYSCALL_slot1);
   nDFF_lr #(1) dff_commit_EINSN_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EINSN & wb_epu_in_slot_1), commit_EINSN_slot1);
   nDFF_lr #(1) dff_commit_EIPF_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EIPF & wb_epu_in_slot_1), commit_EIPF_slot1);
   nDFF_lr #(1) dff_commit_EITM_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EITM & wb_epu_in_slot_1), commit_EITM_slot1);
   nDFF_lr #(1) dff_commit_EIRQ_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EIRQ & wb_epu_in_slot_1), commit_EIRQ_slot1);
   
   nDFF_lr #(1) dff_commit_E_FLUSH_TLB_slot2
      (clk, rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_E_FLUSH_TLB & ~wb_epu_in_slot_1), commit_E_FLUSH_TLB_slot2);
   nDFF_lr #(1) dff_commit_ERET_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_ERET & ~wb_epu_in_slot_1), commit_ERET_slot2);
   nDFF_lr #(1) dff_commit_ESYSCALL_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_ESYSCALL & ~wb_epu_in_slot_1), commit_ESYSCALL_slot2);
   nDFF_lr #(1) dff_commit_EINSN_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EINSN & ~wb_epu_in_slot_1), commit_EINSN_slot2);
   nDFF_lr #(1) dff_commit_EIPF_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EIPF & ~wb_epu_in_slot_1), commit_EIPF_slot2);
   nDFF_lr #(1) dff_commit_EITM_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EITM & ~wb_epu_in_slot_1), commit_EITM_slot2);
   nDFF_lr #(1) dff_commit_EIRQ_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID_nxt & wb_EIRQ & ~wb_epu_in_slot_1), commit_EIRQ_slot2);
   
   nDFF_lr #(1) dff_bpu_wb
      (clk, rst_n, s1_pipe_cke, (s1o_noflush & bpu_wb_nxt), bpu_wb);
   
   // Data path
   nDFF_l #(1) dff_s1o_slot_rd_we_1
      (clk, s1_pipe_cke, slot_1_rd_we, s1o_slot_rd_we[1]);
   nDFF_l #(1) dff_s1o_slot_rd_we_2
      (clk, s1_pipe_cke, slot_2_rd_we, s1o_slot_rd_we[2]);

   nDFF_l #(`NCPU_REG_AW) dff_s1o_slot_rd_addr_1
      (clk, s1_pipe_cke, slot_1_rd_addr, s1o_slot_rd_addr[1]);
   nDFF_l #(`NCPU_REG_AW) dff_s1o_slot_rd_addr_2
      (clk, s1_pipe_cke, slot_2_rd_addr, s1o_slot_rd_addr[2]);

   nDFF_l #(1) dff_wb_lsu_rd_we
      (clk, s1_pipe_cke, wb_lsu_rd_we_nxt, wb_lsu_rd_we);
   nDFF_l #(`NCPU_REG_AW) dff_wb_lsu_rd_addr
      (clk, s1_pipe_cke, wb_lsu_rd_addr_nxt, wb_lsu_rd_addr);

`ifdef NCPU_ENABLE_TRACER
   nDFF_l #(1) dff_trace_wb_lsu_load
      (clk, s1_pipe_cke, lsu_load, trace_wb_lsu_load);
   nDFF_l #(1) dff_trace_wb_lsu_store
      (clk, s1_pipe_cke, lsu_store, trace_wb_lsu_store);
   nDFF_l #(3) dff_trace_wb_lsu_size
      (clk, s1_pipe_cke, lsu_load ? lsu_load_size : lsu_store_size, trace_wb_lsu_size);
`endif

   nDFF_l #(1) dff_s1o_wb_epu_exc
      (clk, s1_pipe_cke, wb_epu_exc, s1o_wb_epu_exc);
   nDFF_l #(`NCPU_AW-2) dff_s1o_wb_epu_exc_vec
      (clk, s1_pipe_cke, wb_epu_exc_vec, s1o_wb_epu_exc_vec);

   nDFF_l #(`NCPU_DW) dff_commit_wmsr_dat
      (clk, s1_pipe_cke, wb_wmsr_dat, commit_wmsr_dat);
      
   nDFF_l #(1) dff_wb_epu_in_slot_1
      (clk, s1_pipe_cke, wb_epu_in_slot_1, s1o_wb_epu_in_slot_1);

   nDFF_l #(`NCPU_AW-2) dff_commit_pc
      (clk, s1_pipe_cke, wb_epu_pc, s1o_wb_epu_pc);
   nDFF_l #(`NCPU_AW-2) dff_commit_pc_4
      (clk, s1_pipe_cke, wb_epu_pc + 'b1, s1o_wb_epu_pc_4);

`ifdef NCPU_ENABLE_TRACER
   nDFF_l #(`NCPU_AW-2) dff_s1o_slot_pc_1
      (clk, s1_pipe_cke, slot_1_pc, trace_s1o_slot_pc[1]);
   nDFF_l #(`NCPU_AW-2) dff_s1o_slot_pc_2
      (clk, s1_pipe_cke, slot_2_pc, trace_s1o_slot_pc[2]);
`endif

   nDFF_l #(1) dff_bpu_wb_is_bcc
      (clk ,s1_pipe_cke, wb_bru_is_bcc, bpu_wb_is_bcc);
   nDFF_l #(1) dff_bpu_wb_is_breg
      (clk, s1_pipe_cke, wb_bru_is_breg, bpu_wb_is_breg);
   nDFF_l #(1) dff_bpu_wb_taken
      (clk, s1_pipe_cke, wb_bru_branch_taken, bpu_wb_taken);
   nDFF_l #(`NCPU_AW-2) dff_bpu_wb_pc
      (clk, s1_pipe_cke, (wb_bru_in_slot_1 ? slot_1_pc : slot_2_pc), bpu_wb_pc);
   nDFF_l #(`NCPU_AW-2) dff_bpu_wb_pc_nxt_act
      (clk, s1_pipe_cke, wb_bru_branch_tgt, bpu_wb_pc_nxt_act);
   nDFF_l #(BPU_UPD_DW) dff_bpu_wb_upd
      (clk, s1_pipe_cke, (wb_bru_in_slot_1 ? slot_1_bpu_upd : slot_2_bpu_upd), bpu_wb_upd);


   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3 (of backend)
   /////////////////////////////////////////////////////////////////////////////

   assign commit_EDTM_slot1 = (wb_lsu_AVALID & wb_lsu_EDTM & wb_lsu_in_slot_1);
   assign commit_EDPF_slot1 = (wb_lsu_AVALID & wb_lsu_EDPF & wb_lsu_in_slot_1);
   assign commit_EALIGN_slot1 = (wb_lsu_AVALID & wb_lsu_EALIGN & wb_lsu_in_slot_1);

   assign commit_EDTM_slot2 = (wb_lsu_AVALID & wb_lsu_EDTM & ~wb_lsu_in_slot_1);
   assign commit_EDPF_slot2 = (wb_lsu_AVALID & wb_lsu_EDPF & ~wb_lsu_in_slot_1);
   assign commit_EALIGN_slot2 = (wb_lsu_AVALID & wb_lsu_EALIGN & ~wb_lsu_in_slot_1);

   assign commit_exc_slot1 = (commit_EALIGN_slot1|commit_EDPF_slot1|commit_EDTM_slot1|
                              commit_EINSN_slot1|
                              commit_EIPF_slot1|
                              commit_EIRQ_slot1|
                              commit_EITM_slot1|
                              commit_ERET_slot1|
                              commit_ESYSCALL_slot1|
                              commit_E_FLUSH_TLB_slot1);

   // Exception are generated both by EPU or LSU
   // If slot 1 occurs an exception, then any exception in slot 2 is ignored,
   // because insn in slot 2 will be flushed out.
   assign commit_EALIGN = commit_EALIGN_slot1 | (~commit_exc_slot1 & commit_EALIGN_slot2);
   assign commit_EDPF = commit_EDPF_slot1 | (~commit_exc_slot1 & commit_EDPF_slot2);
   assign commit_EDTM = commit_EDTM_slot1 | (~commit_exc_slot1 & commit_EDTM_slot2);
   assign commit_EINSN = commit_EINSN_slot1 | (~commit_exc_slot1 & commit_EINSN_slot2);
   assign commit_EIPF = commit_EIPF_slot1 | (~commit_exc_slot1 & commit_EIPF_slot2);
   assign commit_EIRQ = commit_EIRQ_slot1 | (~commit_exc_slot1 & commit_EIRQ_slot2);
   assign commit_EITM = commit_EITM_slot1 | (~commit_exc_slot1 & commit_EITM_slot2);
   assign commit_ERET = commit_ERET_slot1 | (~commit_exc_slot1 & commit_ERET_slot2);
   assign commit_ESYSCALL = commit_ESYSCALL_slot1 | (~commit_exc_slot1 & commit_ESYSCALL_slot2);
   assign commit_E_FLUSH_TLB = commit_E_FLUSH_TLB_slot1 | (~commit_exc_slot1 & commit_E_FLUSH_TLB_slot2);

   // If it is an LSU exception, set EPC as the address of LS insn.
   assign commit_pc = (commit_EDTM | commit_EDPF | commit_EALIGN) ? wb_lsu_pc : s1o_wb_epu_pc;
   assign commit_LSA = wb_lsu_LSA;

   // 1. Don't writeback LSU insns if exception raised.
   // 2. Writeback EPU insn although exception raised.
   assign s2_inv_slot_1 = (commit_EDTM_slot1 | commit_EDPF_slot1 | commit_EALIGN_slot1);
   assign s2_inv_slot_2 = s2_inv_slot_1 |
                           (s1o_wb_epu_AVALID & s1o_wb_epu_exc & s1o_wb_epu_in_slot_1) |
                           (commit_E_FLUSH_TLB_slot1) |
                           (commit_EDTM_slot2 | commit_EDPF_slot2 | commit_EALIGN_slot2);

   assign s2_flush = (commit_EDTM | commit_EDPF | commit_EALIGN | commit_E_FLUSH_TLB |
                        (s1o_wb_epu_AVALID & s1o_wb_epu_exc));

   // Exceptions of D-MMU are prior to others
   assign s2_flush_tgt = (commit_EDTM)
                           ? CONFIG_EDTM_VECTOR[2 +: `NCPU_AW-2]
                           : (commit_EDPF)
                              ? CONFIG_EDPF_VECTOR[2 +: `NCPU_AW-2]
                              : (commit_EALIGN)
                                 ? CONFIG_EALIGN_VECTOR[2 +: `NCPU_AW-2]
                                 : (commit_E_FLUSH_TLB)
                                    ? s1o_wb_epu_pc_4
                                    : s1o_wb_epu_exc_vec;

   // For 1-st stage of ALU/BRU/EPU/LPU, the scheme is invalidating BVALID instead of flushing
   // For LSU, the scheme is flushing
   assign fu_flush = s2_flush;

   // Assert (2105042339)
   assign s2o_slot_BVALID[1] = ~s2_inv_slot_1 &
                                 (s1o_slot_BVALID[1] |
                                  (wb_lsu_AVALID & wb_lsu_in_slot_1));

   // Assert (2105042347)
   assign s2o_slot_BVALID[2] = ~s2_inv_slot_2 &
                                 (s1o_slot_BVALID[2] |
                                  (wb_lsu_AVALID & ~wb_lsu_in_slot_1));

   assign s2o_slot_dout[1] = s1o_slot_BVALID[1] ? s1o_slot_dout[1] : wb_lsu_dout;

   assign s2o_slot_dout[2] = ({`NCPU_DW{s1o_slot_BVALID[2]}}   &  s1o_slot_dout[2]) |
                              ({`NCPU_DW{wb_lsu_AVALID & ~wb_lsu_in_slot_1}}  & wb_lsu_dout);

   generate
      for(i=1;i<=2;i=i+1)
         begin : gen_slot_rd
            assign s2o_slot_rd_we[i] = s1o_slot_rd_we[i];
            assign s2o_slot_rd_addr[i] = s1o_slot_rd_addr[i];
         end
   endgenerate

   assign arf_1_we = (s2o_slot_BVALID[1] & s2o_slot_rd_we[1]);
   assign arf_2_we = (s2o_slot_BVALID[2] & s2o_slot_rd_we[2]);
   assign arf_1_waddr = s2o_slot_rd_addr[1];
   assign arf_2_waddr = s2o_slot_rd_addr[2];
   assign arf_1_wdat = s2o_slot_dout[1];
   assign arf_2_wdat = s2o_slot_dout[2];

`ifdef NCPU_ENABLE_TRACER
   ncpu32k_tracer
      #(
         .CONFIG_DBUS_AW               (CONFIG_DBUS_AW)
      )
   TRACER
      (
         .clk                          (clk),
         .stall_bck                    (stall_bck),
         .wb_slot_1_BVALID             (s2o_slot_BVALID[1]),
         .wb_slot_1_rd_we              (s2o_slot_rd_we[1]),
         .wb_slot_1_rd_addr            (s2o_slot_rd_addr[1]),
         .wb_slot_1_dout               (s2o_slot_dout[1]),
         .wb_slot_1_pc                 (trace_s1o_slot_pc[1]),
         .wb_slot_2_BVALID             (s2o_slot_BVALID[2]),
         .wb_slot_2_rd_we              (s2o_slot_rd_we[2]),
         .wb_slot_2_rd_addr            (s2o_slot_rd_addr[2]),
         .wb_slot_2_dout               (s2o_slot_dout[2]),
         .wb_slot_2_pc                 (trace_s1o_slot_pc[2])
      );
`endif

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3 (of backend)
   /////////////////////////////////////////////////////////////////////////////

   ncpu32k_regfile REGFILE
      (/*AUTOINST*/
       // Outputs
       .arf_1_rs1_dout                  (arf_1_rs1_dout[`NCPU_DW-1:0]),
       .arf_1_rs2_dout                  (arf_1_rs2_dout[`NCPU_DW-1:0]),
       .arf_2_rs1_dout                  (arf_2_rs1_dout[`NCPU_DW-1:0]),
       .arf_2_rs2_dout                  (arf_2_rs2_dout[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .arf_1_rs1_addr                  (arf_1_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_1_rs2_addr                  (arf_1_rs2_addr[`NCPU_REG_AW-1:0]),
       .arf_1_rs1_re                    (arf_1_rs1_re),
       .arf_1_rs2_re                    (arf_1_rs2_re),
       .arf_2_rs1_addr                  (arf_2_rs1_addr[`NCPU_REG_AW-1:0]),
       .arf_2_rs2_addr                  (arf_2_rs2_addr[`NCPU_REG_AW-1:0]),
       .arf_2_rs1_re                    (arf_2_rs1_re),
       .arf_2_rs2_re                    (arf_2_rs2_re),
       .arf_1_waddr                     (arf_1_waddr[`NCPU_REG_AW-1:0]),
       .arf_1_wdat                      (arf_1_wdat[`NCPU_DW-1:0]),
       .arf_1_we                        (arf_1_we),
       .arf_2_waddr                     (arf_2_waddr[`NCPU_REG_AW-1:0]),
       .arf_2_wdat                      (arf_2_wdat[`NCPU_DW-1:0]),
       .arf_2_we                        (arf_2_we));

   ncpu32k_psr
      #(
         .CPUID_VER                    (CPUID_VER),
         .CPUID_REV                    (CPUID_REV),
         .CPUID_FIMM                   (CPUID_FIMM),
         .CPUID_FDMM                   (CPUID_FDMM),
         .CPUID_FICA                   (CPUID_FICA),
         .CPUID_FDCA                   (CPUID_FDCA),
         .CPUID_FDBG                   (CPUID_FDBG),
         .CPUID_FFPU                   (CPUID_FFPU),
         .CPUID_FIRQC                  (CPUID_FIRQC),
         .CPUID_FTSC                   (CPUID_FTSC)
      )
   PSR
      (/*AUTOINST*/
       // Outputs
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epsr_nobyp                  (msr_epsr_nobyp[`NCPU_PSR_DW-1:0]),
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

   // Arbiter of flush
   assign flush = (s2_flush | s1_se_flush);
   // s2 is prior to s1
   assign flush_tgt = (s2_flush)
                        ? s2_flush_tgt
                        : s1_se_flush_tgt;

   // Stall
   assign stall_bck = (lsu_stall | stall_bck_nolsu);
   assign stall_bck_nolsu = (lpu_stall | icinv_stall);
   assign stall_fnt = (sch_stall | stall_bck);

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (count_1({commit_EALIGN_slot1,
                     commit_EDPF_slot1,
                     commit_EDTM_slot1,
                     commit_EINSN_slot1,
                     commit_EIPF_slot1,
                     commit_EIRQ_slot1,
                     commit_EITM_slot1,
                     commit_ERET_slot1,
                     commit_ESYSCALL_slot1,
                     commit_E_FLUSH_TLB_slot1}) > 1 )
         $fatal (1, "BUG ON: Exception sel of slot1");
      if (count_1({commit_EALIGN_slot2,
                     commit_EDPF_slot2,
                     commit_EDTM_slot2,
                     commit_EINSN_slot2,
                     commit_EIPF_slot2,
                     commit_EIRQ_slot2,
                     commit_EITM_slot2,
                     commit_ERET_slot2,
                     commit_ESYSCALL_slot2,
                     commit_E_FLUSH_TLB_slot2}) > 1 )
         $fatal (1, "BUG ON: Exception sel of slot2");
      // Assert 2105041412
      if (count_1({wb_alu_1_AVALID,
                     (wb_bru_AVALID & wb_bru_in_slot_1),
                     (wb_lpu_AVALID & wb_lpu_in_slot_1),
                     (wb_epu_AVALID & wb_epu_in_slot_1),
                     (lsu_AVALID & lsu_in_slot_1)}) > 1 )
         $fatal (1, "BUG ON: Multi selection of FUs in 1st slot");
      // Assert 2105041434
      if (count_1({wb_alu_2_AVALID,
                     (wb_bru_AVALID & ~wb_bru_in_slot_1),
                     (wb_lpu_AVALID & ~wb_lpu_in_slot_1),
                     (wb_epu_AVALID & ~wb_epu_in_slot_1),
                     (lsu_AVALID & ~lsu_in_slot_1)}) > 1 )
         $fatal (1, "BUG ON: Multi selection of FUs in 2rd slot");

      // Assert 2105042339
      if (count_1({s1o_slot_BVALID[1], (wb_lsu_AVALID & wb_lsu_in_slot_1)}) > 1)
         $fatal (1, "BUG ON: BVALID of 1st slot");
      // Assert 2105042347
      if (count_1({s1o_slot_BVALID[2], (wb_lsu_AVALID & ~wb_lsu_in_slot_1)}) > 1)
         $fatal (1, "BUG ON: BVALID of 2rd slot");

      // Assert 2105110002
      if (alu_2_AVALID & (alu_2_operand1_frm_alu_1|alu_2_operand2_frm_alu_1) & ~alu_1_AVALID)
         $fatal (1, "BUG ON: ALU1->ALU2 bypass control");

      // Assert 2105051653
      if (bru_AVALID & (bru_operand1_frm_alu_1|bru_operand2_frm_alu_1) & ~alu_1_AVALID)
         $fatal (1, "BUG ON: ALU1->BRU bypass control");

   end
`endif

`endif
   // synthesis translate_on

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "./fu"
// )
// End:
