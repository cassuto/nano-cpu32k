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

module ncpu32k_psr
#(
   parameter [7:0] CPUID_VER = 1,
   parameter [9:0] CPUID_REV = 0,
   parameter [0:0] CPUID_FIMM = 1,
   parameter [0:0] CPUID_FDMM = 1,
   parameter [0:0] CPUID_FICA = 0,
   parameter [0:0] CPUID_FDCA = 0,
   parameter [0:0] CPUID_FDBG = 0,
   parameter [0:0] CPUID_FFPU = 0,
   parameter [0:0] CPUID_FIRQC = 1,
   parameter [0:0] CPUID_FTSC = 1
)
(
   input                   clk,
   input                   rst_n,
   // PSR
   input                   msr_exp_ent,
   output [`NCPU_PSR_DW-1:0] msr_psr,
   output [`NCPU_PSR_DW-1:0] msr_psr_nold,
   input                   msr_psr_cc_nxt,
   output                  msr_psr_cc,
   input                   msr_psr_cc_we,
   input                   msr_psr_rm_nxt,
   output                  msr_psr_rm,
   input                   msr_psr_rm_we,
   input                   msr_psr_ire_nxt,
   output                  msr_psr_ire,
   input                   msr_psr_ire_we,
   input                   msr_psr_imme_nxt,
   output                  msr_psr_imme,
   input                   msr_psr_imme_we,
   input                   msr_psr_dmme_nxt,
   output                  msr_psr_dmme,
   input                   msr_psr_dmme_we,
   // CPUID
   output [`NCPU_DW-1:0]   msr_cpuid,
   // EPSR
   input [`NCPU_PSR_DW-1:0] msr_epsr_nxt,
   output [`NCPU_PSR_DW-1:0] msr_epsr,
   input                   msr_epsr_we,
   // EPC
   input [`NCPU_DW-1:0]    msr_epc_nxt,
   output [`NCPU_DW-1:0]   msr_epc,
   input                   msr_epc_we,
   // ELSA
   input [`NCPU_DW-1:0]    msr_elsa_nxt,
   output [`NCPU_DW-1:0]   msr_elsa,
   input                   msr_elsa_we,
   // COREID
   output [`NCPU_DW-1:0]   msr_coreid
);

   wire msr_psr_cc_r;
   wire msr_psr_rm_r;
   wire msr_psr_ire_r;
   wire msr_psr_imme_r;
   wire msr_psr_dmme_r;
   wire [`NCPU_PSR_DW-1:0] msr_epsr_r;
   wire [`NCPU_DW-1:0] msr_epc_r;
   wire [`NCPU_DW-1:0] msr_elsa_r;
   wire psr_rm_set;
   wire psr_imme_msk;
   wire psr_dmme_msk;
   wire psr_ire_msk;
   
   wire psr_ld = msr_exp_ent;
   assign psr_rm_set = msr_exp_ent;
   assign psr_imme_msk = ~msr_exp_ent;
   assign psr_dmme_msk = ~msr_exp_ent;
   assign psr_ire_msk = ~msr_exp_ent;
   
   // Flip-flops
   nDFF_lr #(1) dff_msr_psr_cc (clk, rst_n, msr_psr_cc_we, msr_psr_cc_nxt, msr_psr_cc_r);
   nDFF_lr #(1, 1'b1) dff_msr_psr_rm (clk, rst_n, msr_psr_rm_we|psr_ld, msr_psr_rm_nxt|psr_rm_set, msr_psr_rm_r);
   nDFF_lr #(1) dff_msr_psr_ire (clk, rst_n, msr_psr_ire_we|psr_ld, msr_psr_ire_nxt&psr_ire_msk, msr_psr_ire_r);
   nDFF_lr #(1) dff_msr_psr_imme (clk, rst_n, msr_psr_imme_we|psr_ld, msr_psr_imme_nxt&psr_imme_msk, msr_psr_imme_r);
   nDFF_lr #(1) dff_msr_psr_dmme (clk, rst_n, msr_psr_dmme_we|psr_ld, msr_psr_dmme_nxt&psr_dmme_msk, msr_psr_dmme_r);
   
   nDFF_lr #(`NCPU_PSR_DW) dff_msr_epsr (clk, rst_n, msr_epsr_we, msr_epsr_nxt, msr_epsr_r);
   
   nDFF_lr #(`NCPU_DW) dff_msr_epc (clk, rst_n, msr_epc_we, msr_epc_nxt, msr_epc_r);
   
   nDFF_lr #(`NCPU_DW) dff_msr_elsa (clk, rst_n, msr_elsa_we, msr_elsa_nxt, msr_elsa_r);
   
   // MSR Bypass
   assign msr_psr_cc = (msr_psr_cc_we ? msr_psr_cc_nxt : msr_psr_cc_r);
   // Not bypass the data loaded by psr_ld
   wire msr_psr_rm_nold = (msr_psr_rm_we ? msr_psr_rm_nxt : msr_psr_rm_r);
   wire msr_psr_ire_nold = (msr_psr_ire_we ? msr_psr_ire_nxt : msr_psr_ire_r);
   wire msr_psr_imme_nold = (msr_psr_imme_we ? msr_psr_imme_nxt : msr_psr_imme_r);
   wire msr_psr_dmme_nold = (msr_psr_dmme_we ? msr_psr_dmme_nxt : msr_psr_dmme_r);
   // bypass the data loaded by psr_ld
   assign msr_psr_rm = (msr_psr_rm_we|psr_ld ? msr_psr_rm_nxt|psr_rm_set : msr_psr_rm_r);
   assign msr_psr_ire = (msr_psr_ire_we|psr_ld ? msr_psr_ire_nxt&psr_ire_msk : msr_psr_ire_r);
   assign msr_psr_imme = (msr_psr_imme_we|psr_ld ? msr_psr_imme_nxt&psr_imme_msk : msr_psr_imme_r);
   assign msr_psr_dmme = (msr_psr_dmme_we|psr_ld ? msr_psr_dmme_nxt&psr_dmme_msk : msr_psr_dmme_r);
   
   assign msr_epsr = (msr_epsr_we ? msr_epsr_nxt : msr_epsr_r);
   assign msr_epc = (msr_epc_we ? msr_epc_nxt : msr_epc_r);
   assign msr_elsa = (msr_elsa_we ? msr_elsa_nxt : msr_elsa_r);
   
   // PSR Pack
   assign msr_psr = {1'b0,1'b0,msr_psr_dmme,msr_psr_imme,msr_psr_ire,msr_psr_rm,1'b0,1'b0,1'b0,msr_psr_cc};
   assign msr_psr_nold = {1'b0,1'b0,msr_psr_dmme_nold,msr_psr_imme_nold,msr_psr_ire_nold,msr_psr_rm_nold,1'b0,1'b0,1'b0,msr_psr_cc};
   
   // CPUID
   assign msr_cpuid = {CPUID_FTSC,CPUID_FIRQC,CPUID_FFPU,CPUID_FDBG,CPUID_FDCA,CPUID_FICA,CPUID_FDMM,CPUID_FIMM,CPUID_REV[9:0],CPUID_VER[7:0]};
   
   // COREID
   assign msr_coreid = {`NCPU_DW{1'b0}};
   
endmodule
