/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_dmmu
#(
   parameter CONFIG_DMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED , // = log2(Size of a page in bytes)
   parameter CONFIG_DMMU_ENABLE_UNCACHED_SEG
   `PARAM_NOT_SPECIFIED , // 0x80000000 segment
   parameter CONFIG_DTLB_NSETS_LOG2
   `PARAM_NOT_SPECIFIED // (2^CONFIG_DTLB_NSETS_LOG2) entries
)
(
   input                   clk,
   input                   rst_n,
   input                   re,
   input [`NCPU_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] vpn,
   input                   we,
   output [`NCPU_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] ppn,
   output                  EDTM,
   output                  EDPF,
   output                  uncached,
   // PSR
   input                   msr_psr_dmme,
   input                   msr_psr_rm,
   // DMMID
   output [`NCPU_DW-1:0]   msr_dmmid,
   // DTLBL
   input [`NCPU_TLB_AW-1:0] msr_dmm_tlbl_idx,
   input [`NCPU_DW-1:0]    msr_dmm_tlbl_nxt,
   input                   msr_dmm_tlbl_we,
   // DTLBH
   input [`NCPU_TLB_AW-1:0] msr_dmm_tlbh_idx,
   input [`NCPU_DW-1:0]    msr_dmm_tlbh_nxt,
   input                   msr_dmm_tlbh_we
);

   // VPN shift bit
   localparam VPN_SHIFT = CONFIG_DMMU_PAGE_SIZE_LOG2;
   // PPN shift bit
   localparam PPN_SHIFT = VPN_SHIFT;
   // Bitwidth of Virtual Page Number
   localparam VPN_DW = `NCPU_AW-VPN_SHIFT;
   // Bitwidth of Physical Page Number
   localparam PPN_DW = `NCPU_AW-PPN_SHIFT;

   // MSR.DMMID
   assign msr_dmmid = {{32-3{1'b0}}, CONFIG_DTLB_NSETS_LOG2[2:0]};

   // TLB
   wire msr_psr_dmme_r;
   wire msr_psr_rm_r;
   wire we_r;
   wire [VPN_DW-1:0] tgt_vpn_r;
   wire [`NCPU_DW-1:0] tlb_l_r;
   wire [`NCPU_DW-1:0] tlb_h_r;

   // Assert (03091855)
   wire [CONFIG_DTLB_NSETS_LOG2-1:0] tgt_index_nxt = vpn[CONFIG_DTLB_NSETS_LOG2-1:0];

   nDFF_lr #(1) dff_msr_psr_dmme_r
      (clk,rst_n, re, msr_psr_dmme, msr_psr_dmme_r);
   nDFF_lr #(1) dff_msr_psr_rm_r
      (clk,rst_n, re, msr_psr_rm, msr_psr_rm_r);
   nDFF_lr #(1) dff_dbus_cmd_we_r
      (clk,rst_n, re, we, we_r);
   nDFF_lr #(VPN_DW) dff_tgt_vpn_r
      (clk,rst_n, re, vpn[VPN_DW-1:0], tgt_vpn_r[VPN_DW-1:0]);

   // Instance of lowpart TLB
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (CONFIG_DTLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS (1)
      )
   TLB_L
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (tgt_index_nxt),
         .re      (re),
         .dout    (tlb_l_r),
         .waddr   (msr_dmm_tlbl_idx),
         .we      (msr_dmm_tlbl_we),
         .din     (msr_dmm_tlbl_nxt)
      );

   // Instance of highpart TLB
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (CONFIG_DTLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS (1)
      )
   TLB_H
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (tgt_index_nxt),
         .re      (re),
         .dout    (tlb_h_r),
         .waddr   (msr_dmm_tlbh_idx),
         .we      (msr_dmm_tlbh_we),
         .din     (msr_dmm_tlbh_nxt)
      );

   wire tlb_v = tlb_l_r[0];
   wire [VPN_DW-1:0] tlb_vpn = tlb_l_r[`NCPU_DW-1:`NCPU_DW-VPN_DW];
   wire tlb_p = tlb_h_r[0];
   wire tlb_uw = tlb_h_r[3];
   wire tlb_ur = tlb_h_r[4];
   wire tlb_rw = tlb_h_r[5];
   wire tlb_rr = tlb_h_r[6];
   wire tlb_unc = tlb_h_r[7];
   wire tlb_s = tlb_h_r[8];
   wire [PPN_DW-1:0] tlb_ppn = tlb_h_r[`NCPU_DW-1:`NCPU_DW-PPN_DW];
   wire perm_denied;
   wire tlb_miss;

   assign perm_denied =
      (
         // In root mode.
         (msr_psr_rm_r &
            ((we_r & ~tlb_rw) | (~we_r & ~tlb_rr)) ) |
         // In user mode
         (~msr_psr_rm_r &
            ((we_r & ~tlb_uw) | (~we_r & ~tlb_ur)) )
       );

   // TLB miss exception
   assign tlb_miss = ~(tlb_v & (tlb_vpn == tgt_vpn_r));
   assign EDTM = tlb_miss & msr_psr_dmme_r;

   // Permission check, Page Fault exception
   assign EDPF = perm_denied & ~tlb_miss & msr_psr_dmme_r;

   assign ppn = msr_psr_dmme_r ? tlb_ppn : tgt_vpn_r;

   // If DMMU is disabled, UNC bit in page entry is not functioned.
   // Uncached segment is always functioned as long as physical addr is valid
   // and is within 0x80000000~0x8FFFFFFF
generate
   if (CONFIG_DMMU_ENABLE_UNCACHED_SEG)
      assign uncached = (msr_psr_dmme_r & ~tlb_miss & tlb_unc) | (~EDTM & (ppn[`NCPU_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1 -: 4]==4'h8));
   else
      assign uncached = msr_psr_dmme_r & ~tlb_miss & tlb_unc;
endgenerate
   

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      // Assertion (03061058)
      if (!(CONFIG_DTLB_NSETS_LOG2 <= VPN_DW)) begin
         $fatal (0, "\n CONFIG_DTLB_NSETS_LOG2 should <= VPN_DW\n");
      end
      // Assertion (03091855)
      if (!(CONFIG_DTLB_NSETS_LOG2 <= VPN_DW)) begin
         $fatal (0, "\n CONFIG_DTLB_NSETS_LOG2 should <= VPN_DW\n");
      end
   end

   // Assertion
   always @(posedge clk) begin
      if (EDTM & EDPF)
         $fatal ("\n EDTM and EDPF should be mutex\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
