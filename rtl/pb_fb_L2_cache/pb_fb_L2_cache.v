/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is s1o_free edition; you can redistribute it and/or           */
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

module pb_fb_L2_cache
#(
   parameter P_WAYS = 2, // 2^ways
   parameter P_SETS	= 6, // 2^sets
   parameter P_LINE	= 6, // 2^P_LINE bytes per line (= busrt length of DRAM)
   parameter L2_CH_AW = 25,
   parameter L2_CH_DW = 32,
   parameter CONFIG_PIPEBUF_BYPASS=-1
)
(
   input                   clk,
   input                   rst_n,
   // L2 cache interface
   output                  l2_ch_BVALID,
   input                   l2_ch_BREADY,
   output                  l2_ch_AREADY,
   input                   l2_ch_AVALID,
   input [L2_CH_AW-1:0]    l2_ch_AADDR,
   input [1:0]             l2_ch_AEXC,
   input [L2_CH_DW/8-1:0]  l2_ch_AWMSK,
   output [L2_CH_DW-1:0]   l2_ch_BDATA,
   output [1:0]            l2_ch_BEXC,
   input [L2_CH_DW-1:0]    l2_ch_ADATA,
   input                   l2_ch_flush,

   // 2:1 SDRAM interface
   input                   sdr_clk,
   input                   sdr_rst_n,
   input [L2_CH_DW/2-1:0]  sdr_dout,
   output reg[L2_CH_DW/2-1:0] sdr_din,
   output reg              sdr_cmd_bst_rd_req,
   output reg              sdr_cmd_bst_we_req,
   output [L2_CH_AW-3:0]   sdr_cmd_addr,
   input                   sdr_r_vld,
   input                   sdr_w_rdy
);
   // Main FSM states
   localparam S_IDLE = 3'b000;
   localparam S_WRITE_PENDING = 3'b011;
   localparam S_RAW = 3'b111;
   localparam S_READ_PENDING_1 = 3'b100;
   localparam S_READ_PENDING_2 = 3'b101;
   localparam S_BOOT = 3'b110;

   // Tag data
   localparam TAG_ADDR_DW = L2_CH_AW-P_SETS-P_LINE;
   localparam TAG_DW = 2 + TAG_ADDR_DW; // V + D + ADDR

   genvar i;

   wire l2_ch_w_rdy; // Cache line write ready
   wire l2_ch_r_vld; // Cache line read valid
   reg nl_rd_r; // Read from next level cache/memory
   reg nl_we_r; // Write to next level cache/memory
   reg [L2_CH_AW-P_LINE-1:0] nl_baddr_r;
   wire [L2_CH_DW/2-1:0] nl_dout;
   reg [P_SETS-1:0] cls_cnt;
   reg [2:0] status_r;
   wire ch_idle = (status_r == S_IDLE);
   wire ch_boot = (status_r == S_BOOT);
	reg [P_LINE-2:0] line_adr_cnt; // unit: word (2 B)
	reg line_adr_cnt_msb_sr;
   wire [L2_CH_DW-1:0] ch_mem_dout;

   //
   // Structure of pipelined cache:
   //
   //       +---+          +-----+         +---+
   // s1i ->|DFF| -> s1o ->|combo|-> s2i ->|DFF| -> s2o
   //       +---+          +-----+         +---+
   //

   // Input of Stage #1
   wire [L2_CH_AW-1:0]     s1i_addr;
   wire [P_SETS-1:0]       s1i_entry_idx;

   // Output of Stage #1
	reg [L2_CH_AW-1:0]      s1o_addr_r;
	reg [L2_CH_DW-1:0]      s1o_din_r;
	reg [L2_CH_DW/8-1:0]    s1o_wmask_r;
   reg [1:0]               s1o_exc_r;
   reg [P_SETS-1:0]        s1o_entry_idx;
   wire                    s1o_tag_v        [0:(1<<P_WAYS)-1];
	wire [(1<<P_WAYS)-1:0]  s1o_tag_dirty;
	wire [P_WAYS-1:0]       s1o_tag_lru      [0:(1<<P_WAYS)-1];
	wire [TAG_ADDR_DW-1:0]  s1o_tag_addr     [0:(1<<P_WAYS)-1];

   // Input of Stage #2
   reg                     s2i_tag_v        [0:(1<<P_WAYS)-1];
	reg [(1<<P_WAYS)-1:0]   s2i_tag_dirty;
	reg [P_WAYS-1:0]        s2i_tag_lru      [0:(1<<P_WAYS)-1];
	reg [TAG_ADDR_DW-1:0]   s2i_tag_addr     [0:(1<<P_WAYS)-1];
   wire [P_SETS-1:0]       s2i_entry_idx;

   // Output of Stage #2
   reg [1:0]               s2o_exc_r;

   reg wb_idle_r;

   // This bit indicates the write-back has finished, while `s1o_hit` is still false.
   // When the next bus cmd transaction occurs, this bit will be zeroed.
   reg wb_finished_r;

   wire s1_cke;
   wire s1o_valid, s1_ready;
   wire s2_cke;
   wire pipe_en;

   ncpu32k_cell_pipebuf pipebuf_1 (
      .clk        (clk),
      .rst_n      (rst_n),
      .A_en       (~ch_boot),
      .AVALID     (l2_ch_AVALID),
      .AREADY     (l2_ch_AREADY),
      .B_en       (1'b1),
      .BVALID     (s1o_valid),
      .BREADY     (s1_ready),
      .cke        (s1_cke),
      .pending    ()
   );
   ncpu32k_cell_pipebuf pipebuf_2 (
      .clk        (clk),
      .rst_n      (rst_n),
      .A_en       (pipe_en),
      .AVALID     (s1o_valid),
      .AREADY     (s1_ready),
      .B_en       (1'b1),
      .BVALID     (l2_ch_BVALID),
      .BREADY     (l2_ch_BREADY),
      .cke        (s2_cke),
      .pending    ()
   );

   assign s1i_addr = l2_ch_AADDR;
   assign s1i_entry_idx = ch_boot ? cls_cnt : s1i_addr[P_LINE+P_SETS-1:P_LINE];

   always @(posedge clk) begin
		if (s1_cke) begin
			s1o_addr_r <= s1i_addr;
			s1o_din_r <= l2_ch_ADATA;
			s1o_wmask_r <= l2_ch_AWMSK & {L2_CH_DW/8{~|l2_ch_AEXC}}; // do not write if exception raised
         s1o_exc_r <= l2_ch_AEXC;
         s1o_entry_idx <= s1i_entry_idx;
		end
      if (s2_cke) begin
         s2o_exc_r <= s1o_exc_r;
      end
   end

   assign s2i_entry_idx = ch_boot ? cls_cnt : s1o_entry_idx;

   // Tag entries
generate
   for(i=0;i<(1<<P_WAYS);i=i+1)
      begin
         wire [TAG_DW-1:0] s2i_tag_din, s1o_tag_dout;
         wire [P_SETS-1:0] entry_idx;

         // stall input of stage 1
         assign entry_idx = pipe_en ? s1i_entry_idx : s2i_entry_idx;

         assign s2i_tag_din = {s2i_tag_v[i], s2i_tag_dirty[i], s2i_tag_addr[i]};
         assign {s1o_tag_v[i], s1o_tag_dirty[i], s1o_tag_addr[i]} = s1o_tag_dout;

         // Tags (V + D + ADDR)
         ncpu32k_cell_sdpram_sclk #(
            .AW(P_SETS),
            .DW(TAG_DW),
            .ENABLE_BYPASS(1)
         )
         tags (
            .clk    (clk),
            .rst_n  (rst_n),
            // Port A (Read)
            .raddr  (entry_idx),
            .dout   (s1o_tag_dout),
            .re     (s1_cke),
            // Port B (Write)
            .waddr  (s2i_entry_idx),
            .din    (s2i_tag_din),
            .we     (1'b1)
         );

         // LRU
         ncpu32k_cell_sdpram_sclk #(
            .AW(P_SETS),
            .DW(P_WAYS),
            .ENABLE_BYPASS(1)
         )
         tags_lru (
            .clk    (clk),
            .rst_n  (rst_n),
            // Port A (Read)
            .raddr  (entry_idx),
            .dout   (s1o_tag_lru[i]),
            .re     (s1_cke),
            // Port B (Write)
            .waddr  (s2i_entry_idx),
            .din    (s2i_tag_lru[i]),
            .we     (1'b1)
         );
      end
endgenerate

   wire [(1<<P_WAYS)-1:0]  s1o_match;
	wire [(1<<P_WAYS)-1:0]  s1o_free;
   wire [P_WAYS-1:0]       s1o_lru[(1<<P_WAYS)-1:0];

generate
	for(i=0; i<(1<<P_WAYS); i=i+1) begin : entry_wires
		assign s1o_match[i] = s1o_tag_v[i] & (s1o_tag_addr[i] == s1o_addr_r[L2_CH_AW-1:P_LINE+P_SETS]);
		assign s1o_free[i] = ~|s1o_tag_lru[i];
		assign s1o_lru[i] = {P_WAYS{s1o_match[i]}} & s1o_tag_lru[i];
	end
endgenerate

	wire s1o_hit = |s1o_match;
	wire s1o_dirty = |(s1o_free & s1o_tag_dirty);

   wire [P_WAYS-1:0] s1o_match_way_idx;
   wire [P_WAYS-1:0] s1o_free_way_idx;
   wire [P_WAYS-1:0] s1o_lru_thresh;

generate
   if (P_WAYS==2) begin : p_ways_2
      // 4-to-2 binary encoder. Assert (03251128)
      assign s1o_match_way_idx = {|s1o_match[3:2], s1o_match[3] | s1o_match[1]};
      // 4-to-2 binary encoder
      assign s1o_free_way_idx = {|s1o_free[3:2], s1o_free[3] | s1o_free[1]};
      // LRU threshold
      assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1] | s1o_lru[2] | s1o_lru[3];
   end else if (P_WAYS==1) begin : p_ways_1
      // 1-to-2 binary encoder. Assert (03251128)
      assign s1o_match_way_idx = s1o_match[1];
      // 1-to-2 binary encoder
      assign s1o_free_way_idx = s1o_free[1];
      // LRU threshold
      assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1];
   end
endgenerate

   // Maintain the line addr counter,
   // when burst transmission for cache line filling or writing back
   always @(posedge sdr_clk or negedge sdr_rst_n)
      if(~sdr_rst_n)
         line_adr_cnt <= {P_LINE-1{1'b0}};
      else if(l2_ch_w_rdy | l2_ch_r_vld)
         line_adr_cnt <= line_adr_cnt + 1'b1;

   // Mask HI/LO 16bit. Assert (03161421)
   always @(posedge sdr_clk)
      sdr_din <= line_adr_cnt[0] ? ch_mem_dout[15:0] : ch_mem_dout[31:16];

   localparam BLK_AW = P_SETS+P_LINE-2;

   // Mask HI/LO 16bit. Assert (03161421)
   wire [L2_CH_DW/8-1:0] line_adr_cnt_msk = {line_adr_cnt[0], line_adr_cnt[0], ~line_adr_cnt[0], ~line_adr_cnt[0]};

   // Port A (Slow side)
   wire [L2_CH_DW-1:0] s2o_blk_dout_a [(1<<P_WAYS)-1:0];
   // Port B (Fast side)
   wire [L2_CH_DW-1:0] s2o_blk_dout_b [(1<<P_WAYS)-1:0];

   // Blocks
generate
   for(i=0;i<(1<<P_WAYS);i=i+1)
      begin
         wire                  s2i_blk_en_a;
         wire [BLK_AW-1:0]     s2i_blk_addr_a;
         wire [L2_CH_DW-1:0]   s2i_blk_din_a;
         wire [L2_CH_DW/8-1:0] s2i_blk_we_a;
         wire                  s2i_blk_en_b;
         wire [BLK_AW-1:0]     s2i_blk_addr_b;
         wire [L2_CH_DW-1:0]   s2i_blk_din_b;
         wire [L2_CH_DW/8-1:0] s2i_blk_we_b;

         wire s2i_matched = (s1o_match_way_idx == i);

         assign s2i_blk_en_a = s2i_matched & (l2_ch_w_rdy | l2_ch_r_vld);
         assign s2i_blk_addr_a = {s1o_entry_idx[P_SETS-1:0], line_adr_cnt[P_LINE-2:1]};
         assign s2i_blk_din_a = {nl_dout[L2_CH_DW/2-1:0], nl_dout[L2_CH_DW/2-1:0]};
         assign s2i_blk_we_a = {L2_CH_DW/8{s2i_matched & l2_ch_w_rdy}} & line_adr_cnt_msk;

         assign s2i_blk_en_b = s2i_matched & s2_cke & ch_idle & (s1o_hit|wb_finished_r);
         assign s2i_blk_addr_b = {s1o_entry_idx[P_SETS-1:0], s1o_addr_r[P_LINE-1:2]};
         assign s2i_blk_we_b = {L2_CH_DW/8{s2i_matched}} & s1o_wmask_r;
         assign s2i_blk_din_b = s1o_din_r;

`ifdef PLATFORM_XILINX_XC6
         ramblk_cache_mem block_mem
            (
               .clka    (sdr_clk),
               .addra   (s2i_blk_addr_a[BLK_AW-1:0]),
               .wea     (s2i_blk_we_a[L2_CH_DW/8-1:0]),
               .dina    (s2i_blk_din_a[L2_CH_DW-1:0]),
               .douta   (s2o_blk_dout_a[i][L2_CH_DW-1:0]),
               .ena     (s2i_blk_en_a),
               .clkb    (clk),
               .addrb   (s2i_blk_addr_b[BLK_AW-1:0]),
               .web     (s2i_blk_we_b[L2_CH_DW/8-1:0]),
               .dinb    (s2i_blk_din_b[L2_CH_DW-1:0]),
               .doutb   (s2o_blk_dout_b[i][L2_CH_DW-1:0]),
               .enb     (s2i_blk_en_b)
            );
`else
         ncpu32k_cell_tdpram_aclkd_sclk
            #(
               .AW(BLK_AW),
               .DW(L2_CH_DW)
            )
         block_mem
            (
               .clk_a   (sdr_clk),
               .addr_a  (s2i_blk_addr_a[BLK_AW-1:0]),
               .we_a    (s2i_blk_we_a[L2_CH_DW/8-1:0]),
               .din_a   (s2i_blk_din_a[L2_CH_DW-1:0]),
               .dout_a  (s2o_blk_dout_a[i][L2_CH_DW-1:0]),
               .en_a    (s2i_blk_en_a),
               .clk_b   (clk),
               .addr_b  (s2i_blk_addr_b[BLK_AW-1:0]),
               .we_b    (s2i_blk_we_b[L2_CH_DW/8-1:0]),
               .din_b   (s2i_blk_din_b[L2_CH_DW-1:0]),
               .dout_b  (s2o_blk_dout_b[i][L2_CH_DW-1:0]),
               .en_b    (s2i_blk_en_b)
            );
`endif
      end
endgenerate

   assign l2_ch_BDATA = s2o_blk_dout_b[s1o_match_way_idx];
   assign l2_ch_BEXC = s2o_exc_r;

   assign ch_mem_dout = s2o_blk_dout_a[s1o_match_way_idx];

   // Combined logic to maintain tags
generate
	for(i=0; i<(1<<P_WAYS); i=i+1) begin : gen_combways

      // LRU combs
      always @(*)
         if (ch_boot) begin
            // Reset LRU tag
            s2i_tag_lru[i] = i;
         end else if (ch_idle & s1o_valid & s1o_hit) begin
            // Update LRU priority
            s2i_tag_lru[i] = s1o_match[i] ? {P_WAYS{1'b1}} : s1o_tag_lru[i] - (s1o_tag_lru[i] > s1o_lru_thresh);
         end else begin
            // Hold
            s2i_tag_lru[i] = s1o_tag_lru[i];
         end

      // D combs
      always @(*)
         if (ch_boot) begin
            // Reset D tag
            s2i_tag_dirty[i] = 1'b0;
         end else if (ch_idle & s1o_valid & s1o_hit) begin
            // Mark it dirty when write
            s2i_tag_dirty[i] = s1o_match[i] ? s1o_tag_dirty[i] | (|s1o_wmask_r) : s1o_tag_dirty;
         end else if(ch_idle & s1o_valid & s1o_free[i]) begin
            // Mark it clean when entry is freed
            s2i_tag_dirty[i] = 1'b0;
         end else begin
            // Hold
            s2i_tag_dirty[i] = s1o_tag_dirty[i];
         end

      // V + ADDR combs
		always @(*)
         if(ch_boot) begin
            // Reset V ADDR tag
            s2i_tag_v[i] = 1'b0;
            s2i_tag_addr[i] = {TAG_ADDR_DW{1'b0}};
         end else if(ch_idle & s1o_valid & ~s1o_hit & (s1o_free_way_idx == i)) begin
            // Cache missed
            // Replace a free entry
            s2i_tag_v[i] = 1'b1;
            s2i_tag_addr[i] = s1o_addr_r[L2_CH_AW-1:P_LINE+P_SETS];
         end else begin
            // Hold
            s2i_tag_v[i] = s1o_tag_v[i];
            s2i_tag_addr[i] = s1o_tag_addr[i];
         end

   end
endgenerate

   assign pipe_en = wb_idle_r & (~s1o_valid | (s1o_hit|wb_finished_r));

   // *Cross clock domain*
   always @(posedge clk or negedge rst_n)
      if(~rst_n)
         line_adr_cnt_msb_sr <= 1'b0;
      else
         line_adr_cnt_msb_sr <= line_adr_cnt[P_LINE-2];

   // Write-back FSM
	always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
         status_r <= S_BOOT;
         cls_cnt <= {P_SETS{1'b1}};
         wb_idle_r <= 1'b0;
         wb_finished_r <= 1'b0;
      end else begin
         if (s1_cke)
            wb_finished_r <= 1'b0;

         case(status_r)
            S_BOOT: begin
                // Invalidate cache lines
                cls_cnt <= cls_cnt - 1'b1;
                if (cls_cnt == {P_SETS{1'b0}}) begin
                    status_r <= S_IDLE;
                    wb_idle_r <= 1'b1;
                end
            end

            S_IDLE: begin
               nl_baddr_r <= s1o_dirty ? {s1o_tag_addr[s1o_free_way_idx], s1o_entry_idx} : s1o_addr_r[L2_CH_AW-1:P_LINE];
               if(s1o_valid & ~(s1o_hit|wb_finished_r)) begin
                  // Cache missed
                  // If the target is dirty, then write back
                  nl_rd_r <= ~s1o_dirty;
                  nl_we_r <= s1o_dirty;
                  status_r <= s1o_dirty ? S_WRITE_PENDING : S_READ_PENDING_1;
                  wb_idle_r <= 1'b0;
               end else begin
                  wb_idle_r <= 1'b1;
               end
            end
            // Pending for writing
            S_WRITE_PENDING: begin
               nl_rd_r <= 1'b1;
               if(line_adr_cnt_msb_sr) begin
                  nl_we_r <= 1'b0;
                  status_r <= S_RAW;
               end
            end
            // Read-after-write
            // Note writing is not really finished.
            S_RAW: begin
               nl_baddr_r <= s1i_addr[L2_CH_AW-1:P_LINE];
               if(~line_adr_cnt_msb_sr)
                  status_r <= S_READ_PENDING_1;
            end
            // Pending for reading
            S_READ_PENDING_1: begin
               if(line_adr_cnt_msb_sr)
                  status_r <= S_READ_PENDING_2;
            end
            S_READ_PENDING_2: begin
               nl_rd_r <= 1'b0;
               if(~line_adr_cnt_msb_sr) begin
                  status_r <= S_IDLE;
                  wb_finished_r <= 1'b1;
               end
            end
         endcase
      end
	end

   // SDRAM arbiter
   // *Cross clock domain*
   // Receive signals from nl_*

   // 2 Flip flops for crossing clock domains
   reg [1:0]sdr_rd_sr;
	reg [1:0]sdr_we_sr;
   reg [L2_CH_AW-3:0] sdr_cmd_addr_r;

   // Sample requests at SDRAM clock rise
   always @ (posedge sdr_clk or negedge sdr_rst_n) begin
      if(~sdr_rst_n) begin
         sdr_rd_sr <= 0;
         sdr_we_sr <= 0;
         sdr_cmd_bst_rd_req <= 1'b0;
         sdr_cmd_bst_we_req <= 1'b0;
      end else begin
         sdr_rd_sr <= {sdr_rd_sr[0], nl_rd_r};
         sdr_we_sr <= {sdr_we_sr[0], nl_we_r};
         sdr_cmd_addr_r <= {nl_baddr_r[L2_CH_AW-P_LINE-1:0], {P_LINE-2{1'b0}}};

         // Priority arbiter
         if(sdr_we_sr[1])
            sdr_cmd_bst_we_req <= 1'b1;
         else if(sdr_rd_sr[1])
            sdr_cmd_bst_rd_req <= 1'b1;
         else begin
            sdr_cmd_bst_we_req <= 1'b0;
            sdr_cmd_bst_rd_req <= 1'b0;
         end
      end
   end

   assign sdr_cmd_addr = sdr_cmd_addr_r;

   assign nl_dout = sdr_dout;

   assign l2_ch_w_rdy = sdr_r_vld;
   assign l2_ch_r_vld = sdr_w_rdy;

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions (03161421)
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if(L2_CH_DW!=32)
         $fatal ("\n non 32bit L2 cache unsupported.");
   end
`endif

   // Assertions (03251128)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (s1o_valid & count_1(s1o_match)>1)
         $fatal(0, "math should be mutex.");
      if (s1o_valid & count_1(s1o_free)>1)
         $fatal(0, "s1o_free should be mutex.");
   end
`endif

`endif
   // synthesis translate_on

endmodule
