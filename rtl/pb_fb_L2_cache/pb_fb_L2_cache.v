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

module pb_fb_L2_cache
#(
   parameter P_WAYS = 2, // 2^ways
   parameter P_SETS	= 6, // 2^sets
   parameter P_LINE	= 6, // 2^P_LINE bytes per line (= busrt length of DRAM)
   parameter AW = 25,
   parameter DW = 32,
   parameter ENABLE_BYPASS
)
(
   input                   clk,
   input                   rst_n,
   // L2 cache interface
   output                  l2_ch_valid,
   input                   l2_ch_ready,
   input [2:0]             l2_ch_cmd_size,
   output                  l2_ch_cmd_ready, /* sram is ready to accept cmd */
   input                   l2_ch_cmd_valid, /* cmd is presented at sram'input */
   input [AW-1:0]          l2_ch_cmd_addr,
   input                   l2_ch_cmd_we,
   output [DW-1:0]         l2_ch_dout,
   input [DW-1:0]          l2_ch_din,
   input                   l2_ch_flush,
   
   // 2:1 SDRAM interface
   input                   sdr_clk,
   input [DW/2-1:0]        sdr_din,
   output reg[DW/2-1:0]    sdr_dout,
   output reg              sdr_cmd_bst_rd_req,
   output reg              sdr_cmd_bst_we_req,
   output [AW-3:0]         sdr_cmd_addr,
   input                   sdr_r_vld,
   input                   sdr_w_rdy
);
   wire l2_ch_w_rdy; // Cache line write ready
   wire l2_ch_r_vld; // Cache line read valid
   
   reg nl_rd_r; // Read from next level cache/memory
   reg nl_we_r; // Write to next level cache/memory
   reg [AW-P_LINE-1:0] nl_baddr_r;
   
   wire [3:0] l2_ch_size_msk = {4{l2_ch_cmd_we}} & (l2_ch_cmd_size==4'd1 ? 4'b0001 :
                              l2_ch_cmd_size==4'd2 ? 4'b0011 :
                              l2_ch_cmd_size==4'd3 ? 4'b1111 : 4'b0000);

   reg l2_ch_valid_r = 1'b0;
	reg [AW-1:0] addr_r;
	reg [DW-1:0] din_r;
	reg [3:0] size_msk_r;
	reg mreq_r;

   // Handshake FSM
   wire push = (l2_ch_cmd_valid & l2_ch_cmd_ready);
   wire pop = (l2_ch_valid & l2_ch_ready);

   reg pending_r;
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         pending_r <= 1'b0;
      else if(push|pop)
         pending_r <= (push | ~pop);
   end
   
   generate
      if (ENABLE_BYPASS) begin :enable_bypass
         assign l2_ch_cmd_ready = (~pending_r | pop);
      end else begin
         assign l2_ch_cmd_ready = (~pending_r);
      end
   endgenerate
   
   always @(posedge clk) begin
		if (~pending_r) begin
			addr_r <= l2_ch_cmd_addr;
			din_r <= l2_ch_din;
			size_msk_r <= l2_ch_size_msk;
			mreq_r <= push;
		end
   end
   
   wire [AW-1:0] maddr = pending_r ? addr_r : l2_ch_cmd_addr;
	wire [DW-1:0] mdin = pending_r ? din_r : l2_ch_din;
	wire [3:0] mwmask = pending_r ? size_msk_r : l2_ch_size_msk;
	wire mmreq = pending_r ? mreq_r : push;
   
   assign l2_ch_valid = pending_r & l2_ch_valid_r;
   
   // Flushing FSM
	reg fls_req = 1'b0;
	reg [P_WAYS+P_SETS:0] fls_cnt = 0;
	wire fls_pending = fls_cnt[P_WAYS+P_SETS];
   
	wire [P_SETS-1:0] entry_idx = fls_pending ? fls_cnt[P_SETS-1:0] : maddr[P_LINE+P_SETS-1:P_LINE];
	
   // Main FSM states
   localparam S_IDLE = 3'b000;
   localparam S_WRITE_PENDING = 3'b011;
   localparam S_RAW = 3'b111;
   localparam S_READ_PENDING_1 = 3'b100;
   localparam S_READ_PENDING_2 = 3'b101;
   
	reg [2:0]status_r = 0;
   wire ch_idle = status_r == S_IDLE;
	reg [P_LINE-2:0]line_adr_cnt = 0; // unit: word (2 B)
	reg line_adr_cnt_msb = 0;
   
   wire [DW-1:0]ch_mem_dout;

   // Cache entries
   reg cache_v[0:(1<<P_WAYS)-1][0:(1<<P_SETS)-1];
	reg [(1<<P_WAYS)-1:0] cache_dirty[0:(1<<P_SETS)-1];
	reg [P_WAYS-1:0] cache_lru[0:(1<<P_WAYS)-1][0:(1<<P_SETS)-1];
	reg [AW-P_SETS-P_LINE-1:0] cache_addr[0:(1<<P_WAYS)-1][0:(1<<P_SETS)-1];
	
   wire [(1<<P_WAYS)-1:0] match;
	wire [(1<<P_WAYS)-1:0] free;
   wire [P_WAYS-1:0] lru[(1<<P_WAYS)-1:0];

generate
	genvar i;
	for(i=0; i<(1<<P_WAYS); i=i+1) begin
		assign match[i] = ~fls_pending & cache_v[i][entry_idx] & (cache_addr[i][entry_idx] == maddr[AW-1:P_LINE+P_SETS]);
		assign free[i] = fls_pending ? (fls_cnt[P_WAYS+P_SETS-1:P_SETS] == i) : ~|cache_lru[i][entry_idx];
		assign lru[i] = {P_WAYS{match[i]}} & cache_lru[i][entry_idx];
	end
endgenerate

	wire hit = |match;
	wire dirty = |(free & cache_dirty[entry_idx]);	

   wire [P_WAYS-1:0] match_set;
   wire [P_WAYS-1:0] free_set_idx;
   wire [P_WAYS-1:0] lru_thresh;
   
generate
   if (P_WAYS==2) begin : p_ways_2
      // 4-to-2 binary encoder
      assign match_set = fls_cnt[P_WAYS+P_SETS-1:P_SETS] | {|match[3:2], match[3] | match[1]};
      // 4-to-2 binary encoder
      assign free_set_idx = {|free[3:2], free[3] | free[1]};
      // LRU threshold
      assign lru_thresh = lru[0] | lru[1] | lru[2] | lru[3];
   end else if (P_WAYS==1) begin : p_ways_1
      // 1-to-2 binary encoder
      assign match_set = fls_cnt[P_WAYS+P_SETS-1:P_SETS] | match[1];
      // 1-to-2 binary encoder
      assign free_set_idx = free[1];
      // LRU threshold
      assign lru_thresh = lru[0] | lru[1];
   end
endgenerate

   // Reset control
generate
   genvar j;
   for(i=0;i<(1<<P_SETS);i=i+1) begin
      always @(posedge clk or negedge rst_n) begin
         if (~rst_n) begin
            cache_dirty[i] <= 0;
         end
      end
   end
   for(i=0;i<(1<<P_WAYS);i=i+1) begin
      for(j=0;j<(1<<P_SETS);j=j+1) begin
         always @(posedge clk or negedge rst_n) begin
            if (~rst_n) begin
               cache_v[i][j] <= 0;
               cache_lru[i][j] <= 0;
               cache_addr[i][j] <= 0;
            end
         end
      end
   end
endgenerate

	always begin
      // When burst transmission for cache line filling or writing back
      // maintain the line addr counter
      @(posedge sdr_clk)
         if(l2_ch_w_rdy | l2_ch_r_vld)
            line_adr_cnt <= line_adr_cnt + 1'b1;

      // Mask HI/LO 16bit. Assert (03161421)
      @(posedge sdr_clk)
         sdr_dout <= line_adr_cnt[0] ? ch_mem_dout[15:0] : ch_mem_dout[31:16];
	end

   localparam CH_AW = P_WAYS+P_SETS+P_LINE-1;
   
   // Mask HI/LO 16bit. Assert (03161421)
   wire [3:0] line_adr_cnt_msk = {line_adr_cnt[0], line_adr_cnt[0], ~line_adr_cnt[0], ~line_adr_cnt[0]};
   
   wire ch_mem_en_a = l2_ch_w_rdy | l2_ch_r_vld;
   wire [DW/8-1:0] ch_mem_we_a = {4{l2_ch_w_rdy}} & line_adr_cnt_msk;
   wire [CH_AW-1:0] ch_mem_addr_a = {match_set, ~entry_idx[P_SETS-1:10-P_LINE], entry_idx[10-P_LINE-1:0], line_adr_cnt[P_LINE-2:1]};
   wire [DW-1:0] ch_mem_din_a = {sdr_din, sdr_din};
   wire ch_mem_en_b = mmreq & hit & ch_idle;
   wire [DW/8-1:0] ch_mem_we_b = mwmask;
   wire [CH_AW-1:0] ch_mem_addr_b = {match_set, ~entry_idx[P_SETS-1:10-P_LINE], entry_idx[10-P_LINE-1:0], maddr[P_LINE-1:2]};
   wire [DW-1:0] ch_mem_din_b = mdin;
   wire [DW-1:0] ch_mem_dout_b;
   
   ncpu32k_cell_tdpram_aclkd_sclk
      #(
         .AW(CH_AW),
         .DW(DW)
      )
   cache_mem
      (
         .clk_a   (sdr_clk),
         .addr_a  (ch_mem_addr_a[CH_AW-1:0]),
         .we_a    (ch_mem_we_a[DW/8-1:0]),
         .din_a   (ch_mem_din_a[DW-1:0]),
         .dout_a  (ch_mem_dout[DW-1:0]),
         .en_a    (ch_mem_en_a),
         .clk_b   (clk),
         .addr_b  (ch_mem_addr_b[CH_AW-1:0]),
         .we_b    (ch_mem_we_b[DW/8-1:0]),
         .din_b   (ch_mem_din_b[DW-1:0]),
         .dout_b  (ch_mem_dout_b[DW-1:0]),
         .en_b    (ch_mem_en_b)
      );
      
   assign l2_ch_dout = (l2_ch_cmd_size==3'd1 ? {24'b0, ch_mem_dout_b[7:0]} :
                              l2_ch_cmd_size==3'd2 ? {16'b0, ch_mem_dout_b[15:8],ch_mem_dout_b[7:0]} :
                              l2_ch_cmd_size==3'd3 ? ch_mem_dout_b : 4'b0000);

generate
	for(i=0; i<(1<<P_WAYS); i=i+1)
		always @(posedge clk) begin
			if(ch_idle && mmreq)
				if(hit) begin
               // Update LRU priority
					cache_lru[i][entry_idx] <= match[i] ? {P_WAYS{1'b1}} : cache_lru[i][entry_idx] - (cache_lru[i][entry_idx] > lru_thresh); 
					// Mark dirty when written
               if(match[i]) begin
                  cache_dirty[entry_idx][i] <= cache_dirty[entry_idx][i] || (|mwmask);
               end
				end else if(free[i]) begin
               // Mark clean when entry is freed
               cache_dirty[entry_idx][i] <= 1'b0;
            end
      end
endgenerate

   // Main FSM
	always @(posedge clk) begin
		line_adr_cnt_msb <= line_adr_cnt[P_LINE-2];
		fls_req <= ~fls_cnt[P_WAYS+P_SETS] & (fls_req | l2_ch_flush);
		
		case(status_r)
			S_IDLE: begin
				nl_baddr_r <= dirty ? {cache_addr[free_set_idx][entry_idx], entry_idx} : maddr[AW-1:P_LINE]; 
				if(mmreq && ~hit) begin
               // Cache missed
               // Fill a free entry.
               // If the target entry is dirty, firstly sync with the
               // next level cache/memory, then refill it.
					if(~fls_pending) begin
                  cache_v[free_set_idx][entry_idx] <= 1'b1;
                  cache_addr[free_set_idx][entry_idx] <= maddr[AW-1:P_LINE+P_SETS];
               end
					nl_rd_r <= ~dirty & ~fls_pending;
					nl_we_r <= dirty;
					status_r <= dirty ? S_WRITE_PENDING : S_READ_PENDING_1;
               l2_ch_valid_r <= 1'b0;
				end else begin
               // Accept flush request
					fls_cnt[P_WAYS+P_SETS] <= fls_cnt[P_WAYS+P_SETS] | fls_req;
               // Accept accessing cmd
               l2_ch_valid_r <= 1'b1;
            end
			end
         // Pending for writing
			S_WRITE_PENDING: begin
				nl_rd_r <= ~fls_pending;
				if(line_adr_cnt_msb) begin
					nl_we_r <= 1'b0;
					status_r <= S_RAW;
				end
			end
         // Read-after-write
         // Note writing is not really finished.
			S_RAW: begin
				nl_baddr_r <= maddr[AW-1:P_LINE];
				if(~line_adr_cnt_msb)
               status_r <= S_READ_PENDING_1;
			end
         // Pending for reading
			S_READ_PENDING_1: begin	
				if(fls_pending) begin
					fls_cnt <= fls_cnt + 1'b1;
					status_r <= S_IDLE;
				end else if(line_adr_cnt_msb)
               status_r <= S_READ_PENDING_2;
			end
			S_READ_PENDING_2: begin
				nl_rd_r <= 1'b0;
				if(~line_adr_cnt_msb) begin
					status_r <= S_IDLE;
				end
			end
		endcase
	end
	
   // SDRAM arbiter
   // Receive signals from nl_*
   
   // 2 Flip flops for crossing clock domains
   reg [1:0]sdr_rd_r;
	reg [1:0]sdr_we_r;
   reg [AW-3:0] sdr_cmd_addr_r;
   
   // Sample requests at SDRAM clock rise
   always @ (posedge sdr_clk or negedge rst_n) begin
      if(~rst_n) begin
         sdr_rd_r <= 0;
         sdr_we_r <= 0;
         sdr_cmd_bst_rd_req <= 1'b0;
         sdr_cmd_bst_we_req <= 1'b0;
      end else begin
         sdr_rd_r <= {sdr_rd_r[0], nl_rd_r};
         sdr_we_r <= {sdr_we_r[0], nl_we_r};
         sdr_cmd_addr_r <= {nl_baddr_r[AW-P_LINE-1:0], {P_LINE-2{1'b0}}};
         
         // Priority arbiter
         if(sdr_we_r[1])
            sdr_cmd_bst_we_req <= 1'b1;
         else if(sdr_rd_r[1])
            sdr_cmd_bst_rd_req <= 1'b1;
         else begin
            sdr_cmd_bst_we_req <= 1'b0;
            sdr_cmd_bst_rd_req <= 1'b0;
         end
      end
   end
   
   assign sdr_cmd_addr = sdr_cmd_addr_r;
   
   assign l2_ch_w_rdy = sdr_r_vld;
   assign l2_ch_r_vld = sdr_w_rdy;
   
   // synthesis translate_off
`ifndef SYNTHESIS                   
                 
   // Assertions (03161421)
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if(DW!=32)
         $fatal ("\n non 32bit L2 cache unsupported.");
   end
`endif

`endif
   // synthesis translate_on
   
endmodule
