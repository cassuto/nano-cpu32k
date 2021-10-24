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
   output                        icinv_stall, // If cache is processing ICINV
   // ICID
   output [`NCPU_DW-1:0]         msr_icid,
   // ICINV
   input [`NCPU_DW-1:0]          msr_icinv_nxt,
   input                         msr_icinv_we,
   // I-Bus Master
   input                         ibus_ARREADY,
   output                        ibus_ARVALID,
   output [CONFIG_IBUS_AW-1:0]   ibus_ARADDR,
   input                         ibus_RVALID,
   output                        ibus_RREADY,
   input [CONFIG_IBUS_DW-1:0]    ibus_RDATA
);

   // Main FSM states
   localparam [2:0]              S_IDLE = 3'b000;
   localparam [2:0]              S_READ_PENDING = 3'b001;
   localparam [2:0]              S_READOUT = 3'b011;
   localparam [2:0]              S_BOOT = 3'b010;
   localparam [2:0]              S_INV_1 = 3'b110;
   localparam [2:0]              S_INV_2 = 3'b111;

   // Tag data
   localparam                    TAG_ADDR_DW = CONFIG_IC_AW-CONFIG_IC_P_SETS-CONFIG_IC_P_LINE;
   localparam                    TAG_DW = 1 + TAG_ADDR_DW; // V + ADDR

   genvar i;

   wire [CONFIG_IC_P_SETS-1:0]   cls_cnt;
   wire [2:0]                    status_r;
   reg [2:0]                     status_nxt;
   wire                          ch_idle = (status_r == S_IDLE);
   wire                          ch_boot = (status_r == S_BOOT);
   wire                          ch_inv_1 = (status_r == S_INV_1);
   wire                          ch_inv_2 = (status_r == S_INV_2);
   wire                          ch_idle_no_inv;
   wire                          inv_pending_r;
   reg                           inv_pending_nxt;
   wire [`NCPU_AW-1:0]           inv_paddr_r;
   reg [`NCPU_AW-1:0]            inv_paddr_nxt;
   wire                          ibus_A_set;
   wire                          ibus_A_clr;

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
   wire                          s1o_re_r;
   wire [CONFIG_IMMU_PAGE_SIZE_LOG2-1:0] s1o_page_off_r;
   wire [CONFIG_IC_AW-1:0]       s1o_paddr;
   wire [CONFIG_IC_P_SETS-1:0]   s1o_entry_idx;
   wire                          s1o_tag_v      [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [CONFIG_IC_P_WAYS-1:0]   s1o_tag_lru    [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [TAG_ADDR_DW-1:0]        s1o_tag_paddr   [0:(1<<CONFIG_IC_P_WAYS)-1];

   // Input of Stage #2
   reg                           s2i_tag_v      [0:(1<<CONFIG_IC_P_WAYS)-1];
   reg [CONFIG_IC_P_WAYS-1:0]    s2i_tag_lru    [0:(1<<CONFIG_IC_P_WAYS)-1];
   reg [TAG_ADDR_DW-1:0]         s2i_tag_paddr  [0:(1<<CONFIG_IC_P_WAYS)-1];
   wire [CONFIG_IC_P_SETS-1:0]   s2i_entry_idx_final;

   wire                          s1_cke;
   wire                          s1_readtag;
   reg [(1<<CONFIG_IC_P_WAYS)-1:0] s2i_wr_tag;
   reg [(1<<CONFIG_IC_P_WAYS)-1:0] s2i_wr_tag_lru;

   assign s1i_page_off = page_off;
   assign s1i_entry_idx = ch_boot ? cls_cnt : s1i_page_off[CONFIG_IC_P_LINE+CONFIG_IC_P_SETS-1:CONFIG_IC_P_LINE];

   assign s1_cke = ~stall_pc;

   // Control path
   nDFF_lr #(1) dff_s1o_re_r
      (clk, rst_n, s1_cke, re, s1o_re_r);
   nDFF_lr #(CONFIG_IC_P_SETS) dff_s1o_entry_idx // Needed reset for bootstrap
      (clk, rst_n, (s1_cke & re), s1i_entry_idx, s1o_entry_idx);

   // Data path
   nDFF_l #(CONFIG_IMMU_PAGE_SIZE_LOG2) dff_s1o_page_off_r
      (clk, (s1_cke & re), s1i_page_off, s1o_page_off_r);

   // Switch the index for ch_boot | ch_inv
   assign s2i_entry_idx_final = (ch_boot)
                                 ? cls_cnt
                                 : (ch_inv_1 | ch_inv_2)
                                    ? inv_paddr_r[CONFIG_IC_P_LINE+CONFIG_IC_P_SETS-1:CONFIG_IC_P_LINE]
                                    : s1o_entry_idx;

   // Switch the index for s1_cke | ch_inv | s1_readtag
   assign s1i_entry_idx_final = (s1_cke)
                                 ? s1i_entry_idx
                                 : s2i_entry_idx_final;
   assign s1i_page_off_final = (s1_cke)
                                 ? s1i_page_off
                                 : (ch_inv_1 | ch_inv_2)
                                    ? inv_paddr_r[CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]
                                    : s1o_page_off_r;

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
               .ENABLE_BYPASS(0)
            )
         TAGS
            (
               .clk     (clk),
               .rst_n   (rst_n),
               // Port A (Read)
               .raddr   (s1i_entry_idx_final),
               .dout    (s1o_tag_dout),
               .re      ((s1_cke&re) | s1_readtag | ch_inv_1),
               // Port B (Write)
               .waddr   (s2i_entry_idx_final),
               .din     (s2i_tag_din),
               .we      (s2i_wr_tag[i])
            );

         // LRU
         ncpu32k_cell_sdpram_sclk
            #(
               .AW(CONFIG_IC_P_SETS),
               .DW(CONFIG_IC_P_WAYS),
               .ENABLE_BYPASS(0)
            )
         TAGS_LRU
            (
               .clk    (clk),
               .rst_n  (rst_n),
               // Port A (Read)
               .raddr  (s1i_entry_idx_final),
               .dout   (s1o_tag_lru[i]),
               .re     ((s1_cke&re) | s1_readtag | ch_inv_1),
               // Port B (Write)
               .waddr  (s2i_entry_idx_final),
               .din    (s2i_tag_lru[i]),
               .we     (s2i_wr_tag_lru[i])
            );
      end
endgenerate

   assign s1o_paddr = (ch_inv_1 | ch_inv_2)
                        ? inv_paddr_r
                        : {tlb_ppn[CONFIG_IC_AW-CONFIG_IMMU_PAGE_SIZE_LOG2-1:0], s1o_page_off_r[CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]};

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
   wire [CONFIG_IC_P_WAYS-1:0] s1o_lru_thresh;

generate
   if (CONFIG_IC_P_WAYS==2)
      begin : p_ways_2
         // 4-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = {|s1o_match[3:2], s1o_match[3] | s1o_match[1]};
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1] | s1o_lru[2] | s1o_lru[3];
      end
   else if (CONFIG_IC_P_WAYS==1)
      begin : p_ways_1
         // 1-to-2 binary encoder. Assert (03251128)
         assign s1o_match_way_idx = s1o_match[1];
         // LRU threshold
         assign s1o_lru_thresh = s1o_lru[0] | s1o_lru[1];
      end
endgenerate

   wire ibus_hds_B;
   reg [CONFIG_IC_P_LINE - CONFIG_IBUS_BYTES_LOG2 - 1:0] line_adr_cnt; // MSB is used to check overflow

   assign ibus_hds_B = (ibus_RVALID & ibus_RREADY);

   // Maintain the line address counter
   // for burst transmission of cache line when writing back
   always @(posedge clk or negedge rst_n)
      if (~rst_n)
         line_adr_cnt <= {CONFIG_IC_P_LINE - CONFIG_IBUS_BYTES_LOG2 {1'b0}};
      else if (ibus_hds_B)
         line_adr_cnt <= line_adr_cnt + 1'b1;

   wire [CONFIG_IC_DW/8-1:0] line_adr_cnt_msk;

   generate
      if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 16)
         assign line_adr_cnt_msk = {line_adr_cnt[1:0]==2'b11, line_adr_cnt[1:0]==2'b11,
                                    line_adr_cnt[1:0]==2'b10, line_adr_cnt[1:0]==2'b10,
                                    line_adr_cnt[1:0]==2'b01, line_adr_cnt[1:0]==2'b01,
                                    line_adr_cnt[1:0]==2'b00, line_adr_cnt[1:0]==2'b00};
      else if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 32)
         assign line_adr_cnt_msk = {line_adr_cnt[0], line_adr_cnt[0],
                                    line_adr_cnt[0], line_adr_cnt[0],
                                    ~line_adr_cnt[0], ~line_adr_cnt[0]
                                    ~line_adr_cnt[0], ~line_adr_cnt[0]};
      else if (CONFIG_IC_DW == 32 && CONFIG_IBUS_DW == 16)
         assign line_adr_cnt_msk = {line_adr_cnt[0], line_adr_cnt[0],
                                    ~line_adr_cnt[0], ~line_adr_cnt[0]};
      else
         initial $fatal(1, "Please implement one");
   endgenerate

   // Port B (Fast side)
   wire [CONFIG_IC_DW-1:0] s1o_blk_dout_b [(1<<CONFIG_IC_P_WAYS)-1:0];

   localparam BLK_AW = CONFIG_IC_P_SETS + CONFIG_IC_P_LINE - CONFIG_IC_DW_BYTES_LOG2;

   // Port B (Fast side)
   wire                    s1i_blk_en_b;
   wire [BLK_AW-1:0]       s1i_blk_addr_b;

   assign s1i_blk_en_b = ((s1_cke&re & ch_idle_no_inv) | s1_readtag);
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

         wire s2i_matched = s1o_free[i];

         localparam DELTA_DW = CONFIG_IC_DW_BYTES_LOG2-CONFIG_IBUS_BYTES_LOG2;

         assign s2i_blk_en_a = ibus_hds_B & s2i_matched;
         assign s2i_blk_addr_a = {s1o_entry_idx[CONFIG_IC_P_SETS-1:0], line_adr_cnt[DELTA_DW +: CONFIG_IC_P_LINE-CONFIG_IC_DW_BYTES_LOG2]};
         assign s2i_blk_we_a = {CONFIG_IC_DW/8{ibus_hds_B & s2i_matched}} & line_adr_cnt_msk;

         if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 16)
            assign s2i_blk_din_a = {ibus_RDATA[15:0], ibus_RDATA[15:0],
                                    ibus_RDATA[15:0], ibus_RDATA[15:0]};
         else if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 32)
            assign s2i_blk_din_a = {ibus_RDATA[31:0], ibus_RDATA[31:0]};
         else if (CONFIG_IC_DW == 64 && CONFIG_IBUS_DW == 64)
            assign s2i_blk_din_a = ibus_RDATA;
         else
            initial $fatal(1, "Please implement one");

         ncpu32k_icache_ram
            #(
               .AW (BLK_AW) ,
               .DW (CONFIG_IC_DW)
            )
         PAYLOAD_RAM
            (
               .clk     (clk),
               .addr_a  (s2i_blk_addr_a[BLK_AW-1:0]),
               .we_a    (s2i_blk_we_a[CONFIG_IC_DW/8-1:0]),
               .din_a   (s2i_blk_din_a[CONFIG_IC_DW-1:0]),
               .en_a    (s2i_blk_en_a),
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
   assign dout_vld = (ch_idle_no_inv & s1o_hit);

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
               else if (ch_idle_no_inv & s1o_re_r & s1o_hit)
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
               else if(ch_idle_no_inv & s1o_re_r & ~s1o_hit & s1o_free[i])
                  begin
                     // Cache missed
                     // Replace a free entry
                     s2i_tag_v[i] = 1'b1;
                     s2i_tag_paddr[i] = s1o_paddr[CONFIG_IC_AW-1:CONFIG_IC_P_LINE+CONFIG_IC_P_SETS];
                     s2i_wr_tag[i] = 1'b1;
                  end
               else if(ch_inv_2 & s1o_re_r & s1o_hit & s1o_match[i])
                  begin
                     // Invalidate the cache line
                     s2i_tag_v[i] = 1'b0;
                     s2i_tag_paddr[i] = s1o_tag_paddr[i];
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

   // If INV is pending, do not handle any command
   // until INV is finished.
   assign ch_idle_no_inv = (ch_idle & ~msr_icinv_we);

   assign icinv_stall = inv_pending_r;

   // Write-back FSM
   always @(*)
      begin
         status_nxt = status_r;
         inv_pending_nxt = inv_pending_r;
         inv_paddr_nxt = inv_paddr_r;
         case(status_r)
            S_BOOT:
               begin
                  if (cls_cnt == {CONFIG_IC_P_SETS{1'b0}})
                     status_nxt = S_READOUT;
               end

            S_IDLE:
               begin
                  if (msr_icinv_we) // Invalidate
                     begin
                        inv_pending_nxt = 1'b1;
                        inv_paddr_nxt = msr_icinv_nxt;
                        status_nxt = S_INV_1;
                     end
                  else if (s1o_re_r & ~s1o_hit) // Cache missed
                     status_nxt = S_READ_PENDING;
               end
            
            S_INV_1:
               status_nxt = S_INV_2;

            S_INV_2:
               status_nxt = S_READOUT;

            S_READ_PENDING:
               begin
                  if(&line_adr_cnt)
                     status_nxt = S_READOUT;
               end

            S_READOUT:
               begin
                  if (inv_pending_r)
                     inv_pending_nxt = 1'b0;
                  status_nxt = S_IDLE;
               end

            default: begin
            end
         endcase
      end

   nDFF_r #(1) dff_inv_pending_r
      (clk, rst_n, inv_pending_nxt, inv_pending_r);
   nDFF_l #(`NCPU_DW) dff_inv_paddr_r
      (clk, 1'b1, inv_paddr_nxt, inv_paddr_r);


   nDFF_r #(3, S_BOOT) dff_status_r
      (clk, rst_n, status_nxt, status_r);
   nDFF_lr #(CONFIG_IC_P_SETS, {CONFIG_IC_P_SETS{1'b1}}) dff_cls_cnt
      (clk, rst_n, ch_boot, cls_cnt - 'b1, cls_cnt);
      
   // Read the tags while stage #1 is stalling.
   // This happens when cache line replacement is completed,
   // in the next beat, tags will hold the latest value.
   // In addition, readout the cleared values when booting.
   assign s1_readtag = (status_r == S_READOUT);

   assign stall_pc = ~ch_idle_no_inv | (s1o_re_r & ~s1o_hit);

   // Send request to IBUS
   assign ibus_A_set = (status_r != S_READ_PENDING && status_nxt == S_READ_PENDING);
   assign ibus_A_clr = (ibus_ARVALID & ibus_ARREADY);
   
   nDFF_lr #(1) dff_ibus_AVALID
      (clk,rst_n, (ibus_A_set|ibus_A_clr), (ibus_A_set|~ibus_A_clr), ibus_ARVALID);

   assign ibus_ARADDR = {s1o_paddr[CONFIG_IBUS_AW-1:CONFIG_IC_P_LINE], {CONFIG_IC_P_LINE{1'b0}} }; // align at size of a line, truncate address bits

   assign ibus_RREADY = 1'b1;

   // ICID Register
   assign msr_icid[3:0] = CONFIG_IC_P_SETS[3:0];
   assign msr_icid[7:4] = CONFIG_IC_P_LINE[3:0];
   assign msr_icid[11:8] = CONFIG_IC_P_WAYS[3:0];
   assign msr_icid[31:12] = 20'b0;

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
