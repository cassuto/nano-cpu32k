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

module rob
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_WRITEBACK_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   // From issue
   input [CONFIG_P_ISSUE_WIDTH:0]     rob_push_size,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_epu_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pc,
   input [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_lrd,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_prd_we,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pfree,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_bcc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_brel,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_breg,
   // To issue
   output                              rob_ready,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank, 
   // From WB
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_valid,
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] wb_rob_id,
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] wb_rob_bank,
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_fls,
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_exc,
   input [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_opera,
   input [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_operb,
   input [`PC_W*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_fls_tgt,
   // To WB
   output [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_rob_ready,
   // To CMT
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_valid,
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_epu_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lsu_opc_bus,
   output [`BPU_UPD_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pc,
   output [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lrd,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd,
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_bcc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_brel,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_breg,
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls,
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_exc,
   output [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_opera,
   output [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_operb,
   output [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls_tgt,
   // From CMT
   input [CONFIG_P_COMMIT_WIDTH:0]     cmt_pop_size
);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   localparam WW                       = (1<<CONFIG_P_WRITEBACK_WIDTH);
   localparam ROB_DEPTH                = (1<<CONFIG_P_ROB_DEPTH);
   localparam uBANK_DW                 = (`NCPU_EPU_IOPW +
                                          `NCPU_LSU_IOPW +
                                          `BPU_UPD_W +
                                          `PC_W +
                                          `NCPU_LRF_AW +
                                          `NCPU_PRF_AW +
                                          1 +
                                          `NCPU_PRF_AW +
                                          1 +
                                          1 +
                                          1);
   localparam P_BANKS                  = (CONFIG_P_COMMIT_WIDTH);
   localparam BANKS                    = (1<<P_BANKS);
   localparam vBANK_DW                 = (CONFIG_DW +
                                          CONFIG_DW +
                                          `PC_W);
   wire [P_BANKS-1:0]                  head_ff, tail_ff;
   wire [P_BANKS-1:0]                  head_nxt, tail_nxt;
   wire [P_BANKS-1:0]                  head_l                        [CW-1:0];
   wire [P_BANKS-1:0]                  head_r                        [CW-1:0];
   wire [P_BANKS-1:0]                  tail_l                        [CW-1:0];
   wire [P_BANKS-1:0]                  tail_r                        [CW-1:0];
   wire [uBANK_DW-1:0]                 que_din_mux                   [BANKS-1:0];
   wire [uBANK_DW-1:0]                 que_din                       [BANKS-1:0];
   wire [uBANK_DW-1:0]                 que_dout                      [BANKS-1:0];
   wire                                que_valid                     [BANKS-1:0];
   wire [BANKS-1:0]                    que_ready;
   wire                                que_push                      [BANKS-1:0];
   wire                                que_pop                       [BANKS-1:0];
   reg                                 que_wb                        [BANKS-1:0];
   reg [CONFIG_P_ROB_DEPTH-1:0]        que_wb_id                     [BANKS-1:0];
   reg                                 que_wb_fls                    [BANKS-1:0];
   reg                                 que_wb_exc                    [BANKS-1:0];
   reg [vBANK_DW-1:0]                  que_wb_vbank                  [BANKS-1:0];
   wire [P_BANKS:0]                    pop_cnt_adapt;
   wire [CONFIG_P_ROB_DEPTH-1:0]       que_rptr                      [BANKS-1:0];
   wire [CONFIG_P_ROB_DEPTH-1:0]       que_wptr                      [BANKS-1:0];
   wire                                que_rdy                       [BANKS-1:0];
   wire                                que_fls                       [BANKS-1:0];
   wire                                que_exc                       [BANKS-1:0];
   wire [vBANK_DW-1:0]                 que_vbank                     [BANKS-1:0];
   wire [CW-1:0]                       ent_valid;
   reg [CW-1:0]                        cmt_valid_;
   reg [WW-1:0]                        wb_ready;
   genvar i, k;
   integer j;

   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_ptr
         assign head_l[i]  = i + head_ff;
         assign head_r[i]  = i - head_ff;
         assign tail_l[i] = i + tail_ff;
         assign tail_r[i] = i - tail_ff;
      end
   endgenerate
   
   // Width adapter
   generate
      if (P_BANKS == CONFIG_P_ISSUE_WIDTH)
         assign pop_cnt_adapt = cmt_pop_size;
      else
         assign pop_cnt_adapt = {{P_BANKS-CONFIG_P_ISSUE_WIDTH{1'b0}}, cmt_pop_size};
   endgenerate
   
   // MUX for FIFO input
   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_bank_ctrl
         assign que_din_mux[i] = {rob_push_epu_opc_bus[i * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW],
                                    rob_push_lsu_opc_bus[i * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW],
                                    rob_push_bpu_upd[i * `BPU_UPD_W +: `BPU_UPD_W],
                                    rob_push_pc[i * `PC_W +: `PC_W],
                                    rob_push_lrd[i * `NCPU_LRF_AW +: `NCPU_LRF_AW],
                                    rob_push_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                                    rob_push_prd_we[i],
                                    rob_push_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                                    rob_push_is_bcc[i],
                                    rob_push_is_brel[i],
                                    rob_push_is_breg[i]};
         assign que_din[i] = que_din_mux[tail_r[i]];
         assign que_pop[i]  = ({1'b0, head_r[i]} < pop_cnt_adapt);
         assign que_push[i] = ({1'b0, tail_r[i]} < rob_push_size);
      end
   endgenerate
   
   assign head_nxt = (head_ff + pop_cnt_adapt[P_BANKS-1:0]) & {P_BANKS{~flush}};
   assign tail_nxt = (tail_ff + rob_push_size[P_BANKS-1:0]) & {P_BANKS{~flush}};
   
   mDFF_r #(.DW(P_BANKS)) ff_head (.CLK(clk), .RST(rst), .D(head_nxt), .Q(head_ff) );
   mDFF_r #(.DW(P_BANKS)) ff_tail (.CLK(clk), .RST(rst), .D(tail_nxt), .Q(tail_ff) );
   
   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_BANKS
         wire                       payload_re;
         wire [CONFIG_P_ROB_DEPTH-1:0] payload_raddr;
         wire [CONFIG_P_ROB_DEPTH-1:0] payload_waddr;
         wire [uBANK_DW-1:0]        payload_rdata;
         wire                       payload_we;
         wire [uBANK_DW-1:0]        payload_wdata;
         
         wire [ROB_DEPTH-1:0]       tag_rdy;
         wire [ROB_DEPTH-1:0]       tag_fls;
         wire [ROB_DEPTH-1:0]       tag_exc;
         wire [vBANK_DW*ROB_DEPTH-1:0] tag_vbank;
         wire [vBANK_DW-1:0]        tag_vbank_mux [ROB_DEPTH-1:0];
         
         fifo_fwft_ctrl_rp_wp
            #(
               .DW            (uBANK_DW),
               .DEPTH_WIDTH   (CONFIG_P_ROB_DEPTH)
            )
         U_FIFO_CTRL
            (
               .clk           (clk),
               .rst           (rst),
               .flush         (flush),
               .push          (que_push[i]),
               .din           (que_din[i]),
               .ready         (que_ready[i]),
               .pop           (que_pop[i]),
               .dout          (que_dout[i]),
               .valid         (que_valid[i]),
               .rptr          (que_rptr[i]),
               .wptr          (que_wptr[i]),
               .payload_re    (payload_re),
               .payload_raddr (payload_raddr),
               .payload_rdata (payload_rdata),
               .payload_we    (payload_we),
               .payload_waddr (payload_waddr),
               .payload_wdata (payload_wdata)
            );
            
         `mRF_nwnr
            #(
               .DW (uBANK_DW),
               .AW (CONFIG_P_ROB_DEPTH),
               .NUM_READ   (1),
               .NUM_WRITE  (1)
            )
         U_uBANK
            (
               .CLK     (clk),
               `rst
               .RE      (payload_re),
               .RADDR   (payload_raddr),
               .RDATA   (payload_rdata),
               .WE      (payload_we),
               .WADDR   (payload_waddr),
               .WDATA   (payload_wdata)
            );
            
         mRF_nw_do_r
            #(
               .DW (1),
               .AW (CONFIG_P_ROB_DEPTH),
               .RST_VECTOR ('b0),
               .NUM_WRITE (2)
            )
         U_TAG_RDY
            (
               .CLK  (clk),
               .RST  (rst),
               .WE   ({que_wb[i], que_push[i]}),
               .WADDR ({que_wb_id[i], payload_waddr}),
               .WDATA ({1'b1, 1'b0}),
               .DO   (tag_rdy)
            );
            
         mRF_nw_do_r
            #(
               .DW (1),
               .AW (CONFIG_P_ROB_DEPTH),
               .RST_VECTOR ('b0),
               .NUM_WRITE (2)
            )
         U_TAG_FLS
            (
               .CLK  (clk),
               .RST  (rst),
               .WE   ({que_wb[i], que_push[i]}),
               .WADDR ({que_wb_id[i], payload_waddr}),
               .WDATA ({que_wb_fls[i], 1'b0}),
               .DO   (tag_fls)
            );
   
         mRF_nw_do_r
            #(
               .DW (1),
               .AW (CONFIG_P_ROB_DEPTH),
               .RST_VECTOR ('b0),
               .NUM_WRITE (2)
            )
         U_TAG_EXC
            (
               .CLK  (clk),
               .RST  (rst),
               .WE   ({que_wb[i], que_push[i]}),
               .WADDR ({que_wb_id[i], payload_waddr}),
               .WDATA ({que_wb_exc[i], 1'b0}),
               .DO   (tag_exc)
            );
         
         `mRF_nw_do
            #(
               .DW (vBANK_DW),
               .AW (CONFIG_P_ROB_DEPTH),
               .NUM_WRITE (1)
            )
         U_vBANK
            (
               .CLK  (clk),
               `rst
               .WE   (que_wb[i]),
               .WADDR (que_wb_id[i]),
               .WDATA (que_wb_vbank[i]),
               .DO   (tag_vbank)
            );
           
         // Address decoder
         assign que_rdy[i] = tag_rdy[que_rptr[i]];
         assign que_fls[i] = tag_fls[que_rptr[i]];
         assign que_exc[i] = tag_exc[que_rptr[i]];
         
         for(k=0;k<ROB_DEPTH;k=k+1)
            begin : gen_tag_vbank_mux
               assign tag_vbank_mux[k] = tag_vbank[k * vBANK_DW +: vBANK_DW];
            end
         
         assign que_vbank[i] = tag_vbank_mux[que_rptr[i]];
      end
   endgenerate
   
   // wb signal for each bank
   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_que_wb
         always @(*)
            begin
               que_wb[i] = 'b0;
               for(j=0;j<CW;j=j+1)
                  que_wb[i] = que_wb[i] | (wb_valid[j]&wb_ready[j] & (i==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]));
            end
      end
   endgenerate
   
   // MUX for each bank
   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_que_wb_din
         always @(*)
            begin : gen_wb_id_mux
               que_wb_id[i] = 'b0;
               que_wb_fls[i] = 'b0;
               que_wb_exc[i] = 'b0;
               que_wb_vbank[i] = 'b0;
               for(j=0;j<WW;j=j+1)
                  begin
                     que_wb_id[i] = que_wb_id[i] |
                                       ({CONFIG_P_ROB_DEPTH{wb_valid[j]&wb_ready[j] & (i==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH])}} &
                                       wb_rob_id[j*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]);
                     que_wb_fls[i] = que_wb_fls[i] |
                                       (wb_valid[j]&wb_ready[j] & (i==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]) &
                                       wb_fls[j]);
                     que_wb_exc[i] = que_wb_exc[i] |
                                       (wb_valid[j]&wb_ready[j] & (i==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]) &
                                       wb_exc[j]);
                     que_wb_vbank[i] = que_wb_vbank[i] |
                                       ({vBANK_DW{wb_valid[j]&wb_ready[j] & (i==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH])}} &
                                       {wb_fls_tgt[j*`PC_W +: `PC_W], wb_operb[j*CONFIG_DW +: CONFIG_DW], wb_opera[j*CONFIG_DW +: CONFIG_DW]});
                  end
            end
      end
   endgenerate
   
   // Conflict detection
   // Not allowed to write to a bank at the same time.
   generate for(i=0;i<WW;i=i+1)
      begin : gen_conflict_dec
         always @(*)
            begin
               wb_ready[i] = 'b1;
               for(j=0;j<i;j=j+1)
                  wb_ready[i] = wb_ready[i] & ~(wb_valid[j] &
                     (wb_rob_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]==wb_rob_bank[j*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]));
            end
      end
   endgenerate
   assign wb_rob_ready = wb_ready;
   
   // Output the address of free bank
   generate for(i=0;i<BANKS;i=i+1)
      begin : gen_rob_free
         assign rob_free_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH] = que_wptr[tail_l[i]];
         assign rob_free_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH] = tail_l[i];
      end
   endgenerate
   
   // MUX for data output
   generate for(i=0;i<CW;i=i+1)
      begin : gen_pop
         assign {cmt_epu_opc_bus[i * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW],
                  cmt_lsu_opc_bus[i * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW],
                  cmt_bpu_upd[i * `BPU_UPD_W +: `BPU_UPD_W],
                  cmt_pc[i * `PC_W +: `PC_W],
                  cmt_lrd[i * `NCPU_LRF_AW +: `NCPU_LRF_AW],
                  cmt_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                  cmt_prd_we[i],
                  cmt_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                  cmt_is_bcc[i],
                  cmt_is_brel[i],
                  cmt_is_breg[i] } = que_dout[head_l[i]];
         assign cmt_fls[i] = que_fls[head_l[i]];
         assign cmt_exc[i] = que_exc[head_l[i]];
         assign {cmt_fls_tgt[i*`PC_W +: `PC_W],
                  cmt_operb[i*CONFIG_DW +: CONFIG_DW],
                  cmt_opera[i*CONFIG_DW +: CONFIG_DW]} = que_vbank[head_l[i]];
         assign ent_valid[i] = (que_valid[head_l[i]] & que_rdy[head_l[i]]);
      end
   endgenerate
   
   // Ensure in-order commit
   always @(*)
      begin
         cmt_valid_[0] = ent_valid[0];
         for(j=1;j<CW;j=j+1)
            cmt_valid_[j] = cmt_valid_[j-1] & ent_valid[j];
      end
   assign cmt_valid = cmt_valid_;
   
   assign rob_ready = &que_ready;
   
endmodule
