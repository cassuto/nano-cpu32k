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

module ncpu32k_dcache
#(
   parameter CONFIG_DBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_DBUS_DW/8) */
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DC_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DC_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DC_DW_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_DC_DW/8) */
   parameter CONFIG_DC_P_LINE
   `PARAM_NOT_SPECIFIED , /* = log2(Size of a line) */
   parameter CONFIG_DC_P_SETS
   `PARAM_NOT_SPECIFIED   /* = log2(Number of sets) */
)
(
   input                         clk,
   input                         rst_n,
   output                        stall,
   input                         req,
   input [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] page_off,
   input [CONFIG_DC_DW/8-1:0]    wmsk,
   input [CONFIG_DC_DW-1:0]      wdat,
   output [CONFIG_DC_DW-1:0]     rdat,
   // From TLB
   input                         tlb_exc,
   input                         tlb_uncached,
   input [CONFIG_DC_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] tlb_ppn,
   // Async D-Bus Master
   input                         dbus_clk,
   input                         dbus_rst_n,   
   input                         dbus_AREADY,
   output                        dbus_AVALID,
   output [CONFIG_DBUS_AW-1:0]   dbus_AADDR,
   output [CONFIG_DBUS_DW/8-1:0] dbus_AWMSK,
   output [CONFIG_DC_P_LINE-1:0] dbus_ALEN,
   output [CONFIG_DBUS_DW-1:0]   dbus_WDATA,
   input                         dbus_BVALID,
   output                        dbus_BREADY,
   input [CONFIG_DBUS_DW-1:0]    dbus_BDATA,
   input                         dbus_BWE
);
   // Main FSM states
   localparam                    S_IDLE = 3'b000;
   localparam                    S_WRITE_PENDING_1 = 3'b001;
   localparam                    S_WRITE_PENDING_2 = 3'b011;
   localparam                    S_READ_PENDING_1 = 3'b111;
   localparam                    S_READ_PENDING_2 = 3'b110;
   localparam                    S_BOOT = 3'b100;

   // Tag data
   localparam                    TAG_ADDR_DW = CONFIG_DC_AW - CONFIG_DC_P_SETS - CONFIG_DC_P_LINE;
   localparam                    TAG_DW = 2 + TAG_ADDR_DW; // V + D + ADDR

   genvar i;

   reg [CONFIG_DBUS_AW-1:0]      dbus_AADDR_nxt;
   wire [CONFIG_DC_P_SETS-1:0]   cls_cnt;
   wire [2:0]                    status_r;
   reg [2:0]                     status_nxt;
   wire                          ch_idle = (status_r == S_IDLE);
   wire                          ch_boot = (status_r == S_BOOT);
   wire [CONFIG_DC_DW-1:0]       ch_mem_dout;
   wire                          cdc_line_adr_cnt_msb;
   wire                          cdc_dbus_A_set;
   wire                          cdc_dbus_A_clr;
   wire                          cdc_dbus_AVALID;
   wire                          cdc_dbus_AREADY;
   wire                          cdc_dbus_AWE;

   //
   // Structure of pipelined cache:
   //
   //       +---+          +-----+         +---+
   // s1i ->|DFF| -> s1o ->|combo|-> s2i ->|DFF| -> s2o
   //       +---+          +-----+         +---+
   //

   // Input of Stage #1
   wire [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off;
   wire [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off_final;
   wire [CONFIG_DC_DW/8-1:0]              s1i_wmask_final;
   wire [CONFIG_DC_DW-1:0]                s1i_din_final;
   wire [CONFIG_DC_P_SETS-1:0]   s1i_entry_idx;

   // Output of Stage #1
   wire                          s1o_req_tmp_r;
   wire                          s1o_req;
	wire [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] s1o_page_off_r;
   wire [CONFIG_DC_AW-1:0]       s1o_paddr;
	wire [CONFIG_DC_DW-1:0]       s1o_din_r;
	wire [CONFIG_DC_DW/8-1:0]     s1o_wmsk_r;
   wire [CONFIG_DC_P_SETS-1:0]   s1o_entry_idx;
   wire                          s1o_tag_v;
	wire                          s1o_tag_dirty;
	wire [TAG_ADDR_DW-1:0]        s1o_tag_paddr;

   // Input of Stage #2
   reg                           s2i_tag_v;
	reg                           s2i_tag_dirty;
	reg [TAG_ADDR_DW-1:0]         s2i_tag_paddr;
   wire [CONFIG_DC_P_SETS-1:0]   s2i_entry_idx;

   wire                          s1_cke;
   wire s1_readtag;
   reg s2i_wr_tag;
   wire s2_cke;

   wire sdr_rd_sr;
	wire sdr_we_sr;

   assign s1_cke = ~stall;

   assign s1i_page_off = page_off;
   assign s1i_entry_idx = ch_boot ? cls_cnt : s1i_page_off[CONFIG_DC_P_LINE+CONFIG_DC_P_SETS-1:CONFIG_DC_P_LINE];

   // Control path
   nDFF_lr #(1) dff_s1o_req_tmp_r
      (clk, rst_n, s1_cke, req, s1o_req_tmp_r);
   nDFF_lr #(CONFIG_DC_P_SETS) dff_s1o_entry_idx // Needed reset for bootstrap
      (clk, rst_n, (s1_cke & req), s1i_entry_idx, s1o_entry_idx);

   // Data path
   nDFF_l #(CONFIG_DMMU_PAGE_SIZE_LOG2) dff_s1o_page_off_r
      (clk, (s1_cke & req), s1i_page_off, s1o_page_off_r);
   nDFF_l #(CONFIG_DC_DW) dff_s1o_din_r
      (clk, (s1_cke & req), wdat, s1o_din_r);
   nDFF_l #(CONFIG_DC_DW/8) dff_s1o_wmsk_r
      (clk, (s1_cke & req), wmsk, s1o_wmsk_r);

   assign s2i_entry_idx = ch_boot ? cls_cnt : s1o_entry_idx;

   // Cancel the request if MMU raised exceptions or cache is inhibited
   assign s1o_req = s1o_req_tmp_r & ~tlb_exc & ~tlb_uncached;

   // Tag entries
   wire [CONFIG_DC_P_SETS-1:0] s1i_entry_idx_final;
   wire [TAG_DW-1:0] s2i_tag_din;
   wire [TAG_DW-1:0] s1o_tag_dout;

   // Switch the index for s1_cke | s1_readtag
   assign s1i_entry_idx_final = s1_cke ? s1i_entry_idx : s2i_entry_idx;
   assign s1i_page_off_final = s1_cke ? s1i_page_off : s1o_page_off_r;
   assign s1i_wmask_final = s1_cke ? wmsk : s1o_wmsk_r;
   assign s1i_din_final = s1_cke ? wdat : s1o_din_r;

   assign s2i_tag_din = {s2i_tag_v, s2i_tag_dirty, s2i_tag_paddr};
   assign {s1o_tag_v, s1o_tag_dirty, s1o_tag_paddr} = s1o_tag_dout;

   // Tags (V + D + ADDR)
   ncpu32k_cell_sdpram_sclk
      #(
         .AW(CONFIG_DC_P_SETS),
         .DW(TAG_DW),
         .ENABLE_BYPASS(1)
      )
   TAGS
      (
         .clk    (clk),
         .rst_n  (rst_n),
         // Port A (Read)
         .raddr  (s1i_entry_idx_final),
         .dout   (s1o_tag_dout),
         .re     ((s1_cke&req) | s1_readtag),
         // Port B (Write)
         .waddr  (s2i_entry_idx),
         .din    (s2i_tag_din),
         .we     (|s2i_wr_tag)
      );

   assign s1o_paddr = {tlb_ppn[CONFIG_DC_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0], s1o_page_off_r[CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]};

   wire s1o_match;

   assign s1o_match = s1o_tag_v & (s1o_tag_paddr == s1o_paddr[CONFIG_DC_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS]);

	wire s1o_hit = s1o_match;
	wire s1o_dirty = s1o_tag_dirty;

/////////////////////////////////////////////////////////////////////////////
// Begin of dbus clock domain
/////////////////////////////////////////////////////////////////////////////
   reg [CONFIG_DC_P_LINE - CONFIG_DBUS_BYTES_LOG2 -1:0] slow_line_adr_cnt;
   wire                          dbus_hds_B;

   // Maintain the line address counter,
   // when burst transmission for cache line filling or writing back
   always @(posedge dbus_clk or negedge dbus_rst_n)
      if (~dbus_rst_n)
         slow_line_adr_cnt <= {CONFIG_DC_P_LINE - CONFIG_DBUS_BYTES_LOG2{1'b0}};
      else if (dbus_hds_B)
         slow_line_adr_cnt <= slow_line_adr_cnt + 'b1;

   ncpu32k_cdc_sync
      #(
         .RST_VALUE ('b0),
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_LINE_ADR_CNT_MSB
      (
         .A (slow_line_adr_cnt[CONFIG_DC_P_LINE - CONFIG_DBUS_BYTES_LOG2 -1]),
         .CLK_B (clk),
         .RST_N_B (rst_n),
         .B (cdc_line_adr_cnt_msb)
      );

   wire [CONFIG_DC_DW/8-1:0] slow_line_adr_cnt_msk;

   // Mask HI/LO 16bit.
generate
   if (CONFIG_DBUS_DW == 16 && CONFIG_DC_DW == 32)
      begin
         assign slow_line_adr_cnt_msk = {slow_line_adr_cnt[0], slow_line_adr_cnt[0], ~slow_line_adr_cnt[0], ~slow_line_adr_cnt[0]};

         assign dbus_WDATA = slow_line_adr_cnt[0] ? ch_mem_dout[15:0] : ch_mem_dout[31:16];
      end
   else if (CONFIG_DBUS_DW == 32 && CONFIG_DC_DW == 32)
      begin
         assign slow_line_adr_cnt_msk = 4'b1111;

         assign dbus_WDATA = ch_mem_dout[31:0];
      end
   else initial $fatal(1, "Please implement one");
endgenerate

/////////////////////////////////////////////////////////////////////////////
// End of dbus clock domain
/////////////////////////////////////////////////////////////////////////////

   localparam BLK_AW = CONFIG_DC_P_SETS + CONFIG_DC_P_LINE - CONFIG_DC_DW_BYTES_LOG2;

   // Port A (Slow side)
   wire [CONFIG_DC_DW-1:0] s2o_blk_dout_a;
   // Port B (Fast side)
   wire [CONFIG_DC_DW-1:0] s1o_blk_dout_b;

   // Blocks
   wire                       s2i_blk_en_a;
   wire [BLK_AW-1:0]          s2i_blk_addr_a;
   wire [CONFIG_DC_DW-1:0]    s2i_blk_din_a;
   wire [CONFIG_DC_DW/8-1:0]  s2i_blk_we_a;
   wire                       s1i_blk_en_b;
   wire [BLK_AW-1:0]          s1i_blk_addr_b;
   wire [CONFIG_DC_DW-1:0]    s1i_blk_din_b;
   wire [CONFIG_DC_DW/8-1:0]  s1i_blk_we_b;

/////////////////////////////////////////////////////////////////////////////
// Begin of dbus clock domain
/////////////////////////////////////////////////////////////////////////////
   localparam DELTA_DW = CONFIG_DC_DW_BYTES_LOG2-CONFIG_DBUS_BYTES_LOG2;
   assign s2i_blk_en_a = dbus_hds_B;
   assign s2i_blk_addr_a = {s1o_entry_idx[CONFIG_DC_P_SETS-1:0], slow_line_adr_cnt[DELTA_DW +: CONFIG_DC_P_LINE-CONFIG_DC_DW_BYTES_LOG2]};
   assign s2i_blk_we_a = {CONFIG_DC_DW/8{dbus_hds_B & ~dbus_BWE}} & slow_line_adr_cnt_msk;

   if (CONFIG_DBUS_DW == 16 && CONFIG_DC_DW == 32)
      assign s2i_blk_din_a = {dbus_BDATA[CONFIG_DBUS_DW-1:0], dbus_BDATA[CONFIG_DBUS_DW-1:0]};
   else if (CONFIG_DBUS_DW == 32 && CONFIG_DC_DW == 32)
      assign s2i_blk_din_a = dbus_BDATA[CONFIG_DBUS_DW-1:0];
   else
      initial $fatal(1, "Please implement one");
/////////////////////////////////////////////////////////////////////////////
// End of dbus clock domain
/////////////////////////////////////////////////////////////////////////////

   wire s1i_blk_cke = ((s1_cke&req)|s1_readtag);

   assign s1i_blk_en_b = s1i_blk_cke & (ch_idle | (status_nxt==S_IDLE));
   assign s1i_blk_addr_b = {s1i_entry_idx_final[CONFIG_DC_P_SETS-1:0], s1i_page_off_final[CONFIG_DC_P_LINE-1:CONFIG_DC_DW_BYTES_LOG2]};
   assign s1i_blk_we_b = {CONFIG_DC_DW/8{s1i_blk_cke}} & s1i_wmask_final;
   assign s1i_blk_din_b = s1i_din_final;

   ncpu32k_dcache_ram
      #(
         .AW       (BLK_AW),
         .DW       (CONFIG_DC_DW)
      )
   PAYLOAD_RAM
      (
         .clk_a    (dbus_clk),
         .addr_a   (s2i_blk_addr_a[BLK_AW-1:0]),
         .we_a     (s2i_blk_we_a[CONFIG_DC_DW/8-1:0]),
         .din_a    (s2i_blk_din_a[CONFIG_DC_DW-1:0]),
         .dout_a   (s2o_blk_dout_a[CONFIG_DC_DW-1:0]),
         .en_a     (s2i_blk_en_a),
         .clk_b    (clk),
         .addr_b   (s1i_blk_addr_b[BLK_AW-1:0]),
         .we_b     (s1i_blk_we_b[CONFIG_DC_DW/8-1:0]),
         .din_b    (s1i_blk_din_b[CONFIG_DC_DW-1:0]),
         .dout_b   (s1o_blk_dout_b[CONFIG_DC_DW-1:0]),
         .en_b     (s1i_blk_en_b)
      );

   assign rdat = s1o_blk_dout_b;

   // Note that RAM writing happens at stage #1, which means that, if cache is miss,
   // the original data of this line was clobbered.
   // As port B of payload RAM has been configured to write-first,
   // `s1o_blk_dout_b` now holds the previous value before writing, so we can
   // get the original data from it.
   assign ch_mem_dout = (s2i_blk_addr_a==s1i_blk_addr_b) ? s1o_blk_dout_b : s2o_blk_dout_a;

   // Combined logic to maintain tags
   
   // D combs
   always @(*)
      if (ch_boot)
         begin
            // Reset D tag
            s2i_tag_dirty = 1'b0;
            s2i_wr_tag = 1'b1;
         end
      else if (ch_idle & s1o_req & s1o_hit)
         begin
            // Mark it dirty when write
            s2i_tag_dirty = s1o_match ? s1o_tag_dirty | (|s1o_wmsk_r) : s1o_tag_dirty;
            s2i_wr_tag = 1'b1;
         end
      else if(ch_idle & s1o_req)
         begin
            // Mark it clean when entry is freed
            s2i_tag_dirty = 1'b0;
            s2i_wr_tag = 1'b1;
         end
      else
         begin
            // Hold
            s2i_tag_dirty = s1o_tag_dirty;
            s2i_wr_tag = 1'b0;
         end

   // V + ADDR combs
   always @(*)
      if(ch_boot)
         begin
            // Reset V ADDR tag
            s2i_tag_v = 1'b0;
            s2i_tag_paddr = {TAG_ADDR_DW{1'b0}};
         end
      else if(ch_idle & s1o_req & ~s1o_hit)
         begin
            // Cache missed
            // Replace a free entry
            s2i_tag_v = 1'b1;
            s2i_tag_paddr = s1o_paddr[CONFIG_DC_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS];
         end
      else
         begin
            // Hold
            s2i_tag_v = s1o_tag_v;
            s2i_tag_paddr = s1o_tag_paddr;
         end


   // Read the tags while stage #1 is stalling.
   // This happens when cache line replacement is completed,
   // in the next beat, tags will hold the latest value.
   assign s1_readtag = ((status_r == S_READ_PENDING_2) & (status_nxt == S_IDLE));

   assign stall = ~ch_idle | (s1o_req & ~s1o_hit);

   // Write-back FSM
   always @(*)
      begin
         status_nxt = status_r;
         case (status_r)
            S_BOOT:
               begin
                  if (cls_cnt == {CONFIG_DC_P_SETS{1'b0}})
                     status_nxt = S_IDLE;
               end
            S_IDLE:
               begin
                  if (s1o_req & ~s1o_hit)
                     begin
                        // Cache missed
                        // If the target is dirty, then write back
                        status_nxt = s1o_dirty ? S_WRITE_PENDING_1 : S_READ_PENDING_1;
                     end
               end
            
            S_WRITE_PENDING_1:
               if (cdc_line_adr_cnt_msb)
                  status_nxt = S_WRITE_PENDING_2;
            S_WRITE_PENDING_2:
               if (~cdc_line_adr_cnt_msb)
                  status_nxt = S_READ_PENDING_1;
               
            S_READ_PENDING_1:
               if (cdc_line_adr_cnt_msb)
                  status_nxt = S_READ_PENDING_2;
            S_READ_PENDING_2:
               if (~cdc_line_adr_cnt_msb)
                  status_nxt = S_IDLE;

            default: begin
               status_nxt = status_r;
            end
         endcase
      end

   nDFF_r #(3, S_BOOT) dff_status_r
      (clk, rst_n, status_nxt, status_r);
   nDFF_lr #(CONFIG_DC_P_SETS, {CONFIG_DC_P_SETS{1'b1}}) dff_cls_cnt
      (clk, rst_n, ch_boot, cls_cnt - 'b1, cls_cnt);

   wire [CONFIG_DC_AW-1:0] s1o_replace_line_paddr;

   assign s1o_replace_line_paddr = {s1o_tag_paddr, s1o_entry_idx, {CONFIG_DC_P_LINE{1'b0}} };

   // Resolve the start address of burst transmission
   // NOTE: Ensure dbus_AADDR doesn't change while dbus_AVALID is asserting.
	always @(*)
      begin
         dbus_AADDR_nxt = dbus_AADDR;
         case(status_r)
            S_IDLE:
               begin
                  dbus_AADDR_nxt = s1o_dirty
                                       ? s1o_replace_line_paddr[CONFIG_DBUS_AW-1:0] // truncate address bits
                                       : {s1o_paddr[CONFIG_DBUS_AW-1:CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits
               end
            S_WRITE_PENDING_1:
               begin
                  if (status_nxt == S_WRITE_PENDING_2)
                     begin
                        // Prepare to read from DBUS (But DBUS is currently writing)
                        dbus_AADDR_nxt = {s1o_paddr[CONFIG_DBUS_AW-1:CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits
                     end
               end
            default:
               begin
                  dbus_AADDR_nxt = dbus_AADDR;
               end
         endcase
      end

   nDFF_l #(CONFIG_DBUS_AW) dff_dbus_AADDR
      (clk, 1'b1, dbus_AADDR_nxt, dbus_AADDR);

   assign cdc_dbus_A_set = // Prepare to read or write:
                           (status_r == S_IDLE && status_nxt != S_IDLE) |
                           // Prepare to read:
                           (status_r == S_WRITE_PENDING_1 && status_nxt == S_WRITE_PENDING_2);
   assign cdc_dbus_A_clr = (cdc_dbus_AVALID & cdc_dbus_AREADY);

   nDFF_lr #(1) dff_cdc_dbus_AVALID
      (clk,rst_n, (cdc_dbus_A_set|cdc_dbus_A_clr), (cdc_dbus_A_set | ~cdc_dbus_A_clr), cdc_dbus_AVALID);

   assign cdc_dbus_AWE = (status_r == S_IDLE && status_nxt == S_WRITE_PENDING_1) |
                           (status_r == S_WRITE_PENDING_1);

/////////////////////////////////////////////////////////////////////////////
// Begin of dbus clock domain
/////////////////////////////////////////////////////////////////////////////
   wire dbus_we;

   // cache to dbus
   ncpu32k_cdc_sync_hds
      #(
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_DBUS
      (
         .clk_a      (clk),
         .rst_a_n    (rst_n),
         .AVALID     (cdc_dbus_AVALID),
         .AREADY     (cdc_dbus_AREADY),
         .clk_b      (dbus_clk),
         .rst_b_n    (dbus_rst_n),
         .BVALID     (dbus_AVALID),
         .BREADY     (dbus_AREADY)
      );

   ncpu32k_cdc_sync
      #(
         .RST_VALUE ('b0),
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_DBUS_WE
      (
         .A       (cdc_dbus_AWE),
         .CLK_B   (dbus_clk),
         .RST_N_B (dbus_rst_n),
         .B       (dbus_we)
      );

   assign dbus_AWMSK = {CONFIG_DBUS_DW/8{dbus_we}};
   
   assign dbus_ALEN = {CONFIG_DC_P_LINE{1'b1}};

   assign dbus_hds_B = (dbus_BVALID & dbus_BREADY);

   assign dbus_BREADY = 1'b1;

/////////////////////////////////////////////////////////////////////////////
// End of dbus clock domain
/////////////////////////////////////////////////////////////////////////////


   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if ((1<<CONFIG_DBUS_BYTES_LOG2) != (CONFIG_DBUS_DW/8))
         $fatal(1, "Error value of CONFIG_DBUS_BYTES_LOG2");
      if ((1<<CONFIG_DC_DW_BYTES_LOG2) != (CONFIG_DC_DW/8))
         $fatal(1, "Error value of CONFIG_DC_DW_BYTES_LOG2");
      if (CONFIG_DC_DW_BYTES_LOG2 < CONFIG_DBUS_BYTES_LOG2)
         $fatal(1, "Invalid configuration of DW or DBUS");
      if (CONFIG_DMMU_PAGE_SIZE_LOG2 < CONFIG_DC_P_LINE + CONFIG_DC_P_SETS)
         $fatal(1, "Invalid size of dcache (Must <= page size of D-MMU)");
   end
`endif

`endif
   // synthesis translate_on

endmodule
