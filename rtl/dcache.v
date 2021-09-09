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
   input [2:0]                         size,
   input [CONFIG_DW/8-1:0]             wmsk,
   input [CONFIG_DW-1:0]               wdat,
   input [CONFIG_P_PAGE_SIZE-1:0]      vpo,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn_s2,
   input                               kill_req_s2,
   input                               uncached_s2,
   input                               inv,
   input                               fls,
   output [CONFIG_DW-1:0]              dout,
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
   input [AXI_USER_WIDTH-1:0]          dbus_BUSER, // unused
/* verilator lint_on UNUSED */

   // DCID
   output [CONFIG_DW-1:0]              msr_dcid
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
   // Stage 1 Output / Stage 2 Input
   wire                                s1o_inv;
   wire                                s1o_fls;
   wire                                s2i_ready;
   wire                                s2i_d_we                [(1<<CONFIG_DC_P_WAYS)-1:0];
   reg [TAG_V_RAM_AW-1:0]              s2i_d_waddr;
   reg                                 s2i_d_wdat;
   wire [PAYLOAD_DW/8-1:0]             s2i_payload_we          [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [PAYLOAD_DW/8-1:0]             s2i_payload_tgt_we;
   reg [PAYLOAD_DW-1:0]                s2i_payload_din;
   wire [PAYLOAD_DW/8-1:0]             s2i_wb_we;
   wire [PAYLOAD_DW-1:0]               s2i_wb_din;
   wire                                s2i_wb_re;
   wire [2:0]                          s1o_size;
   wire [CONFIG_DW/8-1:0]              s1o_wmsk;
   wire [CONFIG_DW-1:0]                s1o_wdat;
   wire [CONFIG_DC_P_SETS-1:0]         s1o_line_addr;
   reg [PAYLOAD_AW-1:0]                s2i_payload_addr;
   wire                                s2i_payload_re;
   wire                                s1o_valid;
   wire [TAG_V_RAM_DW-1:0]             s1o_tag_v               [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s1o_d;
   wire                                s1o_free_dirty;
   wire [CONFIG_P_PAGE_SIZE-1:0]       s1o_vpo;
   reg [CONFIG_AW-1:0]                 s2i_paddr;
   wire [TAG_WIDTH-1:0]                s2i_tag                 [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire                                s2i_v                   [(1<<CONFIG_DC_P_WAYS)-1:0];
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2i_hit_vec;
   wire                                s2i_hit;
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2o_fsm_free_way;
   // Stage 2 Output / Stage 3 Input
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s3i_match_vec;
   wire                                s2o_fls;
   wire [CONFIG_DC_P_SETS-1:0]         s2o_line_addr;
   wire [CONFIG_AW-1:0]                s2o_paddr;
   wire [CONFIG_DW/8-1:0]              s2o_wmsk;
   wire [CONFIG_DW-1:0]                s2o_wdat;
   wire [PAYLOAD_DW*(1<<CONFIG_DC_P_WAYS)-1:0] s2o_payload;
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2o_hit_vec;
   wire [PAYLOAD_DW-1:0]               s2o_match_payload;
   wire [PAYLOAD_DW-1:0]               s2o_wb_payload;
   wire                                s2o_free_dirty;
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    s2o_d;
   wire                                s2o_hit_dirty;
   wire [PAYLOAD_AW-1:0]               s2o_payload_addr;
   wire [2:0]                          s2o_size;
   wire                                s2o_uncached;
   // FSM
   reg [3:0]                           fsm_state_nxt;
   wire [3:0]                          fsm_state_ff;
   wire [(1<<CONFIG_DC_P_WAYS)-1:0]    fsm_free_way, fsm_free_way_nxt;
   wire [CONFIG_DC_P_SETS-1:0]         fsm_boot_cnt;
   wire [CONFIG_DC_P_SETS:0]           fsm_boot_cnt_nxt_carry;
   wire [CONFIG_DC_P_LINE-1:0]         fsm_refill_cnt;
   wire [CONFIG_DC_P_LINE:0]           fsm_refill_cnt_nxt_carry;
   reg [CONFIG_DC_P_LINE-1:0]          fsm_refill_cnt_nxt;
   reg                                 fsm_uncached_req;
   wire                                p_ce;
   wire [CONFIG_AW-1:0]                axi_paddr_nxt;
   // AXI
   reg                                 ar_set, aw_set;
   wire                                ar_clr, aw_clr;
   wire                                wvalid_set, wvalid_clr;
   wire                                wlast_set, wlast_clr;
   wire                                hds_axi_R;
   wire                                hds_axi_R_last;
   wire                                hds_axi_W;
   wire                                hds_axi_W_last;
   wire                                hds_axi_B;
   wire [AXI_ADDR_WIDTH-1:0]           axi_arw_addr_nxt;
   wire [PAYLOAD_DW-1:0]               axi_aligned_rdata_ff;
   wire [PAYLOAD_DW/8-1:0]             axi_aligned_rdata_ff_wmsk;
   wire [PAYLOAD_DW-1:0]               axi_aligned_rdata_nxt;

   localparam [3:0] S_BOOT             = 4'd0;
   localparam [3:0] S_IDLE             = 4'd1;
   localparam [3:0] S_REPLACE          = 4'd2;
   localparam [3:0] S_REFILL           = 4'd3;
   localparam [3:0] S_WRITEBACK        = 4'd4;
   localparam [3:0] S_INVALIDATE       = 4'd5;
   localparam [3:0] S_RELOAD_S1O_S2O   = 4'd6;
   localparam [3:0] S_FLUSH            = 4'd7;
   localparam [3:0] S_UNCACHED_BOOT    = 4'd8;
   localparam [3:0] S_UNCACHED_READ    = 4'd9;
   localparam [3:0] S_UNCACHED_WRITE   = 4'd10;

   genvar way, i, j;

   assign p_ce = (~stall_req);

   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         begin : gen_ways
            wire rf_d, rf_d_ff;
            wire rf_conflict;
            wire rf_bypass;

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
                  .WE   (s2i_payload_we[way]),
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
                  .RDATA   (rf_d),
                  .WE      (s2i_d_we[way]),
                  .WADDR   (s2i_d_waddr),
                  .WDATA   (s2i_d_wdat)
               );

            // Bypass D flag
            assign rf_conflict = ((s1i_line_addr == s2i_d_waddr) & s2i_d_we[way]);

            mDFF_lr #(.DW(1)) ff_bypass (.CLK(clk), .RST(rst), .LOAD(rf_conflict | s1i_tag_v_re), .D(rf_conflict | ~s1i_tag_v_re), .Q(rf_bypass) );
            mDFF_l #(.DW(1)) ff_rd_d (.CLK(clk), .LOAD(s1i_tag_v_re), .D(s2i_d_wdat), .Q(rf_d_ff) );

            assign s1o_d[way] = rf_bypass ? rf_d_ff : rf_d;

            assign {s2i_tag[way], s2i_v[way]} = s1o_tag_v[way];

            assign s2i_hit_vec[way] = (s2i_v[way] & (s2i_tag[way] == s2i_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS]) );
         end
   endgenerate

   assign s2i_hit = (|s2i_hit_vec);
   
   // Select the matched way
   assign s3i_match_vec = (fsm_state_ff==S_RELOAD_S1O_S2O) ? s2o_fsm_free_way : s2o_hit_vec;
   
   // Sel the dout of matched way
   pmux #(.SELW(1<<CONFIG_DC_P_WAYS), .DW(PAYLOAD_DW)) pmux_s2o_payload (.sel(s3i_match_vec), .din(s2o_payload), .dout(s2o_match_payload),
                                                            /* verilator lint_off PINCONNECTEMPTY */
                                                            .valid() /* unused */
                                                            /* verilator lint_on PINCONNECTEMPTY */ );
   pmux #(.SELW(1<<CONFIG_DC_P_WAYS), .DW(1)) pmux_s2o_d (.sel(s2o_hit_vec), .din(s2o_d), .dout(s2o_hit_dirty),
                                                            /* verilator lint_off PINCONNECTEMPTY */
                                                            .valid() /* unused */
                                                            /* verilator lint_on PINCONNECTEMPTY */);

   pmux #(.SELW(1<<CONFIG_DC_P_WAYS), .DW(1)) pmux_s1o_free_dirty (.sel(fsm_free_way), .din(s1o_d), .dout(s1o_free_dirty),
                                                            /* verilator lint_off PINCONNECTEMPTY */
                                                            .valid() /* unused */
                                                            /* verilator lint_on PINCONNECTEMPTY */);

   pmux #(.SELW(1<<CONFIG_DC_P_WAYS), .DW(PAYLOAD_DW)) pmux_s2o_wb_payload (.sel(s2o_fsm_free_way), .din(s2o_payload), .dout(s2o_wb_payload),
                                                            /* verilator lint_off PINCONNECTEMPTY */
                                                            .valid() /* unused */
                                                            /* verilator lint_on PINCONNECTEMPTY */);
                                                  
   mDFF_lr # (.DW(1)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(req), .Q(s1o_valid) );
   mDFF_lr # (.DW(1)) ff_s1o_inv (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(inv), .Q(s1o_inv) );
   mDFF_lr # (.DW(1)) ff_s1o_fls (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(fls), .Q(s1o_fls) );
   mDFF_l # (.DW(3)) ff_s1o_size (.CLK(clk), .LOAD(p_ce), .D(size), .Q(s1o_size) );
   mDFF_lr # (.DW(CONFIG_DW/8)) ff_s1o_wmsk (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(wmsk), .Q(s1o_wmsk) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s1o_wdat (.CLK(clk), .LOAD(p_ce), .D(wdat), .Q(s1o_wdat) );
   mDFF_l # (.DW(CONFIG_P_PAGE_SIZE)) ff_s1o_vpo (.CLK(clk), .LOAD(p_ce), .D(vpo), .Q(s1o_vpo) );
   mDFF_l # (.DW(CONFIG_DC_P_SETS)) ff_s1o_line_addr (.CLK(clk), .LOAD(p_ce), .D(s1i_line_addr), .Q(s1o_line_addr) );
   mDFF_l # (.DW(1<<CONFIG_DC_P_WAYS)) ff_s2o_hit_vec (.CLK(clk), .LOAD(p_ce), .D(fsm_free_way), .Q(s2o_hit_vec) );
   mDFF_l # (.DW(CONFIG_DC_P_SETS)) ff_s2o_line_addr (.CLK(clk), .LOAD(p_ce), .D(s1o_line_addr), .Q(s2o_line_addr) );
   mDFF_l # (.DW(1<<CONFIG_DC_P_WAYS)) ff_s2o_fsm_free_way (.CLK(clk), .LOAD(p_ce), .D(fsm_free_way), .Q(s2o_fsm_free_way) );

   mDFF_lr # (.DW(1)) ff_s2o_fls (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_fls), .Q(s2o_fls) );
   mDFF_l # (.DW(CONFIG_AW)) ff_s2o_paddr (.CLK(clk), .LOAD(p_ce), .D(s2i_paddr), .Q(s2o_paddr) );
   mDFF_l # (.DW(1<<CONFIG_DC_P_WAYS)) ff_s2o_d (.CLK(clk), .LOAD(p_ce), .D(s1o_d), .Q(s2o_d) );
   mDFF_l # (.DW(1)) ff_s2o_free_dirty (.CLK(clk), .LOAD(p_ce), .D(s1o_free_dirty), .Q(s2o_free_dirty) );
   mDFF_l # (.DW(PAYLOAD_AW)) ff_s2o_payload_addr (.CLK(clk), .LOAD(p_ce), .D(s2i_payload_addr), .Q(s2o_payload_addr) );
   mDFF_l # (.DW(3)) ff_s2o_size (.CLK(clk), .LOAD(p_ce), .D(s1o_size), .Q(s2o_size) );
   mDFF_l # (.DW(CONFIG_DW)) ff_s2o_wdat (.CLK(clk), .LOAD(p_ce), .D(s1o_wdat), .Q(s2o_wdat) );
   mDFF_lr # (.DW(CONFIG_DW/8)) ff_s2o_wmsk (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_wmsk), .Q(s2o_wmsk) );
   mDFF_lr # (.DW(1)) ff_s2o_use_uncached_dout (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(uncached_s2), .Q(s2o_uncached) );
   

   // Main FSM
   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         ar_set = 'b0;
         aw_set = 'b0;
         fsm_uncached_req = 'b0;
         case (fsm_state_ff)
            S_BOOT:
               if (fsm_boot_cnt_nxt_carry[CONFIG_DC_P_SETS])
                  fsm_state_nxt = S_IDLE;

            S_IDLE:
               if (s1o_valid)
                  if (s1o_inv)
                     fsm_state_nxt = S_INVALIDATE;
                  else if (s1o_fls)
                     fsm_state_nxt = s2i_hit ? S_FLUSH : S_IDLE;
                  else if (s1o_valid & uncached_s2 & ~kill_req_s2) // Uncached access
                     fsm_state_nxt = S_UNCACHED_BOOT;
                  else if (s1o_valid & ~s2i_hit & ~uncached_s2 & ~kill_req_s2) // Miss
                     fsm_state_nxt = S_REPLACE;

            S_REPLACE:
               begin
                  fsm_state_nxt = (s2o_free_dirty) ? S_WRITEBACK : S_REFILL;
                  ar_set = ~s2o_free_dirty;
                  aw_set = s2o_free_dirty;
               end

            S_WRITEBACK:
               if (hds_axi_B)
                  begin
                     fsm_state_nxt = (s2o_fls) ? S_IDLE : S_REFILL;
                     ar_set = ~s2o_fls;
                  end

            S_REFILL:
               if (hds_axi_R_last)
                  fsm_state_nxt = S_RELOAD_S1O_S2O;

            S_INVALIDATE:
               fsm_state_nxt = S_IDLE;

            S_RELOAD_S1O_S2O:
               fsm_state_nxt = S_IDLE;

            S_FLUSH:
               begin
                  fsm_state_nxt = (s2o_hit_dirty) ? S_WRITEBACK : S_IDLE;
                  aw_set = s2o_hit_dirty;
               end

            S_UNCACHED_BOOT:
               begin
                  fsm_state_nxt = (|s2o_wmsk) ? S_UNCACHED_WRITE : S_UNCACHED_READ;
                  ar_set = ~(|s2o_wmsk);
                  aw_set = (|s2o_wmsk);
                  fsm_uncached_req = 'b1;
               end
               
            S_UNCACHED_READ:
               if (hds_axi_R)
                  fsm_state_nxt = S_IDLE;
            
            S_UNCACHED_WRITE:
               if (hds_axi_B)
                  fsm_state_nxt = S_IDLE;
               
            default: ;
         endcase
      end

   // Cache line hit and no invalidate or flush
   assign s2i_ready = ((fsm_state_ff==S_IDLE) & s1o_valid & ~s1o_inv & ~s1o_fls & ~uncached_s2 & s2i_hit & ~kill_req_s2);

   mDFF_r # (.DW(4), .RST_VECTOR(S_BOOT)) ff_state_r (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff) );
   
   // Clock algorithm
   assign fsm_free_way_nxt = (fsm_free_way[(1<<CONFIG_DC_P_WAYS)-1])
                              ? {{(1<<CONFIG_DC_P_WAYS)-1{1'b0}}, 1'b1}
                              : {fsm_free_way[(1<<CONFIG_DC_P_WAYS)-2:0], 1'b0};

   mDFF_r #(.DW(1<<CONFIG_DC_P_WAYS), .RST_VECTOR({{(1<<CONFIG_DC_P_WAYS)-1{1'b0}}, 1'b1}) ) ff_fsm_free_idx
      (.CLK(clk), .RST(rst), .D(fsm_free_way_nxt), .Q(fsm_free_way) );

   // Boot counter
   assign fsm_boot_cnt_nxt_carry = fsm_boot_cnt + 'b1;

   mDFF_r # (.DW(CONFIG_DC_P_SETS)) ff_fsm_boot_cnt_nxt (.CLK(clk), .RST(rst), .D(fsm_boot_cnt_nxt_carry[CONFIG_DC_P_SETS-1:0]), .Q(fsm_boot_cnt) );

   // Refill counter
   always @(*)
      if (((fsm_state_ff==S_REFILL) & hds_axi_R) | ((fsm_state_ff==S_WRITEBACK) & s2i_wb_re))
         fsm_refill_cnt_nxt = fsm_refill_cnt_nxt_carry[CONFIG_DC_P_LINE-1:0];
      else
         fsm_refill_cnt_nxt = fsm_refill_cnt;

   assign fsm_refill_cnt_nxt_carry = (fsm_refill_cnt + (1<<AXI_FETCH_SIZE));

   mDFF_r # (.DW(CONFIG_DC_P_LINE)) ff_fsm_refill_cnt (.CLK(clk), .RST(rst), .D(fsm_refill_cnt_nxt), .Q(fsm_refill_cnt) );


   // MUX for tag RAM addr
   always @(*)
      case (fsm_state_ff)
         S_BOOT:
            s1i_line_addr = fsm_boot_cnt;
         S_INVALIDATE,
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
         S_REPLACE:
            s1i_replace_tag_v = {s2o_paddr[CONFIG_AW-1:CONFIG_DC_P_LINE+CONFIG_DC_P_SETS], 1'b1};
         default: // S_BOOT, S_INVALIDATE:
            s1i_replace_tag_v = 'b0;
      endcase

   assign s1i_tag_v_re = (p_ce | (fsm_state_ff==S_RELOAD_S1O_S2O));

   // tag RAM write enable
   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         assign s1i_tag_v_we[way] = (fsm_state_ff==S_BOOT) |
                                    (fsm_state_ff==S_INVALIDATE) |
                                    ((fsm_state_ff==S_REPLACE) & (s2o_fsm_free_way[way]));
   endgenerate

   // MUX for D flag RAM addr
   always @(*)
      case (fsm_state_ff)
         S_IDLE:
            s2i_d_waddr = s1o_line_addr;
         default:
            s2i_d_waddr = s1i_line_addr;
      endcase

   // MUX for D flag RAM din
   always @(*)
      case (fsm_state_ff)
         S_IDLE:
            s2i_d_wdat = (|s1o_wmsk);
         default: // S_BOOT, S_INVALIDATE, S_REPLACE:
            s2i_d_wdat = 'b0;
      endcase

   // D flag RAM write enable
   generate
      for(way=0; way<(1<<CONFIG_DC_P_WAYS); way=way+1)
         assign s2i_d_we[way] = (s1i_tag_v_we[way] | (s2i_ready & s2i_hit_vec[way])); // FIXME?????
   endgenerate

   // MUX for physical addr tag to match
   assign s2i_paddr = {ppn_s2, s1o_vpo};

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

   // MUX for payload RAM din
   always @(*)
      case (fsm_state_ff)
         S_IDLE:
            s2i_payload_din = s1o_wdat;
         S_RELOAD_S1O_S2O:
            s2i_payload_din = s2o_wdat;
         default:
            s2i_payload_din = s2i_wb_din;
      endcase

   assign s2i_payload_re = (p_ce |
                              ((fsm_state_ff==S_WRITEBACK) & s2i_wb_re) |
                              (fsm_state_ff==S_RELOAD_S1O_S2O));

   // MUX for payload RAM we
   assign s2i_payload_tgt_we = ({CONFIG_DW/8{s2i_ready}} & s1o_wmsk) |
                                 ({CONFIG_DW/8{fsm_state_ff==S_RELOAD_S1O_S2O}} & s2o_wmsk) |
                                 s2i_wb_we;
   
   generate
      for(way=0;way<(1<<CONFIG_DC_P_WAYS);way=way+1)
         assign s2i_payload_we[way] = (s2i_payload_tgt_we &
                                       {CONFIG_DW/8{
                                          (s2i_ready & s2i_hit_vec[way]) |
                                          ((fsm_state_ff==S_RELOAD_S1O_S2O) & s2o_fsm_free_way[way]) |
                                          ((fsm_state_ff==S_REFILL) & s2o_fsm_free_way[way])
                                       }});
   endgenerate

   // Aligner for payload RAM din
   align_r
      #(
         .AXI_P_DW_BYTES               (AXI_P_DW_BYTES),
         .PAYLOAD_P_DW_BYTES           (PAYLOAD_P_DW_BYTES),
         .RAM_AW                       (CONFIG_DC_P_LINE)
      )
   U_ALIGN_R
      (
         .i_axi_RDATA                  (dbus_RDATA),
         .i_ram_we                     (fsm_state_ff == S_REFILL),
         .i_ram_addr                   (fsm_refill_cnt),
         .o_ram_wmsk                   (s2i_wb_we),
         .o_ram_din                    (s2i_wb_din)
      );

   assign stall_req = (fsm_state_ff != S_IDLE);

   // Output
   assign dout = (s2o_uncached)
                     ? axi_aligned_rdata_ff
                     : s2o_match_payload;

   // AXI - AR
   assign dbus_ARPROT = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign dbus_ARID = {AXI_ID_WIDTH{1'b0}};
   assign dbus_ARUSER = {AXI_USER_WIDTH{1'b0}};
   assign dbus_ARLEN = (fsm_state_ff==S_UNCACHED_READ) ? 'b0 : ((1<<(CONFIG_DC_P_LINE-AXI_FETCH_SIZE))-1);
   assign dbus_ARSIZE = (fsm_state_ff==S_UNCACHED_READ) ? s2o_size : AXI_FETCH_SIZE;
   assign dbus_ARBURST = `AXI_BURST_TYPE_INCR;
   assign dbus_ARLOCK = 'b0;
   assign dbus_ARCACHE = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign dbus_ARQOS = 'b0;
   assign dbus_ARREGION = 'b0;
   assign ar_clr = (dbus_ARREADY & dbus_ARVALID);
   
   assign axi_paddr_nxt = (fsm_uncached_req)
                           ? s2o_paddr
                           : {s2o_paddr[CONFIG_DC_P_LINE +: CONFIG_AW - CONFIG_DC_P_LINE], {CONFIG_DC_P_LINE{1'b0}}};

   // Address width adapter (truncate or fill zero)
   generate
      if (AXI_ADDR_WIDTH > CONFIG_AW)
         assign axi_arw_addr_nxt = {{AXI_ADDR_WIDTH-CONFIG_AW{1'b0}}, axi_paddr_nxt};
      else if (AXI_ADDR_WIDTH < CONFIG_AW)
         assign axi_arw_addr_nxt = axi_paddr_nxt[AXI_ADDR_WIDTH-1:0];
      else
         assign axi_arw_addr_nxt = axi_paddr_nxt;
   endgenerate

   mDFF_lr # (.DW(1)) ff_dbus_ARVALID (.CLK(clk), .RST(rst), .LOAD(ar_set|ar_clr), .D(ar_set|~ar_clr), .Q(dbus_ARVALID) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_dbus_ARADDR (.CLK(clk), .RST(rst), .LOAD(ar_set), .D(axi_arw_addr_nxt), .Q(dbus_ARADDR) );


   // AXI - R
   assign dbus_RREADY = (fsm_state_ff == S_REFILL) | (fsm_state_ff == S_UNCACHED_READ);
   assign hds_axi_R = (dbus_RVALID & dbus_RREADY);
   assign hds_axi_R_last = (hds_axi_R & dbus_RLAST);
   
   // Aligner for uncached R
   generate
      if (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES)
         begin : gen_uncached_align
            align_r
               #(
                  .AXI_P_DW_BYTES               (AXI_P_DW_BYTES),
                  .PAYLOAD_P_DW_BYTES           (PAYLOAD_P_DW_BYTES),
                  .RAM_AW                       (AXI_ADDR_WIDTH)
               )
            U_ALIGN_UNUCACHED_R
               (
                  .i_axi_RDATA                  (dbus_RDATA),
                  .i_ram_we                     (hds_axi_R),
                  .i_ram_addr                   (dbus_ARADDR),
                  .o_ram_wmsk                   (axi_aligned_rdata_ff_wmsk),
                  .o_ram_din                    (axi_aligned_rdata_nxt)
               );
               
            mDFF_l # (.DW(PAYLOAD_DW)) ff_axi_aligned_rdata (.CLK(clk), .LOAD(|axi_aligned_rdata_ff_wmsk), .D(axi_aligned_rdata_nxt), .Q(axi_aligned_rdata_ff) );
         end
      else
         initial $fatal(1, "Unsupported bitwidth for uncached device!");
   endgenerate
   

   // AXI - AW
   assign dbus_AWPROT = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign dbus_AWID = {AXI_ID_WIDTH{1'b0}};
   assign dbus_AWUSER = {AXI_USER_WIDTH{1'b0}};
   assign dbus_AWLEN = (fsm_state_ff==S_UNCACHED_READ) ? 'b0 : ((1<<(CONFIG_DC_P_LINE-AXI_FETCH_SIZE))-1);
   assign dbus_AWSIZE = (fsm_state_ff==S_UNCACHED_READ) ? s2o_size : AXI_FETCH_SIZE;
   assign dbus_AWBURST = `AXI_BURST_TYPE_INCR;
   assign dbus_AWLOCK = 'b0;
   assign dbus_AWCACHE = `AXI_AWCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign dbus_AWQOS = 'b0;
   assign dbus_AWREGION = 'b0;
   assign aw_clr = (dbus_AWREADY & dbus_AWVALID);

   mDFF_lr # (.DW(1)) ff_dbus_AWVALID (.CLK(clk), .RST(rst), .LOAD(aw_set|aw_clr), .D(aw_set|~aw_clr), .Q(dbus_AWVALID) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_dbus_AWADDR (.CLK(clk), .RST(rst), .LOAD(aw_set), .D(axi_arw_addr_nxt), .Q(dbus_AWADDR) );

   // AXI - W
   assign dbus_WUSER = 'b0;

   // Aligner for AXI W
   align_w
      #(
         .AXI_P_DW_BYTES                     (AXI_P_DW_BYTES),
         .PAYLOAD_P_DW_BYTES                 (PAYLOAD_P_DW_BYTES),
         .I_AXI_ADDR_AW                      (CONFIG_DC_P_LINE)
      )
   U_ALIGN_W
      (
         .i_axi_din                          ((fsm_state_ff == S_WRITEBACK) ? s2o_wb_payload : s2o_wdat),
         .i_axi_we                           ((fsm_state_ff == S_WRITEBACK) | (fsm_state_ff == S_UNCACHED_WRITE)),
         .i_axi_addr                         ((fsm_state_ff == S_WRITEBACK) ? fsm_refill_cnt : dbus_AWADDR[CONFIG_DC_P_LINE-1:0]),
         .o_axi_WSTRB                        (dbus_WSTRB),
         .o_axi_WDATA                        (dbus_WDATA)
      );

   // Look ahead one address, since payload RAM takes 1 cycle to output the result
   assign s2i_wb_re = (wvalid_set | hds_axi_W);

   assign wvalid_set = (aw_set);
   assign wvalid_clr = (hds_axi_W_last);
   mDFF_lr #(.DW(1)) ff_dbus_WVALID (.CLK(clk), .RST(rst), .LOAD(wvalid_set|wvalid_clr), .D(wvalid_set|~wvalid_clr), .Q(dbus_WVALID) );

   assign wlast_set = ((fsm_state_ff==S_WRITEBACK) & (s2i_wb_re & fsm_refill_cnt_nxt_carry[CONFIG_DC_P_LINE])) |
                        (fsm_uncached_req);
   assign wlast_clr = (wvalid_clr);
   mDFF_lr #(.DW(1)) ff_dbus_WLAST (.CLK(clk), .RST(rst), .LOAD(wlast_set|wlast_clr), .D(wlast_set|~wlast_clr), .Q(dbus_WLAST) );

   assign hds_axi_W = (dbus_WVALID & dbus_WREADY);
   assign hds_axi_W_last = (hds_axi_W & dbus_WLAST);

   // AXI - B
   assign dbus_BREADY = (fsm_state_ff == S_WRITEBACK);
   assign hds_axi_B = (dbus_BREADY & dbus_BVALID);

   // DCID Register
   assign msr_dcid[3:0] = CONFIG_DC_P_SETS[3:0];
   assign msr_dcid[7:4] = CONFIG_DC_P_LINE[3:0];
   assign msr_dcid[11:8] = CONFIG_DC_P_WAYS[3:0];
   assign msr_dcid[31:12] = 20'b0;

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
