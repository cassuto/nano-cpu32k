/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module dcache
#(
   parameter CONFIG_AW = 0,
   parameter CONFIG_P_DW = 0,
   parameter CONFIG_P_PAGE_SIZE = 0,
   parameter CONFIG_DC_P_LINE = 0,
   parameter CONFIG_DC_P_SETS = 0,
   parameter CONFIG_DC_P_WAYS = 0,
   parameter AXI_P_DW_BYTES  = 3,
   parameter AXI_ADDR_WIDTH    = 64,
   parameter AXI_ID_WIDTH      = 4,
   parameter AXI_USER_WIDTH    = 1
)
(
   input                               clk,
   input                               rst,
   input                               req,
   output                              stall_req,
   input [CONFIG_P_PAGE_SIZE-1:0]      vpo,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn_s2,
   input                               kill_req_s2,
   input                               op_inv,
   input [CONFIG_AW-1:0]               op_inv_paddr,
   output [(1<<CONFIG_P_DW)-1:0]       dout,
   output                              valid,
   
   // AXI Master
   input                               axi_ar_ready_i,
   output                              axi_ar_valid_o,
   output [AXI_ADDR_WIDTH-1:0]         axi_ar_addr_o,
   output [2:0]                        axi_ar_prot_o,
   output [AXI_ID_WIDTH-1:0]           axi_ar_id_o,
   output [AXI_USER_WIDTH-1:0]         axi_ar_user_o,
   output [7:0]                        axi_ar_len_o,
   output [2:0]                        axi_ar_size_o,
   output [1:0]                        axi_ar_burst_o,
   output                              axi_ar_lock_o,
   output [3:0]                        axi_ar_cache_o,
   output [3:0]                        axi_ar_qos_o,
   output [3:0]                        axi_ar_region_o,
   output                              axi_r_ready_o,
   input                               axi_r_valid_i,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  axi_r_data_i,
/* verilator lint_off UNUSED */
   input  [1:0]                        axi_r_resp_i, // unused
   input                               axi_r_last_i, // unused
   input  [AXI_ID_WIDTH-1:0]           axi_r_id_i, // unused
   input  [AXI_USER_WIDTH-1:0]         axi_r_user_i, // unused
/* verilator lint_on UNUSED */
   input                               axi_aw_ready_i,
   output                              axi_aw_valid_o,
   output [AXI_ADDR_WIDTH-1:0]         axi_aw_addr_o,
   output [2:0]                        axi_aw_prot_o,
   output [AXI_ID_WIDTH-1:0]           axi_aw_id_o,
   output [AXI_USER_WIDTH-1:0]         axi_aw_user_o,
   output [7:0]                        axi_aw_len_o,
   output [2:0]                        axi_aw_size_o,
   output [1:0]                        axi_aw_burst_o,
   output                              axi_aw_lock_o,
   output [3:0]                        axi_aw_cache_o,
   output [3:0]                        axi_aw_qos_o,
   output [3:0]                        axi_aw_region_o,

   input                               axi_w_ready_i,
   output                              axi_w_valid_o,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  axi_w_data_o,
   output [(1<<AXI_P_DW_BYTES)-1:0]    axi_w_strb_o,
   output                              axi_w_last_o,
   output [AXI_USER_WIDTH-1:0]         axi_w_user_o,

   output                              axi_b_ready_o,
   input                               axi_b_valid_i,
   input  [1:0]                        axi_b_resp_i,
   input  [AXI_ID_WIDTH-1:0]           axi_b_id_i,
   input  [AXI_USER_WIDTH-1:0]         axi_b_user_i
);

   localparam TAG_WIDTH                = (CONFIG_AW - CONFIG_DC_P_SETS - CONFIG_DC_P_LINE);
   localparam TAG_V_RAM_AW             = (CONFIG_DC_P_SETS);
   localparam TAG_V_RAM_DW             = (TAG_WIDTH + 1); // TAG + V
   localparam PAYLOAD_AW               = (CONFIG_DC_P_SETS + CONFIG_DC_P_LINE - PAYLOAD_P_DW_BYTES);
   localparam PAYLOAD_DW               = (1<<CONFIG_P_DW);
   localparam PAYLOAD_P_DW_BYTES       = (CONFIG_P_DW-3); // = $clog2(PAYLOAD_DW/8)
   localparam AXI_WR_SIZE              = (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES) ? PAYLOAD_P_DW_BYTES : AXI_P_DW_BYTES;
   
   // Stage 1 Input
   reg [CONFIG_DC_P_SETS-1:0]          s1i_line_addr;
   reg [TAG_V_RAM_DW-1:0]              s1i_replace_tag_v;
   wire                                s1i_tag_v_we;
   reg [PAYLOAD_AW-1:0]                s1i_payload_addr;
   wire [PAYLOAD_DW/8-1:0]             s1i_payload_we;
   wire [PAYLOAD_DW-1:0]               s1i_payload_din;
   // Stage 1 Output / Stage 2 Input
   wire s1o_valid;
   wire [PAYLOAD_DW-1:0]               s1o_payload             [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [TAG_V_RAM_DW-1:0]             s1o_tag_v               [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [CONFIG_P_PAGE_SIZE-1:0]       s1o_vpo;
   wire [CONFIG_AW-1:0]                s2i_paddr;
   wire [TAG_WIDTH-1:0]                s2i_tag                 [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s2i_v                   [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s2i_d                   [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2i_hit;
   wire [CONFIG_DC_P_WAYS-1:0]         s2i_match_way_idx;
   wire                                s2i_get_dat;
   wire [PAYLOAD_DW-1:0]               s2i_dout;
   wire                                s2i_dirty;
   wire [TAG_WIDTH-1:0]                s2i_free_tag;
   wire                                s1o_op_inv;
   wire [CONFIG_AW-1:0]                s1o_op_inv_paddr;
   // Stage 2 Output / Stage 3 Input
   wire                                s2o_valid;
   wire                                s2o_dirty;
   wire [CONFIG_AW-1:0]                s2o_paddr;
   wire [TAG_WIDTH-1:0]                s2o_free_tag;
   wire [CONFIG_DC_P_SETS-1:0]         s2o_free_idx;
   wire [(1<<CONFIG_P_DW)-1:0]         s2o_ins;
   wire [CONFIG_AW-1:0]                s2o_op_inv_paddr;
   // FSM
   reg [2:0]                           fsm_state_nxt;
   wire [2:0]                          fsm_state_r;
   wire [CONFIG_DC_P_SETS-1:0]         fsm_free_idx, fsm_free_idx_nxt;
   wire [CONFIG_DC_P_LINE-1:0]         fsm_line_cnt;
   reg [CONFIG_DC_P_LINE-1:0]          fsm_line_cnt_nxt;
   wire                                p_ce;
   wire                                writeback_ce;
   // AXI
   wire                                arvalid_set, arvalid_clr;
   wire                                awvalid_set, awvalid_clr;
   wire                                wvalid_set, wvalid_clr;
   wire                                wlast_set, wlast_clr;
   wire [AXI_ADDR_WIDTH-1:0]           araddr_nxt;
   wire [AXI_ADDR_WIDTH-1:0]           awaddr_nxt;
   wire                                hds_axi_R;
   wire                                hds_axi_W;
   
   localparam [2:0] S_BOOT             = 3'd0;
   localparam [2:0] S_IDLE             = 3'd1;
   localparam [2:0] S_REPLACE          = 3'd2;
   localparam [2:0] S_REFILL           = 3'd3;
   localparam [2:0] S_INVALIDATE       = 3'd4;
   
   genvar way, i, j;
   
   assign p_ce = (~stall_req);
   assign s2i_paddr = {ppn_s2, s1o_vpo};
   
   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         begin : gen_ways
            mRAM_s_s_be
               #(
                  .DW   (PAYLOAD_DW),
                  .AW   (PAYLOAD_AW)
               )
            U_PAYLOAD_RAM
               (
                  .CLK  (clk),
                  .ADDR (s1i_payload_addr),
                  .RE   (p_ce|writeback_ce),
                  .DOUT (s1o_payload[way]),
                  .WE   (s1i_payload_we),
                  .DIN  (s1i_payload_din)
               );
               
            mRAM_s_s
               #(
                  .DW   (TAG_V_RAM_DW),
                  .AW   (TAG_V_RAM_AW)
               )
            U_TAG_V_RAM
               (
                  .CLK  (clk),
                  .ADDR (s1i_line_addr),
                  .RE   (p_ce),
                  .DOUT (s1o_tag_v[way]),
                  .WE   (s1i_tag_v_we),
                  .DIN  (s1i_replace_tag_v)
               );
               
            mRF_1w1r
               #(
                  .DW (1),
                  .AW (TAG_V_RAM_AW)
               )
            U_D_RF
               (
                  .CLK     (clk),
                  .RE      (p_ce),
                  .RADDR   (s1i_line_addr),
                  .RDATA   (s2i_d[way]),
                  input WE,
                  input [AW-1:0] WADDR,
                  input [DW-1:0] WDATA
               );
               
            assign {s2i_tag[way], s2i_v[way]} = s1o_tag_v[way];
            
            assign s2i_hit[way] = (s2i_v[way] & (s2i_tag[way] == s2i_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS]) );
         end
   endgenerate
   
   assign s2i_dirty = s2i_d[s2i_match_way_idx];
   
   // Vector to index
   priority_encoder  #(.P_DW (CONFIG_DC_P_WAYS)) U_ENC ( .din (s2i_hit), .dout (s2i_match_way_idx) );
   
   mDFF_lr # (.DW(1)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(req), .Q(s1o_valid) );
   mDFF_l # (.DW(CONFIG_P_PAGE_SIZE)) ff_s1o_vpo (.CLK(clk), .LOAD(p_ce), .D(vpo), .Q(s1o_vpo) );
   mDFF_lr # (.DW(1)) ff_s1o_op_inv (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(op_inv), .Q(s1o_op_inv) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s1o_op_inv_paddr (.CLK(clk), .LOAD(p_ce), .D(op_inv_paddr), .Q(s1o_op_inv_paddr) );
   
   mDFF_lr # (.DW(1)) ff_s2o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_valid), .Q(s2o_valid) );
   mDFF_lr # (.DW(1)) ff_s2o_dirty (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s2i_dirty), .Q(s2o_dirty) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s2o_paddr (.CLK(clk), .LOAD(p_ce), .D(s2i_paddr), .Q(s2o_paddr) );
   mDFF_l # (.DW(CONFIG_DC_P_SETS)) ff_s2o_free_idx (.CLK(clk), .LOAD(p_ce), .D(fsm_free_idx), .Q(s2o_free_idx) );
   mDFF_l # (.DW(TAG_WIDTH)) ff_s2o_free_tag (.CLK(clk), .LOAD(p_ce), .D(s2i_tag[fsm_free_idx]), .Q(s2o_free_tag) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s2o_op_inv_paddr (.CLK(clk), .LOAD(p_ce), .D(s1o_op_inv_paddr), .Q(s2o_op_inv_paddr) );
  
   
   // Main FSM
   always @(*)
      begin
         fsm_state_nxt = fsm_state_r;
         case (fsm_state_r)
            S_BOOT:
               if (~|fsm_free_idx_nxt)
                  fsm_state_nxt = S_IDLE;

            S_IDLE:
               if (s1o_op_inv)
                  fsm_state_nxt = S_INVALIDATE;
               else if (s1o_valid & ~kill_req_s2 & ~|s2i_hit)
                  fsm_state_nxt = S_REPLACE;

            S_REPLACE:
               fsm_state_nxt = (s2o_dirty) ? S_WRITEBACK : S_REFILL;
            
            S_WRITEBACK:
               if ((&fsm_line_cnt) & hds_axi_W)
                  fsm_state_nxt = S_REFILL;
            
            S_REFILL:
               if ((&fsm_line_cnt) & hds_axi_R)
                  fsm_state_nxt = S_IDLE;
            
            S_INVALIDATE:
               fsm_state_nxt = S_IDLE;
            default: ;
         endcase
      end
      
   // Clock algorithm
   assign fsm_free_idx_nxt = fsm_free_idx + 'b1;
   
   mDFF_r # (.DW(3), .RST_VECTOR(S_BOOT)) ff_state_r (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_r) );
   mDFF_r # (.DW(CONFIG_DC_P_SETS)) ff_fsm_free_idx (.CLK(clk), .RST(rst), .D(fsm_free_idx_nxt), .Q(fsm_free_idx) );
   
   // Refill counter
   always @(*)
      begin
         fsm_line_cnt_nxt = fsm_line_cnt;
         case (fsm_state_r)
            S_REFILL:
               if (hds_axi_R)
                  fsm_line_cnt_nxt = fsm_line_cnt + (1<<AXI_WR_SIZE);
            S_WRITEBACK:
               if (hds_axi_W)
                  fsm_line_cnt_nxt = fsm_line_cnt + (1<<AXI_WR_SIZE);
            default:
               fsm_line_cnt_nxt = 'b0;
         endcase
      end
   
   mDFF_r # (.DW(CONFIG_DC_P_LINE)) ff_fsm_refill_cnt (.CLK(clk), .RST(rst), .D(fsm_line_cnt_nxt), .Q(fsm_line_cnt) );
   

   // MUX for tag RAM addr 
   always @(*)
      case (fsm_state_r)
         S_BOOT,
         S_REPLACE:
            s1i_line_addr = s2o_free_idx;
         S_INVALIDATE:
            s1i_line_addr = s2o_op_inv_paddr[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS];
         default:
            s1i_line_addr = vpo[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS]; // index
      endcase
      
   // MUX for tag RAM din
   always @(*)
      case (fsm_state_r)
         S_BOOT,
         S_INVALIDATE:
            s1i_replace_tag_v = 'b0;
         default:
            s1i_replace_tag_v = {s2o_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS], 1'b1};
      endcase
      
   assign s1i_tag_v_we = (fsm_state_r==S_BOOT) | (fsm_state_r==S_INVALIDATE) | (fsm_state_r==S_REPLACE);
        
   // MUX for payload RAM addr
   always @(*)
      case (fsm_state_r)
         S_REFILL:
            s1i_payload_addr = {s2o_paddr[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS], fsm_line_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES]};
         S_WRITEBACK:
            s1i_payload_addr = {s2o_free_tag, fsm_line_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES]};
         default:
            s1i_payload_addr = vpo[PAYLOAD_P_DW_BYTES +: PAYLOAD_AW]; // {index,offset}
      endcase
      
   // Aligner for payload RAM din
   generate
      for(i=0;i<PAYLOAD_DW/8;i=i+1)
         begin : gen_aligner
            assign s1i_payload_we[i] = (fsm_state_r == S_REFILL) & (fsm_line_cnt[PAYLOAD_P_DW_BYTES-1:0] == i);
            assign s1i_payload_din[i*8 +: 8] = axi_r_data_i[(i%(1<<AXI_WR_SIZE))*8 +: 8];
         end
   endgenerate
   
   assign stall_req = (fsm_state_r != S_IDLE);
   
   assign s2i_get_dat = (s2o_paddr[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES] == 
                    fsm_line_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES]);
   
   // Output
   generate
      for(j=0;j<PAYLOAD_DW/8;j=j+1)
         begin : gen_output_inner
            always @(*)
               case (fsm_state_r)
                  S_REFILL:
                     if (s2i_get_dat & s1i_payload_we[j])
                        s2i_dout[j*8 +: 8] = s1i_payload_din[j*8 +: 8]; // Get data from AXI bus
                     else
                        s2i_dout[j*8 +: 8] = dout[j*8 +: 8];
                  default:
                     s2i_dout[j*8 +: 8] = s1o_payload[s2i_match_way_idx][j*8 +: 8]; // From the matched way
               endcase
         end
   endgenerate

   mDFF_l # (.DW(PAYLOAD_DW)) ff_ins
      (.CLK(clk), .LOAD(p_ce|(fsm_state_r==S_REFILL)), .D(s2i_dout), .Q(dout) );
               
   assign valid = (s2o_valid & ~stall_req);
   
   // AXI - AR
   assign axi_ar_prot_o = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign axi_ar_id_o = {AXI_ID_WIDTH{1'b0}};
   assign axi_ar_user_o = {AXI_USER_WIDTH{1'b0}};
   assign axi_ar_len_o = ((1<<(CONFIG_DC_P_LINE-AXI_WR_SIZE))-1);
   assign axi_ar_size_o = AXI_WR_SIZE;
   assign axi_ar_burst_o = `AXI_BURST_TYPE_INCR;
   assign axi_ar_lock_o = 'b0;
   assign axi_ar_cache_o = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign axi_ar_qos_o = 'b0;
   assign axi_ar_region_o = 'b0;
   assign arvalid_set = (fsm_state_r==S_REPLACE) & ~s2o_dirty;
   assign arvalid_clr = (axi_ar_ready_i & axi_ar_valid_o);
   assign araddr_nxt = {s2o_paddr[CONFIG_DC_P_LINE +: AXI_ADDR_WIDTH - CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}}};
   
   mDFF_lr # (.DW(1)) ff_axi_ar_valid (.CLK(clk), .RST(rst), .LOAD(arvalid_set|arvalid_clr), .D(arvalid_set|~arvalid_clr), .Q(axi_ar_valid_o) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_axi_ar_addr (.CLK(clk), .RST(rst), .LOAD(arvalid_set), .D(araddr_nxt), .Q(axi_ar_addr_o) );
   
   // AXI - R
   assign axi_r_ready_o = (fsm_state_r == S_REFILL);
   assign hds_axi_R = (axi_r_valid_i & axi_r_ready_o);
   
   // AXI - AW
   assign axi_aw_prot_o = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign axi_aw_id_o = {AXI_ID_WIDTH{1'b0}};
   assign axi_aw_user_o = {AXI_USER_WIDTH{1'b0}};
   assign axi_aw_len_o = ((1<<(CONFIG_DC_P_LINE-AXI_WR_SIZE))-1);
   assign axi_aw_size_o = AXI_WR_SIZE;
   assign axi_aw_burst_o = `AXI_BURST_TYPE_INCR;
   assign axi_aw_lock_o = 'b0;
   assign axi_aw_cache_o = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign axi_aw_qos_o = 'b0;
   assign axi_aw_region_o = 'b0;
   assign awvalid_set = (fsm_state_r==S_REPLACE) & s2o_dirty;
   assign awvalid_clr = (axi_aw_ready_i & axi_aw_valid_o);
   assign awaddr_nxt = {s2o_free_tag[CONFIG_DC_P_LINE +: TAG_WIDTH - CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}}};
   
   mDFF_lr # (.DW(1)) ff_axi_aw_valid (.CLK(clk), .RST(rst), .LOAD(awvalid_set|awvalid_clr), .D(awvalid_set|~awvalid_clr), .Q(axi_aw_valid_o) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_axi_aw_addr (.CLK(clk), .RST(rst), .LOAD(awvalid_set), .D(awaddr_nxt), .Q(axi_aw_addr_o) );
   
   // AXI - W
   assign axi_w_user_o = 'b0;
   assign writeback_ce = (fsm_state_r==S_WRITEBACK) & axi_w_ready_i;
   assign wvalid_set = (~axi_w_valid_o & writeback_ce);
   assign wvalid_clr = (axi_w_valid_o & axi_w_last_o & axi_w_ready_i);
   assign wlast_set = (writeback_ce & (&fsm_line_cnt));
   assign wlast_clr = wvalid_clr;
   
   mDFF_lr #(.DW(1)) ff_axi_w_valid_o (.CLK(clk), .RST(rst), .LOAD(wvalid_set|wvalid_clr), .D(wvalid_set|~wvalid_clr), .Q(axi_w_valid_o) );
   mDFF_lr #(.DW(1)) ff_axi_w_last_o (.CLK(clk), .RST(rst), .LOAD(wlast_set|wlast_clr), .D(wlast_set|~wlast_clr), .Q(axi_w_last_o) );
   
   // Aligner
   generate
      if (PAYLOAD_P_DW_BYTES == AXI_P_DW_BYTES)
         begin
            assign axi_w_strb_o = {(1<<PAYLOAD_P_DW_BYTES){1'b1}};
            assign axi_w_data_o = s1o_payload[s2o_free_idx];
         end
      else if (PAYLOAD_P_DW_BYTES < AXI_P_DW_BYTES)
         begin
            assign axi_w_strb_o = {{AXI_P_DW_BYTES-PAYLOAD_P_DW_BYTES{1'b0}, {(1<<PAYLOAD_P_DW_BYTES){1'b1}}};
            assign axi_w_data_o = {{(1<<AXI_P_DW_BYTES-PAYLOAD_P_DW_BYTES)*8{1'b0}}, s1o_payload[s2o_free_idx]};
         end
      else
         for(i=0;i<PAYLOAD_DW/8;i=i+1)
            begin : gen_aligner
               assign axi_w_strb_o[i] = (fsm_line_cnt[AXI_WR_SIZE +: PAYLOAD_P_DW_BYTES-AXI_WR_SIZE] == (i/(1<<AXI_WR_SIZE)) );
               assign axi_w_data_o[i*8 +: 8] = s1o_payload[s2o_free_idx][(i%(1<<AXI_FETCH_SIZE))*8 +: 8];
            end
   endgenerate
   
   
   // synthesis translate_off
`ifndef SYNTHESIS
   initial
      begin
         if (CONFIG_P_PAGE_SIZE < CONFIG_DC_P_LINE + CONFIG_DC_P_SETS)
            $fatal(1, "Invalid size of icache (Must <= page size of MMU)");
         if (CONFIG_DC_P_LINE < PAYLOAD_P_DW_BYTES)
            $fatal(1, "Line size of icache is too small to accommodate with a fetching window");
         if ((1<<CONFIG_IBUS_BYTES_LOG2) != (CONFIG_IBUS_DW/8))
            $fatal(1, "Error value of CONFIG_IBUS_BYTES_LOG2");
         if ((1<<CONFIG_IC_DW_BYTES_LOG2) != (CONFIG_IC_DW/8))
            $fatal(1, "Error value of CONFIG_IC_DW_BYTES_LOG2");
         if (CONFIG_IC_DW_BYTES_LOG2 < CONFIG_IBUS_BYTES_LOG2)
            $fatal(1, "Invalid configuration of IBW or IBUS");
      end
`endif
   // synthesis translate_on

endmodule
