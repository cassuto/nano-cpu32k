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

module ncpu32k_icache
#(
   parameter CONFIG_IBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_IBUS_DW/8) */
   parameter CONFIG_IBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IC_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IC_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IC_DW_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_IC_DW/8) */
   parameter CONFIG_IC_P_LINE
   `PARAM_NOT_SPECIFIED , /* = log2(Size of a line) */
   parameter CONFIG_IC_P_SETS
   `PARAM_NOT_SPECIFIED , /* = log2(Number of sets) */
   parameter CONFIG_IC_P_WAYS
   `PARAM_NOT_SPECIFIED /* = log2(Number of ways) */
)
(
   input                         clk,
   input                         rst_n,
   input                         re,
   input [CONFIG_IMMU_PAGE_SIZE_LOG2-1:0] page_off,
   input [CONFIG_IC_AW-CONFIG_IMMU_PAGE_SIZE_LOG2-1:0] tlb_ppn,
   output [CONFIG_IC_DW-1:0]     dout,
   output                        dout_vld, // If cache is blocking, then assert low
   output                        dout_rdy,
   output                        stall_pc,
   // Async I-Bus Master
   input                         ibus_clk,
   input                         ibus_rst_n,
   input                         ibus_AREADY,
   output                        ibus_AVALID,
   output [CONFIG_IBUS_AW-1:0]   ibus_AADDR,
   output [CONFIG_IC_P_LINE-1:0] ibus_ALEN,
   input                         ibus_BVALID,
   output                        ibus_BREADY,
   input [CONFIG_IBUS_DW-1:0]    ibus_BDATA
);

   // Main FSM states
   localparam                    S_IDLE = 2'b00;
   localparam                    S_READ_PENDING_1 = 2'b01;
   localparam                    S_READ_PENDING_2 = 2'b11;
   localparam                    S_BOOT = 2'b10;

   // Tag data
   localparam                    TAG_ADDR_DW = CONFIG_IC_AW-CONFIG_IC_P_SETS-CONFIG_IC_P_LINE;
   localparam                    TAG_DW = 1 + TAG_ADDR_DW; // V + ADDR

   genvar i;

   wire [CONFIG_IC_P_SETS-1:0]   cls_cnt;
   wire [1:0]                    status_r;
   reg [1:0]                     status_nxt;
   wire                          ch_idle = (status_r == S_IDLE);
   wire                          ch_boot = (status_r == S_BOOT);
   wire                          cdc_line_adr_cnt_msb;
   wire                          cdc_ibus_A_set;
   wire                          cdc_ibus_A_clr;
   wire                          cdc_ibus_AVALID;
   wire                          cdc_ibus_AREADY;

   //
   // Structure of pipelined cache:
   //
   //       +---+          +-----+         +---+
   // s1i ->|DFF| -> s1o ->|combo|-> s2i ->|DFF| -> s2o
   //       +---+          +-----+         +---+
   //

   // Input of Stage #1
   wire [CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off;
   wire [CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]  s1i_page_off_final;
   wire [CONFIG_IC_P_SETS-1:0]   s1i_entry_idx;
   wire [CONFIG_IC_P_SETS-1:0]   s1i_entry_idx_final;

   // Output of Stage #1
   reg                           s1o_re_r;
   reg [CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]   s1o_page_off_r;
   wire [CONFIG_IC_AW-1:0]       s1o_paddr;
   reg [CONFIG_IC_P_SETS-1:0]    s1o_entry_idx;
   wire                          s1o_tag_v      [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [CONFIG_IC_P_WAYS-1:0]   s1o_tag_lru    [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [TAG_ADDR_DW-1:0]        s1o_tag_paddr   [0:(1<<CONFIG_IC_P_WAYS)-1];

   // Input of Stage #2
   reg                           s2i_tag_v      [0:(1<<CONFIG_IC_P_WAYS)-1];
   reg [CONFIG_IC_P_WAYS-1:0]    s2i_tag_lru    [0:(1<<CONFIG_IC_P_WAYS)-1];
   reg [TAG_ADDR_DW-1:0]         s2i_tag_paddr  [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [CONFIG_IC_P_SETS-1:0]   s2i_entry_idx;

   wire                          s1_cke;
   wire                          s1_readtag;
   reg [(1<<CONFIG_IC_P_WAYS)-1:0] s2i_wr_tag;
   reg [(1<<CONFIG_IC_P_WAYS)-1:0] s2i_wr_tag_lru;

   assign s1i_page_off = page_off;
   assign s1i_entry_idx = ch_boot ? cls_cnt : s1i_page_off[CONFIG_IC_P_LINE+CONFIG_IC_P_SETS-1:CONFIG_IC_P_LINE];

   assign s1_cke = ~stall_pc;

   always @(posedge clk or negedge rst_n)
      if (~rst_n)
         begin
            s1o_re_r <= 1'b0;
            s1o_entry_idx <= 'b0; // Needed for bootstrap
         end
      else if (s1_cke)
         begin
            s1o_re_r <= re;
            s1o_page_off_r <= s1i_page_off;
            s1o_entry_idx <= s1i_entry_idx;
         end

   // Switch the index for s1_cke | s1_readtag
   // And keep the previous index when stalling
   assign s1i_entry_idx_final = s1_cke ? s1i_entry_idx : s1o_entry_idx;
   assign s1i_page_off_final = s1_cke ? s1i_page_off : s1o_page_off_r;

   assign s2i_entry_idx = ch_boot ? cls_cnt : s1o_entry_idx;

   // Tag entries
generate
   for(i=0;i<(1<<CONFIG_IC_P_WAYS);i=i+1)
      begin : gen_tags_ram
         wire [TAG_DW-1:0] s2i_tag_din;
         wire [TAG_DW-1:0] s1o_tag_dout;

         assign s2i_tag_din = {s2i_tag_v[i], s2i_tag_paddr[i]};
         assign {s1o_tag_v[i], s1o_tag_paddr[i]} = s1o_tag_dout;

         // Tags (V + D + ADDR)
         ncpu32k_cell_sdpram_sclk
            #(
               .AW(CONFIG_IC_P_SETS),
               .DW(TAG_DW),
               .ENABLE_BYPASS(1)
            )
         TAGS
            (
               .clk     (clk),
               .rst_n   (rst_n),
               // Port A (Read)
               .raddr   (s1i_entry_idx_final),
               .dout    (s1o_tag_dout),
               .re      (s1_cke | s1_readtag),
               // Port B (Write)
               .waddr   (s2i_entry_idx),
               .din     (s2i_tag_din),
               .we      (|s2i_wr_tag)
            );

         // LRU
         ncpu32k_cell_sdpram_sclk
            #(
               .AW(CONFIG_IC_P_SETS),
               .DW(CONFIG_IC_P_WAYS),
               .ENABLE_BYPASS(1)
            )
         TAGS_LRU
            (
               .clk    (clk),
               .rst_n  (rst_n),
               // Port A (Read)
               .raddr  (s1i_entry_idx_final),
               .dout   (s1o_tag_lru[i]),
               .re     (s1_cke | s1_readtag),
               // Port B (Write)
               .waddr  (s2i_entry_idx),
               .din    (s2i_tag_lru[i]),
               .we     (|s2i_wr_tag_lru)
            );
      end
endgenerate

   assign s1o_paddr = {tlb_ppn[CONFIG_IC_AW-CONFIG_IMMU_PAGE_SIZE_LOG2-1:0], s1o_page_off_r[CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]};

   wire [(1<<CONFIG_IC_P_WAYS)-1:0]  s1o_match;
   wire [(1<<CONFIG_IC_P_WAYS)-1:0]  s1o_free;
   wire [CONFIG_IC_P_WAYS-1:0]       s1o_lru [(1<<CONFIG_IC_P_WAYS)-1:0];

generate
   for(i=0; i<(1<<CONFIG_IC_P_WAYS); i=i+1)
      begin : entry_wires
         assign s1o_match[i] = s1o_tag_v[i] & (s1o_tag_paddr[i] == s1o_paddr[CONFIG_IC_AW-1:CONFIG_IC_P_LINE+CONFIG_IC_P_SETS] );
         assign s1o_free[i] = ~|s1o_tag_lru[i];
         assign s1o_lru[i] = {CONFIG_IC_P_WAYS{s1o_match[i]}} & s1o_tag_lru[i];
      end
endgenerate

   wire s1o_hit = |s1o_match;

   wire [CONFIG_IC_P_WAYS-1:0] s1o_match_way_idx;
   wire [CONFIG_IC_P_WAYS-1:0] s1o_free_way_idx;
   wire [CONFIG_IC_P_WAYS-1:0] s1o_lru_thresh;

generate
   if (CONFIG_IC_P_WAYS==2)
      begin : p_ways_2
         // 4-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = {|s1o_match[3:2], s1o_match[3] | s1o_match[1]};
         // 4-to-2 binary encoder
         assign s1o_free_way_idx = {|s1o_free[3:2], s1o_free[3] | s1o_free[1]};
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1] | s1o_lru[2] | s1o_lru[3];
      end
   else if (CONFIG_IC_P_WAYS==1)
      begin : p_ways_1
         // 1-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = s1o_match[1];
         // 1-to-2 binary encoder
         assign s1o_free_way_idx = s1o_free[1];
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1];
      end
endgenerate

/////////////////////////////////////////////////////////////////////////////
// Begin of ibus clock domain
/////////////////////////////////////////////////////////////////////////////
   wire ibus_hds_B;
   reg [CONFIG_IC_P_LINE - CONFIG_IBUS_BYTES_LOG2 -1:0] slow_line_adr_cnt; // MSB is used to check overflow

   assign ibus_hds_B = (ibus_BVALID & ibus_BREADY);

   // Maintain the line address counter
   // for burst transmission of cache line when writing back
   always @(posedge ibus_clk or negedge ibus_rst_n)
      if (~ibus_rst_n)
         slow_line_adr_cnt <= {CONFIG_IC_P_LINE - CONFIG_IBUS_BYTES_LOG2 {1'b0}};
      else if (ibus_hds_B)
         slow_line_adr_cnt <= slow_line_adr_cnt + 1'b1;
      
   ncpu32k_cdc_sync
      #(
         .RST_VALUE ('b0),
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_LINE_ADR_CNT_MSB
      (
         .A (slow_line_adr_cnt[CONFIG_IC_P_LINE - CONFIG_IBUS_BYTES_LOG2 -1]),
         .CLK_B (clk),
         .RST_N_B (rst_n),
         .B (cdc_line_adr_cnt_msb)
      );

   wire [CONFIG_IC_DW/8-1:0] slow_line_adr_cnt_msk;

   generate
      if (CONFIG_IC_DW == 64)
         assign slow_line_adr_cnt_msk = {slow_line_adr_cnt[1:0]==2'b11, slow_line_adr_cnt[1:0]==2'b11,
                                    slow_line_adr_cnt[1:0]==2'b10, slow_line_adr_cnt[1:0]==2'b10,
                                    slow_line_adr_cnt[1:0]==2'b01, slow_line_adr_cnt[1:0]==2'b01,
                                    slow_line_adr_cnt[1:0]==2'b00, slow_line_adr_cnt[1:0]==2'b00};
      else if (CONFIG_IC_DW == 32)
         assign slow_line_adr_cnt_msk = {slow_line_adr_cnt[0], slow_line_adr_cnt[0],
                                    ~slow_line_adr_cnt[0], ~slow_line_adr_cnt[0]};
      else
         initial $fatal(1, "Please implement one");
   endgenerate

/////////////////////////////////////////////////////////////////////////////
// End of ibus clock domain
/////////////////////////////////////////////////////////////////////////////

   // Port B (Fast side)
   wire [CONFIG_IC_DW-1:0] s1o_blk_dout_b [(1<<CONFIG_IC_P_WAYS)-1:0];

   localparam BLK_AW = CONFIG_IC_P_SETS + CONFIG_IC_P_LINE - CONFIG_IC_DW_BYTES_LOG2;

   // Port B (Fast side)
   wire                    s1i_blk_en_b;
   wire [BLK_AW-1:0]       s1i_blk_addr_b;

   assign s1i_blk_en_b = ((s1_cke&re)|s1_readtag) & (ch_idle | (status_nxt == S_IDLE));
   assign s1i_blk_addr_b = {s1i_entry_idx_final[CONFIG_IC_P_SETS-1 : 0], s1i_page_off_final[CONFIG_IC_P_LINE-1 : CONFIG_IC_DW_BYTES_LOG2]};

   // Blocks
generate
   for(i=0;i<(1<<CONFIG_IC_P_WAYS);i=i+1)
      begin : gen_blk_ram
         // Port A (Slow side)
         wire                    s2i_blk_en_a;
         wire [BLK_AW-1:0]       s2i_blk_addr_a;
         wire [CONFIG_IC_DW-1:0] s2i_blk_din_a;
         wire [CONFIG_IC_DW/8-1:0] s2i_blk_we_a;

         wire s2i_matched = (s1o_match_way_idx == i);

/////////////////////////////////////////////////////////////////////////////
// Begin of ibus clock domain
/////////////////////////////////////////////////////////////////////////////

         localparam DELTA_DW = CONFIG_IC_DW_BYTES_LOG2-CONFIG_IBUS_BYTES_LOG2;

         assign s2i_blk_en_a = ibus_hds_B & s2i_matched;
         assign s2i_blk_addr_a = {s1o_entry_idx[CONFIG_IC_P_SETS-1:0], slow_line_adr_cnt[DELTA_DW +: CONFIG_IC_P_LINE-CONFIG_IC_DW_BYTES_LOG2]};
         assign s2i_blk_we_a = {CONFIG_IC_DW/8{ibus_hds_B & s2i_matched}} & slow_line_adr_cnt_msk;

         if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 16)
            assign s2i_blk_din_a = {ibus_BDATA[15:0], ibus_BDATA[15:0],
                                    ibus_BDATA[15:0], ibus_BDATA[15:0]};
         else if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 32)
            assign s2i_blk_din_a = {ibus_BDATA[31:0], ibus_BDATA[31:0]};
         else if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 64)
            assign s2i_blk_din_a = ibus_BDATA;
         else
            initial $fatal(1, "Please implement one");

/////////////////////////////////////////////////////////////////////////////
// End of ibus clock domain
/////////////////////////////////////////////////////////////////////////////

         ncpu32k_icache_ram
            #(
               .AW (BLK_AW) ,
               .DW (CONFIG_IC_DW)
            )
         PAYLOAD_RAM
            (
               .clk_a   (ibus_clk),
               .addr_a  (s2i_blk_addr_a[BLK_AW-1:0]),
               .we_a    (s2i_blk_we_a[CONFIG_IC_DW/8-1:0]),
               .din_a   (s2i_blk_din_a[CONFIG_IC_DW-1:0]),
               .en_a    (s2i_blk_en_a),
               .clk_b   (clk),
               .addr_b  (s1i_blk_addr_b[BLK_AW-1:0]),
               .dout_b  (s1o_blk_dout_b[i][CONFIG_IC_DW-1:0]),
               .en_b    (s1i_blk_en_b)
            );
      end
endgenerate

   assign dout = s1o_blk_dout_b[s1o_match_way_idx];

   // If icache is blocking, then `dout_vld` is asserted low.
   // Use this signal to check whether we should issue the invalid NOP insn
   // to the backend.
   assign dout_vld = (ch_idle & s1o_hit);

   // As long as dout is valid, this signal is asserted high,
   // while icache may be blocking.
   // Use this signal to flush PC when BPU predicates taken.
   nDFF_lr #(1) dff_dout_rdy
      (clk, rst_n, s1i_blk_en_b, 1'b1, dout_rdy);


   // Combined logic to maintain tags
generate
   for(i=0; i<(1<<CONFIG_IC_P_WAYS); i=i+1)
      begin : gen_combways

         // LRU combs
         always @(*)
            begin
               if (ch_boot)
                  begin
                     // Reset LRU tag
                     s2i_tag_lru[i] = i;
                     s2i_wr_tag_lru[i] = 1'b1;
                  end
               else if (ch_idle & s1o_re_r & s1o_hit)
                  begin
                     // Update LRU priority
                     s2i_tag_lru[i] = s1o_match[i] ? {CONFIG_IC_P_WAYS{1'b1}} : s1o_tag_lru[i] - (s1o_tag_lru[i] > s1o_lru_thresh);
                     s2i_wr_tag_lru[i] = 1'b1;
                  end
               else
                  begin
                     // Hold
                     s2i_tag_lru[i] = s1o_tag_lru[i];
                     s2i_wr_tag_lru[i] = 1'b0;
                  end
            end

         // V + ADDR combs
         always @(*)
            begin
               if(ch_boot)
                  begin
                     // Reset V ADDR tag
                     s2i_tag_v[i] = 1'b0;
                     s2i_tag_paddr[i] = {TAG_ADDR_DW{1'b0}};
                     s2i_wr_tag[i] = 1'b1;
                  end
               else if(ch_idle & s1o_re_r & ~s1o_hit & (s1o_free_way_idx == i))
                  begin
                     // Cache missed
                     // Replace a free entry
                     s2i_tag_v[i] = 1'b1;
                     s2i_tag_paddr[i] = s1o_paddr[CONFIG_IC_AW-1:CONFIG_IC_P_LINE+CONFIG_IC_P_SETS];
                     s2i_wr_tag[i] = 1'b1;
                  end
               else
                  begin
                     // Hold
                     s2i_tag_v[i] = s1o_tag_v[i];
                     s2i_tag_paddr[i] = s1o_tag_paddr[i];
                     s2i_wr_tag[i] = 1'b0;
                  end
            end

      end
endgenerate

   // Write-back FSM
   always @(*)
      begin
         status_nxt = status_r;
         case(status_r)
            S_BOOT:
               begin
                  if (cls_cnt == {CONFIG_IC_P_SETS{1'b0}})
                     status_nxt = S_IDLE;
               end

            S_IDLE:
               begin
                  if (s1o_re_r & ~s1o_hit) // Cache missed
                     status_nxt = S_READ_PENDING_1;
               end
            
            S_READ_PENDING_1:
               begin
                  if(cdc_line_adr_cnt_msb)
                     status_nxt = S_READ_PENDING_2;
               end
            S_READ_PENDING_2:
               begin
                  if(~cdc_line_adr_cnt_msb)
                     status_nxt = S_IDLE;
               end
         endcase
      end

   nDFF_r #(2, S_BOOT) dff_status_r
      (clk, rst_n, status_nxt, status_r);
   nDFF_lr #(CONFIG_IC_P_SETS, {CONFIG_IC_P_SETS{1'b1}}) dff_cls_cnt
      (clk, rst_n, ch_boot, cls_cnt - 'b1, cls_cnt);
      
   // Read the tags while stage #1 is stalling.
   // This happens when cache line replacement is completed,
   // in the next beat, tags will hold the latest value.
   // In addition, readout the cleared values when booting.
   assign s1_readtag = ((status_r == S_READ_PENDING_2) & (status_nxt == S_IDLE)) | ch_boot;

   assign stall_pc = ~ch_idle | (s1o_re_r & ~s1o_hit);

   // Send request to IBUS
   assign cdc_ibus_A_set = (status_r == S_IDLE && status_nxt == S_READ_PENDING_1);
   assign cdc_ibus_A_clr = (cdc_ibus_AVALID & cdc_ibus_AREADY);
   
   nDFF_lr #(1) dff_ibus_AVALID
      (clk,rst_n, (cdc_ibus_A_set|cdc_ibus_A_clr), (cdc_ibus_A_set|~cdc_ibus_A_clr), cdc_ibus_AVALID);

/////////////////////////////////////////////////////////////////////////////
// Begin of ibus clock domain
/////////////////////////////////////////////////////////////////////////////

   //
   // cache to ibus
   //
   ncpu32k_cdc_sync_hds
      #(
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_IBUS
      (
         .clk_a      (clk),
         .rst_a_n    (rst_n),
         .AVALID     (cdc_ibus_AVALID),
         .AREADY     (cdc_ibus_AREADY),
         .clk_b      (ibus_clk),
         .rst_b_n    (ibus_rst_n),
         .BVALID     (ibus_AVALID),
         .BREADY     (ibus_AREADY)
      );

   assign ibus_AADDR = {s1o_paddr[CONFIG_IBUS_AW-1:CONFIG_IC_P_LINE], {CONFIG_IC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits
   
   assign ibus_ALEN = {CONFIG_IC_P_LINE{1'b1}};

   assign ibus_BREADY = 1'b1;

/////////////////////////////////////////////////////////////////////////////
// End of ibus clock domain
/////////////////////////////////////////////////////////////////////////////

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   initial
      begin
         if ((1<<CONFIG_IBUS_BYTES_LOG2) != (CONFIG_IBUS_DW/8))
            $fatal(1, "Error value of CONFIG_IBUS_BYTES_LOG2");
         if ((1<<CONFIG_IC_DW_BYTES_LOG2) != (CONFIG_IC_DW/8))
            $fatal(1, "Error value of CONFIG_IC_DW_BYTES_LOG2");
         if (CONFIG_IC_DW_BYTES_LOG2 < CONFIG_IBUS_BYTES_LOG2)
            $fatal(1, "Invalid configuration of IBW or IBUS");
         if (CONFIG_IMMU_PAGE_SIZE_LOG2 < CONFIG_IC_P_LINE + CONFIG_IC_P_SETS)
            $fatal(1, "Invalid size of icache (Must <= page size of I-MMU)");
      end

   // Assertions (03251128)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (s1o_re_r & count_1(s1o_match)>1)
         $fatal(1, "math should be mutex.");
      if (s1o_re_r & count_1(s1o_free)>1)
         $fatal(1, "s1o_free should be mutex.");
   end
`endif

`endif
   // synthesis translate_on

endmodule
