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
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input [CONFIG_P_COMMIT_WIDTH:0]     push_size,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_pc,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_prd_we,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] push_pfree,
   input [CONFIG_P_COMMIT_WIDTH:0]     cmt_pop_size,
   // From WB
   input [(1<<CONFIG_P_COMMIT_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] wb_rob_id,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] wb_rob_bank,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] wb_rob_comp,
   // To issue
   output                              rob_ready,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank, 
   // To CMT
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_valid,
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_epu_opc_bus,
   output [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_bru_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_lsu_opc_bus,
   output [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_pc,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_pfree
);

   localparam FW                       = (1<<CONFIG_P_FETCH_WIDTH);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam FIFO_DW                  = (`NCPU_EPU_IOPW +
                                          `NCPU_BRU_IOPW +
                                          `NCPU_LSU_IOPW +
                                          `BPU_UPD_W +
                                          `PC_W +
                                          `NCPU_PRF_AW +
                                          1 +
                                          `NCPU_PRF_AW);
   localparam P_BANKS                  = (CONFIG_P_COMMIT_WIDTH);
   localparam BANKS                    = (1<<P_BANKS);

   wire [P_BANKS-1:0]                  head_ff, tail_ff;
   wire [P_BANKS-1:0]                  head_nxt, tail_nxt;
   wire [P_BANKS-1:0]                  head_l                        [FW-1:0];
   wire [P_BANKS-1:0]                  head_r                        [FW-1:0];
   wire [P_BANKS-1:0]                  tail_l                        [FW-1:0];
   wire [P_BANKS-1:0]                  tail_r                        [FW-1:0];
   wire [FIFO_DW-1:0]                  que_din_mux                   [BANKS-1:0];
   wire [FIFO_DW-1:0]                  que_din                       [BANKS-1:0];
   wire [FIFO_DW-1:0]                  que_dout                      [BANKS-1:0];
   wire                                que_valid                     [BANKS-1:0];
   wire [BANKS-1:0]                    que_ready;
   wire                                que_push                      [BANKS-1:0];
   wire                                que_pop                       [BANKS-1:0];
   wire [P_BANKS:0]                    pop_cnt_adapt;
   wire [DEPTH_WIDTH-1:0]              payload_waddr                 [BANKS-1:0];
   genvar i;

   generate
      for(i=0;i<BANKS;i=i+1)
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
   generate
      for(i=0;i<BANKS;i=i+1)
         begin : gen_bank_ctrl
            assign que_din_mux[i] = {push_epu_opc_bus[i * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW],
                                       push_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW],
                                       push_lsu_opc_bus[i * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW],
                                       push_bpu_upd[i * `BPU_UPD_W +: `BPU_UPD_W],
                                       push_pc[i * `PC_W +: `PC_W],
                                       push_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                                       push_prd_we[i],
                                       push_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]};
            assign que_din[i] = que_din_mux[tail_r[i]];
            assign que_pop[i]  = ({1'b0, head_r[i]} < pop_cnt_adapt);
            assign que_push[i] = ({1'b0, tail_r[i]} < push_size);
         end
   endgenerate
   
   assign head_nxt = (head_ff + pop_cnt_adapt[P_BANKS-1:0]) & {P_BANKS{~flush}};
   assign tail_nxt = (tail_ff + push_size[P_BANKS-1:0]) & {P_BANKS{~flush}};
   
   mDFF_r #(.DW(P_BANKS)) ff_head (.CLK(clk), .RST(rst), .D(head_nxt), .Q(head_ff) );
   mDFF_r #(.DW(P_BANKS)) ff_tail (.CLK(clk), .RST(rst), .D(tail_nxt), .Q(tail_ff) );
   
   generate
      for(i=0;i<BANKS;i=i+1)
         begin : gen_BANKS
            wire                       payload_re;
            wire [DEPTH_WIDTH-1:0]     payload_raddr;
            wire [FIFO_DW-1:0]         payload_rdata;
            wire                       payload_we;
            wire [FIFO_DW-1:0]         payload_wdata;
            
            fifo_fwft_ctrl
               #(
                  .DW            (FIFO_DW),
                  .DEPTH_WIDTH   (CONFIG_P_ROB_DEPTH)
               )
            U_FIFO
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
                  .payload_re    (payload_re),
                  .payload_raddr (payload_raddr),
                  .payload_rdata (payload_rdata),
                  .payload_we    (payload_we),
                  .payload_waddr (payload_waddr),
                  .payload_wdata (payload_wdata)
               );
            
            
         end
   endgenerate
   
   generate
      for(i=0;i<BANKS;i=i+1)
         begin : gen_rob_free
            assign rob_free_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH] = payload_waddr[tail_l[i]];
            assign rob_free_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH] = tail_l[i];
         end
   endgenerate
   
   // MUX for data output
   generate
      for(i=0;i<(1<<CONFIG_P_ISSUE_WIDTH);i=i+1)
         begin : gen_pop
            assign {cmt_epu_opc_bus[i * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW],
                     cmt_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW],
                     cmt_lsu_opc_bus[i * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW],
                     cmt_bpu_upd[i * `BPU_UPD_W +: `BPU_UPD_W],
                     cmt_pc[i * `PC_W +: `PC_W],
                     cmt_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW],
                     cmt_prd_we[i],
                     cmt_pfree[i * `NCPU_PRF_AW +: `NCPU_PRF_AW] } = que_dout[head_l[i]];
            assign cmt_valid[i] = que_valid[head_l[i]];
         end
   endgenerate
   
   assign ready = &que_ready;

endmodule
