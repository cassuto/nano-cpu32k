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
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_DW = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_DC_P_LINE = 0,
   parameter                           CONFIG_DC_P_SETS = 0,
   parameter                           CONFIG_DC_P_WAYS = 0,
   parameter                           AXI_P_DW_BYTES    = 0,
   parameter                           AXI_ADDR_WIDTH    = 0,
   parameter                           AXI_ID_WIDTH      = 0,
   parameter                           AXI_USER_WIDTH    = 0
)
(
   input                               clk,
   input                               rst,
   output                              stall_req,
   input                               req,
   input [CONFIG_DW/8-1:0]             wmsk,
   input [CONFIG_P_PAGE_SIZE-1:0]      vpo,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn_s2,
   input                               kill_req_s2,
   input                               op_inv,
   input [CONFIG_AW-1:0]               op_inv_paddr,
   input                               op_fls,
   input [CONFIG_AW-1:0]               op_fls_paddr,
   output                              op_stall_req,
   output [CONFIG_DW-1:0]              dout,
   output                              valid,
   // AXI Master
   input                               dbus_ARREADY,
   output                              dbus_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_ARADDR,
   output [2:0]                        dbus_ARPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_ARID,
   output [AXI_USER_WIDTH-1:0]         dbus_ARUSER,
   output [7:0]                        dbus_ARLEN,
   output [2:0]                        dbus_ARSIZE,
   output [1:0]                        dbus_ARBURST,
   output                              dbus_ARLOCK,
   output [3:0]                        dbus_ARCACHE,
   output [3:0]                        dbus_ARQOS,
   output [3:0]                        dbus_ARREGION,

   output                              dbus_RREADY,
   input                               dbus_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_RDATA,
   input                               dbus_RLAST,
   
   input                               dbus_AWREADY,
   output                              dbus_AWVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_AWADDR,
   output [2:0]                        dbus_AWPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_AWID,
   output [AXI_USER_WIDTH-1:0]         dbus_AWUSER,
   output [7:0]                        dbus_AWLEN,
   output [2:0]                        dbus_AWSIZE,
   output [1:0]                        dbus_AWBURST,
   output                              dbus_AWLOCK,
   output [3:0]                        dbus_AWCACHE,
   output [3:0]                        dbus_AWQOS,
   output [3:0]                        dbus_AWREGION,

   input                               dbus_WREADY,
   output                              dbus_WVALID,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_WDATA,
   output [(1<<AXI_P_DW_BYTES)-1:0]    dbus_WSTRB,
   output                              dbus_WLAST,
   output [AXI_USER_WIDTH-1:0]         dbus_WUSER,

   output                              dbus_BREADY,
   input                               dbus_BVALID,
   
/* verilator lint_off UNUSED */
   input  [1:0]                        dbus_RRESP, // unused
   input  [AXI_ID_WIDTH-1:0]           dbus_RID, // unused
   input  [AXI_USER_WIDTH-1:0]         dbus_RUSER, // unused
   input [1:0]                         dbus_BRESP, // unused
   input [AXI_ID_WIDTH-1:0]            dbus_BID, // unused
   input [AXI_USER_WIDTH-1:0]          dbus_BUSER // unused
/* verilator lint_on UNUSED */
);

   localparam TAG_WIDTH                = (CONFIG_AW - CONFIG_DC_P_SETS - CONFIG_DC_P_LINE);
   localparam TAG_V_RAM_AW             = (CONFIG_DC_P_SETS);
   localparam TAG_V_RAM_DW             = (TAG_WIDTH + 1); // TAG + V
   localparam PAYLOAD_DW               = (CONFIG_DW);
   localparam PAYLOAD_P_DW_BYTES       = (CONFIG_P_DW-3); // = $clog2(PAYLOAD_DW/8)
   localparam PAYLOAD_AW               = (CONFIG_DC_P_SETS + CONFIG_DC_P_LINE - PAYLOAD_P_DW_BYTES);
   localparam AXI_FETCH_SIZE           = (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES) ? PAYLOAD_P_DW_BYTES : AXI_P_DW_BYTES;
   
   // Stage 1 Input
   reg [CONFIG_DC_P_SETS-1:0]          s1i_line_addr;
   reg [TAG_V_RAM_DW-1:0]              s1i_replace_tag_v;
   wire                                s1i_tag_v_re;
   wire                                s1i_tag_v_we            [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s2i_d_we                [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [TAG_V_RAM_AW-1:0]             s2i_d_waddr;
   wire                                s2i_d_wdat;
   wire [PAYLOAD_DW/8-1:0]             s2i_payload_we;
   wire [PAYLOAD_DW-1:0]               s2i_payload_din;
   // Stage 1 Output / Stage 2 Input
   wire [CONFIG_DW/8-1:0]              s1o_wmsk;
   wire [CONFIG_DC_P_SETS-1:0]         s1o_line_addr;
   reg [PAYLOAD_AW-1:0]                s2i_payload_addr;
   wire                                s2i_payload_re;
   wire                                s1o_valid;
   wire [TAG_V_RAM_DW-1:0]             s1o_tag_v               [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s1o_d                   [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s1o_dirty;
   wire [CONFIG_P_PAGE_SIZE-1:0]       s1o_vpo;
   wire [CONFIG_AW-1:0]                s2i_paddr;
   wire [TAG_WIDTH-1:0]                s2i_tag                 [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s2i_v                   [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2i_hit_vec;
   wire                                s2i_hit;
   wire                                s2i_get_dat;
   wire [CONFIG_AW-1:0]                s1o_op_inv_paddr;
   wire [CONFIG_DC_P_WAYS-1:0]         s2o_fsm_free_way;
   // Stage 2 Output / Stage 3 Input
   wire [CONFIG_DC_P_SETS-1:0]         s2o_line_addr;
   wire                                s2o_valid;
   wire [CONFIG_AW-1:0]                s2o_paddr;
   wire [PAYLOAD_DW*(1<<CONFIG_DC_P_WAYS)-1:0] s2o_payload;
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2o_hit_vec;
   wire [PAYLOAD_DW-1:0]               s2o_match_payload;
   wire                                s2o_dirty;
   // FSM
   reg [2:0]                           fsm_state_nxt;
   wire [2:0]                          fsm_state_ff;
   wire [CONFIG_DC_P_WAYS-1:0]         fsm_free_way, fsm_free_way_nxt;
   wire [CONFIG_DC_P_SETS-1:0]         fsm_boot_cnt, fsm_boot_cnt_nxt;
   wire [CONFIG_DC_P_LINE-1:0]         fsm_refill_cnt;
   reg [CONFIG_DC_P_LINE-1:0]          fsm_refill_cnt_nxt;
   wire                                p_ce;
   wire [CONFIG_AW-1:0]                refill_paddr;
   // AXI
   wire                                ar_set, ar_clr;
   wire                                hds_axi_R;
   wire                                hds_axi_R_last;
   wire [AXI_ADDR_WIDTH-1:0]           axi_ar_addr_nxt;
   
   localparam [2:0] S_BOOT             = 3'd0;
   localparam [2:0] S_IDLE             = 3'd1;
   localparam [2:0] S_REPLACE          = 3'd2;
   localparam [2:0] S_REFILL           = 3'd3;
   localparam [2:0] S_INVALIDATE       = 3'd4;
   localparam [2:0] S_RELOAD_S1O_S2O   = 3'd5;
   
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
                  .ADDR (s2i_payload_addr),
                  .RE   (s2i_payload_re),
                  .DOUT (s2o_payload[way*PAYLOAD_DW +: PAYLOAD_DW]),
                  .WE   (s2i_payload_we),
                  .DIN  (s2i_payload_din)
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
                  .RE   (s1i_tag_v_re),
                  .DOUT (s1o_tag_v[way]),
                  .WE   (s1i_tag_v_we[way]),
                  .DIN  (s1i_replace_tag_v)
               );
            mRF_nwnr
               #(
                  .DW   (1),
                  .AW   (TAG_V_RAM_AW),
                  .NUM_READ (1),
                  .NUM_WRITE (1)
               )
            U_D_RF
               (
                  .CLK     (clk),
                  .RE      (s1i_tag_v_re),
                  .RADDR   (s1i_line_addr),
                  .RDATA   (s1o_d[way]),
                  .WE      (s2i_d_we[way]),
                  .WADDR   (s2i_d_waddr),
                  .WDATA   (s2i_d_wdat)
               );
               
            assign {s2i_tag[way], s2i_v[way]} = s1o_tag_v[way];
            
            assign s2i_hit_vec[way] = (s2i_v[way] & (s2i_tag[way] == s2i_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS]) );
         end
   endgenerate
   
   // Sel the dout of matched way
   pmux #(.SELW(1<<CONFIG_DC_P_WAYS), .DW(PAYLOAD_DW)) U_PMUX_BNPC (.sel(s2o_hit_vec), .din(s2o_payload), .dout(s2o_match_payload), .valid(s2i_hit) );
   
   mDFF_lr # (.DW(1)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(req), .Q(s1o_valid) );
   mDFF_lr # (.DW(CONFIG_DW/8)) ff_s1o_wmsk (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(wmsk), .Q(s1o_wmsk) );
   mDFF_l # (.DW(CONFIG_P_PAGE_SIZE)) ff_s1o_vpo (.CLK(clk), .LOAD(p_ce), .D(vpo), .Q(s1o_vpo) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s1o_op_inv_paddr (.CLK(clk), .LOAD(p_ce), .D(op_inv_paddr), .Q(s1o_op_inv_paddr) );
   mDFF_l # (.DW(CONFIG_DC_P_SETS)) ff_s1o_line_addr (.CLK(clk), .LOAD(p_ce), .D(s1i_line_addr), .Q(s1o_line_addr) );
   mDFF_l # (.DW(1<<CONFIG_DC_P_WAYS)) ff_s2o_hit_vec (.CLK(clk), .LOAD(p_ce), .D(s2i_hit_vec), .Q(s2o_hit_vec) );
   mDFF_l # (.DW(CONFIG_DC_P_SETS)) ff_s2o_line_addr (.CLK(clk), .LOAD(p_ce), .D(s1o_line_addr), .Q(s2o_line_addr) );
   mDFF_l # (.DW(CONFIG_DC_P_WAYS)) ff_s2o_fsm_free_way (.CLK(clk), .LOAD(p_ce), .D(fsm_free_way), .Q(s2o_fsm_free_way) );
   
   mDFF_lr # (.DW(1)) ff_s2o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_valid), .Q(s2o_valid) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s2o_paddr (.CLK(clk), .LOAD(p_ce), .D(s2i_paddr), .Q(s2o_paddr) );
   
   // Main FSM
   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         case (fsm_state_ff)
            S_BOOT:
               if (~|fsm_boot_cnt_nxt)
                  fsm_state_nxt = S_IDLE;

            S_IDLE:
               if (op_inv)
                  fsm_state_nxt = S_INVALIDATE;
               else if (s1o_valid & ~s2i_hit & ~kill_req_s2)
                  fsm_state_nxt = S_REPLACE;

            S_REPLACE:
               fsm_state_nxt = s2o_dirty ? S_WRITEBACK : S_REFILL;
            
            S_REFILL:
               if (hds_axi_R_last)
                  fsm_state_nxt = S_RELOAD_S1O_S2O;
            
            S_INVALIDATE:
               fsm_state_nxt = S_IDLE;
               
            S_RELOAD_S1O_S2O:
               fsm_state_nxt = S_IDLE;
            default: ;
         endcase
      end
      
   // Clock algorithm
   assign fsm_free_way_nxt = fsm_free_way + 'b1;
   
   mDFF_r # (.DW(3), .RST_VECTOR(S_BOOT)) ff_state_r (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff) );
   mDFF_r # (.DW(CONFIG_DC_P_WAYS)) ff_fsm_free_idx (.CLK(clk), .RST(rst), .D(fsm_free_way_nxt), .Q(fsm_free_way) );
   
   // Boot counter
   assign fsm_boot_cnt_nxt = fsm_boot_cnt + 'b1;
   
   mDFF_r # (.DW(CONFIG_DC_P_SETS)) ff_fsm_boot_cnt_nxt (.CLK(clk), .RST(rst), .D(fsm_boot_cnt_nxt), .Q(fsm_boot_cnt) );
   
   // Refill counter
   always @(*)
      begin
         fsm_refill_cnt_nxt = fsm_refill_cnt;
         case (fsm_state_ff)
            S_REFILL:
               if (hds_axi_R)
                  fsm_refill_cnt_nxt = fsm_refill_cnt + (1<<AXI_FETCH_SIZE);
            default:
               fsm_refill_cnt_nxt = 'b0;
         endcase
      end
   
   mDFF_r # (.DW(CONFIG_DC_P_LINE)) ff_fsm_refill_cnt (.CLK(clk), .RST(rst), .D(fsm_refill_cnt_nxt), .Q(fsm_refill_cnt) );
   
   assign s1o_dirty = s1o_d[fsm_free_way];
   
   mDFF_lr # (.DW(1)) ff_s2o_dirty (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_dirty), .Q(s2o_dirty) );
   

   // MUX for tag RAM addr 
   always @(*)
      case (fsm_state_ff)
         S_BOOT:
            s1i_line_addr = fsm_boot_cnt;
         S_INVALIDATE:
            s1i_line_addr = s1o_op_inv_paddr[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS];
         S_REPLACE:
            s1i_line_addr = s2o_line_addr;
         S_RELOAD_S1O_S2O:
            s1i_line_addr = s1o_line_addr;
         default:
            s1i_line_addr = vpo[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS]; // index
      endcase
      
   // MUX for tag RAM din
   always @(*)
      case (fsm_state_ff)
         S_BOOT,
         S_INVALIDATE:
            s1i_replace_tag_v = 'b0;
         default:
            s1i_replace_tag_v = {s2o_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS], 1'b1};
      endcase
      
   assign s1i_tag_v_re = (p_ce | (fsm_state_ff==S_RELOAD_S1O_S2O));
   
   // tag RAM write enable
   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         assign s1i_tag_v_we[way] = (fsm_state_ff==S_BOOT) |
                                    (fsm_state_ff==S_INVALIDATE) |
                                    ((fsm_state_ff==S_REPLACE) & (way == s2o_fsm_free_way));
   endgenerate

   // MUX for D flag RAM addr 
   always @(*)
      case (fsm_state_ff)
         S_BOOT:
            s2i_d_waddr = fsm_boot_cnt;
         S_INVALIDATE:
            s2i_d_waddr = s1o_op_inv_paddr[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS];
         S_REPLACE:
            s2i_d_waddr = s2o_line_addr;
         default:
            s2i_d_waddr = s1o_line_addr;
      endcase
      
   // MUX for D flag RAM din
   always @(*)
      case (fsm_state_ff)
         S_BOOT,
         S_INVALIDATE,
         S_REPLACE:
            s2i_d_wdat = 'b0;
         default:
            s2i_d_wdat = (|s1o_wmsk);
      endcase
   
   // D flag RAM write enable
   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         assign s2i_d_we[way] = s1i_tag_v_we[way] |
                                 // Cache line hit and no invalidate or flush
                                 ((fsm_state_ff==S_IDLE) & ~op_inv & ~op_fls & s1o_valid & s2i_hit & ~kill_req_s2);
   endgenerate

   // MUX for payload RAM addr
   always @(*)
      case (fsm_state_ff)
         S_REFILL:
            s2i_payload_addr = {s2o_paddr[CONFIG_DC_P_LINE +: CONFIG_DC_P_SETS], fsm_refill_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES]};
         S_RELOAD_S1O_S2O:
            s2i_payload_addr = s2o_payload_addr;
         default:
            s2i_payload_addr = s1o_vpo[PAYLOAD_P_DW_BYTES +: PAYLOAD_AW]; // {index,offset}
      endcase
      
   assign s2i_payload_re = (p_ce | (fsm_state_ff==S_RELOAD_S1O_S2O));

   // Aligner for payload RAM din
   generate
      if (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES)
         begin
            assign s2i_payload_we = {PAYLOAD_DW/8{fsm_state_ff == S_REFILL}};
            assign s2i_payload_din = axi_r_data_i[(1<<PAYLOAD_P_DW_BYTES)*8-1:0];
         end
      else
         for(i=0;i<PAYLOAD_DW/8;i=i+1)
            begin : gen_aligner
               assign s2i_payload_we[i] = (fsm_state_ff == S_REFILL) &
                                          (fsm_refill_cnt[AXI_FETCH_SIZE +: PAYLOAD_P_DW_BYTES-AXI_FETCH_SIZE] == i[AXI_FETCH_SIZE +: PAYLOAD_P_DW_BYTES-AXI_FETCH_SIZE]);
               assign s2i_payload_din[i*8 +: 8] = axi_r_data_i[(i%(1<<AXI_FETCH_SIZE))*8 +: 8];
            end
   endgenerate
   
   assign stall_req = (fsm_state_ff != S_IDLE);
   
   assign op_stall_req = (op_inv | stall_req); // Stall the EXU if icache is temporarily unable to receive a new operation
   
   assign s2i_get_dat = (s2o_paddr[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES] == 
                    fsm_refill_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_DC_P_LINE-PAYLOAD_P_DW_BYTES]);
   
   // Output
   mDFF_l # (.DW(PAYLOAD_DW)) ff_ins (.CLK(clk), .LOAD(p_ce), .D(s2o_match_payload), .Q(dout) );
               
   assign valid = (s2o_valid & ~stall_req);
   
   // AXI - AR
   assign axi_ar_prot_o = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign axi_ar_id_o = {AXI_ID_WIDTH{1'b0}};
   assign axi_ar_user_o = {AXI_USER_WIDTH{1'b0}};
   assign axi_ar_len_o = ((1<<(CONFIG_DC_P_LINE-AXI_FETCH_SIZE))-1);
   assign axi_ar_size_o = AXI_FETCH_SIZE;
   assign axi_ar_burst_o = `AXI_BURST_TYPE_INCR;
   assign axi_ar_lock_o = 'b0;
   assign axi_ar_cache_o = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign axi_ar_qos_o = 'b0;
   assign axi_ar_region_o = 'b0;
   assign ar_set = (fsm_state_ff==S_REPLACE);
   assign ar_clr = (axi_ar_ready_i & axi_ar_valid_o);
   assign refill_paddr = {s2o_paddr[CONFIG_DC_P_LINE +: CONFIG_AW - CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}}};
   
   // Address adapter (truncate or fill zero)
   generate
      if (AXI_ADDR_WIDTH > CONFIG_AW)
         assign axi_ar_addr_nxt = {{AXI_ADDR_WIDTH-CONFIG_AW{1'b0}}, refill_paddr};
      else if (AXI_ADDR_WIDTH < CONFIG_AW)
         assign axi_ar_addr_nxt = refill_paddr[AXI_ADDR_WIDTH-1:0];
      else
         assign axi_ar_addr_nxt = refill_paddr;
   endgenerate
   
   mDFF_lr # (.DW(1)) ff_axi_ar_valid (.CLK(clk), .RST(rst), .LOAD(ar_set|ar_clr), .D(ar_set|~ar_clr), .Q(axi_ar_valid_o) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_axi_ar_addr (.CLK(clk), .RST(rst), .LOAD(ar_set), .D(axi_ar_addr_nxt), .Q(axi_ar_addr_o) );
   
   
   // AXI - R
   assign axi_r_ready_o = (fsm_state_ff == S_REFILL);
   assign hds_axi_R = (axi_r_valid_i & axi_r_ready_o);
   assign hds_axi_R_last = (hds_axi_R & axi_r_last_i);
   
   
   // synthesis translate_off
`ifndef SYNTHESIS
   initial
      begin
         if ((1<<CONFIG_P_DW) != CONFIG_DW)
            $fatal(1, "The value of CONFIG_P_DW and CONFIG_DW do not match");
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
