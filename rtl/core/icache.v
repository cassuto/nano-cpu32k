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

module icache
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_FETCH_WIDTH = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_IC_P_LINE = 0,
   parameter                           CONFIG_IC_P_SETS = 0,
   parameter                           CONFIG_IC_P_WAYS = 0,
   parameter                           AXI_P_DW_BYTES  = 3,
   parameter                           AXI_UNCACHED_P_DW_BYTES = 2,
   parameter                           AXI_ADDR_WIDTH    = 64,
   parameter                           AXI_ID_WIDTH      = 4,
   parameter                           AXI_USER_WIDTH    = 1
)
(
   input                               clk,
   input                               rst,
   input                               p_ce,
   output                              stall_req,
   input [CONFIG_P_PAGE_SIZE-1:0]      vpo,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn_s2,
   input                               uncached_s2,
   input                               kill_req_s2,
   output [`NCPU_INSN_DW * (1<<CONFIG_P_FETCH_WIDTH)-1:0] ins,
   output                              valid,
   // ICID
   output [CONFIG_DW-1:0]              msr_icid,
   // ICINV
   input [CONFIG_DW-1:0]               msr_icinv_nxt,
   input                               msr_icinv_we,
   output                              msr_icinv_ready,

   // AXI Master (Inst Bus)
   input                               ibus_ARREADY,
   output                              ibus_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         ibus_ARADDR,
   output [2:0]                        ibus_ARPROT,
   output [AXI_ID_WIDTH-1:0]           ibus_ARID,
   output [AXI_USER_WIDTH-1:0]         ibus_ARUSER,
   output [7:0]                        ibus_ARLEN,
   output [2:0]                        ibus_ARSIZE,
   output [1:0]                        ibus_ARBURST,
   output                              ibus_ARLOCK,
   output [3:0]                        ibus_ARCACHE,
   output [3:0]                        ibus_ARQOS,
   output [3:0]                        ibus_ARREGION,
   output                              ibus_RREADY,
   input                               ibus_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  ibus_RDATA,
   input                               ibus_RLAST,
/* verilator lint_off UNUSED */
   input  [1:0]                        ibus_RRESP, // unused
   input  [AXI_ID_WIDTH-1:0]           ibus_RID, // unused
   input  [AXI_USER_WIDTH-1:0]         ibus_RUSER // unused
/* verilator lint_on UNUSED */
);

   localparam TAG_WIDTH                = (CONFIG_AW - CONFIG_IC_P_SETS - CONFIG_IC_P_LINE);
   localparam TAG_V_RAM_AW             = (CONFIG_IC_P_SETS);
   localparam TAG_V_RAM_DW             = (TAG_WIDTH + 1); // TAG + V
   localparam PAYLOAD_DW               = (`NCPU_INSN_DW * (1<<CONFIG_P_FETCH_WIDTH));
   localparam PAYLOAD_P_DW_BYTES       = (`NCPU_P_INSN_LEN + CONFIG_P_FETCH_WIDTH); // = $clog2(PAYLOAD_DW/8)
   localparam PAYLOAD_AW               = (CONFIG_IC_P_SETS + CONFIG_IC_P_LINE - PAYLOAD_P_DW_BYTES);
   localparam AXI_FETCH_SIZE           = (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES) ? PAYLOAD_P_DW_BYTES : AXI_P_DW_BYTES;
   localparam AXI_UNCACHED_DW          = (1<<AXI_UNCACHED_P_DW_BYTES)*8;

   // Stage 1 Input
   reg [CONFIG_IC_P_SETS-1:0]          s1i_line_addr;
   reg [TAG_V_RAM_DW-1:0]              s1i_replace_tag_v;
   wire                                s1i_tag_v_re;
   wire                                s1i_tag_v_we            [(1<<CONFIG_IC_P_WAYS)-1:0];
   wire                                s1i_payload_re;
   reg [PAYLOAD_AW-1:0]                s1i_payload_addr;
   wire [PAYLOAD_DW/8-1:0]             s1i_payload_we          [(1<<CONFIG_IC_P_WAYS)-1:0];
   wire [PAYLOAD_DW-1:0]               s1i_payload_din;
   wire [AXI_UNCACHED_DW/8-1:0]        s1i_uncached_align_we;
   wire [AXI_UNCACHED_DW-1:0]          s1i_uncached_align_din;
   wire [PAYLOAD_DW/8-1:0]             s1i_uncached_we;
   wire [PAYLOAD_DW-1:0]               s1i_uncached_din;
   wire [PAYLOAD_DW/8-1:0]             s1i_payload_tgt_we;
   // Stage 1 Output / Stage 2 Input
   wire [CONFIG_IC_P_SETS-1:0]         s1o_line_addr;
   wire [PAYLOAD_AW-1:0]               s1o_payload_addr;
   wire                                s1o_valid;
   wire [PAYLOAD_DW*(1<<CONFIG_IC_P_WAYS)-1:0] s1o_payload;
   wire [PAYLOAD_DW-1:0]               s1o_match_payload;
   wire [TAG_V_RAM_DW-1:0]             s1o_tag_v               [(1<<CONFIG_IC_P_WAYS)-1:0];
   wire [CONFIG_P_PAGE_SIZE-1:0]       s1o_vpo;
   wire [CONFIG_AW-1:0]                s2i_paddr;
   wire [TAG_WIDTH-1:0]                s2i_tag                 [(1<<CONFIG_IC_P_WAYS)-1:0];
   wire                                s2i_v                   [(1<<CONFIG_IC_P_WAYS)-1:0];
   wire [(1<<CONFIG_IC_P_WAYS)-1:0]    s2i_hit_vec;
   wire                                s2i_hit;
   wire                                s2i_refill_get_dat;
   wire                                s2i_uncached_get_dat;
   reg [PAYLOAD_DW-1:0]                s2i_ins;
   wire [CONFIG_AW-1:0]                s1o_op_inv_paddr;
   wire                                s2i_uncached_inflight;
   wire                                s2i_miss_inflight;
   // Stage 2 Output / Stage 3 Input
   wire [CONFIG_IC_P_SETS-1:0]         s2o_line_addr;
   wire                                s2o_valid;
   wire [CONFIG_AW-1:0]                s2o_paddr;
   wire [(1<<CONFIG_IC_P_WAYS)-1:0]    s2o_fsm_free_way;
   wire                                s2o_uncached_inflight;
   wire                                s2o_miss_inflight;
   // FSM
   reg [2:0]                           fsm_state_nxt;
   wire [2:0]                          fsm_state_ff;
   wire [(1<<CONFIG_IC_P_WAYS)-1:0]    fsm_free_way, fsm_free_way_nxt;
   wire [CONFIG_IC_P_SETS-1:0]         fsm_boot_cnt;
   wire [CONFIG_IC_P_SETS:0]           fsm_boot_cnt_nxt_carry;
   wire [CONFIG_IC_P_LINE-1:0]         fsm_refill_cnt;
   reg [CONFIG_IC_P_LINE-1:0]          fsm_refill_cnt_nxt;
   wire [PAYLOAD_P_DW_BYTES-1:0]       fsm_uncached_cnt;
   reg [PAYLOAD_P_DW_BYTES-1:0]        fsm_uncached_cnt_nxt;
   wire [PAYLOAD_P_DW_BYTES:0]         fsm_uncached_cnt_nxt_carry;
   reg                                 fsm_uncached_rd_req;
   wire                                fsm_idle;
   // AXI
   wire                                ar_set, ar_clr;
   wire                                hds_axi_R;
   wire                                hds_axi_R_last;
   wire [CONFIG_AW-1:0]                axi_paddr_nxt;
   wire [AXI_ADDR_WIDTH-1:0]           axi_ar_addr_nxt;

   localparam [2:0] S_BOOT             = 3'd0;
   localparam [2:0] S_IDLE             = 3'd1;
   localparam [2:0] S_REPLACE          = 3'd2;
   localparam [2:0] S_REFILL           = 3'd3;
   localparam [2:0] S_INVALIDATE       = 3'd4;
   localparam [2:0] S_RELOAD_S1O       = 3'd5;
   localparam [2:0] S_UNCACHED_BOOT    = 3'd6;
   localparam [2:0] S_UNCACHED_READ    = 3'd7;

   genvar way, j;

   assign s2i_paddr = {ppn_s2, s1o_vpo};

   generate for(way=0; way<(1<<CONFIG_IC_P_WAYS); way=way+1)
      begin : gen_ways
         mRAM_s_s_be
            #(
               .P_DW (PAYLOAD_P_DW_BYTES + 3),
               .AW   (PAYLOAD_AW)
            )
         U_PAYLOAD_RAM
            (
               .CLK  (clk),
               .RST  (rst),
               .ADDR (s1i_payload_addr),
               .RE   (s1i_payload_re),
               .DOUT (s1o_payload[way*PAYLOAD_DW +: PAYLOAD_DW]),
               .WE   (s1i_payload_we[way]),
               .DIN  (s1i_payload_din)
            );

         `mRF_1wr
            #(
               .DW   (TAG_V_RAM_DW),
               .AW   (TAG_V_RAM_AW)
            )
         U_TAG_V_RAM
            (
               .CLK  (clk),
               `rst
               .ADDR (s1i_line_addr),
               .RE   (s1i_tag_v_re),
               .RDATA (s1o_tag_v[way]),
               .WE   (s1i_tag_v_we[way]),
               .WDATA (s1i_replace_tag_v)
            );

         assign {s2i_tag[way], s2i_v[way]} = s1o_tag_v[way];

         assign s2i_hit_vec[way] = (s2i_v[way] & (s2i_tag[way] == s2i_paddr[CONFIG_AW-1:CONFIG_IC_P_LINE+CONFIG_IC_P_SETS]) );
      end
   endgenerate

   // Sel the dout of matched way
   pmux_v #(.SELW(1<<CONFIG_IC_P_WAYS), .DW(PAYLOAD_DW)) pmux_s1o_payload (.sel(s2i_hit_vec), .din(s1o_payload), .dout(s1o_match_payload), .valid(s2i_hit) );

   mDFF_lr # (.DW(1)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(1'b1), .Q(s1o_valid) );
   `mDFF_l # (.DW(CONFIG_P_PAGE_SIZE)) ff_s1o_vpo (.CLK(clk),`rst .LOAD(p_ce), .D(vpo), .Q(s1o_vpo) );
   `mDFF_l # (.DW(CONFIG_AW)) ff_s1o_op_inv_paddr (.CLK(clk),`rst .LOAD(fsm_idle), .D(msr_icinv_nxt), .Q(s1o_op_inv_paddr) );
   `mDFF_l # (.DW(CONFIG_IC_P_SETS)) ff_s1o_line_addr (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_line_addr), .Q(s1o_line_addr) );
   `mDFF_l # (.DW(PAYLOAD_AW)) ff_s1o_payload_addr (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_payload_addr), .Q(s1o_payload_addr) );
   `mDFF_l # (.DW(CONFIG_IC_P_SETS)) ff_s2o_line_addr (.CLK(clk),`rst .LOAD(p_ce), .D(s1o_line_addr), .Q(s2o_line_addr) );

   mDFF_lr # (.DW(1)) ff_s2o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_valid), .Q(s2o_valid) );
   `mDFF_l # (.DW(CONFIG_AW)) ff_s2o_paddr (.CLK(clk),`rst .LOAD(p_ce), .D(s2i_paddr), .Q(s2o_paddr) );
   mDFF_lr # (.DW(1)) ff_s2o_uncached_inflight (.CLK(clk), .RST(rst), .LOAD(fsm_idle), .D(s2i_uncached_inflight), .Q(s2o_uncached_inflight) );
   mDFF_lr # (.DW(1)) ff_s2o_miss_inflight (.CLK(clk), .RST(rst), .LOAD(fsm_idle), .D(s2i_miss_inflight), .Q(s2o_miss_inflight) );
   

   // Main FSM
   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         fsm_uncached_rd_req = 1'b0;
         case (fsm_state_ff)
            S_BOOT:
               if (fsm_boot_cnt_nxt_carry[CONFIG_IC_P_SETS])
                  fsm_state_nxt = S_IDLE;

            S_IDLE:
               if (msr_icinv_we) // Invalidate one cache line
                  fsm_state_nxt = S_INVALIDATE;
               else if (s2i_uncached_inflight) // Uncached access
                  fsm_state_nxt = S_UNCACHED_BOOT;
               else if (s2i_miss_inflight) // Miss
                  fsm_state_nxt = S_REPLACE;

            S_REPLACE:
               fsm_state_nxt = S_REFILL;

            S_REFILL:
               if (hds_axi_R_last)
                  fsm_state_nxt = S_RELOAD_S1O;

            S_INVALIDATE:
               // Reboot the blocked request
               fsm_state_nxt = (s2o_uncached_inflight)
                                 ? S_UNCACHED_BOOT
                                 : (s2o_miss_inflight)
                                    ? S_REPLACE
                                    : S_IDLE;

            S_RELOAD_S1O:
               fsm_state_nxt = S_IDLE;
               
            S_UNCACHED_BOOT:
               begin
                  fsm_state_nxt = S_UNCACHED_READ;
                  fsm_uncached_rd_req = 'b1;
               end
            S_UNCACHED_READ:
               if (fsm_uncached_cnt_nxt_carry[PAYLOAD_P_DW_BYTES] & hds_axi_R)
                  fsm_state_nxt = S_IDLE;
               else if (hds_axi_R)
                  fsm_uncached_rd_req = 'b1; // Start the next read transaction
            
            default:
               fsm_state_nxt = fsm_state_ff;
         endcase
      end
   
   assign s2i_uncached_inflight = (p_ce & s1o_valid & uncached_s2 & ~kill_req_s2);
   
   assign s2i_miss_inflight = (p_ce & s1o_valid & ~s2i_hit & ~uncached_s2 & ~kill_req_s2);

   mDFF_r # (.DW(3), .RST_VECTOR(S_BOOT)) ff_state_r (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff) );
   
   // Clock algorithm
   assign fsm_free_way_nxt = (fsm_free_way[(1<<CONFIG_IC_P_WAYS)-1])
                              ? {{(1<<CONFIG_IC_P_WAYS)-1{1'b0}}, 1'b1}
                              : {fsm_free_way[(1<<CONFIG_IC_P_WAYS)-2:0], 1'b0};
                              
   mDFF_r #(.DW(1<<CONFIG_IC_P_WAYS), .RST_VECTOR({{(1<<CONFIG_IC_P_WAYS)-1{1'b0}}, 1'b1}) ) ff_fsm_free_idx
      (.CLK(clk), .RST(rst), .D(fsm_free_way_nxt), .Q(fsm_free_way) );

   // Boot counter
   assign fsm_boot_cnt_nxt_carry = fsm_boot_cnt + {{CONFIG_IC_P_SETS-1{1'b0}}, 1'b1};

   mDFF_r # (.DW(CONFIG_IC_P_SETS)) ff_fsm_boot_cnt_nxt (.CLK(clk), .RST(rst), .D(fsm_boot_cnt_nxt_carry[CONFIG_IC_P_SETS-1:0]), .Q(fsm_boot_cnt) );

   localparam [CONFIG_IC_P_LINE-1:0] FSM_REFILL_CNT_DELTA = (1<<AXI_FETCH_SIZE);
   
   // Refill counter
   always @(*)
      if ((fsm_state_ff == S_REFILL) & hds_axi_R)
         fsm_refill_cnt_nxt = fsm_refill_cnt + FSM_REFILL_CNT_DELTA;
      else
         fsm_refill_cnt_nxt = fsm_refill_cnt;

   mDFF_r # (.DW(CONFIG_IC_P_LINE)) ff_fsm_refill_cnt (.CLK(clk), .RST(rst), .D(fsm_refill_cnt_nxt), .Q(fsm_refill_cnt) );

   // Uncached access counter
   always @(*)
      if ((fsm_state_ff == S_UNCACHED_READ) & hds_axi_R)
         fsm_uncached_cnt_nxt = fsm_uncached_cnt_nxt_carry[PAYLOAD_P_DW_BYTES-1:0];
      else
         fsm_uncached_cnt_nxt = fsm_uncached_cnt;
   
   localparam [PAYLOAD_P_DW_BYTES-1:0] FSM_UNCACHED_CNT_DELTA = (1<<AXI_UNCACHED_P_DW_BYTES);
   assign fsm_uncached_cnt_nxt_carry = fsm_uncached_cnt + FSM_UNCACHED_CNT_DELTA;
   
   mDFF_r # (.DW(PAYLOAD_P_DW_BYTES)) ff_fsm_uncached_cnt (.CLK(clk), .RST(rst), .D(fsm_uncached_cnt_nxt), .Q(fsm_uncached_cnt) );

   // MUX for tag RAM addr
   always @(*)
      case (fsm_state_ff)
         S_BOOT:
            s1i_line_addr = fsm_boot_cnt;
         S_INVALIDATE:
            s1i_line_addr = s1o_op_inv_paddr[CONFIG_IC_P_LINE +: CONFIG_IC_P_SETS];
         S_REPLACE:
            s1i_line_addr = s2o_line_addr;
         S_RELOAD_S1O:
            s1i_line_addr = s1o_line_addr;
         default:
            s1i_line_addr = vpo[CONFIG_IC_P_LINE +: CONFIG_IC_P_SETS]; // index
      endcase

   // MUX for tag RAM din
   always @(*)
      case (fsm_state_ff)
         S_REPLACE:
            s1i_replace_tag_v = {s2o_paddr[CONFIG_AW-1:CONFIG_IC_P_LINE+CONFIG_IC_P_SETS], 1'b1};
         default: // S_BOOT, S_INVALIDATE:
            s1i_replace_tag_v = {TAG_V_RAM_DW{1'b0}};
      endcase

   assign s1i_tag_v_re = (p_ce | (fsm_state_ff==S_RELOAD_S1O));

   // tag RAM write enable
   generate for(way=0; way<(1<<CONFIG_IC_P_WAYS); way=way+1)
      begin : gen_tag_v_we
         assign s1i_tag_v_we[way] = (fsm_state_ff==S_BOOT) |
                                    (fsm_state_ff==S_INVALIDATE) |
                                    ((fsm_state_ff==S_REPLACE) & (fsm_free_way[way]));
      end
   endgenerate
   
   `mDFF_l #(.DW(1<<CONFIG_IC_P_WAYS)) ff_s2o_fsm_free_way(.CLK(clk),`rst .LOAD(fsm_state_ff==S_REPLACE), .D(fsm_free_way), .Q(s2o_fsm_free_way));

   // MUX for payload RAM addr
   always @(*)
      case (fsm_state_ff)
         S_REFILL:
            s1i_payload_addr = {s2o_paddr[CONFIG_IC_P_LINE +: CONFIG_IC_P_SETS], fsm_refill_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_IC_P_LINE-PAYLOAD_P_DW_BYTES]};
         S_RELOAD_S1O:
            s1i_payload_addr = s1o_payload_addr;
         default:
            s1i_payload_addr = vpo[PAYLOAD_P_DW_BYTES +: PAYLOAD_AW]; // {index,offset}
      endcase

   assign s1i_payload_re = s1i_tag_v_re;

   // Aligner for payload RAM din
   align_r
      #(
         .IN_P_DW_BYTES                (AXI_P_DW_BYTES),
         .OUT_P_DW_BYTES               (PAYLOAD_P_DW_BYTES),
         .IN_AW                        (CONFIG_IC_P_LINE)
      )
   U_ALIGN_R
      (
         .i_dat                        (ibus_RDATA),
         .i_be                         ({(1<<AXI_P_DW_BYTES){fsm_state_ff == S_REFILL}}),
         .i_addr                       (fsm_refill_cnt),
         .o_be                         (s1i_payload_tgt_we),
         .o_dat                        (s1i_payload_din)
      );
      
   generate for(way=0; way<(1<<CONFIG_IC_P_WAYS); way=way+1)
      begin : gen_payload_we
         assign s1i_payload_we[way] = (s1i_payload_tgt_we & {PAYLOAD_DW/8{s2o_fsm_free_way[way]}});
      end
   endgenerate
   
   // Aligner for uncached din
   align_r
      #(
         .IN_P_DW_BYTES                (AXI_P_DW_BYTES),
         .OUT_P_DW_BYTES               (AXI_UNCACHED_P_DW_BYTES),
         .IN_AW                        (AXI_ADDR_WIDTH)
      )
   U_ALIGN_R_UNCACHED_A
      (
         .i_dat                        (ibus_RDATA),
         .i_be                         ({(1<<AXI_P_DW_BYTES){fsm_state_ff == S_UNCACHED_READ}}),
         .i_addr                       (ibus_ARADDR),
         .o_be                         (s1i_uncached_align_we),
         .o_dat                        (s1i_uncached_align_din)
      );
   align_r
      #(
         .IN_P_DW_BYTES                (AXI_UNCACHED_P_DW_BYTES),
         .OUT_P_DW_BYTES               (PAYLOAD_P_DW_BYTES),
         .IN_AW                        (AXI_ADDR_WIDTH)
      )
   U_ALIGN_R_UNCACHED_B
      (
         .i_dat                        (s1i_uncached_align_din),
         .i_be                         (s1i_uncached_align_we),
         .i_addr                       (ibus_ARADDR),
         .o_be                         (s1i_uncached_we),
         .o_dat                        (s1i_uncached_din)
      );

   assign fsm_idle = (fsm_state_ff == S_IDLE);
   assign stall_req = ~fsm_idle;

   assign msr_icinv_ready = (~fsm_idle); // Tell if I$ is temporarily unable to accept ICINV operation

   assign s2i_refill_get_dat = (s2o_paddr[PAYLOAD_P_DW_BYTES +: CONFIG_IC_P_LINE-PAYLOAD_P_DW_BYTES] ==
                                 fsm_refill_cnt[PAYLOAD_P_DW_BYTES +: CONFIG_IC_P_LINE-PAYLOAD_P_DW_BYTES]);
   
   assign s2i_uncached_get_dat = (s2o_paddr[PAYLOAD_P_DW_BYTES +: CONFIG_IC_P_LINE-PAYLOAD_P_DW_BYTES] ==
                                 ibus_ARADDR[PAYLOAD_P_DW_BYTES +: CONFIG_IC_P_LINE-PAYLOAD_P_DW_BYTES]);

   // Output
   generate for(j=0;j<PAYLOAD_DW/8;j=j+1)
      begin : gen_output_inner
         always @(*)
            case (fsm_state_ff)
               S_REFILL:
                  if (s2i_refill_get_dat & s1i_payload_tgt_we[j])
                     s2i_ins[j*8 +: 8] = s1i_payload_din[j*8 +: 8]; // Get data from AXI bus
                  else
                     s2i_ins[j*8 +: 8] = ins[j*8 +: 8];
               
               S_UNCACHED_READ:
                  if (s2i_uncached_get_dat & s1i_uncached_we[j])
                     s2i_ins[j*8 +: 8] = s1i_uncached_din[j*8 +: 8]; // Get data from AXI bus, but not write to any payload RAM
                  else
                     s2i_ins[j*8 +: 8] = ins[j*8 +: 8];
                     
               default:
                  s2i_ins[j*8 +: 8] = s1o_match_payload[j*8 +: 8]; // From the matched way
            endcase
      end
   endgenerate

   // Control path
   mDFF_lr # (.DW(PAYLOAD_DW)) ff_ins (.CLK(clk), .RST(rst), .LOAD(p_ce|(fsm_state_ff==S_REFILL)|(fsm_state_ff==S_UNCACHED_READ)), .D(s2i_ins & {PAYLOAD_DW{p_ce & ~kill_req_s2}}), .Q(ins) );

   assign valid = s2o_valid;

   // AXI - AR
   assign ibus_ARPROT = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign ibus_ARID = {AXI_ID_WIDTH{1'b0}};
   assign ibus_ARUSER = {AXI_USER_WIDTH{1'b0}};
   localparam [7:0] ARLEN_S_REFILL = ((1<<(CONFIG_IC_P_LINE-AXI_FETCH_SIZE))-1);
   assign ibus_ARLEN = (fsm_state_ff==S_REFILL) ? ARLEN_S_REFILL : 8'b0;
   assign ibus_ARSIZE = (fsm_state_ff==S_REFILL) ? AXI_FETCH_SIZE[2:0] : AXI_UNCACHED_P_DW_BYTES[2:0];
   assign ibus_ARBURST = `AXI_BURST_TYPE_INCR;
   assign ibus_ARLOCK = 1'b0;
   assign ibus_ARCACHE = `AXI_ARCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign ibus_ARQOS = 4'b0;
   assign ibus_ARREGION = 4'b0;
   assign ar_set = ((fsm_state_ff==S_REPLACE) | fsm_uncached_rd_req);
   assign ar_clr = (ibus_ARREADY & ibus_ARVALID);
   
   assign axi_paddr_nxt = (fsm_uncached_rd_req)
                           ? {s2o_paddr[PAYLOAD_P_DW_BYTES +: CONFIG_AW - PAYLOAD_P_DW_BYTES], fsm_uncached_cnt_nxt}
                           : {s2o_paddr[CONFIG_IC_P_LINE +: CONFIG_AW - CONFIG_IC_P_LINE], {CONFIG_IC_P_LINE{1'b0}}};

   // Address width adapter (truncate or fill zero)
   generate
      if (AXI_ADDR_WIDTH > CONFIG_AW)
         assign axi_ar_addr_nxt = {{AXI_ADDR_WIDTH-CONFIG_AW{1'b0}}, axi_paddr_nxt};
      else if (AXI_ADDR_WIDTH < CONFIG_AW)
         assign axi_ar_addr_nxt = axi_paddr_nxt[AXI_ADDR_WIDTH-1:0];
      else
         assign axi_ar_addr_nxt = axi_paddr_nxt;
   endgenerate

   mDFF_lr # (.DW(1)) ff_axi_ar_valid (.CLK(clk), .RST(rst), .LOAD(ar_set|ar_clr), .D(ar_set|~ar_clr), .Q(ibus_ARVALID) );
   mDFF_lr # (.DW(AXI_ADDR_WIDTH)) ff_axi_ar_addr (.CLK(clk), .RST(rst), .LOAD(ar_set), .D(axi_ar_addr_nxt), .Q(ibus_ARADDR) );


   // AXI - R
   assign ibus_RREADY = (fsm_state_ff == S_REFILL) | (fsm_state_ff == S_UNCACHED_READ);
   assign hds_axi_R = (ibus_RVALID & ibus_RREADY);
   assign hds_axi_R_last = (hds_axi_R & ibus_RLAST);

   // ICID Register
   assign msr_icid[3:0] = CONFIG_IC_P_SETS[3:0];
   assign msr_icid[7:4] = CONFIG_IC_P_LINE[3:0];
   assign msr_icid[11:8] = CONFIG_IC_P_WAYS[3:0];
   assign msr_icid[31:12] = 20'b0;

   // synthesis translate_off
`ifndef SYNTHESIS
`ifdef NCPU_ENABLE_ASSERT

   initial
      begin
         if (CONFIG_P_PAGE_SIZE < CONFIG_IC_P_LINE + CONFIG_IC_P_SETS)
            $fatal(1, "Invalid size of icache (Must <= page size of MMU)");
         if (CONFIG_IC_P_LINE < PAYLOAD_P_DW_BYTES)
            $fatal(1, "Line size of icache is too small to accommodate with a fetching window");
         if (((1<<(CONFIG_IC_P_LINE-AXI_FETCH_SIZE))-1) >= (1<<8))
            $fatal(1, "Line size of icache exceeds AXI4 burst length limit");
      end

`endif
`endif
   // synthesis translate_on

endmodule
