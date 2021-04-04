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

module ncpu32k_immu
#(
   parameter CONFIG_ITLB_NSETS_LOG2, // (2^CONFIG_ITLB_NSETS_LOG2) entries
   parameter CONFIG_PIPEBUF_BYPASS,
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR
)
(
   input                   clk,
   input                   rst_n,
   output                  ibus_AREADY,
   input                   ibus_AVALID,
   input [`NCPU_AW-1:0]    ibus_AADDR,
   input                   icache_AREADY,
   output                  icache_AVALID,
   output [`NCPU_AW-1:0]   icache_AADDR,
   output [1:0]            icache_AEXC, // [0] tlb_miss, [1] page_fault
   // PSR
   input                   msr_psr_imme,
   input                   msr_psr_rm,
   // IMMID
   output [`NCPU_DW-1:0]   msr_immid,
   // TLBL
   output [`NCPU_DW-1:0]   msr_imm_tlbl,
   input [`NCPU_TLB_AW-1:0] msr_imm_tlbl_idx,
   input [`NCPU_DW-1:0]    msr_imm_tlbl_nxt,
   input                   msr_imm_tlbl_we,
   // TLBH
   output [`NCPU_DW-1:0]   msr_imm_tlbh,
   input [`NCPU_TLB_AW-1:0] msr_imm_tlbh_idx,
   input [`NCPU_DW-1:0]    msr_imm_tlbh_nxt,
   input                   msr_imm_tlbh_we

);

   // VPN shift bit
   localparam VPN_SHIFT = 13;
   // PPN shift bit
   localparam PPN_SHIFT = 13;
   // Bitwidth of Virtual Page Number
   localparam VPN_DW = `NCPU_DW-VPN_SHIFT;
   // Bitwidth of Physical Page Number
   localparam PPN_DW = `NCPU_DW-PPN_SHIFT;

   wire tlb_cke;
   wire tlb_pending;

   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS(CONFIG_PIPEBUF_BYPASS)
      )
   pipebuf_immu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .A_en       (1'b1),
         .AVALID     (ibus_AVALID),
         .AREADY     (ibus_AREADY),
         .B_en       (1'b1),
         .BVALID     (icache_AVALID),
         .BREADY     (icache_AREADY),
         .cke        (tlb_cke),
         .pending    (tlb_pending)
      );

   // MSR.IMMID
   assign msr_immid = {{32-3{1'b0}}, CONFIG_ITLB_NSETS_LOG2[2:0]};

   // TLB
   wire msr_psr_imme_r;
   wire msr_psr_rm_r;
   wire [PPN_SHIFT-1:0] tgt_page_offset_r;
   wire [VPN_DW-1:0] tgt_vpn_r;
   wire [`NCPU_DW-1:0] tlb_l_r;
   wire [`NCPU_DW-1:0] tlb_h_r;
   wire [`NCPU_AW-1:0] tlb_dummy_addr;

   wire [PPN_SHIFT-1:0] tgt_page_offset_nxt = ibus_AADDR[PPN_SHIFT-1:0];
   wire [VPN_DW-1:0] tgt_vpn_nxt = ibus_AADDR[VPN_DW+VPN_SHIFT-1:VPN_SHIFT];
   // Assert (03061058)
   wire [CONFIG_ITLB_NSETS_LOG2-1:0] tgt_index_nxt = tgt_vpn_nxt[CONFIG_ITLB_NSETS_LOG2-1:0];

   nDFF_lr #(1) dff_msr_psr_imme_r
                (clk,rst_n, tlb_cke, msr_psr_imme, msr_psr_imme_r);
   nDFF_lr #(1) dff_msr_psr_rm_r
                (clk,rst_n, tlb_cke, msr_psr_rm, msr_psr_rm_r);
   nDFF_lr #(PPN_SHIFT) dff_tgt_page_offset_r
                (clk,rst_n, tlb_cke, tgt_page_offset_nxt[PPN_SHIFT-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]);
   nDFF_lr #(VPN_DW) dff_tgt_vpn_r
                (clk,rst_n, tlb_cke, tgt_vpn_nxt[VPN_DW-1:0], tgt_vpn_r[VPN_DW-1:0]);

   // Dummy TLB (No translation)
   nDFF_lr #(`NCPU_AW) dff_tlb
                (clk,rst_n, tlb_cke, ibus_AADDR[`NCPU_AW-1:0], tlb_dummy_addr[`NCPU_AW-1:0]);


   // Instance of lowpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (CONFIG_ITLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
         )
      tlb_l_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[CONFIG_ITLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_l_r[`NCPU_DW-1:0]),
          .en_a   (tlb_cke),
          // Port B
          .addr_b (msr_imm_tlbl_idx[CONFIG_ITLB_NSETS_LOG2-1:0]),
          .we_b   (msr_imm_tlbl_we),
          .din_b  (msr_imm_tlbl_nxt),
          .dout_b (msr_imm_tlbl),
          .en_b   (1'b1)
         );

   // Instance of highpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (CONFIG_ITLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
         )
      tlb_h_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[CONFIG_ITLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_h_r[`NCPU_DW-1:0]),
          .en_a   (tlb_cke),
          // Port B
          .addr_b (msr_imm_tlbh_idx[CONFIG_ITLB_NSETS_LOG2-1:0]),
          .we_b   (msr_imm_tlbh_we),
          .din_b  (msr_imm_tlbh_nxt),
          .dout_b (msr_imm_tlbh),
          .en_b   (1'b1)
         );

   wire tlb_v = tlb_l_r[0];
   wire [VPN_DW-1:0] tlb_vpn = tlb_l_r[`NCPU_DW-1:`NCPU_DW-VPN_DW];
   wire tlb_p = tlb_h_r[0];
   wire tlb_ux = tlb_h_r[3];
   wire tlb_rx = tlb_h_r[4];
   wire tlb_s = tlb_h_r[8];
   wire [PPN_DW-1:0] tlb_ppn = tlb_h_r[`NCPU_DW-1:`NCPU_DW-PPN_DW];

   assign perm_denied = ((msr_psr_rm_r & ~tlb_rx) |
                         (~msr_psr_rm_r & ~tlb_ux));

   // TLB miss exception
   assign icache_AEXC[0] = ~(tlb_v & tlb_vpn == tgt_vpn_r) & msr_psr_imme_r;

   // Permission check, Page Fault exception
   assign icache_AEXC[1] = perm_denied & ~icache_AEXC[0] & msr_psr_imme_r;

   assign icache_AADDR =
      (
         // IMMU is enabled
         msr_psr_imme_r ?
            // If exception raised, send a trusted address for robustness.
            // The slave module should do NOT actually read if there is any exception, and its B-channel
            // is undefined.
            // BTW, as we give the slave module exception vector, Prefetching is possible.
            // Note that, whatever the address is selected, this insn will be flushed out anyway
            // in the subsequent CPU units.
            icache_AEXC[0] ? CONFIG_EITM_VECTOR
            : icache_AEXC[1] ? CONFIG_EIPF_VECTOR

            // Translated address
            : {tlb_ppn[PPN_DW-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]}

         // IMMU is disabled
         : tlb_dummy_addr
      );

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   // Assertion (03061058)
   initial begin
      if (!(CONFIG_ITLB_NSETS_LOG2 <= VPN_DW)) begin
         $fatal (0, "\n CONFIG_ITLB_NSETS_LOG2 should <= VPN_DW\n");
      end
   end
   // Assertion
   always @(posedge clk) begin
      if (icache_AEXC[0] & icache_AEXC[1])
         $fatal ("\n EITM and EIPF should be mutex\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
