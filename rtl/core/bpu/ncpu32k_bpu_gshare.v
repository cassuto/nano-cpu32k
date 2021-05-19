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

module ncpu32k_bpu_gshare
#(
   parameter CONFIG_PHT_NUM_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_BTB_NUM_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter BPU_UPD_DW = (CONFIG_PHT_NUM_LOG2 + CONFIG_BTB_NUM_LOG2 + 4)
)
(
   input                               clk,
   input                               rst_n,
   input                               bpu_re,
   // IF channel #1
   input [`NCPU_AW-3:0]                bpu_insn_pc_1,
   output [`NCPU_AW-3:0]               bpu_pred_pc_nxt_1,
   output [BPU_UPD_DW-1:0]             bpu_pred_upd_1,
   // IF channel #2
   input [`NCPU_AW-3:0]                bpu_insn_pc_2,
   output [`NCPU_AW-3:0]               bpu_pred_pc_nxt_2,
   output [BPU_UPD_DW-1:0]             bpu_pred_upd_2,
   // WB
   input                               bpu_wb,
   input                               bpu_wb_is_bcc,
   input                               bpu_wb_is_breg,
   input                               bpu_wb_taken,
   input [`NCPU_AW-3:0]                bpu_wb_pc,
   input [`NCPU_AW-3:0]                bpu_wb_pc_nxt_act,
   input [BPU_UPD_DW-1:0]              bpu_wb_upd
);

   localparam PHT_NUM = (1<<CONFIG_PHT_NUM_LOG2);
   localparam BTB_NUM = (1<<CONFIG_BTB_NUM_LOG2);
   localparam BTB_DW = (1 + 1 + `NCPU_AW-CONFIG_BTB_NUM_LOG2-2 + `NCPU_AW-2); // V + IS_BCC + PC_TAG + PC_NXT

   wire [`NCPU_AW-3:0]                 bpu_insn_pc_1_r;
   wire [`NCPU_AW-3:0]                 bpu_insn_pc_2_r;
   wire [1:0]                          bpu_upd_pht_taken [1:0];
   wire [1:0]                          bpu_upd_pht_not_taken [1:0];
   wire [CONFIG_BTB_NUM_LOG2-1:0]      bpu_wb_btb_idx;
   wire [CONFIG_PHT_NUM_LOG2-1:0]      bpu_wb_pht_idx;
   wire [1:0]                          bpu_wb_pht_taken;
   wire [1:0]                          bpu_wb_pht_not_taken;

   wire [CONFIG_BTB_NUM_LOG2-1:0]      pred_btb_idx [1:0];
   wire [CONFIG_BTB_NUM_LOG2-1:0]      pred_btb_idx_r [1:0];
   wire                                pred_btb_v  [1:0];
   wire                                pred_btb_is_bcc [1:0];
   wire [`NCPU_AW-CONFIG_BTB_NUM_LOG2-3:0] pred_btb_pc_tag [1:0];
   wire [`NCPU_AW-3:0]                 pred_btb_pc_nxt [1:0];
   wire                                pred_btb_hit [1:0];
   wire                                pred_taken [1:0];
   wire                                upd_btb_we;

   wire [CONFIG_PHT_NUM_LOG2-1:0]      pred_pht_idx [1:0];
   wire [CONFIG_PHT_NUM_LOG2-1:0]      pred_pht_idx_r [1:0];
   wire [1:0]                          pred_pht_cnt [1:0];
   wire                                upd_pht_we;
   wire [1:0]                          upd_pht_cnt;

   wire [CONFIG_PHT_NUM_LOG2-1:0]      GHSR_r;
   wire [CONFIG_PHT_NUM_LOG2-1:0]      GHSR_nxt;
   genvar i;
   
   nDFF_l #(`NCPU_AW-2) dff_bpu_insn_pc_1_r
      (clk, bpu_re, bpu_insn_pc_1, bpu_insn_pc_1_r);
   nDFF_l #(`NCPU_AW-2) dff_bpu_insn_pc_2_r
      (clk, bpu_re, bpu_insn_pc_2, bpu_insn_pc_2_r);

   // Index to BTB
   assign pred_btb_idx[0] = bpu_insn_pc_1[CONFIG_BTB_NUM_LOG2-1:0];
   assign pred_btb_idx[1] = bpu_insn_pc_2[CONFIG_BTB_NUM_LOG2-1:0];

   ncpu32k_cell_mpram_1w2r
      #(
         .AW (CONFIG_BTB_NUM_LOG2),
         .DW (BTB_DW),
         .ENABLE_BYPASS (0)
      )
   BTB
      (
         .clk     (clk),
         .rst_n   (clk),
         .raddr_1 (pred_btb_idx[0]),
         .re_1    (bpu_re),
         .raddr_2 (pred_btb_idx[1]),
         .re_2    (bpu_re),
         .waddr   (bpu_wb_btb_idx),
         .we      (upd_btb_we),
         .din     ({1'b1, bpu_wb_is_bcc, bpu_wb_pc[`NCPU_AW-3:CONFIG_BTB_NUM_LOG2], bpu_wb_pc_nxt_act[`NCPU_AW-3:0]}),
         .dout_1  ({pred_btb_v[0], pred_btb_is_bcc[0], pred_btb_pc_tag[0][`NCPU_AW-CONFIG_BTB_NUM_LOG2-3:0], pred_btb_pc_nxt[0][`NCPU_AW-3:0]}),
         .dout_2  ({pred_btb_v[1], pred_btb_is_bcc[1], pred_btb_pc_tag[1][`NCPU_AW-CONFIG_BTB_NUM_LOG2-3:0], pred_btb_pc_nxt[1][`NCPU_AW-3:0]})
      );

   generate
      for(i=0; i<2; i=i+1)
         begin
            nDFF_l #(CONFIG_BTB_NUM_LOG2) dff_pred_btb_idx_r
               (clk, bpu_re, pred_btb_idx[i], pred_btb_idx_r[i]);
         end
   endgenerate

   assign pred_btb_hit[0] = (pred_btb_v[0] & (pred_btb_pc_tag[0] == bpu_insn_pc_1_r[`NCPU_AW-3:CONFIG_BTB_NUM_LOG2]));
   assign pred_btb_hit[1] = (pred_btb_v[1] & (pred_btb_pc_tag[1] == bpu_insn_pc_2_r[`NCPU_AW-3:CONFIG_BTB_NUM_LOG2]));

   assign upd_btb_we = (bpu_wb & (bpu_wb_is_bcc | bpu_wb_is_breg));

   // Hash function for PHT
   assign pred_pht_idx[0] = bpu_insn_pc_1[CONFIG_PHT_NUM_LOG2-1:0] ^ GHSR_r[CONFIG_PHT_NUM_LOG2-1:0];
   assign pred_pht_idx[1] = bpu_insn_pc_2[CONFIG_PHT_NUM_LOG2-1:0] ^ GHSR_r[CONFIG_PHT_NUM_LOG2-1:0];

   ncpu32k_cell_mpram_1w2r
      #(
         .AW (CONFIG_PHT_NUM_LOG2),
         .DW (2),
         .ENABLE_BYPASS (0)
      )
   PHT
      (
         .clk     (clk),
         .rst_n   (clk),
         .raddr_1 (pred_pht_idx[0]),
         .re_1    (bpu_re),
         .raddr_2 (pred_pht_idx[1]),
         .re_2    (bpu_re),
         .waddr   (bpu_wb_pht_idx),
         .we      (upd_pht_we),
         .din     (upd_pht_cnt),
         .dout_1  (pred_pht_cnt[0]),
         .dout_2  (pred_pht_cnt[1])
      );

   generate
      for(i=0; i<2; i=i+1)
         begin
            nDFF_l #(CONFIG_PHT_NUM_LOG2) dff_pred_pht_idx_r
               (clk, bpu_re, pred_pht_idx[i], pred_pht_idx_r[i]);
         end
   endgenerate

   assign pred_taken[0] = pred_pht_cnt[0][1];
   assign pred_taken[1] = pred_pht_cnt[1][1];

   assign bpu_pred_pc_nxt_1 = (pred_btb_hit[0] & (~pred_btb_is_bcc[0] | pred_taken[0]))
                                 ? pred_btb_pc_nxt[0]
                                 : bpu_insn_pc_1_r + 'b1;
   assign bpu_pred_pc_nxt_2 = (pred_btb_hit[1] & (~pred_btb_is_bcc[1] | pred_taken[1]))
                                 ? pred_btb_pc_nxt[1]
                                 : bpu_insn_pc_2_r + 'b1;

   assign bpu_upd_pht_taken[0] = (pred_pht_cnt[0] == 2'b11)
                                 ? 2'b11
                                 : pred_pht_cnt[0] + 'b1;
   assign bpu_upd_pht_taken[1] = (pred_pht_cnt[1] == 2'b11)
                                 ? 2'b11
                                 : pred_pht_cnt[1] + 'b1;

   assign bpu_upd_pht_not_taken[0] = (pred_pht_cnt[0] == 2'b00)
                                    ? 2'b00
                                    : pred_pht_cnt[0] - 'b1;
   assign bpu_upd_pht_not_taken[1] = (pred_pht_cnt[1] == 2'b00)
                                    ? 2'b00
                                    : pred_pht_cnt[1] - 'b1;

   assign bpu_pred_upd_1 = {bpu_upd_pht_taken[0], bpu_upd_pht_not_taken[0], pred_pht_idx_r[0], pred_btb_idx_r[0]};
   assign bpu_pred_upd_2 = {bpu_upd_pht_taken[1], bpu_upd_pht_not_taken[1], pred_pht_idx_r[1], pred_btb_idx_r[1]};
   
   assign {bpu_wb_pht_taken, bpu_wb_pht_not_taken, bpu_wb_pht_idx, bpu_wb_btb_idx} = bpu_wb_upd;

   assign upd_pht_we = (bpu_wb & bpu_wb_is_bcc);

   assign upd_pht_cnt = bpu_wb_taken ? bpu_wb_pht_taken : bpu_wb_pht_not_taken;

   // Update Global History Shift Register
   assign GHSR_nxt = upd_pht_we ? {GHSR_r[CONFIG_PHT_NUM_LOG2-2:0], bpu_wb_taken}: GHSR_r;

   nDFF_lr #(CONFIG_PHT_NUM_LOG2) dff_GHSR
      (clk, rst_n, upd_pht_we, GHSR_nxt, GHSR_r);


   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   initial
      begin
         if (BPU_UPD_DW != (CONFIG_PHT_NUM_LOG2 + CONFIG_BTB_NUM_LOG2 + 4))
            $fatal(1, "Invalid value of BPU_UPD_DW");
      end

`endif
   // synthesis translate_on

endmodule
