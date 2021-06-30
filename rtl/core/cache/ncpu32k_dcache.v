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
   `PARAM_NOT_SPECIFIED , /* = log2(Number of sets) */
   parameter CONFIG_DC_P_WAYS
   `PARAM_NOT_SPECIFIED /* = log2(Number of ways) */
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
   // DCID
   output [`NCPU_DW-1:0]         msr_dcid,
   // DCINV
   input [`NCPU_DW-1:0]          msr_dcinv_nxt,
   input                         msr_dcinv_we,
   // DCFLS
   input [`NCPU_DW-1:0]          msr_dcfls_nxt,
   input                         msr_dcfls_we,
   // From TLB
   input                         tlb_exc,
   input                         tlb_uncached,
   input [CONFIG_DC_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] tlb_ppn,
   // D-Bus Master
   input                         dbus_ARWREADY,
   output                        dbus_ARWVALID,
   output [CONFIG_DBUS_AW-1:0]   dbus_ARWADDR,
   output                        dbus_AWE,
   input                         dbus_WREADY,
   output                        dbus_WVALID,
   output [CONFIG_DBUS_DW-1:0]   dbus_WDATA,
   input                         dbus_BVALID,
   output                        dbus_BREADY,
   input                         dbus_RVALID,
   output                        dbus_RREADY,
   input [CONFIG_DBUS_DW-1:0]    dbus_RDATA
);
   // Main FSM states
   localparam                    S_IDLE            = 4'd0;
   localparam                    S_WRITE_PENDING   = 4'd1;
   localparam                    S_READ_PENDING    = 4'd2;
   localparam                    S_READOUT         = 4'd3;
   localparam                    S_BOOT            = 4'd4;
   localparam                    S_READ_AFTER_B    = 4'd5;
   localparam                    S_FLS_1           = 4'd6;
   localparam                    S_FLS_2           = 4'd7;
   localparam                    S_INV_1           = 4'd8;
   localparam                    S_INV_2           = 4'd9;

   // Tag data
   localparam                    TAG_ADDR_DW = CONFIG_DC_AW - CONFIG_DC_P_SETS - CONFIG_DC_P_LINE;
   localparam                    TAG_DW = 2 + TAG_ADDR_DW; // V + D + ADDR

   genvar i, j;

   reg [CONFIG_DBUS_AW-1:0]      dbus_AADDR_nxt;
   wire [CONFIG_DC_P_SETS-1:0]   cls_cnt;
   wire [3:0]                    status_r;
   reg [3:0]                     status_nxt;
   wire [`NCPU_DW-1:0]           invfls_paddr_r;
   reg [`NCPU_DW-1:0]            invfls_paddr_nxt;
   wire                          in_invfls_r;
   reg                           in_invfls_nxt;
   wire                          ch_idle = (status_r == S_IDLE);
   wire                          ch_boot = (status_r == S_BOOT);
   wire                          ch_inv_2 = (status_r == S_INV_2);
   wire                          ch_fls_2 = (status_r == S_FLS_2);
   wire                          ch_idle_no_invfls;
   wire [CONFIG_DC_DW-1:0]       ch_mem_dout;
   wire                          dbus_A_set;
   wire                          dbus_A_clr;
   wire                          dbus_we;
   wire                          dbus_hds_R;
   wire                          dbus_hds_W;
   wire                          dbus_hds_B;

   //
   // Structure of pipelined cache:
   //
   //       +---+          +-----+         +---+
   // s1i ->|DFF| -> s1o ->|combo|-> s2i ->|DFF| -> s2o
   //       +---+          +-----+         +---+
   //

   // Input of Stage #1
   wire [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off;
   wire [CONFIG_DC_P_SETS-1:0]            s1i_entry_idx;

   // Output of Stage #1
   reg                                    s1o_req_tmp_r;
   wire                                   s1o_req;
	reg [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]   s1o_page_off_r;
   wire [CONFIG_DC_AW-1:0]                s1o_paddr;
	reg [CONFIG_DC_DW-1:0]                 s1o_din_r;
	reg [CONFIG_DC_DW/8-1:0]               s1o_wmask_r;
   reg [CONFIG_DC_P_SETS-1:0]             s1o_entry_idx;
   wire                                   s1o_tag_v        [0:(1<<CONFIG_DC_P_WAYS)-1];
	wire [(1<<CONFIG_DC_P_WAYS)-1:0]       s1o_tag_dirty;
	wire [CONFIG_DC_P_WAYS-1:0]            s1o_tag_lru      [0:(1<<CONFIG_DC_P_WAYS)-1];
	wire [TAG_ADDR_DW-1:0]                 s1o_tag_paddr    [0:(1<<CONFIG_DC_P_WAYS)-1];

   // Input of Stage #2
   wire [CONFIG_DC_P_SETS-1:0]            s1i_entry_idx_final;
   wire [CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off_final;
   reg                                    s2i_tag_v        [0:(1<<CONFIG_DC_P_WAYS)-1];
	reg [(1<<CONFIG_DC_P_WAYS)-1:0]        s2i_tag_dirty;
	reg [CONFIG_DC_P_WAYS-1:0]             s2i_tag_lru      [0:(1<<CONFIG_DC_P_WAYS)-1];
	reg [TAG_ADDR_DW-1:0]                  s2i_tag_paddr    [0:(1<<CONFIG_DC_P_WAYS)-1];
   wire [CONFIG_DC_P_SETS-1:0]            s2i_entry_idx_final;
   wire                                   s2i_blk_wb_en;

   wire                                   s1_cke;
   wire                                   s1_readtag;
   reg [(1<<CONFIG_DC_P_WAYS)-1:0]        s2i_wr_tag;
   reg [(1<<CONFIG_DC_P_WAYS)-1:0]        s2i_wr_tag_v;
   reg [(1<<CONFIG_DC_P_WAYS)-1:0]        s2i_wr_tag_lru;
   wire                                   s2_cke;

   assign s1_cke = ~stall;
   assign s2_cke = ~stall;

   assign s1i_page_off = page_off;
   assign s1i_entry_idx = ch_boot ? cls_cnt : s1i_page_off[CONFIG_DC_P_LINE+CONFIG_DC_P_SETS-1:CONFIG_DC_P_LINE];

   always @(posedge clk or negedge rst_n)
      if (~rst_n)
         begin
            s1o_req_tmp_r <= 'b0;
            s1o_entry_idx <= 'b0; // Needed for bootstrap
         end
		else if (s1_cke)
         begin
            s1o_req_tmp_r <= req;
            s1o_page_off_r <= s1i_page_off;
            s1o_din_r <= wdat;
            s1o_wmask_r <= wmsk;
            s1o_entry_idx <= s1i_entry_idx;
         end

   // Cancel the request if MMU raised exceptions or cache is inhibited
   assign s1o_req = s1o_req_tmp_r & ~tlb_exc & ~tlb_uncached;

   // Switch the index for ch_boot | in_invfls
   assign s2i_entry_idx_final = (ch_boot)
                                 ? cls_cnt
                                 : (in_invfls_r)
                                    ? invfls_paddr_r[CONFIG_DC_P_LINE+CONFIG_DC_P_SETS-1:CONFIG_DC_P_LINE]
                                    : s1o_entry_idx;

   // Switch the index for s1_cke | s1_readtag | in_invfls
   assign s1i_entry_idx_final = (s1_cke)
                                 ? s1i_entry_idx
                                 : s2i_entry_idx_final;

   assign s1i_page_off_final = (s1_cke)
                                 ? s1i_page_off
                                 : (in_invfls_r)
                                    ? invfls_paddr_r[CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]
                                    : s1o_page_off_r;

   // Tag entries
generate
   for(i=0;i<(1<<CONFIG_DC_P_WAYS);i=i+1)
      begin : gen_tags_ram
         wire [TAG_DW-1:0] s2i_tag_din;
         wire [TAG_DW-1:0] s1o_tag_dout;

         assign s2i_tag_din = {s2i_tag_v[i], s2i_tag_dirty[i], s2i_tag_paddr[i]};
         assign {s1o_tag_v[i], s1o_tag_dirty[i], s1o_tag_paddr[i]} = s1o_tag_dout;

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
               .re     (s1_cke | s1_readtag | in_invfls_r),
               // Port B (Write)
               .waddr  (s2i_entry_idx_final),
               .din    (s2i_tag_din),
               .we     (s2i_wr_tag[i] | s2i_wr_tag_v[i])
            );

         // LRU
         ncpu32k_cell_sdpram_sclk
            #(
               .AW(CONFIG_DC_P_SETS),
               .DW(CONFIG_DC_P_WAYS),
               .ENABLE_BYPASS(1)
            )
         TAGS_LRU
            (
               .clk    (clk),
               .rst_n  (rst_n),
               // Port A (Read)
               .raddr  (s1i_entry_idx_final),
               .dout   (s1o_tag_lru[i]),
               .re     (s1_cke | s1_readtag | in_invfls_r),
               // Port B (Write)
               .waddr  (s2i_entry_idx_final),
               .din    (s2i_tag_lru[i]),
               .we     (s2i_wr_tag_lru[i])
            );
      end
endgenerate

   assign s1o_paddr = (in_invfls_r)
                        ? invfls_paddr_r
                        : {tlb_ppn[CONFIG_DC_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0], s1o_page_off_r[CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]};

   wire [(1<<CONFIG_DC_P_WAYS)-1:0]  s1o_match;
	wire [(1<<CONFIG_DC_P_WAYS)-1:0]  s1o_free;
   wire [CONFIG_DC_P_WAYS-1:0]       s1o_lru[(1<<CONFIG_DC_P_WAYS)-1:0];

generate
	for(i=0; i<(1<<CONFIG_DC_P_WAYS); i=i+1)
      begin : entry_wires
         assign s1o_match[i] = s1o_tag_v[i] & (s1o_tag_paddr[i] == s1o_paddr[CONFIG_DC_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS]);
         assign s1o_free[i] = ~|s1o_tag_lru[i];
         assign s1o_lru[i] = {CONFIG_DC_P_WAYS{s1o_match[i]}} & s1o_tag_lru[i];
      end
endgenerate

	wire s1o_hit = (|s1o_match);
	wire s1o_refill_dirty = |(s1o_free & s1o_tag_dirty);
   wire s1o_hit_dirty = |(s1o_match & s1o_tag_dirty);

   wire [CONFIG_DC_P_WAYS-1:0] s1o_match_way_idx;
   wire [CONFIG_DC_P_WAYS-1:0] s1o_free_way_idx;
   wire [CONFIG_DC_P_WAYS-1:0] s1o_lru_thresh;

generate
   if (CONFIG_DC_P_WAYS==2)
      begin : p_ways_2
         // 4-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = {|s1o_match[3:2], s1o_match[3] | s1o_match[1]};
         // 4-to-2 binary encoder
         assign s1o_free_way_idx = {|s1o_free[3:2], s1o_free[3] | s1o_free[1]};
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1] | s1o_lru[2] | s1o_lru[3];
      end
   else if (CONFIG_DC_P_WAYS==1)
      begin : p_ways_1
         // 1-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = s1o_match[1];
         // 1-to-2 binary encoder
         assign s1o_free_way_idx = s1o_free[1];
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1];
      end
endgenerate

   reg [CONFIG_DC_P_LINE - CONFIG_DBUS_BYTES_LOG2 -1:0] line_adr_cnt;

   // Maintain the line address counter,
   // when burst transmission for cache line filling or writing back
   always @(posedge clk or negedge rst_n)
      if (~rst_n)
         line_adr_cnt <= {CONFIG_DC_P_LINE - CONFIG_DBUS_BYTES_LOG2{1'b0}};
      else if (s2i_blk_wb_en | dbus_hds_R)
         line_adr_cnt <= line_adr_cnt + 'b1;

   wire [CONFIG_DC_DW/8-1:0] line_adr_cnt_msk;

   // Mask HI/LO 16bit.
generate
   if (CONFIG_DBUS_DW == 16 && CONFIG_DC_DW == 32)
      begin
         assign line_adr_cnt_msk = {line_adr_cnt[0], line_adr_cnt[0], ~line_adr_cnt[0], ~line_adr_cnt[0]};

         assign dbus_WDATA = line_adr_cnt[0] ? ch_mem_dout[15:0] : ch_mem_dout[31:16];
      end
   else if (CONFIG_DBUS_DW == 32 && CONFIG_DC_DW == 32)
      begin
         assign line_adr_cnt_msk = 4'b1111;

         assign dbus_WDATA = ch_mem_dout[31:0];
      end
   else initial $fatal(1, "Please implement one");
endgenerate

   localparam BLK_AW = CONFIG_DC_P_SETS + CONFIG_DC_P_LINE - CONFIG_DC_DW_BYTES_LOG2;

   // Port A (Slow side)
   wire [CONFIG_DC_DW-1:0] s2o_blk_dout_a [(1<<CONFIG_DC_P_WAYS)-1:0];
   // Port B (Fast side)
   wire [BLK_AW-1:0]       s1i_blk_addr_b;
   wire                    s1i_blk_en_b;
   wire [CONFIG_DC_DW-1:0] s1o_blk_dout_b [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                    s2i_refill;
   wire [CONFIG_DC_DW-1:0] s2i_refill_din;
   wire                    s2i_blk_en_a_g;
   wire [BLK_AW-1:0]       s2i_blk_addr_a;
   wire [CONFIG_DC_DW/8-1:0] s2i_blk_we_a;
   wire [CONFIG_DC_DW-1:0] s2i_blk_din_a;

   assign s2i_refill = ((status_r==S_READ_PENDING) | (status_r==S_WRITE_PENDING));

   // Stage #1: CPU Read
   assign s1i_blk_addr_b = {s1i_entry_idx_final[CONFIG_DC_P_SETS-1:0], s1i_page_off_final[CONFIG_DC_P_LINE-1:CONFIG_DC_DW_BYTES_LOG2]};
   assign s1i_blk_en_b = ((s1_cke & req & ch_idle_no_invfls) | s1_readtag);

   // Stage #2: CPU Write / Cache refill
   assign s2i_blk_wb_en = (status_r==S_WRITE_PENDING) & dbus_WREADY;
   assign s2i_blk_en_a_g = (status_r==S_WRITE_PENDING) 
                              ? dbus_WREADY
                              : (status_r==S_READ_PENDING)
                                 ? dbus_hds_R
                                 : 1'b1;
   
   // Note that block RAM takes 1clk to get its dout
   nDFF_r #(1) dff_dbus_WVALID
      (clk, rst_n, s2i_blk_wb_en, dbus_WVALID);
   

   localparam DELTA_DW = CONFIG_DC_DW_BYTES_LOG2-CONFIG_DBUS_BYTES_LOG2;

   assign s2i_blk_addr_a = {s2i_entry_idx_final[CONFIG_DC_P_SETS-1:0],
                              (s2i_refill)
                                 ? line_adr_cnt[DELTA_DW +: CONFIG_DC_P_LINE-CONFIG_DC_DW_BYTES_LOG2]
                                 : s1o_paddr[CONFIG_DC_P_LINE-1:CONFIG_DC_DW_BYTES_LOG2]
                              };

   assign s2i_blk_we_a = (s2i_refill)
                                 ? ({CONFIG_DC_DW/8{dbus_hds_R & (status_r==S_READ_PENDING)}} & line_adr_cnt_msk)
                                 : ({CONFIG_DC_DW/8{s2_cke & s1o_req}} & s1o_wmask_r);

   assign s2i_blk_din_a = (s2i_refill)
                           ? s2i_refill_din
                           : s1o_din_r;


generate
   if (CONFIG_DBUS_DW == 16 && CONFIG_DC_DW == 32)
      assign s2i_refill_din = {dbus_RDATA[CONFIG_DBUS_DW-1:0], dbus_RDATA[CONFIG_DBUS_DW-1:0]};
   else if (CONFIG_DBUS_DW == 32 && CONFIG_DC_DW == 32)
      assign s2i_refill_din = dbus_RDATA[CONFIG_DBUS_DW-1:0];
   else
      initial $fatal(1, "Please implement one");
endgenerate

   // Blocks
generate
   for(i=0;i<(1<<CONFIG_DC_P_WAYS);i=i+1)
      begin : gen_blks_ram
         wire s2i_matched = (s2i_refill & ~in_invfls_r)
                              ? s1o_free[i]
                              : s1o_match[i];
         wire [CONFIG_DC_DW/8-1:0] we_a = s2i_blk_we_a[CONFIG_DC_DW/8-1:0] & {CONFIG_DC_DW/8{s2i_matched}};
         wire en_a = (s2i_blk_en_a_g & s2i_matched);
         wire [CONFIG_DC_DW-1:0] dout_b;

         ncpu32k_dcache_ram
            #(
               .AW       (BLK_AW),
               .DW       (CONFIG_DC_DW)
            )
         PAYLOAD_RAM
            (
               .clk      (clk),
               .addr_a   (s2i_blk_addr_a[BLK_AW-1:0]),
               .we_a     (we_a),
               .din_a    (s2i_blk_din_a[CONFIG_DC_DW-1:0]),
               .dout_a   (s2o_blk_dout_a[i][CONFIG_DC_DW-1:0]),
               .en_a     (en_a),
               .addr_b   (s1i_blk_addr_b[BLK_AW-1:0]),
               .we_b     ({CONFIG_DC_DW/8{1'b0}}),
               .din_b    ({CONFIG_DC_DW{1'b0}}),
               .dout_b   (dout_b[CONFIG_DC_DW-1:0]),
               .en_b     (s1i_blk_en_b)
            );

         // Detect RAW dependency in D$ pipeline
         wire                                   rdat_bypass_r;
         wire [CONFIG_DC_DW-1:0]                rdat_din_r;
         wire [CONFIG_DC_DW/8-1:0]              rdat_wmsk_r;
         wire [CONFIG_DC_DW-1:0]                rdat_byp;
         wire                                   rdat_conflict;

         assign rdat_conflict = ((s2i_blk_addr_a == s1i_blk_addr_b) & s1i_blk_en_b & |we_a & en_a);

         // Bypass FSM
         nDFF_lr #(1, 1'b0) dff_rdat_bypass_r
            (clk,rst_n, (rdat_conflict|s1i_blk_en_b), (rdat_conflict | ~s1i_blk_en_b), rdat_bypass_r); // Keep bypass_r valid till the next Read
         // Latch din
         nDFF_l #(CONFIG_DC_DW) dff_rdat_din_r
            (clk, (|we_a & en_a), s2i_blk_din_a, rdat_din_r);
         // Latch w mask
         nDFF_l #(CONFIG_DC_DW/8) dff_rdat_wmsk_r
            (clk, (|we_a & en_a), we_a, rdat_wmsk_r);

         // Restore byte selection
         for(j=0; j<CONFIG_DC_DW/8; j=j+1)
            begin : gen_rdat_byp
               assign rdat_byp[j*8 +: 8] = (rdat_wmsk_r[j])
                                             ? rdat_din_r[j*8 +: 8]
                                             : dout_b[j*8 +: 8];
            end

         assign s1o_blk_dout_b[i] = rdat_bypass_r ? rdat_byp : dout_b;
         
      end
endgenerate

   assign ch_mem_dout = s2o_blk_dout_a[(in_invfls_r)
                                          ? s1o_match_way_idx
                                          : s1o_free_way_idx];

   assign rdat = s1o_blk_dout_b[s1o_match_way_idx];


   // Combined logic to maintain tags
generate
	for(i=0; i<(1<<CONFIG_DC_P_WAYS); i=i+1)
      begin : gen_combways

         // LRU combs
         always @(*)
            if (ch_boot)
               begin
                  // Reset LRU tag
                  s2i_tag_lru[i] = i;
                  s2i_wr_tag_lru[i] = 1'b1;
               end
            else if (ch_idle_no_invfls & s1o_req & s1o_hit)
               begin
                  // Update LRU priority
                  s2i_tag_lru[i] = s1o_match[i] ? {CONFIG_DC_P_WAYS{1'b1}} : s1o_tag_lru[i] - (s1o_tag_lru[i] > s1o_lru_thresh);
                  s2i_wr_tag_lru[i] = 1'b1;
               end
            else
               begin
                  // Hold
                  s2i_tag_lru[i] = s1o_tag_lru[i];
                  s2i_wr_tag_lru[i] = 1'b0;
               end

         // D combs
         always @(*)
            if (ch_boot)
               begin
                  // Reset D tag
                  s2i_tag_dirty[i] = 1'b0;
                  s2i_wr_tag[i] = 1'b1;
               end
            else if (ch_idle_no_invfls & s1o_req & s1o_hit & s1o_match[i])
               begin
                  // Mark it dirty when write
                  s2i_tag_dirty[i] = s1o_tag_dirty[i] | (|s1o_wmask_r);
                  s2i_wr_tag[i] = 1'b1;
               end
            else if(ch_idle_no_invfls & s1o_req & ~s1o_hit & s1o_free[i])
               begin
                  // Mark it clean when entry is freed
                  s2i_tag_dirty[i] = 1'b0;
                  s2i_wr_tag[i] = 1'b1;
               end
            else if (ch_fls_2 & s1o_hit & s1o_match[i])
               begin
                  // Flushed
                  s2i_tag_dirty[i] = 1'b0;
                  s2i_wr_tag[i] = 1'b1;
               end
            else if (ch_inv_2 & s1o_hit & s1o_hit_dirty & s1o_match[i])
               begin
                  // Invalidate with writing back
                  s2i_tag_dirty[i] = 1'b0;
                  s2i_wr_tag[i] = 1'b1;
               end
            else
               begin
                  // Hold
                  s2i_tag_dirty[i] = s1o_tag_dirty[i];
                  s2i_wr_tag[i] = 1'b0;
               end

         // V + ADDR combs
         always @(*)
            if(ch_boot)
               begin
                  // Reset V ADDR tag
                  s2i_tag_v[i] = 1'b0;
                  s2i_tag_paddr[i] = {TAG_ADDR_DW{1'b0}};
                  s2i_wr_tag_v[i] = 1'b1;
               end
            else if(ch_idle_no_invfls & s1o_req & ~s1o_hit & s1o_free[i])
               begin
                  // Cache missed
                  // Replace a free entry
                  s2i_tag_v[i] = 1'b1;
                  s2i_tag_paddr[i] = s1o_paddr[CONFIG_DC_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS];
                  s2i_wr_tag_v[i] = 1'b1;
               end
            else if (ch_inv_2 & s1o_hit & s1o_match[i])
               begin
                  // Invalidated
                  s2i_tag_v[i] = 1'b0;
                  s2i_tag_paddr[i] = s1o_tag_paddr[i];
                  s2i_wr_tag_v[i] = 1'b1;
               end
            else
               begin
                  // Hold
                  s2i_tag_v[i] = s1o_tag_v[i];
                  s2i_tag_paddr[i] = s1o_tag_paddr[i];
                  s2i_wr_tag_v[i] = 1'b0;
               end

      end
endgenerate

   // Read the tags while stage #1 is stalling.
   // This happens when cache line refill is completed,
   // in the next beat, tags will hold the latest value.
   assign s1_readtag = (status_r == S_READOUT);

   assign stall = ~ch_idle | (s1o_req & ~s1o_hit);

   // If INV/FLS is pending, do not handle any command
   // until INV/FLS is finished.
   assign ch_idle_no_invfls = (ch_idle & ~msr_dcinv_we & ~msr_dcfls_we);

   // Write-back FSM
   always @(*)
      begin
         status_nxt = status_r;
         in_invfls_nxt = in_invfls_r;
         invfls_paddr_nxt = invfls_paddr_r;

         case (status_r)
            S_BOOT:
               begin
                  if (cls_cnt == {CONFIG_DC_P_SETS{1'b0}})
                     status_nxt = S_READOUT;
               end
            S_IDLE:
               begin
                  if (msr_dcfls_we)
                     begin
                        // Flush
                        invfls_paddr_nxt = msr_dcfls_nxt;
                        in_invfls_nxt = 1'b1;
                        status_nxt = S_FLS_1;
                     end
                  else if (msr_dcinv_we)
                     begin
                        // Invalidate
                        invfls_paddr_nxt = msr_dcinv_nxt;
                        in_invfls_nxt = 1'b1;
                        status_nxt = S_INV_1;
                     end
                  else if (s1o_req & ~s1o_hit)
                     begin
                        // Cache missed, refill a free line
                        // If the target is dirty, then write back
                        status_nxt = s1o_refill_dirty ? S_WRITE_PENDING : S_READ_PENDING;
                     end
               end
            
            S_WRITE_PENDING:
               if (&line_adr_cnt)
                  status_nxt = S_READ_AFTER_B;
            S_READ_AFTER_B:
               if (dbus_hds_B)
                  begin
                     if (in_invfls_r)
                        begin
                           // End up INV or FLS
                           in_invfls_nxt = 1'b0;
                           status_nxt = S_READOUT;
                        end
                     else
                        begin
                           status_nxt = S_READ_PENDING;
                        end
                  end
               
            S_READ_PENDING:
               if (&line_adr_cnt)
                  status_nxt = S_READOUT;

            S_FLS_1:
               // Readout tag
               status_nxt = S_FLS_2;

            S_INV_1:
               // Readout tag
               status_nxt = S_INV_2;

            S_INV_2,
            S_FLS_2:
               if (s1o_hit & s1o_hit_dirty)
                  begin
                     // Write back the cache line
                     status_nxt = S_WRITE_PENDING;
                  end
               else
                  begin
                     // End up FLS
                     in_invfls_nxt = 1'b0;
                     status_nxt = S_READOUT;
                  end

            S_READOUT:
               status_nxt = S_IDLE;

            default: begin
               status_nxt = status_r;
            end
         endcase
      end

   nDFF_l #(`NCPU_DW) dff_invfls_paddr_r
      (clk, 1'b1, invfls_paddr_nxt, invfls_paddr_r);

   nDFF_r #(1) dff_in_invfls_r
      (clk, rst_n, in_invfls_nxt, in_invfls_r);
   nDFF_r #(4, S_BOOT) dff_status_r
      (clk, rst_n, status_nxt, status_r);

   nDFF_lr #(CONFIG_DC_P_SETS, {CONFIG_DC_P_SETS{1'b1}}) dff_cls_cnt
      (clk, rst_n, ch_boot, cls_cnt - 'b1, cls_cnt);

   wire [CONFIG_DC_AW-1:0] s1o_free_line_paddr;
   wire [CONFIG_DC_AW-1:0] s1o_hit_line_paddr;

   assign s1o_free_line_paddr = {s1o_tag_paddr[s1o_free_way_idx], s2i_entry_idx_final, {CONFIG_DC_P_LINE{1'b0}} };
   assign s1o_hit_line_paddr = {s1o_tag_paddr[s1o_match_way_idx], s2i_entry_idx_final, {CONFIG_DC_P_LINE{1'b0}} };

   // Resolve the start address of burst transmission
   // NOTE: Ensure dbus_ARWADDR doesn't change while dbus_ARWVALID is asserting.
	always @(*)
      begin
         dbus_AADDR_nxt = dbus_ARWADDR;
         case(status_r)
            S_IDLE:
               begin
                  dbus_AADDR_nxt = s1o_refill_dirty
                                       ? s1o_free_line_paddr[CONFIG_DBUS_AW-1:0] // truncate address bits
                                       : {s1o_paddr[CONFIG_DBUS_AW-1:CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits
               end

            S_INV_2,
            S_FLS_2:
               if (s1o_hit & s1o_hit_dirty)
                  begin
                     dbus_AADDR_nxt = s1o_hit_line_paddr[CONFIG_DBUS_AW-1:0]; // truncate address bits
                  end

            S_READ_AFTER_B:
               if (status_nxt == S_READ_PENDING)
                  begin
                     // Prepare to read from DBUS
                     dbus_AADDR_nxt = {s1o_paddr[CONFIG_DBUS_AW-1:CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits
                  end

            default:
               begin
                  dbus_AADDR_nxt = dbus_ARWADDR;
               end
         endcase
      end

   nDFF_l #(CONFIG_DBUS_AW) dff_dbus_AADDR
      (clk, 1'b1, dbus_AADDR_nxt, dbus_ARWADDR);

   assign dbus_A_set = // Prepare to write:
                        (status_r != S_WRITE_PENDING && status_nxt == S_WRITE_PENDING) |
                        // Prepare to read:
                        (status_r != S_READ_PENDING && status_nxt == S_READ_PENDING);

   assign dbus_A_clr = (dbus_ARWVALID & dbus_ARWREADY);

   nDFF_lr #(1) dff_dbus_AVALID
      (clk,rst_n, (dbus_A_set|dbus_A_clr), (dbus_A_set | ~dbus_A_clr), dbus_ARWVALID);

   assign dbus_AWE = (status_r == S_WRITE_PENDING);
   
   assign dbus_hds_R = (dbus_RVALID & dbus_RREADY);
   assign dbus_hds_W = (dbus_WVALID & dbus_WREADY);
   assign dbus_hds_B = (dbus_BVALID & dbus_BREADY);

   assign dbus_BREADY = (status_r == S_READ_AFTER_B);
   assign dbus_RREADY = 1'b1;

   // DCID Register
   assign msr_dcid[3:0] = CONFIG_DC_P_SETS[3:0];
   assign msr_dcid[7:4] = CONFIG_DC_P_LINE[3:0];
   assign msr_dcid[11:8] = CONFIG_DC_P_WAYS[3:0];
   assign msr_dcid[31:12] = 20'b0;


   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      // Assertion 03251128
      if (s1o_req & count_1(s1o_match)>1)
         $fatal(1, "math should be mutex.");
      if (s1o_req & count_1(s1o_free)>1)
         $fatal(1, "s1o_free should be mutex.");

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
