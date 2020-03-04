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
   input [`NCPU_DW:0]         linkaddr,
   // PSR
   input [`NCPU_PSR_DW-1:0]   msr_psr,
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
   output                     msr_syscall_ent,
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
   input [`NCPU_PSR_DW-1:0]   msr_elsa,
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
   output                     msr_imm_tlbh_we
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
   
   // Result MUX
   assign ieu_eu_dout =
      (
         ({`NCPU_DW{bank_ps}} & dout_ps) |
         ({`NCPU_DW{bank_imm}} & dout_imm)
      );
   
   ////////////////////////////////////////////////////////////////////////////////
   
   // Writeback PSR
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
   assign {wmsr_psr_res[9],wmsr_psr_res[8],wmsr_psr_dmme,wmsr_psr_imme,wmsr_psr_ire,wmsr_psr_rm,wmsr_psr_res[3],wmsr_psr_res[2], wmsr_psr_res[1],wmsr_psr_cc} = wmsr_operand;

   // Write back PSR
   assign msr_syscall_ent = ieu_syscall;
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
   assign msr_epsr_nxt = wmsr_epsr_we ? wmsr_operand[`NCPU_PSR_DW-1:0] : msr_psr;
   assign msr_epsr_we = commit & (ieu_syscall | wmsr_epsr_we);
   assign msr_epc_nxt = wmsr_epc_we ? wmsr_operand : linkaddr;
   assign msr_epc_we = commit & (ieu_syscall | wmsr_epc_we);
   // Writeback ELSA
   assign msr_elsa_nxt = wmsr_operand;
   assign msr_elsa_we = wmsr_elsa_we;
   
   // Writeback IMM
   assign msr_imm_tlbl_nxt = wmsr_operand;
   assign msr_imm_tlbl_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_imm & msr_imm_tlbl_sel;
   assign msr_imm_tlbh_nxt = wmsr_operand;
   assign msr_imm_tlbh_we = ieu_eu_opc_bus[`NCPU_EU_WMSR] & bank_imm & msr_imm_tlbh_sel;

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (commit & (ieu_ret|ieu_syscall|au_cc_we|wmsr_psr_we) |
                  ~(ieu_ret^ieu_syscall^au_cc_we^wmsr_psr_we)
       )
         $fatal ("\n ctrls of msr_psr writeback MUX should be mutex\n");
   end
`endif

endmodule
