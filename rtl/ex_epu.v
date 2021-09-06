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

module ex_epu
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EITM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_ESYSCALL_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EINSN_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIRQ_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDTM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EALIGN_VECTOR = 0,
   parameter                           CONFIG_ITLB_P_SETS = 0,
   parameter                           CONFIG_DTLB_P_SETS = 0,
   parameter                           CONFIG_NUM_IRQ = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input [`PC_W-1:0]                   ex_pc,
   input [`PC_W-1:0]                   ex_npc,
   input                               ex_valid,
   input [`NCPU_EPU_IOPW-1:0]          ex_epu_opc_bus,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   input [CONFIG_DW-1:0]               ex_imm,
   // From COMMIT
   input [`PC_W-1:0]                   commit_epc,
   input [`PC_W-1:0]                   commit_nepc,
   input                               commit_EDTM,
   input                               commit_EDPF,
   input                               commit_EALIGN,
   input                               commit_E_FLUSH_TLB,
   input [CONFIG_AW-1:0]               commit_LSA,
   input                               commit_ERET,
   input                               commit_ESYSCALL,
   input                               commit_EINSN,
   input                               commit_EIPF,
   input                               commit_EITM,
   input                               commit_EIRQ,
   input [`NCPU_WMSR_WE_W-1:0]         commit_wmsr_we,
   input [CONFIG_DW-1:0]               commit_wmsr_dat,

   // To WRITEBACK
   output [CONFIG_DW-1:0]              epu_dout,
   output [CONFIG_DW-1:0]              epu_wmsr_dat,
   output [`NCPU_WMSR_WE_W-1:0]        epu_wmsr_we,
   output                              epu_ERET,
   output                              epu_ESYSCALL,
   output                              epu_EINSN,
   output                              epu_EIPF,
   output                              epu_EITM,
   output                              epu_EIRQ,
   output                              epu_E_FLUSH_TLB,

   // Flush
   output                              exc_flush,
   output [`PC_W-1:0]                  exc_flush_tgt,

   // IRQs
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              irq_async,
   output                              tsc_irq,

   // PSR
   input [`NCPU_PSR_DW-1:0]            msr_psr,
   input [`NCPU_PSR_DW-1:0]            msr_psr_nold,
   input                               msr_psr_ire,
   output                              msr_psr_rm_nxt,
   output                              msr_psr_rm_we,
   output                              msr_psr_imme_nxt,
   output                              msr_psr_imme_we,
   output                              msr_psr_dmme_nxt,
   output                              msr_psr_dmme_we,
   output                              msr_psr_ire_nxt,
   output                              msr_psr_ire_we,
   output                              msr_exc_ent,
   // CPUID
   input [CONFIG_DW-1:0]               msr_cpuid,
   // EPC
   input [CONFIG_DW-1:0]               msr_epc,
   output [CONFIG_DW-1:0]              msr_epc_nxt,
   output                              msr_epc_we,
   // EPSR
   input [`NCPU_PSR_DW-1:0]            msr_epsr,
   input [`NCPU_PSR_DW-1:0]            msr_epsr_nobyp,
   output [`NCPU_PSR_DW-1:0]           msr_epsr_nxt,
   output                              msr_epsr_we,
   // ELSA
   input [CONFIG_DW-1:0]               msr_elsa,
   output [CONFIG_DW-1:0]              msr_elsa_nxt,
   output                              msr_elsa_we,
   // COREID
   input [CONFIG_DW-1:0]               msr_coreid,
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
   // DMMID
   input [CONFIG_DW-1:0]               msr_dmmid,
   // DTLBL
   output [CONFIG_DTLB_P_SETS-1:0]     msr_dmm_tlbl_idx,
   output [CONFIG_DW-1:0]              msr_dmm_tlbl_nxt,
   output                              msr_dmm_tlbl_we,
   // DTLBH
   output [CONFIG_DTLB_P_SETS-1:0]     msr_dmm_tlbh_idx,
   output [CONFIG_DW-1:0]              msr_dmm_tlbh_nxt,
   output                              msr_dmm_tlbh_we,
   // ICID
   input [CONFIG_DW-1:0]               msr_icid,
   // ICINV
   output [CONFIG_DW-1:0]              msr_icinv_nxt,
   output                              msr_icinv_we,
   // DCID
   input [CONFIG_DW-1:0]               msr_dcid,
   // DCINV
   output [CONFIG_DW-1:0]              msr_dcinv_nxt,
   output                              msr_dcinv_we,
   // DCFLS
   output [CONFIG_DW-1:0]              msr_dcfls_nxt,
   output                              msr_dcfls_we
);

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [CONFIG_DW-1:0] msr_irqc_imr;           // From U_IRQC of ex_epu_irqc.v
   wire [CONFIG_DW-1:0] msr_irqc_irr;           // From U_IRQC of ex_epu_irqc.v
   wire [CONFIG_DW-1:0] msr_tsc_tcr;            // From U_TSC of ex_epu_tsc.v
   wire [CONFIG_DW-1:0] msr_tsc_tsr;            // From U_TSC of ex_epu_tsc.v
   // End of automatics
   wire [CONFIG_DW-1:0]                msr_irqc_imr_nxt;
   wire                                msr_irqc_imr_we;
   wire [CONFIG_DW-1:0]                msr_tsc_tsr_nxt;
   wire                                msr_tsc_tsr_we;
   wire [CONFIG_DW-1:0]                msr_tsc_tcr_nxt;
   wire                                msr_tsc_tcr_we;
   wire [CONFIG_DW-1:0]                s1i_msr_addr;
   wire [`NCPU_MSR_BANK_AW-1:0]        s1i_bank_addr;
   wire [`NCPU_MSR_BANK_OFF_AW-1:0]    s1i_bank_off;
   wire                                s1i_bank_ps;
   wire                                s1i_bank_imm;
   wire                                s1i_bank_dmm;
   wire                                s1i_bank_ic;
   wire                                s1i_bank_dc;
   wire                                s1i_bank_dbg;
   wire                                s1i_bank_irqc;
   wire                                s1i_bank_tsc;
   wire [CONFIG_DW-1:0]                dout_ps;
   wire                                msr_imm_tlbl_sel;
   wire                                msr_imm_tlbh_sel;
   wire [CONFIG_DW-1:0]                dout_imm;
   wire                                msr_dmm_tlbl_sel;
   wire                                msr_dmm_tlbh_sel;
   wire                                msr_ic_id_sel;
   wire                                msr_ic_inv_sel;
   wire                                msr_dc_id_sel;
   wire                                msr_dc_inv_sel;
   wire                                msr_dc_fls_sel;
   wire [CONFIG_DW-1:0]                dout_dmm;
   wire [CONFIG_DW-1:0]                dout_ic;
   wire [CONFIG_DW-1:0]                dout_dc;
   wire                                msr_irqc_imr_sel;
   wire                                msr_irqc_irr_sel;
   wire [CONFIG_DW-1:0]                dout_irqc;
   wire                                msr_tsc_tsr_sel;
   wire                                msr_tsc_tcr_sel;
   wire [CONFIG_DW-1:0]                dout_tsc;
   wire                                exc_commit;
   wire                                set_elsa_as_pc;
   wire                                set_elsa;
   wire [CONFIG_DW-1:0]                lsa_nxt;
   wire                                epsr_rm_nobpy;
   wire                                epsr_ire_nobpy;
   wire                                epsr_imme_nobpy;
   wire                                epsr_dmme_nobpy;
   wire                                s1i_wmsr_psr_we;
   wire                                s1i_wmsr_epc_we;
   wire                                s1i_wmsr_epsr_we;
   wire                                s1i_wmsr_elsa_we;
`ifdef NCPU_ENABLE_MSGPORT
   wire                                s1i_wmsr_numport_we;
   wire                                s1i_wmsr_msgport_we;
`endif
   wire                                s1i_msr_imm_tlbl_we;
   wire                                s1i_msr_imm_tlbh_we;
   wire                                s1i_msr_dmm_tlbl_we;
   wire                                s1i_msr_dmm_tlbh_we;
   wire                                s1i_msr_ic_inv_we;
   wire                                s1i_msr_dc_inv_we;
   wire                                s1i_msr_dc_fls_we;
   wire                                s1i_msr_irqc_imr_we;
   wire                                s1i_msr_tsc_tsr_we;
   wire                                s1i_msr_tsc_tcr_we;
   wire                                commit_wmsr_psr_we;
   wire                                commit_wmsr_epc_we;
   wire                                commit_wmsr_epsr_we;
   wire                                commit_wmsr_elsa_we;
`ifdef NCPU_ENABLE_MSGPORT
   wire                                commit_wmsr_numport_we;
   wire                                commit_wmsr_msgport_we;
`endif
   wire                                commit_msr_imm_tlbl_we;
   wire                                commit_msr_imm_tlbh_we;
   wire                                commit_msr_dmm_tlbl_we;
   wire                                commit_msr_dmm_tlbh_we;
   wire                                commit_msr_ic_inv_we;
   wire                                commit_msr_dc_inv_we;
   wire                                commit_msr_dc_fls_we;
   wire                                commit_msr_irqc_imr_we;
   wire                                commit_msr_tsc_tsr_we;
   wire                                commit_msr_tsc_tcr_we;
   wire [`NCPU_MSR_BANK_OFF_AW-1:0]    commit_bank_off;
   wire                                wmsr_psr_rm;
   wire                                wmsr_psr_ire;
   wire                                wmsr_psr_imme;
   wire                                wmsr_psr_dmme;
/* verilator lint_off UNUSED */
   wire [9:0]                          wmsr_psr_res; // unsued
   wire [9:0]                          epsr_res; // unsued
/* verilator lint_on UNUSED */
   wire                                msr_exc_ent_ff;
   wire                                save_psr;
   genvar i;

   assign s1i_msr_addr = ex_operand1 | {{CONFIG_DW-15{1'b0}}, ex_imm[14:0]};
   assign s1i_bank_addr = s1i_msr_addr[`NCPU_MSR_BANK_AW+`NCPU_MSR_BANK_OFF_AW-1:`NCPU_MSR_BANK_OFF_AW];
   assign s1i_bank_off = s1i_msr_addr[`NCPU_MSR_BANK_OFF_AW-1:0];

   // Readout PS
   assign dout_ps =
      (
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_PSR]}} & {{CONFIG_DW-`NCPU_PSR_DW{1'b0}}, msr_psr[`NCPU_PSR_DW-1:0]}) |
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_CPUID]}} & msr_cpuid) |
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_EPSR]}} & {{CONFIG_DW-`NCPU_PSR_DW{1'b0}}, msr_epsr[`NCPU_PSR_DW-1:0]}) |
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_EPC]}} & msr_epc) |
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_ELSA]}} & msr_elsa) |
         ({CONFIG_DW{s1i_bank_off[`NCPU_MSR_COREID]}} & msr_coreid)
      );

   // Readout IMM
   assign msr_imm_tlbl_sel = s1i_bank_off[`NCPU_MSR_IMM_TLBSEL] & ~s1i_bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign msr_imm_tlbh_sel = s1i_bank_off[`NCPU_MSR_IMM_TLBSEL] & s1i_bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign dout_imm =
      (
         ({CONFIG_DW{~s1i_bank_off[`NCPU_MSR_IMM_TLBSEL]}} & msr_immid)
      );

   // Readout DMM
   assign msr_dmm_tlbl_sel = s1i_bank_off[`NCPU_MSR_DMM_TLBSEL] & ~s1i_bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign msr_dmm_tlbh_sel = s1i_bank_off[`NCPU_MSR_DMM_TLBSEL] & s1i_bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign dout_dmm =
      (
         ({CONFIG_DW{~s1i_bank_off[`NCPU_MSR_DMM_TLBSEL]}} & msr_dmmid)
      );

   // Readout IC
   assign msr_ic_id_sel = s1i_bank_off[`NCPU_MSR_IC_ID];
   assign msr_ic_inv_sel = s1i_bank_off[`NCPU_MSR_IC_INV];
   assign dout_ic =
      (
         ({CONFIG_DW{msr_ic_id_sel}} & msr_icid)
      );

   // Readout DC
   assign msr_dc_id_sel = s1i_bank_off[`NCPU_MSR_DC_ID];
   assign msr_dc_inv_sel = s1i_bank_off[`NCPU_MSR_DC_INV];
   assign msr_dc_fls_sel = s1i_bank_off[`NCPU_MSR_DC_FLS];
   assign dout_dc =
      (
         ({CONFIG_DW{msr_dc_id_sel}} & msr_dcid)
      );

   // Readout IRQC
   assign msr_irqc_imr_sel = s1i_bank_off[`NCPU_MSR_IRQC_IMR];
   assign msr_irqc_irr_sel = s1i_bank_off[`NCPU_MSR_IRQC_IRR];
   assign dout_irqc =
      (
         ({CONFIG_DW{msr_irqc_imr_sel}} & msr_irqc_imr) |
         ({CONFIG_DW{msr_irqc_irr_sel}} & msr_irqc_irr)
      );

   // Readout TSC
   assign msr_tsc_tsr_sel = s1i_bank_off[`NCPU_MSR_TSC_TSR];
   assign msr_tsc_tcr_sel = s1i_bank_off[`NCPU_MSR_TSC_TCR];
   assign dout_tsc =
      (
         ({CONFIG_DW{msr_tsc_tsr_sel}} & msr_tsc_tsr) |
         ({CONFIG_DW{msr_tsc_tcr_sel}} & msr_tsc_tcr)
      );

   // Decode MSR s1i_bank_addr
   assign s1i_bank_ps = (s1i_bank_addr == `NCPU_MSR_BANK_PS);
   assign s1i_bank_imm = (s1i_bank_addr == `NCPU_MSR_BANK_IMM);
   assign s1i_bank_dmm = (s1i_bank_addr == `NCPU_MSR_BANK_DMM);
   assign s1i_bank_ic = (s1i_bank_addr == `NCPU_MSR_BANK_IC);
   assign s1i_bank_dc = (s1i_bank_addr == `NCPU_MSR_BANK_DC);
   assign s1i_bank_dbg = (s1i_bank_addr == `NCPU_MSR_BANK_DBG);
   assign s1i_bank_irqc = (s1i_bank_addr == `NCPU_MSR_BANK_IRQC);
   assign s1i_bank_tsc = (s1i_bank_addr == `NCPU_MSR_BANK_TSC);

   // Result MUX
   assign epu_dout =
      (
         ({CONFIG_DW{s1i_bank_ps}} & dout_ps) |
         ({CONFIG_DW{s1i_bank_imm}} & dout_imm) |
         ({CONFIG_DW{s1i_bank_dmm}} & dout_dmm) |
         ({CONFIG_DW{s1i_bank_ic}} & dout_ic) |
         ({CONFIG_DW{s1i_bank_dc}} & dout_dc) |
         ({CONFIG_DW{s1i_bank_irqc}} & dout_irqc) |
         ({CONFIG_DW{s1i_bank_tsc}} & dout_tsc)
      );

   assign epu_ERET = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_ERET]);
   assign epu_ESYSCALL = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_ESYSCALL]);
   assign epu_EINSN = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_EINSN]);
   assign epu_EIPF = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_EIPF]);
   assign epu_EITM = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_EITM]);
   assign epu_EIRQ = (ex_valid & ex_epu_opc_bus[`NCPU_EPU_EIRQ]);
   assign epu_E_FLUSH_TLB = (ex_valid & (s1i_wmsr_psr_we |
                              s1i_msr_imm_tlbl_we |
                              s1i_msr_imm_tlbh_we |
                              s1i_msr_dmm_tlbl_we |
                              s1i_msr_dmm_tlbh_we));

   ////////////////////////////////////////////////////////////////////////////////

   // Decode MSR address
   assign epu_wmsr_dat = ex_operand2;

   assign s1i_wmsr_psr_we      = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_PSR];
   assign s1i_wmsr_epc_we      = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_EPC];
   assign s1i_wmsr_epsr_we     = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_EPSR];
   assign s1i_wmsr_elsa_we     = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_ELSA];
`ifdef NCPU_ENABLE_MSGPORT
   assign s1i_wmsr_numport_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dbg & s1i_bank_off[0];
   assign s1i_wmsr_msgport_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dbg & s1i_bank_off[1];
`endif
   assign s1i_msr_imm_tlbl_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_imm & msr_imm_tlbl_sel;
   assign s1i_msr_imm_tlbh_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_imm & msr_imm_tlbh_sel;
   assign s1i_msr_dmm_tlbl_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dmm & msr_dmm_tlbl_sel;
   assign s1i_msr_dmm_tlbh_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dmm & msr_dmm_tlbh_sel;
   assign s1i_msr_ic_inv_we    = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ic & msr_ic_inv_sel;
   assign s1i_msr_dc_inv_we    = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dc & msr_dc_inv_sel;
   assign s1i_msr_dc_fls_we    = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dc & msr_dc_fls_sel;

   assign s1i_msr_irqc_imr_we  = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_irqc & msr_irqc_imr_sel;
   assign s1i_msr_tsc_tsr_we   = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_tsc & msr_tsc_tsr_sel;
   assign s1i_msr_tsc_tcr_we   = ex_valid & ex_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_tsc & msr_tsc_tcr_sel;

   assign epu_wmsr_we = {s1i_wmsr_psr_we,
                        s1i_wmsr_epc_we,
                        s1i_wmsr_epsr_we,
                        s1i_wmsr_elsa_we,
`ifdef NCPU_ENABLE_MSGPORT
                        s1i_wmsr_numport_we,
                        s1i_wmsr_msgport_we,
`endif
                        s1i_msr_imm_tlbl_we,
                        s1i_msr_imm_tlbh_we,
                        s1i_msr_dmm_tlbl_we,
                        s1i_msr_dmm_tlbh_we,
                        s1i_msr_ic_inv_we,
                        s1i_msr_dc_inv_we,
                        s1i_msr_dc_fls_we,
                        s1i_msr_irqc_imr_we,
                        s1i_msr_tsc_tsr_we,
                        s1i_msr_tsc_tcr_we,
                        s1i_bank_off};

   // Unpack commit wmsr we
   assign {
      commit_wmsr_psr_we,
      commit_wmsr_epc_we,
      commit_wmsr_epsr_we,
      commit_wmsr_elsa_we,
`ifdef NCPU_ENABLE_MSGPORT
      commit_wmsr_numport_we,
      commit_wmsr_msgport_we,
`endif
      commit_msr_imm_tlbl_we,
      commit_msr_imm_tlbh_we,
      commit_msr_dmm_tlbl_we,
      commit_msr_dmm_tlbh_we,
      commit_msr_ic_inv_we,
      commit_msr_dc_inv_we,
      commit_msr_dc_fls_we,
      commit_msr_irqc_imr_we,
      commit_msr_tsc_tsr_we,
      commit_msr_tsc_tcr_we,
      commit_bank_off} = commit_wmsr_we;

   // Unpack EPSR. Be consistend with ncpu32k_psr
   assign {epsr_res[9],epsr_res[8],epsr_dmme_nobpy,epsr_imme_nobpy,epsr_ire_nobpy,epsr_rm_nobpy,epsr_res[3],epsr_res[2], epsr_res[1],epsr_res[0]} = msr_epsr_nobyp;

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
   assign msr_psr_rm_nxt = commit_wmsr_psr_we ? wmsr_psr_rm : epsr_rm_nobpy;
   assign msr_psr_imme_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_imme_nxt = commit_wmsr_psr_we ? wmsr_psr_imme : epsr_imme_nobpy;
   assign msr_psr_dmme_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_dmme_nxt = commit_wmsr_psr_we ? wmsr_psr_dmme : epsr_dmme_nobpy;
   assign msr_psr_ire_we = (commit_wmsr_psr_we | commit_ERET);
   assign msr_psr_ire_nxt = commit_wmsr_psr_we ? wmsr_psr_ire : epsr_ire_nobpy;

   mDFF_r #(.DW(1)) ff_msr_exc_ent_r (.CLK(clk), .RST(rst), .D(msr_exc_ent), .Q(msr_exc_ent_ff) );

   // Save PSR to EPSR at the first edge of exception signal
   assign save_psr = msr_exc_ent & ~msr_exc_ent_ff;

   // Commit EPSR
   assign msr_epsr_we = (commit_wmsr_epsr_we | save_psr);
   assign msr_epsr_nxt = commit_wmsr_epsr_we ? commit_wmsr_dat[`NCPU_PSR_DW-1:0] : msr_psr_nold;
   // In syscall, EPC is a pointer to the next insn to syscall, while in general EPC points to the insn
   // that raised the exception.
   assign msr_epc_nxt = commit_wmsr_epc_we ? commit_wmsr_dat :
                        commit_ESYSCALL ? {commit_nepc,2'b0} : {commit_epc,2'b0};
   assign msr_epc_we = msr_exc_ent | commit_wmsr_epc_we;

   // Commit ELSA  Assert (03100705)
   assign set_elsa_as_pc = (commit_EITM | commit_EIPF | commit_EINSN);
   assign set_elsa = (set_elsa_as_pc | commit_EDTM | commit_EDPF | commit_EALIGN);
   // Let ELSA be PC if it's IMMU or EINSN exception
   assign lsa_nxt = set_elsa_as_pc ? {commit_epc,2'b0} : commit_LSA;
   // Assert (03060933)
   assign msr_elsa_nxt = set_elsa ? lsa_nxt : commit_wmsr_dat;
   assign msr_elsa_we = set_elsa | commit_wmsr_elsa_we;

   // Commit IMM
   assign msr_imm_tlbl_idx = commit_bank_off[CONFIG_ITLB_P_SETS-1:0];
   assign msr_imm_tlbl_nxt = commit_wmsr_dat;
   assign msr_imm_tlbl_we = commit_msr_imm_tlbl_we;

   assign msr_imm_tlbh_idx = commit_bank_off[CONFIG_ITLB_P_SETS-1:0];
   assign msr_imm_tlbh_nxt = commit_wmsr_dat;
   assign msr_imm_tlbh_we = commit_msr_imm_tlbh_we;

   // Commit DMM
   assign msr_dmm_tlbl_idx = commit_bank_off[CONFIG_DTLB_P_SETS-1:0];
   assign msr_dmm_tlbl_nxt = commit_wmsr_dat;
   assign msr_dmm_tlbl_we = commit_msr_dmm_tlbl_we;

   assign msr_dmm_tlbh_idx = commit_bank_off[CONFIG_DTLB_P_SETS-1:0];
   assign msr_dmm_tlbh_nxt = commit_wmsr_dat;
   assign msr_dmm_tlbh_we = commit_msr_dmm_tlbh_we;

   // Commit IC
   assign msr_icinv_we = commit_msr_ic_inv_we;
   assign msr_icinv_nxt = commit_wmsr_dat;

   // Commit DC
   assign msr_dcinv_we = commit_msr_dc_inv_we;
   assign msr_dcinv_nxt = commit_wmsr_dat;
   assign msr_dcfls_we = commit_msr_dc_fls_we;
   assign msr_dcfls_nxt = commit_wmsr_dat;

   // Commit IRQC
   assign msr_irqc_imr_we = commit_msr_irqc_imr_we;
   assign msr_irqc_imr_nxt = commit_wmsr_dat;

   // Commit TSC
   assign msr_tsc_tsr_we = commit_msr_tsc_tsr_we;
   assign msr_tsc_tsr_nxt = commit_wmsr_dat;
   assign msr_tsc_tcr_we = commit_msr_tsc_tcr_we;
   assign msr_tsc_tcr_nxt = commit_wmsr_dat;

   // Exceptions
   // Assert 2105051856
   assign exc_flush_tgt = ({CONFIG_AW-2{commit_EDTM}} & CONFIG_EDTM_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EDPF}} & CONFIG_EDPF_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EALIGN}} & CONFIG_EALIGN_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_E_FLUSH_TLB}} & ex_npc) |
                           ({CONFIG_AW-2{commit_ESYSCALL}} & CONFIG_ESYSCALL_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_ERET}} & msr_epc[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EITM}} & CONFIG_EITM_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EIPF}} & CONFIG_EIPF_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EIRQ}} & CONFIG_EIRQ_VECTOR[2 +: CONFIG_AW-2]) |
                           ({CONFIG_AW-2{commit_EINSN}} & CONFIG_EINSN_VECTOR[2 +: CONFIG_AW-2]);

   assign exc_flush = (commit_EDTM |
                        commit_EDPF |
                        commit_EALIGN |
                        commit_E_FLUSH_TLB |
                        commit_ESYSCALL |
                        commit_ERET |
                        commit_EITM |
                        commit_EIPF |
                        commit_EIRQ |
                        commit_EINSN);

	// synthesis translate_off
`ifdef NCPU_ENABLE_MSGPORT
   always @(posedge clk) begin
      if (commit_wmsr_numport_we)
         $display("Num port = %d", commit_wmsr_dat);
      if (commit_wmsr_msgport_we)
         $write("%c", commit_wmsr_dat[7:0]);
   end
`endif
   // synthesis translate_on

   ex_epu_irqc
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ))
   U_IRQC
      (/*AUTOINST*/
       // Outputs
       .irq_async                       (irq_async),
       .msr_irqc_imr                    (msr_irqc_imr[CONFIG_DW-1:0]),
       .msr_irqc_irr                    (msr_irqc_irr[CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_irqc_imr_nxt                (msr_irqc_imr_nxt[CONFIG_DW-1:0]),
       .msr_irqc_imr_we                 (msr_irqc_imr_we));

   ex_epu_tsc
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW))
   U_TSC
      (/*AUTOINST*/
       // Outputs
       .tsc_irq                         (tsc_irq),
       .msr_tsc_tsr                     (msr_tsc_tsr[CONFIG_DW-1:0]),
       .msr_tsc_tcr                     (msr_tsc_tcr[CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .msr_tsc_tsr_nxt                 (msr_tsc_tsr_nxt[CONFIG_DW-1:0]),
       .msr_tsc_tsr_we                  (msr_tsc_tsr_we),
       .msr_tsc_tcr_nxt                 (msr_tsc_tcr_nxt[CONFIG_DW-1:0]),
       .msr_tsc_tcr_we                  (msr_tsc_tcr_we));


   // synthesis translate_off
`ifndef SYNTHESIS
   // Assertions
   always @(posedge clk)
      begin
         // Assertions 03060934
         if ((commit_EITM + commit_EIPF +
               commit_EINSN +
               commit_ESYSCALL + commit_ERET +
               commit_EDTM + commit_EDPF + commit_EALIGN +
               commit_EIRQ +
               commit_wmsr_psr_we)>'d1)
            $fatal (1, "\n Bugs on exception sources (IMMU, IDU, AGU and DMMU)\n");

         // Assertions 2105051856
         if ((commit_EDTM +
               commit_EDPF +
               commit_EALIGN +
               commit_E_FLUSH_TLB +
               commit_ESYSCALL +
               commit_ERET +
               commit_EITM +
               commit_EIPF +
               commit_EIRQ +
               commit_EINSN) > 'd1)
            $fatal (1, "Bugs on EPU exceptions");
      end
`endif
   // synthesis translate_on

endmodule
