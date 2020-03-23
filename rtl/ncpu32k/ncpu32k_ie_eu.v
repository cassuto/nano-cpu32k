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

module ncpu32k_ie_eu
(         
   input                      clk,
   input                      rst_n,
   input [`NCPU_EU_IOPW-1:0]  ieu_eu_opc_bus,
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_DW-1:0]       ieu_operand_3,
   output                     ieu_eu_dout_op,
   output [`NCPU_DW-1:0]      ieu_eu_dout,
   input                      commit,
   input                      au_cc_we,
   input                      au_cc_nxt,
   input                      ieu_ret,
   input                      ieu_syscall,
   input [`NCPU_AW-3:0]       ieu_insn_pc,
   input                      ieu_emu_insn,
   input                      ieu_specul_extexp,
   input                      ieu_let_lsa_pc,
   input                      mu_exp_taken,
   input [`NCPU_DW-1:0]       mu_lsa,
   input [`NCPU_DW-1:0]       linkaddr,
   // PSR
   input [`NCPU_PSR_DW-1:0]   msr_psr,
   input [`NCPU_PSR_DW-1:0]   msr_psr_nold,
   output                     msr_psr_cc_nxt,
   output                     msr_psr_cc_we,
   output                     msr_psr_rm_nxt,
   output                     msr_psr_rm_we,
   output                     msr_psr_imme_nxt,
   output                     msr_psr_imme_we,
   output                     msr_psr_dmme_nxt,
   output                     msr_psr_dmme_we,
   output                     msr_psr_ire_nxt,
   output                     msr_psr_ire_we,
   output                     msr_exp_ent,
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
   input [`NCPU_DW-1:0]       msr_imm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbl_nxt,
   output                     msr_imm_tlbl_we,
   // ITLBH
   input [`NCPU_DW-1:0]       msr_imm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbh_nxt,
   output                     msr_imm_tlbh_we,
   // DMMID
   input [`NCPU_DW-1:0]       msr_dmmid,
   // DTLBL
   input [`NCPU_DW-1:0]       msr_dmm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_dmm_tlbl_nxt,
   output                     msr_dmm_tlbl_we,
   // DTLBH
   input [`NCPU_DW-1:0]       msr_dmm_tlbh,
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

   wire [`NCPU_DW-1:0] msr_addr = ieu_operand_1 + ieu_operand_2;
   wire [`NCPU_MSR_BANK_AW-1:0] bank_addr = msr_addr[`NCPU_MSR_BANK_AW+`NCPU_MSR_BANK_OFF_AW-1:`NCPU_MSR_BANK_OFF_AW];
   wire [`NCPU_MSR_BANK_OFF_AW-1:0] bank_off = msr_addr[`NCPU_MSR_BANK_OFF_AW-1:0];
   
   // Decode MSR bank_addr
   wire bank_ps = (bank_addr == `NCPU_MSR_BANK_PS);
   wire bank_imm = (bank_addr == `NCPU_MSR_BANK_IMM);
   wire bank_dmm = (bank_addr == `NCPU_MSR_BANK_DMM);
   wire bank_ica = (bank_addr == `NCPU_MSR_BANK_ICA);
   wire bank_dca = (bank_addr == `NCPU_MSR_BANK_DCA);
   wire bank_dbg = (bank_addr == `NCPU_MSR_BANK_DBG);
   wire bank_irqc = (bank_addr == `NCPU_MSR_BANK_IRQC);
   wire bank_tsc = (bank_addr == `NCPU_MSR_BANK_TSC);
   
   assign ieu_eu_dout_op = ieu_eu_opc_bus[`NCPU_EU_RMSR];
   
   // Readout PS
   wire [`NCPU_DW-1:0] dout_ps =
      (
         ({`NCPU_DW{bank_off[`NCPU_MSR_PSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_psr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_CPUID]}} & msr_cpuid) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_epsr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPC]}} & msr_epc) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_ELSA]}} & msr_elsa) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_COREID]}} & msr_coreid)
      );

   // Readout IMM
   wire msr_imm_tlbl_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & ~bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   wire msr_imm_tlbh_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   wire [`NCPU_DW-1:0] dout_imm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_IMM_TLBSEL]}} & msr_immid) |
         ({`NCPU_DW{msr_imm_tlbl_sel}} & msr_imm_tlbl) |
         ({`NCPU_DW{msr_imm_tlbh_sel}} & msr_imm_tlbh)
      );
   assign msr_imm_tlbl_idx = bank_off[`NCPU_TLB_AW-1:0];
   assign msr_imm_tlbh_idx = bank_off[`NCPU_TLB_AW-1:0];
   
   // Readout DMM
   wire msr_dmm_tlbl_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & ~bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   wire msr_dmm_tlbh_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   wire [`NCPU_DW-1:0] dout_dmm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_DMM_TLBSEL]}} & msr_dmmid) |
         ({`NCPU_DW{msr_dmm_tlbl_sel}} & msr_dmm_tlbl) |
         ({`NCPU_DW{msr_dmm_tlbh_sel}} & msr_dmm_tlbh)
      );
   assign msr_dmm_tlbl_idx = bank_off[`NCPU_TLB_AW-1:0];
   assign msr_dmm_tlbh_idx = bank_off[`NCPU_TLB_AW-1:0];
   
   // Readout IRQC
   wire msr_irqc_imr_sel = bank_off[`NCPU_MSR_IRQC_IMR];
   wire msr_irqc_irr_sel = bank_off[`NCPU_MSR_IRQC_IRR];
   wire [`NCPU_DW-1:0] dout_irqc =
      (
         ({`NCPU_DW{msr_irqc_imr_sel}} & msr_irqc_imr) |
         ({`NCPU_DW{msr_irqc_irr_sel}} & msr_irqc_irr)
      );
   
   // Readout TSC
   wire msr_tsc_tsr_sel = bank_off[`NCPU_MSR_TSC_TSR];
   wire msr_tsc_tcr_sel = bank_off[`NCPU_MSR_TSC_TCR];
   wire [`NCPU_DW-1:0] dout_tsc =
      (
         ({`NCPU_DW{msr_tsc_tsr_sel}} & msr_tsc_tsr) |
         ({`NCPU_DW{msr_tsc_tcr_sel}} & msr_tsc_tcr)
      );
   
   // Result MUX
   assign ieu_eu_dout =
      (
         ({`NCPU_DW{bank_ps}} & dout_ps) |
         ({`NCPU_DW{bank_imm}} & dout_imm) |
         ({`NCPU_DW{bank_dmm}} & dout_dmm) |
         ({`NCPU_DW{bank_irqc}} & dout_irqc) |
         ({`NCPU_DW{bank_tsc}} & dout_tsc)
      );
   
   ////////////////////////////////////////////////////////////////////////////////
   
   // Decode MSR address
   wire [`NCPU_DW-1:0] wmsr_operand = ieu_operand_3;
   wire wmsr_psr_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_ps & bank_off[`NCPU_MSR_PSR];
   wire wmsr_epc_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPC];
   wire wmsr_epsr_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPSR];
   wire wmsr_elsa_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_ps & bank_off[`NCPU_MSR_ELSA];

   // Unpack EPSR. Be consistend with ncpu32k_psr
   wire epsr_cc;
   wire epsr_rm;
   wire epsr_ire;
   wire epsr_imme;
   wire epsr_dmme;
   wire [9:0] epsr_res;
   assign {epsr_res[9],epsr_res[8],epsr_dmme,epsr_imme,epsr_ire,epsr_rm,epsr_res[3],epsr_res[2], epsr_res[1],epsr_cc} = msr_epsr;
   
   // Unpack WMSR PSR. Be consistend with ncpu32k_psr
   wire wmsr_psr_cc;
   wire wmsr_psr_rm;
   wire wmsr_psr_ire;
   wire wmsr_psr_imme;
   wire wmsr_psr_dmme;
   wire [9:0] wmsr_psr_res;
   assign {wmsr_psr_res[9],wmsr_psr_res[8],wmsr_psr_dmme,wmsr_psr_imme,wmsr_psr_ire,wmsr_psr_rm,wmsr_psr_res[3],wmsr_psr_res[2], wmsr_psr_res[1],wmsr_psr_cc} = wmsr_operand[9:0];

   // Write back PSR Assert (03060934)
   wire extexp_taken = ieu_specul_extexp | mu_exp_taken | ieu_emu_insn;
   assign msr_exp_ent = commit & (ieu_syscall | extexp_taken);
   assign msr_psr_cc_nxt = au_cc_we ? au_cc_nxt : wmsr_psr_we ? wmsr_psr_cc : epsr_cc;
   assign msr_psr_cc_we = commit & (ieu_ret | au_cc_we | wmsr_psr_we);
   assign msr_psr_rm_nxt = wmsr_psr_we ? wmsr_psr_rm : epsr_rm;
   assign msr_psr_rm_we = commit & (ieu_ret | wmsr_psr_we);
   assign msr_psr_imme_nxt = wmsr_psr_we ? wmsr_psr_imme : epsr_imme;
   assign msr_psr_imme_we = commit & (ieu_ret | wmsr_psr_we);
   assign msr_psr_dmme_nxt = wmsr_psr_we ? wmsr_psr_dmme : epsr_dmme;
   assign msr_psr_dmme_we = commit & (ieu_ret | wmsr_psr_we);
   assign msr_psr_ire_nxt = wmsr_psr_we ? wmsr_psr_ire : epsr_ire;
   assign msr_psr_ire_we = commit & (ieu_ret | wmsr_psr_we);
   // Writeback EPSR
   assign msr_epsr_nxt = wmsr_epsr_we ? wmsr_operand[`NCPU_PSR_DW-1:0] : msr_psr_nold;
   assign msr_epsr_we = commit & (msr_exp_ent | wmsr_epsr_we);
   // In syscall, EPC is the next insn of syscall, while in general EPC is the insn
   // that raised the exception.
   assign msr_epc_nxt = wmsr_epc_we ? wmsr_operand : extexp_taken ? {ieu_insn_pc,2'b0} : linkaddr;
   assign msr_epc_we = commit & (extexp_taken | ieu_syscall | wmsr_epc_we);
   
   // Writeback ELSA  Assert (03100705)
   wire set_elsa = ieu_let_lsa_pc | mu_exp_taken;
   wire [`NCPU_DW-1:0] lsa_nxt =
      (
         ({`NCPU_DW{ieu_let_lsa_pc}} & {ieu_insn_pc,2'b0}) |
         ({`NCPU_DW{mu_exp_taken}} & mu_lsa)
      );
   // Assert (03060933)
   assign msr_elsa_nxt = set_elsa ? lsa_nxt : wmsr_operand;
   assign msr_elsa_we = commit & (set_elsa | wmsr_elsa_we);
   
   wire wmsr_commit_we = commit & ieu_eu_opc_bus[`NCPU_EU_WMSR];
   
   // Writeback IMM
   assign msr_imm_tlbl_nxt = wmsr_operand;
   assign msr_imm_tlbl_we = wmsr_commit_we & bank_imm & msr_imm_tlbl_sel;
   assign msr_imm_tlbh_nxt = wmsr_operand;
   assign msr_imm_tlbh_we = wmsr_commit_we & bank_imm & msr_imm_tlbh_sel;

   // Writeback DMM
   assign msr_dmm_tlbl_nxt = wmsr_operand;
   assign msr_dmm_tlbl_we = wmsr_commit_we & bank_dmm & msr_dmm_tlbl_sel;
   assign msr_dmm_tlbh_nxt = wmsr_operand;
   assign msr_dmm_tlbh_we = wmsr_commit_we & bank_dmm & msr_dmm_tlbh_sel;

   // Writeback IRQC
   assign msr_irqc_imr_we = wmsr_commit_we & bank_irqc & msr_irqc_imr_sel;
   assign msr_irqc_imr_nxt = wmsr_operand;
   
   // Writeback TSC
   assign msr_tsc_tsr_we = wmsr_commit_we & bank_tsc & msr_tsc_tsr_sel;
   assign msr_tsc_tsr_nxt = wmsr_operand;
   assign msr_tsc_tcr_we = wmsr_commit_we & bank_tsc & msr_tsc_tcr_sel;
   assign msr_tsc_tcr_nxt = wmsr_operand;
   
	 // synthesis translate_off
`ifndef SYNTHESIS
   wire dbg_numport_sel = bank_off[0];
   wire dbg_msgport_sel = bank_off[1];
   always @(posedge clk) begin
      if (wmsr_commit_we & bank_dbg & dbg_numport_sel)
         $display("Num port = %d", wmsr_operand);
      if (wmsr_commit_we & bank_dbg & dbg_msgport_sel)
         $write("%c", wmsr_operand[7:0]);
   end
`endif
   // synthesis translate_on
   
   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions 03060934
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (commit & (ieu_ret|ieu_syscall|ieu_specul_extexp|mu_exp_taken|au_cc_we|wmsr_psr_we) &
                  ~(ieu_ret^ieu_syscall^ieu_specul_extexp^mu_exp_taken^au_cc_we^wmsr_psr_we)
       )
         $fatal ("\n ctrls of msr_psr writeback MUX should be mutex\n");
   end
`endif

   // Assertions 03060933
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (commit & (wmsr_elsa_we|set_elsa) &
                  ~(wmsr_elsa_we^set_elsa)
       )
         $fatal ("\n ctrls of 'msr_elsa_nxt' MUX should be mutex\n");
   end
`endif

   // Assertions 03100705
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (commit & (ieu_let_lsa_pc|mu_exp_taken) &
                  ~(ieu_let_lsa_pc^mu_exp_taken)
       )
         $fatal ("\n ctrls of 'set_elsa' should be mutex\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
