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

module ncpu32k_epu
#(
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ESYSCALL_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EINSN_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIRQ_VECTOR
   `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   // From ISSUE
   input                      epu_AVALID,
   input [`NCPU_AW-3:0]       epu_pc,
   input [`NCPU_EPU_IOPW-1:0] epu_opc_bus,
   input [`NCPU_DW-1:0]       epu_operand1,
   input [`NCPU_DW-1:0]       epu_operand2,
   input [`NCPU_DW-1:0]       epu_imm32,
   input                      epu_in_slot_1,
   // From arbiter
   input [`NCPU_AW-3:0]       commit_pc,
   input                      commit_EDTM,
   input                      commit_EDPF,
   input                      commit_EALIGN,
   input [`NCPU_AW-1:0]       commit_LSA,
   input                      commit_ERET,
   input                      commit_ESYSCALL,
   input                      commit_EINSN,
   input                      commit_EIPF,
   input                      commit_EITM,
   input                      commit_EIRQ,
   input [`NCPU_WMSR_WE_DW-1:0] commit_wmsr_we,
   input [`NCPU_DW-1:0]       commit_wmsr_dat,

   // To WRITEBACK
   output                     wb_epu_AVALID,
   output [`NCPU_DW-1:0]      wb_epu_dout,
   output                     wb_epu_in_slot_1,
   output                     wb_epu_exc,
   output [`NCPU_AW-3:0]      wb_epu_exc_vec,
   output [`NCPU_DW-1:0]      wb_wmsr_dat,
   output [`NCPU_WMSR_WE_DW-1:0] wb_wmsr_we,
   output                     wb_ERET,
   output                     wb_ESYSCALL,
   output                     wb_EINSN,
   output                     wb_EIPF,
   output                     wb_EITM,
   output                     wb_EIRQ,
   output                     wb_E_FLUSH_TLB,
   output [`NCPU_AW-3:0]      wb_epu_pc,
   // PSR
   input [`NCPU_PSR_DW-1:0]   msr_psr,
   input [`NCPU_PSR_DW-1:0]   msr_psr_nold,
   output                     msr_psr_rm_nxt,
   output                     msr_psr_rm_we,
   output                     msr_psr_imme_nxt,
   output                     msr_psr_imme_we,
   output                     msr_psr_dmme_nxt,
   output                     msr_psr_dmme_we,
   output                     msr_psr_ire_nxt,
   output                     msr_psr_ire_we,
   output                     msr_exc_ent,
   // CPUID
   input [`NCPU_DW-1:0]       msr_cpuid,
   // EPC
   input [`NCPU_DW-1:0]       msr_epc,
   output [`NCPU_DW-1:0]      msr_epc_nxt,
   output                     msr_epc_we,
   // EPSR
   input [`NCPU_PSR_DW-1:0]   msr_epsr,
   output [`NCPU_PSR_DW-1:0]  msr_epsr_nxt,
   output                     msr_epsr_we,
   // ELSA
   input [`NCPU_DW-1:0]       msr_elsa,
   output [`NCPU_DW-1:0]      msr_elsa_nxt,
   output                     msr_elsa_we,
   // COREID
   input [`NCPU_DW-1:0]       msr_coreid,
   // IMMID
   input [`NCPU_DW-1:0]       msr_immid,
   // ITLBL
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbl_nxt,
   output                     msr_imm_tlbl_we,
   // ITLBH
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbh_nxt,
   output                     msr_imm_tlbh_we,
   // DMMID
   input [`NCPU_DW-1:0]       msr_dmmid,
   // DTLBL
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_dmm_tlbl_nxt,
   output                     msr_dmm_tlbl_we,
   // DTLBH
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_dmm_tlbh_nxt,
   output                     msr_dmm_tlbh_we,
   // IMR
   input [`NCPU_DW-1:0]       msr_irqc_imr,
   output [`NCPU_DW-1:0]      msr_irqc_imr_nxt,
   output                     msr_irqc_imr_we,
   // IRR
   input [`NCPU_DW-1:0]       msr_irqc_irr,
   // TSR
   input [`NCPU_DW-1:0]       msr_tsc_tsr,
   output [`NCPU_DW-1:0]      msr_tsc_tsr_nxt,
   output                     msr_tsc_tsr_we,
   // TCR
   input [`NCPU_DW-1:0]       msr_tsc_tcr,
   output [`NCPU_DW-1:0]      msr_tsc_tcr_nxt,
   output                     msr_tsc_tcr_we
);
   /*AUTOWIRE*/
   wire [`NCPU_DW-1:0]        msr_addr;
   wire [`NCPU_MSR_BANK_AW-1:0] bank_addr;
   wire [`NCPU_MSR_BANK_OFF_AW-1:0] bank_off;
   wire                       bank_ps;
   wire                       bank_imm;
   wire                       bank_dmm;
   wire                       bank_ica;
   wire                       bank_dca;
   wire                       bank_dbg;
   wire                       bank_irqc;
   wire                       bank_tsc;
   wire [`NCPU_DW-1:0]        dout_ps;
   wire                       msr_imm_tlbl_sel;
   wire                       msr_imm_tlbh_sel;
   wire [`NCPU_DW-1:0]        dout_imm;
   wire                       msr_dmm_tlbl_sel;
   wire                       msr_dmm_tlbh_sel;
   wire [`NCPU_DW-1:0]        dout_dmm;
   wire                       msr_irqc_imr_sel;
   wire                       msr_irqc_irr_sel;
   wire [`NCPU_DW-1:0]        dout_irqc;
   wire                       msr_tsc_tsr_sel;
   wire                       msr_tsc_tcr_sel;
   wire [`NCPU_DW-1:0]        dout_tsc;
   wire                       exc_commit;
   wire [`NCPU_AW-3:0]        linkaddr;
   wire                       set_elsa_as_pc;
   wire                       set_elsa;
   wire [`NCPU_DW-1:0]        lsa_nxt;
   wire                       epsr_rm;
   wire                       epsr_ire;
   wire                       epsr_imme;
   wire                       epsr_dmme;
   wire [9:0]                 epsr_res;
   wire                       wb_wmsr_psr_we;
   wire                       wb_wmsr_epc_we;
   wire                       wb_wmsr_epsr_we;
   wire                       wb_wmsr_elsa_we;
   wire                       wb_msr_imm_tlbl_we;
   wire                       wb_msr_imm_tlbh_we;
   wire                       wb_msr_dmm_tlbl_we;
   wire                       wb_msr_dmm_tlbh_we;
   wire                       wb_msr_irqc_imr_we;
   wire                       wb_msr_tsc_tsr_we;
   wire                       wb_msr_tsc_tcr_we;
   wire                       commit_wmsr_psr_we;
   wire                       commit_wmsr_epc_we;
   wire                       commit_wmsr_epsr_we;
   wire                       commit_wmsr_elsa_we;
   wire                       commit_msr_imm_tlbl_we;
   wire                       commit_msr_imm_tlbh_we;
   wire                       commit_msr_dmm_tlbl_we;
   wire                       commit_msr_dmm_tlbh_we;
   wire                       commit_msr_irqc_imr_we;
   wire                       commit_msr_tsc_tsr_we;
   wire                       commit_msr_tsc_tcr_we;
   wire [`NCPU_TLB_AW-1:0]    commit_bank_off;
   wire                       wmsr_psr_rm;
   wire                       wmsr_psr_ire;
   wire                       wmsr_psr_imme;
   wire                       wmsr_psr_dmme;
   wire [9:0]                 wmsr_psr_res;
   genvar i;

   assign msr_addr = epu_operand1 | {{`NCPU_DW-15{1'b0}}, epu_imm32[14:0]};
   assign bank_addr = msr_addr[`NCPU_MSR_BANK_AW+`NCPU_MSR_BANK_OFF_AW-1:`NCPU_MSR_BANK_OFF_AW];
   assign bank_off = msr_addr[`NCPU_MSR_BANK_OFF_AW-1:0];

   // Readout PS
   assign dout_ps =
      (
         ({`NCPU_DW{bank_off[`NCPU_MSR_PSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_psr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_CPUID]}} & msr_cpuid) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_epsr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPC]}} & msr_epc) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_ELSA]}} & msr_elsa) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_COREID]}} & msr_coreid)
      );

   // Readout IMM
   assign msr_imm_tlbl_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & ~bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign msr_imm_tlbh_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign dout_imm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_IMM_TLBSEL]}} & msr_immid)
      );

   // Readout DMM
   assign msr_dmm_tlbl_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & ~bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign msr_dmm_tlbh_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign dout_dmm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_DMM_TLBSEL]}} & msr_dmmid)
      );

   // Readout IRQC
   assign msr_irqc_imr_sel = bank_off[`NCPU_MSR_IRQC_IMR];
   assign msr_irqc_irr_sel = bank_off[`NCPU_MSR_IRQC_IRR];
   assign dout_irqc =
      (
         ({`NCPU_DW{msr_irqc_imr_sel}} & msr_irqc_imr) |
         ({`NCPU_DW{msr_irqc_irr_sel}} & msr_irqc_irr)
      );

   // Readout TSC
   assign msr_tsc_tsr_sel = bank_off[`NCPU_MSR_TSC_TSR];
   assign msr_tsc_tcr_sel = bank_off[`NCPU_MSR_TSC_TCR];
   assign dout_tsc =
      (
         ({`NCPU_DW{msr_tsc_tsr_sel}} & msr_tsc_tsr) |
         ({`NCPU_DW{msr_tsc_tcr_sel}} & msr_tsc_tcr)
      );

   // Decode MSR bank_addr
   assign bank_ps = (bank_addr == `NCPU_MSR_BANK_PS);
   assign bank_imm = (bank_addr == `NCPU_MSR_BANK_IMM);
   assign bank_dmm = (bank_addr == `NCPU_MSR_BANK_DMM);
   assign bank_ica = (bank_addr == `NCPU_MSR_BANK_ICA);
   assign bank_dca = (bank_addr == `NCPU_MSR_BANK_DCA);
   assign bank_dbg = (bank_addr == `NCPU_MSR_BANK_DBG);
   assign bank_irqc = (bank_addr == `NCPU_MSR_BANK_IRQC);
   assign bank_tsc = (bank_addr == `NCPU_MSR_BANK_TSC);

   assign wb_epu_AVALID = epu_AVALID;

   // Result MUX
   assign wb_epu_dout =
      (
         ({`NCPU_DW{bank_ps}} & dout_ps) |
         ({`NCPU_DW{bank_imm}} & dout_imm) |
         ({`NCPU_DW{bank_dmm}} & dout_dmm) |
         ({`NCPU_DW{bank_irqc}} & dout_irqc) |
         ({`NCPU_DW{bank_tsc}} & dout_tsc)
      );

   assign wb_epu_exc = (epu_opc_bus[`NCPU_EPU_ESYSCALL] |
                        epu_opc_bus[`NCPU_EPU_ERET] |
                        epu_opc_bus[`NCPU_EPU_EITM] |
                        epu_opc_bus[`NCPU_EPU_EIPF] |
                        epu_opc_bus[`NCPU_EPU_EIRQ] |
                        epu_opc_bus[`NCPU_EPU_EINSN]);

   assign wb_ERET = epu_opc_bus[`NCPU_EPU_ERET];
   assign wb_ESYSCALL = epu_opc_bus[`NCPU_EPU_ESYSCALL];
   assign wb_EINSN = epu_opc_bus[`NCPU_EPU_EINSN];
   assign wb_EIPF = epu_opc_bus[`NCPU_EPU_EIPF];
   assign wb_EITM = epu_opc_bus[`NCPU_EPU_EITM];
   assign wb_EIRQ = epu_opc_bus[`NCPU_EPU_EIRQ];
   assign wb_E_FLUSH_TLB = (wb_wmsr_psr_we |
                              wb_msr_imm_tlbl_we |
                              wb_msr_imm_tlbh_we |
                              wb_msr_dmm_tlbl_we |
                              wb_msr_dmm_tlbh_we);

   assign wb_epu_pc = epu_pc;

   // Assert 2105051856
   assign wb_epu_exc_vec = ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_ESYSCALL]}} & CONFIG_ESYSCALL_VECTOR[2 +: `NCPU_AW-2]) |
                           ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_ERET]}} & msr_epc[2 +: `NCPU_AW-2]) |
                           ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_EITM]}} & CONFIG_EITM_VECTOR[2 +: `NCPU_AW-2]) |
                           ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_EIPF]}} & CONFIG_EIPF_VECTOR[2 +: `NCPU_AW-2]) |
                           ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_EIRQ]}} & CONFIG_EIRQ_VECTOR[2 +: `NCPU_AW-2]) |
                           ({`NCPU_AW-2{epu_opc_bus[`NCPU_EPU_EINSN]}} & CONFIG_EINSN_VECTOR[2 +: `NCPU_AW-2]);

   assign wb_epu_in_slot_1 = epu_in_slot_1;

   ////////////////////////////////////////////////////////////////////////////////

   // Decode MSR address
   assign wb_wmsr_dat = epu_operand2;

   assign wb_wmsr_psr_we      = epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_PSR];
   assign wb_wmsr_epc_we      = epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPC];
   assign wb_wmsr_epsr_we     = epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPSR];
   assign wb_wmsr_elsa_we     = epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_ELSA];
   assign wb_msr_imm_tlbl_we  = epu_opc_bus[`NCPU_EPU_WMSR] & bank_imm & msr_imm_tlbl_sel;
   assign wb_msr_imm_tlbh_we  = epu_opc_bus[`NCPU_EPU_WMSR] & bank_imm & msr_imm_tlbh_sel;
   assign wb_msr_dmm_tlbl_we  = epu_opc_bus[`NCPU_EPU_WMSR] & bank_dmm & msr_dmm_tlbl_sel;
   assign wb_msr_dmm_tlbh_we  = epu_opc_bus[`NCPU_EPU_WMSR] & bank_dmm & msr_dmm_tlbh_sel;
   assign wb_msr_irqc_imr_we  = epu_opc_bus[`NCPU_EPU_WMSR] & bank_irqc & msr_irqc_imr_sel;
   assign wb_msr_tsc_tsr_we   = epu_opc_bus[`NCPU_EPU_WMSR] & bank_tsc & msr_tsc_tsr_sel;
   assign wb_msr_tsc_tcr_we   = epu_opc_bus[`NCPU_EPU_WMSR] & bank_tsc & msr_tsc_tcr_sel;

   assign wb_wmsr_we = {wb_wmsr_psr_we,
                        wb_wmsr_epc_we,
                        wb_wmsr_epsr_we,
                        wb_wmsr_elsa_we,
                        wb_msr_imm_tlbl_we,
                        wb_msr_imm_tlbh_we,
                        wb_msr_dmm_tlbl_we,
                        wb_msr_dmm_tlbh_we,
                        wb_msr_irqc_imr_we,
                        wb_msr_tsc_tsr_we,
                        wb_msr_tsc_tcr_we,
                        bank_off[`NCPU_TLB_AW-1:0]};

   // Unpack commit wmsr we
   assign {
      commit_wmsr_psr_we,
      commit_wmsr_epc_we,
      commit_wmsr_epsr_we,
      commit_wmsr_elsa_we,
      commit_msr_imm_tlbl_we,
      commit_msr_imm_tlbh_we,
      commit_msr_dmm_tlbl_we,
      commit_msr_dmm_tlbh_we,
      commit_msr_irqc_imr_we,
      commit_msr_tsc_tsr_we,
      commit_msr_tsc_tcr_we,
      commit_bank_off} = commit_wmsr_we;

   // Unpack EPSR. Be consistend with ncpu32k_psr
   assign {epsr_res[9],epsr_res[8],epsr_dmme,epsr_imme,epsr_ire,epsr_rm,epsr_res[3],epsr_res[2], epsr_res[1],epsr_res[0]} = msr_epsr;

   // Unpack WMSR PSR. Be consistend with ncpu32k_psr
   assign {wmsr_psr_res[9],wmsr_psr_res[8],wmsr_psr_dmme,wmsr_psr_imme,wmsr_psr_ire,wmsr_psr_rm,wmsr_psr_res[3],wmsr_psr_res[2], wmsr_psr_res[1],wmsr_psr_res[0]} = commit_wmsr_dat[9:0];

   // For the convenience of maintaining EPC, SYSCALL and the other exceptions are treated differently from RET and WMSR.
   assign exc_commit = (commit_ESYSCALL | commit_ERET |
                              commit_EITM | commit_EIPF |
                              commit_EINSN |
                              commit_EDTM | commit_EDPF | commit_EALIGN |
                              commit_EIRQ);

   assign msr_exc_ent = (exc_commit & ~commit_ERET);
   // Commit PSR. Assert (03060934)
   assign msr_psr_rm_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_rm_nxt = commit_wmsr_psr_we ? wmsr_psr_rm : epsr_rm;
   assign msr_psr_imme_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_imme_nxt = commit_wmsr_psr_we ? wmsr_psr_imme : epsr_imme;
   assign msr_psr_dmme_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_dmme_nxt = commit_wmsr_psr_we ? wmsr_psr_dmme : epsr_dmme;
   assign msr_psr_ire_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_ire_nxt = commit_wmsr_psr_we ? wmsr_psr_ire : epsr_ire;
   
   // Commit EPSR
   assign msr_epsr_we = (commit_wmsr_epsr_we | msr_exc_ent);
   assign msr_epsr_nxt = commit_wmsr_epsr_we ? commit_wmsr_dat[`NCPU_PSR_DW-1:0] : msr_psr_nold;
   // In syscall, EPC is a pointer to the next insn to syscall, while in general EPC points to the insn
   // that raised the exception.
   assign linkaddr = commit_pc + 1'b1;
   assign msr_epc_nxt = commit_wmsr_epc_we ? commit_wmsr_dat :
                        commit_ESYSCALL ? {linkaddr[`NCPU_AW-3:0],2'b0} : {commit_pc[`NCPU_AW-3:0],2'b0};
   assign msr_epc_we = msr_exc_ent | commit_wmsr_epc_we;

   // Commit ELSA  Assert (03100705)
   assign set_elsa_as_pc = (commit_EITM | commit_EIPF | commit_EINSN);
   assign set_elsa = (set_elsa_as_pc | commit_EDTM | commit_EDPF | commit_EALIGN);
   // Let ELSA be PC if it's IMMU or EINSN exception
   assign lsa_nxt = set_elsa_as_pc ? {commit_pc[`NCPU_AW-3:0],2'b0} : commit_LSA;
   // Assert (03060933)
   assign msr_elsa_nxt = set_elsa ? lsa_nxt : commit_wmsr_dat;
   assign msr_elsa_we = set_elsa | commit_wmsr_elsa_we;

   // Commit IMM
   assign msr_imm_tlbl_idx = commit_bank_off;
   assign msr_imm_tlbl_nxt = commit_wmsr_dat;
   assign msr_imm_tlbl_we = commit_msr_imm_tlbl_we;

   assign msr_imm_tlbh_idx = commit_bank_off;
   assign msr_imm_tlbh_nxt = commit_wmsr_dat;
   assign msr_imm_tlbh_we = commit_msr_imm_tlbh_we;

   // Commit DMM
   assign msr_dmm_tlbl_idx = commit_bank_off;
   assign msr_dmm_tlbl_nxt = commit_wmsr_dat;
   assign msr_dmm_tlbl_we = commit_msr_dmm_tlbl_we;

   assign msr_dmm_tlbh_idx = commit_bank_off;
   assign msr_dmm_tlbh_nxt = commit_wmsr_dat;
   assign msr_dmm_tlbh_we = commit_msr_dmm_tlbh_we;

   // Commit IRQC
   assign msr_irqc_imr_we = commit_msr_irqc_imr_we;
   assign msr_irqc_imr_nxt = commit_wmsr_dat;

   // Commit TSC
   assign msr_tsc_tsr_we = commit_msr_tsc_tsr_we;
   assign msr_tsc_tsr_nxt = commit_wmsr_dat;
   assign msr_tsc_tcr_we = commit_msr_tsc_tcr_we;
   assign msr_tsc_tcr_nxt = commit_wmsr_dat;

	 // synthesis translate_off
`ifndef SYNTHESIS
   wire dbg_numport_sel = bank_off[0];
   wire dbg_msgport_sel = bank_off[1];
   always @(posedge clk) begin
      if (commit_wmsr_we & bank_dbg & dbg_numport_sel)
         $display("Num port = %d", commit_wmsr_dat);
      if (commit_wmsr_we & bank_dbg & dbg_msgport_sel)
         $write("%c", commit_wmsr_dat[7:0]);
   end
`endif
   // synthesis translate_on

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertions 03060934
         if (count_1({commit_EITM, commit_EIPF,
                        commit_EINSN,
                        commit_ESYSCALL, commit_ERET,
                        commit_EDTM, commit_EDPF, commit_EALIGN,
                        commit_EIRQ,
                        commit_wmsr_psr_we})>1)
            $fatal (1, "\n Bugs on exception sources (IMMU, IDU, AGU and DMMU)\n");
         // Assertions 03060933
         if (commit_wmsr_elsa_we & set_elsa)
            $fatal (1, "\n Bugs on ELSA selection between wmsr and dbus\n");
         // Assertions 03100705
         if (set_elsa_as_pc & (commit_EDTM | commit_EDPF | commit_EALIGN))
            $fatal (1, "\n Bugs on exception unit\n");

         // Assertions 2105051856
         if (count_1({epu_opc_bus[`NCPU_EPU_ESYSCALL] |
                        epu_opc_bus[`NCPU_EPU_ERET] |
                        epu_opc_bus[`NCPU_EPU_EITM] |
                        epu_opc_bus[`NCPU_EPU_EIPF] |
                        epu_opc_bus[`NCPU_EPU_EIRQ] |
                        epu_opc_bus[`NCPU_EPU_EINSN]}) > 1)
            $fatal (1, "Bugs on EPU exceptions");
      end
`endif

`endif
   // synthesis translate_on


endmodule
