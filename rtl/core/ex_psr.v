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

module ex_psr
#(
   parameter                           CONFIG_DW = 0,
   parameter [7:0]                     CPUID_VER = 1,
   parameter [9:0]                     CPUID_REV = 0,
   parameter [0:0]                     CPUID_FIMM = 1,
   parameter [0:0]                     CPUID_FDMM = 1,
   parameter [0:0]                     CPUID_FICA = 0,
   parameter [0:0]                     CPUID_FDCA = 0,
   parameter [0:0]                     CPUID_FDBG = 0,
   parameter [0:0]                     CPUID_FFPU = 0,
   parameter [0:0]                     CPUID_FIRQC = 1,
   parameter [0:0]                     CPUID_FTSC = 1
)
(
   input                               clk,
   input                               rst,
   // PSR
   input                               msr_psr_save,
   input                               msr_psr_restore,
   output [`NCPU_PSR_DW-1:0]           msr_psr,
   input                               msr_psr_rm_nxt,
   output                              msr_psr_rm,
   input                               msr_psr_rm_we,
   input                               msr_psr_ire_nxt,
   output                              msr_psr_ire,
   input                               msr_psr_ire_we,
   input                               msr_psr_imme_nxt,
   output                              msr_psr_imme,
   input                               msr_psr_imme_we,
   input                               msr_psr_dmme_nxt,
   output                              msr_psr_dmme,
   input                               msr_psr_dmme_we,
   input                               msr_psr_ice_nxt,
   output                              msr_psr_ice,
   input                               msr_psr_ice_we,
   input                               msr_psr_dce_nxt,
   output                              msr_psr_dce,
   input                               msr_psr_dce_we,
   // CPUID
   output [CONFIG_DW-1:0]              msr_cpuid,
   // EPSR
   input [`NCPU_PSR_DW-1:0]            msr_epsr_nxt,
   output [`NCPU_PSR_DW-1:0]           msr_epsr,
   input                               msr_epsr_we,
   // EPC
   input [CONFIG_DW-1:0]               msr_epc_nxt,
   output [CONFIG_DW-1:0]              msr_epc,
   input                               msr_epc_we,
   // ELSA
   input [CONFIG_DW-1:0]               msr_elsa_nxt,
   output [CONFIG_DW-1:0]              msr_elsa,
   input                               msr_elsa_we,
   // COREID
   output [CONFIG_DW-1:0]              msr_coreid,
   // EVECT
   input [CONFIG_DW-1:0]               msr_evect_nxt,
   output [CONFIG_DW-1:0]              msr_evect,
   input                               msr_evect_we,
   // SR
   output [CONFIG_DW*`NCPU_SR_NUM-1:0] msr_sr,
   input [CONFIG_DW-1:0]               msr_sr_nxt,
   input [`NCPU_SR_NUM-1:0]            msr_sr_we
);

   wire                                msr_psr_rm_ff;
   wire                                msr_psr_ire_ff;
   wire                                msr_psr_imme_ff;
   wire                                msr_psr_dmme_ff;
   wire                                msr_psr_rm_nold;
   wire                                msr_psr_ire_nold;
   wire                                msr_psr_imme_nold;
   wire                                msr_psr_dmme_nold;
   wire                                msr_psr_ice_ff;
   wire                                msr_psr_dce_ff;
   wire [`NCPU_PSR_DW-1:0]             msr_psr_nold;
   wire [`NCPU_PSR_DW-1:0]             msr_epsr_ff;
   wire [CONFIG_DW-1:0]                msr_epc_ff;
   wire [CONFIG_DW-1:0]                msr_elsa_ff;
   wire [CONFIG_DW-1:0]                msr_evect_ff;
   wire [CONFIG_DW*`NCPU_SR_NUM-1:0]   msr_sr_ff;
   wire                                psr_rm_set;
   wire                                psr_imme_msk;
   wire                                psr_dmme_msk;
   wire                                psr_ire_msk;
   wire                                psr_ld;
   wire                                psr_rm_we;
   wire                                psr_rm_nxt;
   wire                                psr_imme_we;
   wire                                psr_imme_nxt;
   wire                                psr_dmme_we;
   wire                                psr_dmme_nxt;
   wire                                psr_ire_we;
   wire                                psr_ire_nxt;
   wire                                epsr_we;
   wire [`NCPU_PSR_DW-1:0]             epsr_nxt;
   wire                                epsr_rm_nold;
   wire                                epsr_ire_nold;
   wire                                epsr_imme_nold;
   wire                                epsr_dmme_nold;
   genvar                              i;
   
   // Save PSR
   assign psr_ld = msr_psr_save;
   assign psr_rm_set = msr_psr_save;
   assign psr_imme_msk = ~msr_psr_save;
   assign psr_dmme_msk = ~msr_psr_save;
   assign psr_ire_msk = ~msr_psr_save;
   assign epsr_we = (msr_epsr_we | msr_psr_save);
   assign epsr_nxt = msr_psr_save ? msr_psr_nold : msr_epsr_nxt;
   
   // Restore PSR
   assign psr_rm_we = (msr_psr_rm_we | msr_psr_restore);
   assign psr_rm_nxt = (msr_psr_restore) ? epsr_rm_nold : msr_psr_rm_nxt;
   assign psr_imme_we = (msr_psr_imme_we | msr_psr_restore);
   assign psr_imme_nxt = (msr_psr_restore) ? epsr_imme_nold : msr_psr_imme_nxt;
   assign psr_dmme_we = (msr_psr_dmme_we | msr_psr_restore);
   assign psr_dmme_nxt = (msr_psr_restore) ? epsr_dmme_nold : msr_psr_dmme_nxt;
   assign psr_ire_we = (msr_psr_ire_we | msr_psr_restore);
   assign psr_ire_nxt = (msr_psr_restore) ? epsr_ire_nold : msr_psr_ire_nxt;

   // Flip-flops
   // PSR
   mDFF_lr #(.DW(1), .RST_VECTOR(1'b1)) ff_msr_psr_rm (.CLK(clk), .RST(rst), .LOAD(psr_rm_we|psr_ld), .D(psr_rm_nxt|psr_rm_set), .Q(msr_psr_rm_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_ire (.CLK(clk), .RST(rst), .LOAD(psr_ire_we|psr_ld), .D(psr_ire_nxt&psr_ire_msk), .Q(msr_psr_ire_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_imme (.CLK(clk), .RST(rst), .LOAD(psr_imme_we|psr_ld), .D(psr_imme_nxt&psr_imme_msk), .Q(msr_psr_imme_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_dmme (.CLK(clk), .RST(rst), .LOAD(psr_dmme_we|psr_ld), .D(psr_dmme_nxt&psr_dmme_msk), .Q(msr_psr_dmme_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_ice (.CLK(clk), .RST(rst), .LOAD(msr_psr_ice_we), .D(msr_psr_ice_nxt), .Q(msr_psr_ice_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_dce (.CLK(clk), .RST(rst), .LOAD(msr_psr_dce_we), .D(msr_psr_dce_nxt), .Q(msr_psr_dce_ff) );
   // EPSR
   mDFF_lr #(.DW(`NCPU_PSR_DW)) ff_msr_epsr (.CLK(clk), .RST(rst), .LOAD(epsr_we), .D(epsr_nxt), .Q(msr_epsr_ff) );
   // EPC
   mDFF_lr #(.DW(CONFIG_DW)) ff_msr_epc (.CLK(clk), .RST(rst), .LOAD(msr_epc_we), .D(msr_epc_nxt), .Q(msr_epc_ff) );
   // ELSA
   mDFF_lr #(.DW(CONFIG_DW)) dff_msr_elsa (.CLK(clk), .RST(rst), .LOAD(msr_elsa_we), .D(msr_elsa_nxt), .Q(msr_elsa_ff) );
   // EVECT
   mDFF_lr #(.DW(CONFIG_DW)) dff_msr_evect (.CLK(clk), .RST(rst), .LOAD(msr_evect_we), .D(msr_evect_nxt), .Q(msr_evect_ff) );
   // SR
   generate
      for(i=0;i<`NCPU_SR_NUM;i=i+1)
         mDFF_l #(.DW(CONFIG_DW)) dff_sr (.CLK(clk), .LOAD(msr_sr_we[i]), .D(msr_sr_nxt), .Q(msr_sr_ff[i*CONFIG_DW +: CONFIG_DW]) );
   endgenerate
   
   // Bypass logic for PSR
   assign msr_psr_rm = (psr_rm_we|psr_ld) ? (psr_rm_nxt|psr_rm_set) : msr_psr_rm_ff;
   assign msr_psr_ire = (psr_ire_we|psr_ld) ? (psr_ire_nxt&psr_ire_msk) : msr_psr_ire_ff;
   assign msr_psr_imme = (psr_imme_we|psr_ld) ? (psr_imme_nxt&psr_imme_msk) : msr_psr_imme_ff;
   assign msr_psr_dmme = (psr_dmme_we|psr_ld) ? (psr_dmme_nxt&psr_dmme_msk) : msr_psr_dmme_ff;

   // Bypass (not include `psr_ld`)
   assign msr_psr_rm_nold = (psr_rm_we) ? psr_rm_nxt : msr_psr_rm_ff;
   assign msr_psr_ire_nold = (psr_ire_we) ? psr_ire_nxt : msr_psr_ire_ff;
   assign msr_psr_imme_nold = (psr_imme_we) ? psr_imme_nxt : msr_psr_imme_ff;
   assign msr_psr_dmme_nold = (psr_dmme_we) ? psr_dmme_nxt : msr_psr_dmme_ff;
   assign msr_psr_ice = (msr_psr_ice_we) ? (msr_psr_ice_nxt) : msr_psr_ice_ff;
   assign msr_psr_dce = (msr_psr_dce_we) ? (msr_psr_dce_nxt) : msr_psr_dce_ff;
   
   // Bypass logic for E*
   assign msr_epsr = epsr_we ? epsr_nxt : msr_epsr_ff;
   assign msr_epc = msr_epc_we ? msr_epc_nxt : msr_epc_ff;
   assign msr_elsa = msr_elsa_we ? msr_elsa_nxt : msr_elsa_ff;
   assign msr_evect = msr_evect_we ? msr_evect_nxt : msr_evect_ff;
   
   // Bypass logic for SR
   generate
      for(i=0;i<`NCPU_SR_NUM;i=i+1)
         assign msr_sr[i*CONFIG_DW +: CONFIG_DW] = (msr_sr_we[i]) ? msr_sr_nxt : msr_sr_ff[i*CONFIG_DW +: CONFIG_DW];
   endgenerate

   // Pack PSR
   assign msr_psr = {msr_psr_dce,msr_psr_ice,msr_psr_dmme,msr_psr_imme,msr_psr_ire,msr_psr_rm,1'b0,1'b0,1'b0,1'b0};

   assign msr_psr_nold = {msr_psr_dce,msr_psr_ice,msr_psr_dmme_nold,msr_psr_imme_nold,msr_psr_ire_nold,msr_psr_rm_nold,1'b0,1'b0,1'b0,1'b0};

   // Unpack EPSR
   assign {epsr_dmme_nold,epsr_imme_nold,epsr_ire_nold,epsr_rm_nold} = msr_epsr_ff[7:4];
   
   // CPUID
   assign msr_cpuid = {{CONFIG_DW-26{1'b0}},CPUID_FTSC,CPUID_FIRQC,CPUID_FFPU,CPUID_FDBG,CPUID_FDCA,CPUID_FICA,CPUID_FDMM,CPUID_FIMM,CPUID_REV[9:0],CPUID_VER[7:0]};

   // COREID
   assign msr_coreid = {CONFIG_DW{1'b0}};

endmodule
