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
   parameter TLB_NSETS_LOG2 = 7, // (2^TLB_NSETS_LOG2) entries
   parameter CPU_RESET_VECTOR = `NCPU_ERST_VECTOR
)
(
   input                   clk,
   input                   rst_n,
   output                  ibus_valid, /* Insn is presented at immu's output */
   input                   ibus_ready, /* ifu is ready to accepted Insn */
   output [`NCPU_IW-1:0]   ibus_dout,
   output                  ibus_cmd_ready, /* ibus is ready to accept cmd */
   input                   ibus_cmd_valid, /* cmd is presented at ibus'input */
   input [`NCPU_AW-1:0]    ibus_cmd_addr,
   input                   ibus_flush_req,
   output [`NCPU_AW-1:0]   ibus_out_id,
   output [`NCPU_AW-1:0]   ibus_out_id_nxt,
   input                   icache_valid, /* Insn is presented at ibus */
   output                  icache_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    icache_dout,
   input                   icache_cmd_ready, /* icache is ready to accept cmd */
   output                  icache_cmd_valid, /* cmd is presented at icache's input */
   output [`NCPU_AW-1:0]   icache_cmd_addr,
   output                  exp_imm_tlb_miss,
   output                  exp_imm_page_fault,
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

   // MMU FSM
   wire hds_ibus_cmd;
   wire hds_ibus_dout;
   wire hds_icache_cmd;
   wire hds_icache_dout;
   wire icache_cmd_valid_w;
   
   // flush_strobe will:
   //    1. If the icache is accepting cmd while its dout is valid,
   //       then cancel the current command request to icache and flush dout.
   //    2. If the icache has accepted previous cmd and we're waiting for its dout,
   //       then wait to flush the dout and block any incoming cmd requests, until
   //       icache goes ready again.
   // When flush_strobe is asserted, pipebuf treats icache as always ready,
   // which ensures that, when flushing, any handshaking with ibus_cmd is
   // always succeeded. Assert (03072258)
   //
   wire icache_pending_r;
   
   nDFF_lr #(1) dff_out_valid
                   (clk,rst_n, (hds_icache_cmd | hds_icache_dout), (hds_icache_cmd | ~hds_icache_dout), icache_pending_r);
                   
   reg fls_status_r;
   
   always @(posedge clk or negedge rst_n)
      if(~rst_n)
         fls_status_r <= 1'b1;
      else begin
         if(ibus_flush_req & icache_pending_r)
            fls_status_r <= 1'b0;
         else if(~icache_pending_r)
            fls_status_r <= 1'b1;
      end
      
   wire flush_strobe = ibus_flush_req;
   
   wire ibus_cmd_ready_w;
   
   assign ibus_cmd_ready = fls_status_r & ibus_cmd_ready_w;
   
   ncpu32k_cell_pipebuf
      #(
         .ENABLE_BYPASS (1) // force bypassing. for Assert (03072258)
      )
   pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .a_en       (1'b1),
         .a_valid    (ibus_cmd_valid),
         .a_ready    (ibus_cmd_ready_w),
         .b_en       (1'b1),
         .b_valid    (icache_cmd_valid_w),
         .b_ready    (icache_cmd_ready | flush_strobe),
         .cke        (hds_ibus_cmd),
         .pending    ()
      );
      
   assign hds_ibus_dout = ibus_valid & ibus_ready;
      
   assign hds_icache_cmd = icache_cmd_valid & icache_cmd_ready;
   assign hds_icache_dout = icache_valid & icache_ready;
   
   // Cacnel the current cmd handshake with icache when flush_strobe.
   assign icache_cmd_valid = ~flush_strobe & icache_cmd_valid_w;
   
   assign ibus_valid = icache_valid & fls_status_r;
   assign icache_ready = ibus_ready | ~fls_status_r;
   
   assign ibus_dout = icache_dout;
   
   // TLB is to be read
   wire tlb_read = hds_ibus_cmd;
   
   ////////////////////////////////////////////////////////////////////////////////
   // The following flip-flops are used to maintain the address of the (output-valid) insn
   // dff_id_nxt : Sync address with TLB
   //              (after the cur is sent to TLB, the NEXT insn addr should be presented at ibus_cmd_addr )
   // dff_id     : Sync address with ibus dout
   //              (after handshaked with ibus dout, the NEXT insn addr is valid at ibus_out_id )
   ////////////////////////////////////////////////////////////////////////////////
   
   // Flush current-insn-PC indicator
   wire [`NCPU_AW-1:0] ibus_out_id_nxt_bypass = ibus_flush_req ? ibus_cmd_addr[`NCPU_AW-1:0] : ibus_out_id_nxt[`NCPU_AW-1:0];

   // Transfer when TLB is to be read
   nDFF_lr #(`NCPU_AW, CPU_RESET_VECTOR-`NCPU_AW'd4) dff_id_nxt
                   (clk,rst_n, tlb_read, ibus_cmd_addr[`NCPU_AW-1:0], ibus_out_id_nxt[`NCPU_AW-1:0]);
   // Transfer when handshaked with downstream module
   nDFF_lr #(`NCPU_AW, CPU_RESET_VECTOR) dff_id
                   (clk,rst_n, hds_ibus_dout|ibus_flush_req, ibus_out_id_nxt_bypass, ibus_out_id[`NCPU_AW-1:0]);
                   
   ////////////////////////////////////////////////////////////////////////////////

   // MSR.IMMID
   assign msr_immid = {{32-3{1'b0}}, TLB_NSETS_LOG2[2:0]};

   // TLB
   wire msr_psr_imme_r;
   wire msr_psr_rm_r;
   wire [PPN_SHIFT-1:0] tgt_page_offset_r;
   wire [VPN_DW-1:0] tgt_vpn_r;
   wire [`NCPU_DW-1:0] tlb_l_r;
   wire [`NCPU_DW-1:0] tlb_h_r;
   wire [`NCPU_AW-1:0] tlb_dummy_addr;
   wire [`NCPU_AW-1:0] tlb_addr;
   
   wire [PPN_SHIFT-1:0] tgt_page_offset_nxt = ibus_cmd_addr[PPN_SHIFT-1:0];
   wire [VPN_DW-1:0] tgt_vpn_nxt = ibus_cmd_addr[VPN_DW+VPN_SHIFT-1:VPN_SHIFT];
   // Assert (03061058)
   wire [TLB_NSETS_LOG2-1:0] tgt_index_nxt = tgt_vpn_nxt[TLB_NSETS_LOG2-1:0];

   /*nDFF_lr #(1) dff_msr_psr_imme_r
                (clk,rst_n, tlb_read, msr_psr_imme, msr_psr_imme_r);*/
   assign msr_psr_imme_r = msr_psr_imme;
   nDFF_lr #(1) dff_msr_psr_rm_r
                (clk,rst_n, tlb_read, msr_psr_rm, msr_psr_rm_r);
   nDFF_lr #(PPN_SHIFT) dff_tgt_page_offset_r
                (clk,rst_n, tlb_read, tgt_page_offset_nxt[PPN_SHIFT-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]);
   nDFF_lr #(VPN_DW) dff_tgt_vpn_r
                (clk,rst_n, tlb_read, tgt_vpn_nxt[VPN_DW-1:0], tgt_vpn_r[VPN_DW-1:0]);

   // Dummy TLB (No translation)
   nDFF_lr #(`NCPU_AW) dff_tlb
                (clk,rst_n, tlb_read, ibus_cmd_addr[`NCPU_AW-1:0], tlb_dummy_addr[`NCPU_AW-1:0]);
                
                
   // Instance of lowpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (TLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
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
          .en_a   (tlb_read),
          // Port B
          .addr_b (msr_imm_tlbl_idx[TLB_NSETS_LOG2-1:0]),
          .we_b   (msr_imm_tlbl_we),
          .din_b  (msr_imm_tlbl_nxt),
          .dout_b (msr_imm_tlbl),
          .en_b   (1'b1)
         );

   // Instance of highpart TLB
   ncpu32k_cell_tdpram_sclk
      #(
         .AW (TLB_NSETS_LOG2),
         .DW (`NCPU_DW),
         .ENABLE_BYPASS_B2A (1)
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
          .en_a   (tlb_read),
          // Port B
          .addr_b (msr_imm_tlbh_idx[TLB_NSETS_LOG2-1:0]),
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
   wire exp_imm_tlb_miss_nxt = ~(tlb_v & tlb_vpn == tgt_vpn_r) & msr_psr_imme_r;
   
   // Permission check, Page Fault exception
   wire exp_imm_page_fault_nxt = perm_denied & ~exp_imm_tlb_miss_nxt & msr_psr_imme_r;
   
   nDFF_lr #(1) dff_exp_imm_page_fault
                (clk,rst_n, hds_icache_cmd, exp_imm_page_fault_nxt, exp_imm_page_fault);
   nDFF_lr #(1) dff_exp_imm_tlb_miss
                (clk,rst_n, hds_icache_cmd, exp_imm_tlb_miss_nxt, exp_imm_tlb_miss);
   
   assign tlb_addr = {tlb_ppn[PPN_DW-1:0], tgt_page_offset_r[PPN_SHIFT-1:0]};

   assign icache_cmd_addr =
      (
         // IMMU is enabled (if TLB not hit, then speculative exec exception to flush TLB)
         msr_psr_imme_r ? tlb_addr
         // IMMU is disabled
         : tlb_dummy_addr
      );

   // synthesis translate_off
`ifndef SYNTHESIS
      
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
      if ((exp_imm_tlb_miss|exp_imm_page_fault) &
           ~(exp_imm_tlb_miss^exp_imm_page_fault))
         $fatal ("\n EITM and EIPF should be mutex\n");
   end
`endif

   // Assertions (03072258)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (ibus_flush_req & ~hds_ibus_cmd)
         $fatal ("\n when flushing downstream module should handshake with ibus cmd\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
