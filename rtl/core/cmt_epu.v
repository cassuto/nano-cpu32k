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

module cmt_epu
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EITM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_ESYSCALL_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EINSN_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIRQ_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDTM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EALIGN_VECTOR = 0,
   parameter                           CONFIG_ITLB_P_SETS = 0,
   parameter                           CONFIG_DTLB_P_SETS = 0,
   parameter                           CONFIG_NUM_IRQ = 0
)
(
   input                               clk,
   input                               rst,
   input                               p_ce_s1,
   input                               p_ce_s1_no_icinv_stall,
   input                               p_ce_s2,
   input [`PC_W-1:0]                   cmt_pc,
   input [`PC_W-1:0]                   cmt_npc,
   input                               cmt_req_valid,
   input [`NCPU_EPU_IOPW-1:0]          cmt_epu_opc_bus,
   input                               cmt_exc,
   input [`NCPU_FE_W-1:0]              cmt_fe,
   input [CONFIG_DW-1:0]               cmt_addr,
   input [CONFIG_DW-1:0]               cmt_wdat,
   input                               s2i_EDTM,
   input                               s2i_EDPF,
   input                               s2i_EALIGN,
   input [CONFIG_AW-1:0]               s2i_vaddr,
   // To WRITEBACK
   output [CONFIG_DW-1:0]              epu_wb_dout,
   output                              epu_wb_dout_sel,
   output                              epu_wb_valid,

   // Flush
   output                              exc_flush,
   output [`PC_W-1:0]                  exc_flush_tgt,
   output                              refetch,

   // IRQs
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              irq_async,
   output                              tsc_irq,

   // PSR
   input [`NCPU_PSR_DW-1:0]            msr_psr,
   input                               msr_psr_ire,
   output                              msr_psr_rm_nxt,
   output                              msr_psr_rm_we,
   output                              msr_psr_imme_nxt,
   output                              msr_psr_imme_we,
   output                              msr_psr_dmme_nxt,
   output                              msr_psr_dmme_we,
   output                              msr_psr_ire_nxt,
   output                              msr_psr_ire_we,
   output                              msr_psr_ice_nxt,
   output                              msr_psr_ice_we,
   output                              msr_psr_dce_nxt,
   output                              msr_psr_dce_we,
   output                              msr_psr_save,
   output                              msr_psr_restore,
   // CPUID
   input [CONFIG_DW-1:0]               msr_cpuid,
   // EPC
   input [CONFIG_DW-1:0]               msr_epc,
   output [CONFIG_DW-1:0]              msr_epc_nxt,
   output                              msr_epc_we,
   // EPSR
   input [`NCPU_PSR_DW-1:0]            msr_epsr,
   output [`NCPU_PSR_DW-1:0]           msr_epsr_nxt,
   output                              msr_epsr_we,
   // ELSA
   input [CONFIG_DW-1:0]               msr_elsa,
   output [CONFIG_DW-1:0]              msr_elsa_nxt,
   output                              msr_elsa_we,
   // EVECT
   output [CONFIG_AW-1:0]              msr_evect_nxt,
   input [CONFIG_AW-1:0]               msr_evect,
   output                              msr_evect_we,
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
   output                              msr_dcfls_we,
   // SR
   input [CONFIG_DW*`NCPU_SR_NUM-1:0]  msr_sr,
   output [CONFIG_DW-1:0]              msr_sr_nxt,
   output [`NCPU_SR_NUM-1:0]           msr_sr_we
);

`ifdef NCPU_ENABLE_MSGPORT
   localparam NCPU_WMSR_WE_W           = (15 + `NCPU_MSR_BANK_OFF_AW);
`else
   localparam NCPU_WMSR_WE_W           = (13 + `NCPU_MSR_BANK_OFF_AW);
`endif

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [CONFIG_DW-1:0] msr_irqc_imr;           // From U_IRQC of cmt_irqc.v
   wire [CONFIG_DW-1:0] msr_irqc_irr;           // From U_IRQC of cmt_irqc.v
   wire [CONFIG_DW-1:0] msr_tsc_tcr;            // From U_TSC of cmt_tsc.v
   wire [CONFIG_DW-1:0] msr_tsc_tsr;            // From U_TSC of cmt_tsc.v
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
   wire                                s1i_bank_sr;
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
   wire [CONFIG_DW-1:0]                dout_sr;
   wire                                s1i_wmsr_psr_we;
   wire                                s1i_wmsr_epc_we;
   wire                                s1i_wmsr_epsr_we;
   wire                                s1i_wmsr_elsa_we;
   wire                                s1i_wmsr_evect_we;
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
   wire                                s1i_msr_sr_we;
   wire   [CONFIG_DW-1:0]              s1i_msr_wdat;
   wire   [NCPU_WMSR_WE_W-1:0]         s1i_wmsr_we;
   wire                                s1i_ERET;
   wire                                s1i_ESYSCALL;
   wire                                s1i_EINSN;
   wire                                s1i_EIPF;
   wire                                s1i_EITM;
   wire                                s1i_EIRQ;
   wire                                s1i_refetch;
   wire [CONFIG_DW-1:0]                s1i_wb_dout;
   wire                                s1i_wb_dout_sel;
   wire                                s1o_valid;
   wire                                s1o_commit_wmsr_psr_we;
   wire                                s1o_commit_wmsr_epc_we;
   wire                                s1o_commit_wmsr_epsr_we;
   wire                                s1o_commit_wmsr_elsa_we;
   wire                                s1o_commit_wmsr_evect_we;
`ifdef NCPU_ENABLE_MSGPORT
   wire                                s1o_commit_wmsr_numport_we;
   wire                                s1o_commit_wmsr_msgport_we;
`endif
   wire                                s1o_commit_msr_imm_tlbl_we;
   wire                                s1o_commit_msr_imm_tlbh_we;
   wire                                s1o_commit_msr_dmm_tlbl_we;
   wire                                s1o_commit_msr_dmm_tlbh_we;
   wire                                s1o_commit_msr_irqc_imr_we;
   wire                                s1o_commit_msr_tsc_tsr_we;
   wire                                s1o_commit_msr_tsc_tcr_we;
   wire                                s1o_commit_msr_sr_we;
   wire [`NCPU_MSR_BANK_OFF_AW-1:0]    s1o_commit_bank_off;
   wire  [`PC_W-1:0]                   s1o_commit_epc;
   wire [`PC_W-1:0]                    s1o_commit_nepc;
   wire [CONFIG_AW-1:0]                s1o_msr_evect;
   wire                                s1o_commit_ERET;
   wire                                s1o_commit_ESYSCALL;
   wire                                s1o_commit_EINSN;
   wire                                s1o_commit_EIPF;
   wire                                s1o_commit_EITM;
   wire                                s1o_commit_EIRQ;
   wire                                s1o_commit_refetch;
   wire  [NCPU_WMSR_WE_W-1:0]          s1o_commit_wmsr_we;
   wire  [CONFIG_DW-1:0]               s1o_commit_wmsr_dat;
   wire                                s1o_wmsr_psr_rm;
   wire                                s1o_wmsr_psr_ire;
   wire                                s1o_wmsr_psr_imme;
   wire                                s1o_wmsr_psr_dmme;
   wire                                s1o_wmsr_psr_ice;
   wire                                s1o_wmsr_psr_dce;
   wire                                s1o_set_elsa_as_pc;
   wire                                s1o_set_elsa;
   wire [CONFIG_DW-1:0]                s1o_lsa_nxt;
   genvar i;

   assign s1i_msr_wdat = cmt_wdat;
   
   assign s1i_msr_addr = cmt_addr;
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

   // Readout SR
   pmux #(.SELW(`NCPU_SR_NUM), .DW(CONFIG_DW)) pmux_dout_sr (.sel(s1i_bank_off[`NCPU_SR_NUM-1:0]), .din(msr_sr), .dout(dout_sr));

   // Decode for MSR bank addr
   assign s1i_bank_ps = (s1i_bank_addr == `NCPU_MSR_BANK_PS);
   assign s1i_bank_imm = (s1i_bank_addr == `NCPU_MSR_BANK_IMM);
   assign s1i_bank_dmm = (s1i_bank_addr == `NCPU_MSR_BANK_DMM);
   assign s1i_bank_ic = (s1i_bank_addr == `NCPU_MSR_BANK_IC);
   assign s1i_bank_dc = (s1i_bank_addr == `NCPU_MSR_BANK_DC);
   assign s1i_bank_dbg = (s1i_bank_addr == `NCPU_MSR_BANK_DBG);
   assign s1i_bank_irqc = (s1i_bank_addr == `NCPU_MSR_BANK_IRQC);
   assign s1i_bank_tsc = (s1i_bank_addr == `NCPU_MSR_BANK_TSC);
   assign s1i_bank_sr = (s1i_bank_addr == `NCPU_MSR_BANK_SR);

   // Result MUX
   assign s1i_wb_dout =
      (
         ({CONFIG_DW{s1i_bank_ps}} & dout_ps) |
         ({CONFIG_DW{s1i_bank_imm}} & dout_imm) |
         ({CONFIG_DW{s1i_bank_dmm}} & dout_dmm) |
         ({CONFIG_DW{s1i_bank_ic}} & dout_ic) |
         ({CONFIG_DW{s1i_bank_dc}} & dout_dc) |
         ({CONFIG_DW{s1i_bank_irqc}} & dout_irqc) |
         ({CONFIG_DW{s1i_bank_tsc}} & dout_tsc) |
         ({CONFIG_DW{s1i_bank_sr}} & dout_sr)
      );
   
   assign s1i_wb_dout_sel = (cmt_epu_opc_bus[`NCPU_EPU_RMSR]);

   assign s1i_ERET = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_ERET]);
   assign s1i_ESYSCALL = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_ESYSCALL]);
   assign s1i_EINSN = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_EINSN]);
   assign s1i_EIPF = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_EIPF]);
   assign s1i_EITM = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_EITM]);
   assign s1i_EIRQ = (cmt_req_valid & cmt_exc & cmt_fe[`NCPU_FE_EIRQ]);
   assign s1i_refetch = (cmt_req_valid & (s1i_wmsr_psr_we |
                              s1i_msr_imm_tlbl_we |
                              s1i_msr_imm_tlbh_we |
                              s1i_msr_dmm_tlbl_we |
                              s1i_msr_dmm_tlbh_we));

   ////////////////////////////////////////////////////////////////////////////////

   // Decode MSR address
   
   assign s1i_wmsr_psr_we      = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_PSR];
   assign s1i_wmsr_epc_we      = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_EPC];
   assign s1i_wmsr_epsr_we     = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_EPSR];
   assign s1i_wmsr_elsa_we     = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_ELSA];
   assign s1i_wmsr_evect_we    = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ps & s1i_bank_off[`NCPU_MSR_EVECT];
`ifdef NCPU_ENABLE_MSGPORT
   assign s1i_wmsr_numport_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dbg & s1i_bank_off[0];
   assign s1i_wmsr_msgport_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dbg & s1i_bank_off[1];
`endif
   assign s1i_msr_imm_tlbl_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_imm & msr_imm_tlbl_sel;
   assign s1i_msr_imm_tlbh_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_imm & msr_imm_tlbh_sel;
   assign s1i_msr_dmm_tlbl_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dmm & msr_dmm_tlbl_sel;
   assign s1i_msr_dmm_tlbh_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dmm & msr_dmm_tlbh_sel;
   assign s1i_msr_ic_inv_we    = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_ic & msr_ic_inv_sel;
   assign s1i_msr_dc_inv_we    = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dc & msr_dc_inv_sel;
   assign s1i_msr_dc_fls_we    = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_dc & msr_dc_fls_sel;

   assign s1i_msr_irqc_imr_we  = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_irqc & msr_irqc_imr_sel;
   assign s1i_msr_tsc_tsr_we   = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_tsc & msr_tsc_tsr_sel;
   assign s1i_msr_tsc_tcr_we   = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_tsc & msr_tsc_tcr_sel;
   
   assign s1i_msr_sr_we        = cmt_req_valid & cmt_epu_opc_bus[`NCPU_EPU_WMSR] & s1i_bank_sr;
   
   ////////////////////////////////////////////////////////////////////////////////

   // Pack `wmsr we`
   assign s1i_wmsr_we = {s1i_wmsr_psr_we,
                        s1i_wmsr_epc_we,
                        s1i_wmsr_epsr_we,
                        s1i_wmsr_elsa_we,
                        s1i_wmsr_evect_we,
`ifdef NCPU_ENABLE_MSGPORT
                        s1i_wmsr_numport_we,
                        s1i_wmsr_msgport_we,
`endif
                        s1i_msr_imm_tlbl_we,
                        s1i_msr_imm_tlbh_we,
                        s1i_msr_dmm_tlbl_we,
                        s1i_msr_dmm_tlbh_we,
                        s1i_msr_irqc_imr_we,
                        s1i_msr_tsc_tsr_we,
                        s1i_msr_tsc_tcr_we,
                        s1i_msr_sr_we,
                        s1i_bank_off};

   // Pipeline stage
   mDFF_lr # (.DW(1)) ff_epu_wb_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(cmt_req_valid), .Q(s1o_valid) );
   mDFF_l # (.DW(CONFIG_DW)) ff_epu_wb_dout (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_wb_dout), .Q(epu_wb_dout) );
   mDFF_l # (.DW(1)) ff_epu_wb_dout_sel (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_wb_dout_sel), .Q(epu_wb_dout_sel) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_ERET (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_ERET), .Q(s1o_commit_ERET) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_ESYSCALL (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_ESYSCALL), .Q(s1o_commit_ESYSCALL) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_EINSN (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_EINSN), .Q(s1o_commit_EINSN) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_EIPF (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_EIPF), .Q(s1o_commit_EIPF) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_EITM (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_EITM), .Q(s1o_commit_EITM) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_EIRQ (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_EIRQ), .Q(s1o_commit_EIRQ) );
   mDFF_lr # (.DW(1)) ff_s1o_commit_refetch (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_refetch), .Q(s1o_commit_refetch) );
   mDFF_lr # (.DW(NCPU_WMSR_WE_W)) ff_s1o_commit_wmsr_we (.CLK(clk), .RST(rst), .LOAD(p_ce_s1), .D(s1i_wmsr_we), .Q(s1o_commit_wmsr_we) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s1o_commit_wmsr_dat (.CLK(clk), .LOAD(p_ce_s1), .D(s1i_msr_wdat), .Q(s1o_commit_wmsr_dat) );
   mDFF_l # (.DW(`PC_W)) ff_s1o_commit_epc (.CLK(clk), .LOAD(p_ce_s1), .D(cmt_pc), .Q(s1o_commit_epc) );
   mDFF_l # (.DW(`PC_W)) ff_s1o_commit_nepc (.CLK(clk), .LOAD(p_ce_s1), .D(cmt_npc), .Q(s1o_commit_nepc) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s1o_msr_evect (.CLK(clk), .LOAD(p_ce_s1), .D(msr_evect), .Q(s1o_msr_evect) );
   
   // Unpack commit wmsr we
   assign {
      s1o_commit_wmsr_psr_we,
      s1o_commit_wmsr_epc_we,
      s1o_commit_wmsr_epsr_we,
      s1o_commit_wmsr_elsa_we,
      s1o_commit_wmsr_evect_we,
`ifdef NCPU_ENABLE_MSGPORT
      s1o_commit_wmsr_numport_we,
      s1o_commit_wmsr_msgport_we,
`endif
      s1o_commit_msr_imm_tlbl_we,
      s1o_commit_msr_imm_tlbh_we,
      s1o_commit_msr_dmm_tlbl_we,
      s1o_commit_msr_dmm_tlbh_we,
      s1o_commit_msr_irqc_imr_we,
      s1o_commit_msr_tsc_tsr_we,
      s1o_commit_msr_tsc_tcr_we,
      s1o_commit_msr_sr_we,
      s1o_commit_bank_off} = ({NCPU_WMSR_WE_W{p_ce_s2}} & s1o_commit_wmsr_we);

   // Unpack WMSR PSR.
   assign {s1o_wmsr_psr_dce,s1o_wmsr_psr_ice,s1o_wmsr_psr_dmme,s1o_wmsr_psr_imme,s1o_wmsr_psr_ire,s1o_wmsr_psr_rm} = s1o_commit_wmsr_dat[9:4];

   // Save PSR / Restore from EPSR
   assign msr_psr_save = (p_ce_s2 & (s1o_commit_ESYSCALL |
                                    s1o_commit_EITM |
                                    s1o_commit_EIPF |
                                    s1o_commit_EINSN |
                                    s2i_EDTM |
                                    s2i_EDPF |
                                    s2i_EALIGN |
                                    s1o_commit_EIRQ));
   assign msr_psr_restore = (p_ce_s2 & s1o_commit_ERET);
   
   // Commit PSR. Assert (03060934)
   assign msr_psr_rm_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_rm_nxt = s1o_wmsr_psr_rm;
   assign msr_psr_imme_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_imme_nxt = s1o_wmsr_psr_imme;
   assign msr_psr_dmme_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_dmme_nxt = s1o_wmsr_psr_dmme;
   assign msr_psr_ire_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_ire_nxt = s1o_wmsr_psr_ire;
   assign msr_psr_ice_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_ice_nxt = s1o_wmsr_psr_ice;
   assign msr_psr_dce_we = s1o_commit_wmsr_psr_we;
   assign msr_psr_dce_nxt = s1o_wmsr_psr_dce;

   // Commit EPSR
   assign msr_epsr_we = s1o_commit_wmsr_epsr_we;
   assign msr_epsr_nxt = s1o_commit_wmsr_dat[`NCPU_PSR_DW-1:0];
   
   // Commit EPC
   assign msr_epc_nxt = (s1o_commit_wmsr_epc_we)
                           ? s1o_commit_wmsr_dat
                           // EPC stores the next address of syscall instruction 
                           : (s1o_commit_ESYSCALL)
                              ? {s1o_commit_nepc,2'b0}
                              : {s1o_commit_epc,2'b0};
   assign msr_epc_we = (msr_psr_save | s1o_commit_wmsr_epc_we);

   // Commit ELSA  Assert (03100705)
   assign s1o_set_elsa_as_pc = (s1o_commit_EITM | s1o_commit_EIPF | s1o_commit_EINSN);
   assign s1o_set_elsa = (s1o_set_elsa_as_pc | s2i_EDTM | s2i_EDPF | s2i_EALIGN);
   // Let ELSA be PC if it's IMMU or EINSN exception
   assign s1o_lsa_nxt = s1o_set_elsa_as_pc ? {s1o_commit_epc,2'b0} : s2i_vaddr;
   // Assert (03060933)
   assign msr_elsa_nxt = s1o_set_elsa ? s1o_lsa_nxt : s1o_commit_wmsr_dat;
   assign msr_elsa_we = s1o_set_elsa | s1o_commit_wmsr_elsa_we;

   // Commit EVECT
   assign msr_evect_nxt = s1o_commit_wmsr_dat;
   assign msr_evect_we = s1o_commit_wmsr_evect_we;
   
   // Commit IMM
   assign msr_imm_tlbl_idx = s1o_commit_bank_off[CONFIG_ITLB_P_SETS-1:0];
   assign msr_imm_tlbl_nxt = s1o_commit_wmsr_dat;
   assign msr_imm_tlbl_we = s1o_commit_msr_imm_tlbl_we;

   assign msr_imm_tlbh_idx = s1o_commit_bank_off[CONFIG_ITLB_P_SETS-1:0];
   assign msr_imm_tlbh_nxt = s1o_commit_wmsr_dat;
   assign msr_imm_tlbh_we = s1o_commit_msr_imm_tlbh_we;

   // Commit DMM
   assign msr_dmm_tlbl_idx = s1o_commit_bank_off[CONFIG_DTLB_P_SETS-1:0];
   assign msr_dmm_tlbl_nxt = s1o_commit_wmsr_dat;
   assign msr_dmm_tlbl_we = s1o_commit_msr_dmm_tlbl_we;

   assign msr_dmm_tlbh_idx = s1o_commit_bank_off[CONFIG_DTLB_P_SETS-1:0];
   assign msr_dmm_tlbh_nxt = s1o_commit_wmsr_dat;
   assign msr_dmm_tlbh_we = s1o_commit_msr_dmm_tlbh_we;

   // Commit IC
   // Not fire until the pipeline clock is enabled, to avoid interlock between front-end and back-end
   // and avoid repeated operation during pipeline stall.
   assign msr_icinv_we = (s1i_msr_ic_inv_we & p_ce_s1_no_icinv_stall);
   assign msr_icinv_nxt = s1i_msr_wdat;

   // Commit DC
   assign msr_dcinv_we = s1i_msr_dc_inv_we;
   assign msr_dcinv_nxt = s1i_msr_wdat;
   assign msr_dcfls_we = s1i_msr_dc_fls_we;
   assign msr_dcfls_nxt = s1i_msr_wdat;

   // Commit IRQC
   assign msr_irqc_imr_we = s1o_commit_msr_irqc_imr_we;
   assign msr_irqc_imr_nxt = s1o_commit_wmsr_dat;

   // Commit TSC
   assign msr_tsc_tsr_we = s1o_commit_msr_tsc_tsr_we;
   assign msr_tsc_tsr_nxt = s1o_commit_wmsr_dat;
   assign msr_tsc_tcr_we = s1o_commit_msr_tsc_tcr_we;
   assign msr_tsc_tcr_nxt = s1o_commit_wmsr_dat;

   // Commit SR
   assign msr_sr_we = (s1o_commit_bank_off[`NCPU_SR_NUM-1:0] & {`NCPU_SR_NUM{s1o_commit_msr_sr_we}});
   assign msr_sr_nxt = s1o_commit_wmsr_dat;
   
   // Exceptions
   // Assert 2105051856
   assign exc_flush_tgt = ({`PC_W{s2i_EDTM}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EDTM_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s2i_EDPF}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EDPF_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s2i_EALIGN}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EALIGN_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s1o_commit_ESYSCALL}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s1o_commit_ERET}} & msr_epc[`NCPU_P_INSN_LEN +: `PC_W]) |
                           ({`PC_W{s1o_commit_EITM}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s1o_commit_EIPF}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s1o_commit_EIRQ}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]}) |
                           ({`PC_W{s1o_commit_EINSN}} & {s1o_msr_evect[CONFIG_AW-1:`EXCP_VECT_W], CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:`NCPU_P_INSN_LEN]});

   assign exc_flush = p_ce_s2 & (s2i_EDTM |
                        s2i_EDPF |
                        s2i_EALIGN |
                        s1o_commit_ESYSCALL |
                        s1o_commit_ERET |
                        s1o_commit_EITM |
                        s1o_commit_EIPF |
                        s1o_commit_EIRQ |
                        s1o_commit_EINSN);
   
   assign refetch = (p_ce_s2 & s1o_commit_refetch);

   assign epu_wb_valid = (s1o_valid & p_ce_s2);
                        
	// synthesis translate_off
`ifndef SYNTHESIS
`ifdef NCPU_ENABLE_MSGPORT
   always @(posedge clk)
      begin
         if (s1o_commit_wmsr_numport_we)
            $display("Num port = %d", s1o_commit_wmsr_dat);
         if (s1o_commit_wmsr_msgport_we)
            $write("%c", s1o_commit_wmsr_dat[7:0]);
      end
`endif
`endif
   // synthesis translate_on

   cmt_irqc
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

   cmt_tsc
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
`ifdef NCPU_ENABLE_ASSERT

   // Assertions
   always @(posedge clk)
      begin
         // Assertions 03060934
         if ((s1o_commit_EITM + s1o_commit_EIPF +
               s1o_commit_EINSN +
               s1o_commit_ESYSCALL + s1o_commit_ERET +
               s2i_EDTM + s2i_EDPF + s2i_EALIGN +
               s1o_commit_EIRQ +
               s1o_commit_wmsr_psr_we)>'d1)
            $fatal (1, "\n Bugs on exception sources (IMMU, IDU, AGU and DMMU)\n");

         // Assertions 2105051856
         if ((s2i_EDTM +
               s2i_EDPF +
               s2i_EALIGN +
               s1o_commit_ESYSCALL +
               s1o_commit_ERET +
               s1o_commit_EITM +
               s1o_commit_EIPF +
               s1o_commit_EIRQ +
               s1o_commit_EINSN) > 'd1)
            $fatal (1, "Bugs on EPU exceptions");
      end

`endif
`endif
   // synthesis translate_on

endmodule
