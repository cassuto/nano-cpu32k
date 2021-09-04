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

module immu
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_IMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_ITLB_P_SETS = 0
)
(
   input                               clk,
   input                               rst,
   input                               re,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] vpn,
   output [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn,
   output                              EITM,
   output                              EIPF,
   output                              uncached,
   // PSR
   input                               msr_psr_imme,
   input                               msr_psr_rm,
   // IMMID
   output [CONFIG_DW-1:0]              msr_immid,
   // TLBL
   input [CONFIG_ITLB_P_SETS-1:0]      msr_imm_tlbl_idx,
   input [CONFIG_DW-1:0]               msr_imm_tlbl_nxt,
   input                               msr_imm_tlbl_we,
   // TLBH
   input [CONFIG_ITLB_P_SETS-1:0]      msr_imm_tlbh_idx,
   input [CONFIG_DW-1:0]               msr_imm_tlbh_nxt,
   input                               msr_imm_tlbh_we
);

   // VPN shift bit
   localparam VPN_SHIFT                = CONFIG_P_PAGE_SIZE;
   // PPN shift bit
   localparam PPN_SHIFT                = VPN_SHIFT;
   // Bitwidth of Virtual Page Number
   localparam VPN_DW                   = CONFIG_AW-VPN_SHIFT;
   // Bitwidth of Physical Page Number
   localparam PPN_DW                   = CONFIG_AW-PPN_SHIFT;

   // MSR.IMMID
   assign msr_immid = {{32-3{1'b0}}, CONFIG_ITLB_P_SETS[2:0]};

   // TLB
   wire                                msr_psr_imme_ff;
   wire                                msr_psr_rm_ff;
   wire [VPN_DW-1:0]                   tgt_vpn_ff;
   wire [CONFIG_DW-1:0]                tlb_l_ff;
   wire [CONFIG_DW-1:0]                tlb_h_ff;

   wire [VPN_DW-1:0] tgt_vpn_nxt = vpn[VPN_DW-1:0];
   // Assert (03061058)
   wire [CONFIG_ITLB_P_SETS-1:0] tgt_index_nxt = tgt_vpn_nxt[CONFIG_ITLB_P_SETS-1:0];

   mDFF_lr #(.DW(1)) ff_msr_psr_imme (.CLK(clk),.RST(rst), .LOAD(re), .D(msr_psr_imme), .Q(msr_psr_imme_ff) );
   mDFF_lr #(.DW(1)) ff_msr_psr_rm (.CLK(clk),.RST(rst), .LOAD(re), .D(msr_psr_rm), .Q(msr_psr_rm_ff) );
   mDFF_lr #(.DW(VPN_DW)) ff_tgt_vpn (.CLK(clk),.RST(rst), .LOAD(re), .D(tgt_vpn_nxt), .Q(tgt_vpn_ff) );

   // Instance of lower-part TLB
   mRF_nwnr
      #(
         .DW      (CONFIG_DW),
         .AW      (CONFIG_ITLB_P_SETS),
         .NUM_READ (1),
         .NUM_WRITE (1)
      )
   U_TLB_L
      (
         .CLK     (clk),
         .RE      (re),
         .RADDR   (tgt_index_nxt),
         .RDATA   (tlb_l_ff),
         .WE      (msr_imm_tlbl_we),
         .WADDR   (msr_imm_tlbl_idx),
         .WDATA   (msr_imm_tlbl_nxt)
      );

   // Instance of higher-part TLB
   mRF_nwnr
      #(
         .DW      (CONFIG_DW),
         .AW      (CONFIG_ITLB_P_SETS),
         .NUM_READ (1),
         .NUM_WRITE (1)
      )
   U_TLB_H
      (
         .CLK     (clk),
         .RE      (re),
         .RADDR   (tgt_index_nxt),
         .RDATA   (tlb_h_ff),
         .WE      (msr_imm_tlbh_we),
         .WADDR   (msr_imm_tlbh_idx),
         .WDATA   (msr_imm_tlbh_nxt)
      );

   wire tlb_v = tlb_l_ff[0];
   wire [VPN_DW-1:0] tlb_vpn = tlb_l_ff[CONFIG_DW-1:CONFIG_DW-VPN_DW];
   wire tlb_p = tlb_h_ff[0];
   wire tlb_ux = tlb_h_ff[3];
   wire tlb_rx = tlb_h_ff[4];
   wire tlb_unc = tlb_h_ff[7];
   wire tlb_s = tlb_h_ff[8];
   wire [PPN_DW-1:0] tlb_ppn = tlb_h_ff[CONFIG_DW-1:CONFIG_DW-PPN_DW];
   wire perm_denied;
   wire tlb_miss;

   assign perm_denied =
      (
         // In root-mode
         (msr_psr_rm_ff & ~tlb_rx) |
         // In user-mode
         (~msr_psr_rm_ff & ~tlb_ux)
      );

   // TLB miss exception
   assign tlb_miss = ~(tlb_v & tlb_vpn == tgt_vpn_ff);
   assign EITM = (tlb_miss & msr_psr_imme_ff);

   // Permission check, Page Fault exception
   assign EIPF = (perm_denied & ~tlb_miss & msr_psr_imme_ff);

   assign ppn = msr_psr_imme_ff ? tlb_ppn : tgt_vpn_ff;

   // If DMMU is disabled, UNC bit in page entry is not functioned.
   // Uncached segment is always functioned as long as physical addr is valid
   // and is within 0x80000000~0x8FFFFFFF
generate
   if (CONFIG_IMMU_ENABLE_UNCACHED_SEG)
      assign uncached = (msr_psr_imme_ff & ~tlb_miss & ~perm_denied & tlb_unc) | (~EITM & ~EIPF & (ppn[CONFIG_AW-CONFIG_P_PAGE_SIZE-1 -: 4]==4'h8));
   else
      assign uncached = (msr_psr_imme_ff & ~tlb_miss & ~perm_denied & tlb_unc);
endgenerate
   
   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
   initial
      begin
         // Assertion (03061058)
         if (!(CONFIG_ITLB_P_SETS <= VPN_DW))
            $fatal (0, "\n CONFIG_ITLB_P_SETS should <= VPN_DW\n");
      end
      
   always @(posedge clk)
      if (EITM & EIPF)
         $fatal ("\n EITM and EIPF should be mutex\n");

`endif
   // synthesis translate_on

endmodule
