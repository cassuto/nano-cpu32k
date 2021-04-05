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

module ncpu32k_dmmu
#(
   parameter CONFIG_DTLB_NSETS_LOG2 `PARAM_NOT_SPECIFIED , // (2^CONFIG_DTLB_NSETS_LOG2) entries
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED
)
(
   input                   clk,
   input                   rst_n,
   output                  dbus_AREADY,
   input                   dbus_AVALID,
   input [`NCPU_AW-1:0]    dbus_AADDR,
   input [`NCPU_DW/8-1:0]  dbus_AWMSK,
   input [`NCPU_DW-1:0]    dbus_ADATA,
   input                   dcache_AREADY,
   output                  dcache_AVALID,
   output [`NCPU_AW-1:0]   dcache_AADDR,
   output [`NCPU_DW/8-1:0] dcache_AWMSK,
   output [`NCPU_DW-1:0]   dcache_ADATA,
   output [1:0]            dcache_AEXC, // [0] tlb_miss; [1] page_fault
   // PSR
   input                   msr_psr_dmme,
   input                   msr_psr_rm,
   // DMMID
   output [`NCPU_DW-1:0]   msr_dmmid,
   // DTLBL
   output [`NCPU_DW-1:0]   msr_dmm_tlbl,
   input [`NCPU_TLB_AW-1:0] msr_dmm_tlbl_idx,
   input [`NCPU_DW-1:0]    msr_dmm_tlbl_nxt,
   input                   msr_dmm_tlbl_we,
   // DTLBH
   output [`NCPU_DW-1:0]   msr_dmm_tlbh,
   input [`NCPU_TLB_AW-1:0] msr_dmm_tlbh_idx,
   input [`NCPU_DW-1:0]    msr_dmm_tlbh_nxt,
   input                   msr_dmm_tlbh_we
);

   // VPN shift bit
   localparam VPN_SHIFT = 13;
   // PPN shift bit
   localparam PPN_SHIFT = 13;
   // Bitwidth of Virtual Page Number
   localparam VPN_DW = `NCPU_DW-VPN_SHIFT;
   // Bitwidth of Physical Page Number
   localparam PPN_DW = `NCPU_DW-PPN_SHIFT;

   // MMU FSM
   wire tlb_cke;

   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
      )
   pipebuf_dmmu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .flush      (1'b0),
         .A_en       (1'b1),
         .AVALID     (dbus_AVALID),
         .AREADY     (dbus_AREADY),
         .B_en       (1'b1),
         .BVALID     (dcache_AVALID),
         .BREADY     (dcache_AREADY),
         .cke        (tlb_cke),
         .pending    ()
      );

   // MSR.DMMID
   assign msr_dmmid = {{32-3{1'b0}}, CONFIG_DTLB_NSETS_LOG2[2:0]};

   // TLB
   wire msr_psr_dmme_r;
   wire msr_psr_rm_r;
   wire dbus_cmd_we_r;
   wire [`NCPU_DW/8-1:0] dbus_AWMSK_r;
   wire [`NCPU_DW-1:0] dbus_ADATA_r;
   wire [PPN_SHIFT-1:0] tgt_page_offset_r;
   wire [VPN_DW-1:0] tgt_vpn_r;
   wire [`NCPU_DW-1:0] tlb_l_r;
   wire [`NCPU_DW-1:0] tlb_h_r;
   wire [`NCPU_AW-1:0] tlb_dummy_addr;
   wire [`NCPU_AW-1:0] tlb_addr;

   wire [PPN_SHIFT-1:0] tgt_page_offset_nxt = dbus_AADDR[PPN_SHIFT-1:0];
   wire [VPN_DW-1:0] tgt_vpn_nxt = dbus_AADDR[VPN_DW+VPN_SHIFT-1:VPN_SHIFT];
   // Assert (03091855)
   wire [CONFIG_DTLB_NSETS_LOG2-1:0] tgt_index_nxt = tgt_vpn_nxt[CONFIG_DTLB_NSETS_LOG2-1:0];

   nDFF_lr #(1) dff_msr_psr_dmme_r
                (clk,rst_n, tlb_cke, msr_psr_dmme, msr_psr_dmme_r);
   nDFF_lr #(1) dff_msr_psr_rm_r
                (clk,rst_n, tlb_cke, msr_psr_rm, msr_psr_rm_r);
   nDFF_lr #(`NCPU_DW/8) dff_dbus_cmd_we_msk_r
                (clk,rst_n, tlb_cke, dbus_AWMSK[`NCPU_DW/8-1:0], dbus_AWMSK_r[`NCPU_DW/8-1:0]);
   nDFF_lr #(1) dff_dbus_cmd_we_r
                (clk,rst_n, tlb_cke, |dbus_AWMSK, dbus_cmd_we_r);
   nDFF_lr #(`NCPU_DW) dff_dbus_din_r
                (clk,rst_n, tlb_cke, dbus_ADATA[`NCPU_DW-1:0], dbus_ADATA_r[`NCPU_DW-1:0]);
   nDFF_lr #(PPN_SHIFT) dff_tgt_page_offset_r
                (clk,rst_n, tlb_cke, tgt_page_offset_nxt[PPN_SHIFT-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]);
   nDFF_lr #(VPN_DW) dff_tgt_vpn_r
                (clk,rst_n, tlb_cke, tgt_vpn_nxt[VPN_DW-1:0], tgt_vpn_r[VPN_DW-1:0]);

   // Dummy TLB (No translation)
   nDFF_lr #(`NCPU_AW) dff_tlb
                (clk,rst_n, tlb_cke, dbus_AADDR[`NCPU_AW-1:0], tlb_dummy_addr[`NCPU_AW-1:0]);


   // Instance of lowpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (CONFIG_DTLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
         )
      tlb_l_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[CONFIG_DTLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_l_r[`NCPU_DW-1:0]),
          .en_a   (tlb_cke),
          // Port B
          .addr_b (msr_dmm_tlbl_idx[CONFIG_DTLB_NSETS_LOG2-1:0]),
          .we_b   (msr_dmm_tlbl_we),
          .din_b  (msr_dmm_tlbl_nxt),
          .dout_b (msr_dmm_tlbl),
          .en_b   (1'b1)
         );

   // Instance of highpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (CONFIG_DTLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
         )
      tlb_h_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[CONFIG_DTLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_h_r[`NCPU_DW-1:0]),
          .en_a   (tlb_cke),
          // Port B
          .addr_b (msr_dmm_tlbh_idx[CONFIG_DTLB_NSETS_LOG2-1:0]),
          .we_b   (msr_dmm_tlbh_we),
          .din_b  (msr_dmm_tlbh_nxt),
          .dout_b (msr_dmm_tlbh),
          .en_b   (1'b1)
         );

   wire tlb_v = tlb_l_r[0];
   wire [VPN_DW-1:0] tlb_vpn = tlb_l_r[`NCPU_DW-1:`NCPU_DW-VPN_DW];
   wire tlb_p = tlb_h_r[0];
   wire tlb_uw = tlb_h_r[3];
   wire tlb_ur = tlb_h_r[4];
   wire tlb_rw = tlb_h_r[5];
   wire tlb_rr = tlb_h_r[6];
   wire tlb_nc = tlb_h_r[7];
   wire tlb_s = tlb_h_r[8];
   wire [PPN_DW-1:0] tlb_ppn = tlb_h_r[`NCPU_DW-1:`NCPU_DW-PPN_DW];
   wire perm_denied;
   wire tlb_miss;

   assign perm_denied =
      (
         // In root mode.
         (msr_psr_rm_r &
            ((dbus_cmd_we_r & ~tlb_rw) | (~dbus_cmd_we_r & ~tlb_rr)) ) |
         // In user mode
         (~msr_psr_rm_r &
            ((dbus_cmd_we_r & ~tlb_uw) | (~dbus_cmd_we_r & ~tlb_ur)) )
       );

   // TLB miss exception
   assign tlb_miss = ~(tlb_v & tlb_vpn == tgt_vpn_r);
   assign dcache_AEXC[0] = tlb_miss & msr_psr_dmme_r;

   // Permission check, Page Fault exception
   assign dcache_AEXC[1] = perm_denied & ~tlb_miss & msr_psr_dmme_r;

   assign tlb_addr = {tlb_ppn[PPN_DW-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]};

   assign dcache_AADDR =
      (
         // DMMU is enabled
         msr_psr_dmme_r ? tlb_addr
         // DMMU is disabled
         : tlb_dummy_addr
      );

   assign dcache_AWMSK = dbus_AWMSK_r & {`NCPU_DW/8{|dcache_AEXC}};
   assign dcache_ADATA = dbus_ADATA_r;

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
      if (dcache_AEXC[0] & dcache_AEXC[1])
         $fatal ("\n EITM and EIPF should be mutex\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
