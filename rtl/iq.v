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

module iq
#(
   parameter CONFIG_AW = 32,
   parameter CONFIG_P_FETCH_WIDTH = 2,
   parameter CONFIG_P_ISSUE_WIDTH = 2,
   parameter CONFIG_P_IQ_DEPTH = 4, // Depth per fetch channel
   parameter CONFIG_PHT_P_NUM = 0,
   parameter CONFIG_BTB_P_NUM = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input [`NCPU_INSN_DW * (1<<CONFIG_P_FETCH_WIDTH)-1:0] iq_ins,
   input [CONFIG_AW * (1<<CONFIG_P_FETCH_WIDTH)-1:0] iq_pc,
   input [`FNT_EXC_W * (1<<CONFIG_P_FETCH_WIDTH)-1:0] iq_exc,
   input [`BPU_UPD_W * (1<<CONFIG_P_FETCH_WIDTH)-1:0] iq_bpu_upd,
   input [CONFIG_P_FETCH_WIDTH:0]      iq_push_cnt,
   output                              iq_ready,
   // To ID
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid,
   input [CONFIG_P_ISSUE_WIDTH:0]      id_pop_cnt,
   output [`NCPU_INSN_DW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   output [CONFIG_AW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc,
   output [`FNT_EXC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc,
   output [`BPU_UPD_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd
);
   localparam FW                       = (1<<CONFIG_P_FETCH_WIDTH);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam FIFO_DW                  = (`NCPU_INSN_DW + CONFIG_AW + `FNT_EXC_W + `BPU_UPD_W); // INST + PC + EXC + BPU
   localparam P_BANKS                  = (CONFIG_P_FETCH_WIDTH);
   localparam BANKS                    = (1<<P_BANKS);

   wire [P_BANKS-1:0]                  head_ff, tail_ff;
   wire [P_BANKS-1:0]                  head_nxt, tail_nxt;
   wire [P_BANKS-1:0]                  head_l                        [FW-1:0];
   wire [P_BANKS-1:0]                  head_r                        [FW-1:0];
   wire [P_BANKS-1:0]                  tail_r                        [FW-1:0];
   wire [P_BANKS-1:0]                  tail_inv                      [FW-1:0];
   wire [P_BANKS:0]                    offset;
   wire [FIFO_DW-1:0]                  que_din                       [BANKS-1:0];
   wire [FIFO_DW-1:0]                  que_dout                      [BANKS-1:0];
   wire                                que_valid                     [BANKS-1:0];
   wire [BANKS-1:0]                    que_ready;
   wire                                que_push                      [BANKS-1:0];
   wire                                que_pop                       [BANKS-1:0];
   wire [`NCPU_INSN_DW-1:0]            iq_ins_unpacked               [FW-1:0];
   wire [CONFIG_AW-1:0]                iq_pc_unpacked                [FW-1:0];
   wire [`FNT_EXC_W-1:0]               iq_exc_unpacked               [FW-1:0];
   wire [`BPU_UPD_W-1:0]               iq_bpu_upd_unpacked           [FW-1:0];
   genvar i;

   generate
      for(i=0;i<BANKS;i=i+1)
         begin : gen_ptr
            assign head_l[i]  = i + head_ff;
            assign head_r[i]  = i - head_ff;
            assign tail_r[i] = i - tail_ff;
            
            //
            // The data layout in a fetch window is as follows (FW=4)
            // Case: push_cnt = 4:
            // Idx   0   1   2   3
            //     +---+---+---+---+
            // Dat |D0 |D1 |D2 |D3 |
            //     +---+---+---+---+
            // Case: push_cnt = 3:
            //     +---+---+---+---+
            // Dat |X  |D0 |D1 |D2 |
            //     +---+---+---+---+
            // Case: push_cnt = 2:
            //     +---+---+---+---+
            // Dat |X  |X  |D0 |D1 |
            //     +---+---+---+---+
            // Case: push_cnt = 1:
            //     +---+---+---+---+
            // Dat |X  |X  |X  |D0 |
            //     +---+---+---+---+
            //
            assign tail_inv[i] = i - tail_ff + offset[P_BANKS-1:0];
         end
   endgenerate
   
   assign offset = (FW - iq_push_cnt);
   
   // Would you like some syntactic sugar?
   generate
      for(i=0;i<FW;i=i+1)
         begin
            assign iq_ins_unpacked[i] = iq_ins[i*`NCPU_INSN_DW +: `NCPU_INSN_DW];
            assign iq_pc_unpacked[i] = iq_pc[i*CONFIG_AW +: CONFIG_AW];
            assign iq_exc_unpacked[i] = iq_exc[i*`FNT_EXC_W +: `FNT_EXC_W];
            assign iq_bpu_upd_unpacked[i] = iq_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W];
         end
   endgenerate
   
   // MUX for FIFO input
   generate
      for(i=0;i<BANKS;i=i+1)
         begin : gen_bank_ctrl
            assign que_din[i] = {iq_ins_unpacked[tail_inv[i]],
                                 iq_pc_unpacked[tail_inv[i]],
                                 iq_exc_unpacked[tail_inv[i]],
                                 iq_bpu_upd_unpacked[tail_inv[i]]};
            if (P_BANKS == CONFIG_P_ISSUE_WIDTH)
               assign que_pop[i]  = ({1'b0, head_r[i]} < id_pop_cnt);
            else
               assign que_pop[i]  = ({1'b0, head_r[i]} < {{P_BANKS-CONFIG_P_ISSUE_WIDTH{1'b0}}, id_pop_cnt});
            assign que_push[i] = ({1'b0, tail_r[i]} < iq_push_cnt);
         end
   endgenerate
   
   assign head_nxt = (head_ff + id_pop_cnt[P_BANKS-1:0]) & {P_BANKS{~flush}};
   assign tail_nxt = (tail_ff + iq_push_cnt[P_BANKS-1:0]) & {P_BANKS{~flush}};
   
   mDFF_r #(.DW(P_BANKS)) ff_head (.CLK(clk), .RST(rst), .D(head_nxt), .Q(head_ff) );
   mDFF_r #(.DW(P_BANKS)) ff_tail (.CLK(clk), .RST(rst), .D(tail_nxt), .Q(tail_ff) );
   
   generate
      for(i=0;i<BANKS;i=i+1)
         begin
            fifo_fwft
               #(
                  .DW            (FIFO_DW),
                  .DEPTH_WIDTH   (CONFIG_P_IQ_DEPTH)
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
                  .valid         (que_valid[i])
               );
         end
   endgenerate
   
   // MUX for data output
   generate
      for(i=0;i<(1<<CONFIG_P_ISSUE_WIDTH);i=i+1)
         begin : gen_pop
            assign {id_ins[i*`NCPU_INSN_DW +: `NCPU_INSN_DW],
                     id_pc[i*CONFIG_AW +: CONFIG_AW],
                     id_exc[i*`FNT_EXC_W +: `FNT_EXC_W],
                     id_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W] } = que_dout[head_l[i]];
            assign id_valid[i] = que_valid[head_l[i]];
         end
   endgenerate
   
   assign iq_ready = &que_ready;
   
   
   // synthesis translate_off
`ifndef SYNTHESIS
   initial
      begin
         if (CONFIG_P_IQ_DEPTH < CONFIG_P_FETCH_WIDTH)
            $fatal(1, "Unreasonable configuration of IQ depth.");
         if (CONFIG_P_ISSUE_WIDTH > CONFIG_P_FETCH_WIDTH)
            $fatal(1, "Unreasonable configuration of fetch width or issue width.");
      end
      
   always @(posedge clk)
      if (~iq_ready & (|iq_push_cnt))
         $fatal(1, "BUG ON: FIFO is overflow.");
`endif
   // synthesis translate_on

endmodule
