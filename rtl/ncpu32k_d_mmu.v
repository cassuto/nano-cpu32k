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

module ncpu32k_d_mmu
#(
   parameter TLB_NSETS_LOG2 = 7 // (2^TLB_NSETS_LOG2) entries
)
(
   input                   clk,
   input                   rst_n,
   output                  dbus_valid, /* Insn is presented at dmmu's output */
   input                   dbus_ready, /* ifu is ready to accepted Insn */
   output [`NCPU_IW-1:0]   dbus_dout,
   input [`NCPU_IW-1:0]    dbus_din,
   output                  dbus_cmd_ready, /* ibus is ready to accept cmd */
   input                   dbus_cmd_valid, /* cmd is presented at ibus'input */
   input [`NCPU_AW-1:0]    dbus_cmd_addr,
   input [2:0]             dbus_cmd_size,
   input                   dbus_cmd_we,
   input                   dcache_valid, /* Insn is presented at ibus */
   output                  dcache_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    dcache_dout,
   output [`NCPU_DW-1:0]   dcache_din,
   input                   dcache_cmd_ready, /* icache is ready to accept cmd */
   output                  dcache_cmd_valid, /* cmd is presented at icache's input */
   output [`NCPU_AW-1:0]   dcache_cmd_addr,
   output [2:0]            dcache_cmd_size,
   output                  dcache_cmd_we,
   output                  exp_dmm_tlb_miss,
   output                  exp_dmm_page_fault,
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
   
   localparam CLEAR_ON_INIT = 1;


   // MMU FSM
   wire hds_dbus_cmd;
   wire hds_dbus_dout;
   wire hds_dcache_cmd;
   wire hds_dcache_dout;
   wire dcache_cmd_valid_w;
   
   wire flush_strobe;
   
   ncpu32k_cell_pipebuf
      #(
         .DW (`NCPU_IW),
         .ENABLE_BYPASS (1) // force bypassing.
      )
   pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (),
         .dout       (),
         .in_valid   (dbus_cmd_valid),
         .in_ready   (dbus_cmd_ready),
         .out_valid  (dcache_cmd_valid_w),
         .out_ready  (dcache_cmd_ready | flush_strobe),
         .cas        (hds_dbus_cmd)
      );
      
   assign hds_dbus_dout = dbus_valid & dbus_ready;
      
   assign hds_dcache_cmd = dcache_cmd_valid & dcache_cmd_ready;
   assign hds_dcache_dout = dcache_valid & dcache_ready;
   
   // Cacnel the current cmd handshake with icache when Exception raised.
   assign dcache_cmd_valid = ~flush_strobe & dcache_cmd_valid_w;
   
   // We assume that dbus will not go valid if its cmd is invalid.
   // Assert ?
   assign dbus_valid = dcache_valid;
   assign dcache_ready = dbus_ready;
   
   assign dbus_dout = dcache_dout;
   
   // TLB is to be read
   wire tlb_read = hds_dbus_cmd;

   // MSR.DMMID
   assign msr_dmmid = {{32-3{1'b0}}, TLB_NSETS_LOG2[2:0]};

   // TLB
   wire msr_psr_dmme_r;
   wire msr_psr_rm_r;
   wire dbus_cmd_we_r;
   wire [2:0] dbus_cmd_size_r;
   wire [`NCPU_DW-1:0] dbus_din_r;
   wire [PPN_SHIFT-1:0] tgt_page_offset_r;
   wire [VPN_DW-1:0] tgt_vpn_r;
   wire [`NCPU_DW-1:0] tlb_l_r;
   wire [`NCPU_DW-1:0] tlb_h_r;
   wire [`NCPU_AW-1:0] tlb_dummy_addr;
   wire [`NCPU_AW-1:0] tlb_addr;
   
   wire [PPN_SHIFT-1:0] tgt_page_offset_nxt = dbus_cmd_addr[PPN_SHIFT-1:0];
   wire [VPN_DW-1:0] tgt_vpn_nxt = dbus_cmd_addr[VPN_DW+VPN_SHIFT-1:VPN_SHIFT];
   // Assert (03091855)
   wire [TLB_NSETS_LOG2-1:0] tgt_index_nxt = tgt_vpn_nxt[TLB_NSETS_LOG2-1:0];

   ncpu32k_cell_dff_lr #(1) dff_msr_psr_dmme_r
                (clk,rst_n, tlb_read, msr_psr_dmme, msr_psr_dmme_r);
   ncpu32k_cell_dff_lr #(1) dff_msr_psr_rm_r
                (clk,rst_n, tlb_read, msr_psr_rm, msr_psr_rm_r);
   ncpu32k_cell_dff_lr #(3) dff_dbus_cmd_size_r
                (clk,rst_n, tlb_read, dbus_cmd_size[2:0], dbus_cmd_size_r[2:0]);
   ncpu32k_cell_dff_lr #(`NCPU_DW) dff_dbus_din_r
                (clk,rst_n, tlb_read, dbus_din[`NCPU_DW-1:0], dbus_din_r[`NCPU_DW-1:0]);
   ncpu32k_cell_dff_lr #(PPN_SHIFT) dff_tgt_page_offset_r
                (clk,rst_n, tlb_read, tgt_page_offset_nxt[PPN_SHIFT-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]);
   ncpu32k_cell_dff_lr #(VPN_DW) dff_tgt_vpn_r
                (clk,rst_n, tlb_read, tgt_vpn_nxt[VPN_DW-1:0], tgt_vpn_r[VPN_DW-1:0]);

   // Dummy TLB (No translation)
   ncpu32k_cell_dff_lr #(`NCPU_AW) dff_tlb
                (clk,rst_n, tlb_read, dbus_cmd_addr[`NCPU_AW-1:0], tlb_dummy_addr[`NCPU_AW-1:0]);
                
                
   // Instance of lowpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (TLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .CLEAR_ON_INIT (CLEAR_ON_INIT)
         )
      tlb_l_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[TLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_l_r[`NCPU_DW-1:0]),
          .re_a   (tlb_read),
          // Port B
          .addr_b (msr_dmm_tlbl_idx[TLB_NSETS_LOG2-1:0]),
          .we_b   (msr_dmm_tlbl_we),
          .din_b  (msr_dmm_tlbl_nxt),
          .dout_b (msr_dmm_tlbl),
          .re_b   (1'b1)
         );

   // Instance of highpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (TLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .CLEAR_ON_INIT (CLEAR_ON_INIT)
         )
      tlb_h_sclk
         (
          .clk    (clk),
          .rst_n  (rst_n),
          // Port A
          .addr_a (tgt_index_nxt[TLB_NSETS_LOG2-1:0]),
          .we_a   (1'b0),
          .din_a  (),
          .dout_a (tlb_h_r[`NCPU_DW-1:0]),
          .re_a   (tlb_read),
          // Port B
          .addr_b (msr_dmm_tlbh_idx[TLB_NSETS_LOG2-1:0]),
          .we_b   (msr_dmm_tlbh_we),
          .din_b  (msr_dmm_tlbh_nxt),
          .dout_b (msr_dmm_tlbh),
          .re_b   (1'b1)
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
   assign exp_dmm_tlb_miss = ~(tlb_v & tlb_vpn == tgt_vpn_r) & msr_psr_dmme_r;
   
   // Permission check, Page Fault exception
   assign exp_dmm_page_fault = perm_denied & ~exp_dmm_tlb_miss & msr_psr_dmme_r;
   
   // Cancel handshake with dcache when exception raised.
   assign flush_strobe = exp_dmm_page_fault | exp_dmm_tlb_miss;
   
   assign tlb_addr = {tlb_ppn[PPN_DW-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]};

   assign dcache_cmd_addr =
      (
         // DMMU is enabled
         msr_psr_dmme_r ? tlb_addr
         // DMMU is disabled
         : tlb_dummy_addr
      );

   assign dcache_cmd_size = dbus_cmd_size_r;
   
   assign dcache_cmd_we = dbus_cmd_we_r;
   
   assign dcache_din = dbus_din_r;
      
   // Assertion (03061058)
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if (!(TLB_NSETS_LOG2 <= VPN_DW)) begin
         $fatal (0, "\n TLB_NSETS_LOG2 should <= VPN_DW\n");
      end
   end
`endif

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if ((exp_dmm_tlb_miss|exp_dmm_page_fault) &
           ~(exp_dmm_tlb_miss^exp_dmm_page_fault))
         $fatal ("\n EITM and EIPF should be mutex\n");
   end
`endif

   // Assertion (03091855)
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if (!(TLB_NSETS_LOG2 <= VPN_DW)) begin
         $fatal (0, "\n TLB_NSETS_LOG2 should <= VPN_DW\n");
      end
   end
`endif

endmodule
