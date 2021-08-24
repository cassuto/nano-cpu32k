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

module bpu
#(
   parameter CONFIG_PHT_P_NUM = 0,
   parameter CONFIG_BTB_P_NUM = 0,
   parameter CONFIG_AW = 0,
   parameter CONFIG_P_FETCH_WIDTH = 0,
   parameter BPU_UPD_DW = (CONFIG_PHT_P_NUM + CONFIG_BTB_P_NUM + 4)
)
(
   input                                        clk,
   input                                        rst,
   input                                        re,
   input [(CONFIG_AW-2)*(1<<CONFIG_P_FETCH_WIDTH)-1:0] pc,
   output [(CONFIG_AW-2)*(1<<CONFIG_P_FETCH_WIDTH)-1:0] npc,
   output [BPU_UPD_DW*(1<<CONFIG_P_FETCH_WIDTH)-1:0] upd,
   // WB
   input                                        bpu_wb,
   input                                        bpu_wb_is_bcc,
   input                                        bpu_wb_is_breg,
   input                                        bpu_wb_bcc_taken,
   input [CONFIG_AW-3:0]                        bpu_wb_pc,
   input [CONFIG_AW-3:0]                        bpu_wb_npc_act,
   input [BPU_UPD_DW-1:0]                       bpu_wb_upd
);

   localparam PHT_NUM                           = (1<<CONFIG_PHT_P_NUM);
   localparam BTB_NUM                           = (1<<CONFIG_BTB_P_NUM);
   localparam PHT_DW                            = 2; // 2-bit counter
   localparam BTB_DW                            = (1 + 1 + CONFIG_AW-CONFIG_BTB_P_NUM-2 + CONFIG_AW-2); // V + IS_BCC + TAG + NPC

   // Stage 1 Input
   wire [CONFIG_AW-3:0]                         s1i_pc         [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [(1<<CONFIG_P_FETCH_WIDTH)*CONFIG_PHT_P_NUM-1:0] s1i_pht_addr;
   wire [(1<<CONFIG_P_FETCH_WIDTH)*CONFIG_BTB_P_NUM-1:0] s1i_btb_addr;
   // Stage 2 Input / Stage 1 Output
   wire [CONFIG_AW-3:0]                         s1o_pc         [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [CONFIG_AW-3:0]                         s1o_pc_p1      [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [CONFIG_PHT_P_NUM-1:0]                  s1o_pht_addr   [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [CONFIG_BTB_P_NUM-1:0]                  s1o_btb_addr   [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [(1<<CONFIG_P_FETCH_WIDTH)*PHT_DW-1:0]  s1o_pht_count;
   wire                                         s2i_pht_taken  [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [(1<<CONFIG_P_FETCH_WIDTH)*BTB_DW-1:0]  s1o_btb_data;
   wire                                         s2i_btb_v      [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire                                         s2i_btb_is_bcc [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [CONFIG_AW-CONFIG_BTB_P_NUM-3:0]        s2i_btb_tag    [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire [CONFIG_AW-3:0]                         s2i_btb_npc    [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   wire                                         s2i_btb_hit    [(1<<CONFIG_P_FETCH_WIDTH)-1:0];
   // Stage WB
   wire [CONFIG_PHT_P_NUM-1:0]                  wb_pht_addr;
   wire [CONFIG_BTB_P_NUM-1:0]                  wb_btb_addr;
   wire [PHT_DW-1:0]                            wb_pht_count_org;
   wire                                         wb_pht_we;
   reg [PHT_DW-1:0]                             wb_pht_din;
   wire                                         wb_btb_we;
   wire [BTB_DW-1:0]                            wb_btb_din;
   // GHSR
   wire [CONFIG_PHT_P_NUM-1:0]                  ff_GHSR;
   wire [CONFIG_PHT_P_NUM-1:0]                  GHSR_nxt;
   
   genvar i;
   
   generate
      for(i=0;i<(1<<CONFIG_P_FETCH_WIDTH);i=i+1)
         begin
            mDFF_l #(.DW(CONFIG_AW-2)) ff_s1o_pc (.CLK(clk), .LOAD(re), .D(s1i_pc[i]), .Q(s1o_pc[i]) );
            mDFF_l #(.DW(CONFIG_AW-2)) ff_s1o_pc_p1 (.CLK(clk), .LOAD(re), .D(s1i_pc[i] + 'b1), .Q(s1o_pc_p1[i]) );
            mDFF_l #(.DW(CONFIG_AW-2)) ff_s1o_pht_addr (.CLK(clk), .LOAD(re), .D(s1i_pht_addr[i*CONFIG_PHT_P_NUM +: CONFIG_PHT_P_NUM]), .Q(s1o_pht_addr[i]) );
            mDFF_l #(.DW(CONFIG_AW-2)) ff_s1o_btb_addr (.CLK(clk), .LOAD(re), .D(s1i_btb_addr[i*CONFIG_BTB_P_NUM +: CONFIG_BTB_P_NUM]), .Q(s1o_btb_addr[i]) );
            
            assign s1i_pc[i] = pc[i*(CONFIG_AW-2) +: (CONFIG_AW-2)];
            
            // Hash
            assign s1i_pht_addr[i*CONFIG_PHT_P_NUM +: CONFIG_PHT_P_NUM] = s1i_pc[i][CONFIG_PHT_P_NUM-1:0] ^ ff_GHSR;
            assign s1i_btb_addr[i*CONFIG_BTB_P_NUM +: CONFIG_BTB_P_NUM] = s1i_pc[i][CONFIG_BTB_P_NUM-1:0];
            
            // Weakly/Strongly taken
            assign s2i_pht_taken[i] = s1o_pht_count[i*PHT_DW +: PHT_DW][PHT_DW-1];
            
            assign {s2i_btb_npc[i], s2i_btb_tag[i], s2i_btb_is_bcc[i], s2i_btb_v[i]} = s1o_btb_data[i*BTB_DW +: BTB_DW];
            
            assign s2i_btb_hit[i] = (s2i_btb_v[i] & (s2i_btb_tag[i] == s1o_pc[CONFIG_AW-3:CONFIG_BTB_P_NUM]));
            
            // MUX of NPC
            assign npc[i*(CONFIG_AW-2) +: (CONFIG_AW-2)] = (s2i_btb_hit[i] & (~s2i_btb_is_bcc[i] | s2i_pht_taken[i]))
                                                               ? s2i_btb_npc[0]
                                                               : s1o_pc_p1[i];
            
            assign upd[i*BPU_UPD_DW +: BPU_UPD_DW] = {s1o_pht_count[i*PHT_DW +: PHT_DW][PHT_DW-1], s1o_pht_addr[i], s1o_btb_addr[i]};
         end
   endgenerate
   
   mRF_1wnr
      #(
         .DW         (PHT_DW),
         .AW         (CONFIG_PHT_P_NUM),
         .NUM_READ   (1<<CONFIG_P_FETCH_WIDTH)
      )
   U_PHT
      (
         .CLK        (clk),
         .RE         ({NUM_READ{re}}),
         .RADDR      (s1i_pht_addr),
         .RDATA      (s1o_pht_count),
         .WE         (wb_btb_we),
         .WADDR      (wb_pht_addr),
         .WDATA      (wb_pht_din)
      );
      
   mRF_1wnr
      #(
         .DW         (BTB_DW),
         .AW         (CONFIG_BTB_P_NUM),
         .NUM_READ   (1<<CONFIG_P_FETCH_WIDTH)
      )
   U_BTB
      (
         .CLK        (clk),
         .RE         ({NUM_READ{re}}),
         .RADDR      (s1i_btb_addr),
         .RDATA      (s1o_btb_data),
         .WE         (wb_btb_we),
         .WADDR      (wb_btb_addr),
         .WDATA      (wb_btb_din)
      );
      
   assign {wb_pht_count_org, wb_pht_addr, wb_btb_addr} = bpu_wb_upd;
      
   assign wb_pht_we = (bpu_wb & bpu_wb_is_bcc);
   
   // MUX for the PHT counter
   always @(*)
      if (bpu_wb_bcc_taken)
         wb_pht_din = (wb_pht_count_org == 2'b11)
                        ? 2'b11
                        : wb_pht_count_org + 'b1;
      else
         wb_pht_din =  (wb_pht_count_org == 2'b00)
                        ? 2'b00
                        : wb_pht_count_org - 'b1;
      
   assign wb_btb_we = (bpu_wb & bpu_wb_is_breg);
   
   assign wb_btb_din = {bpu_wb_npc_act, bpu_wb_pc[CONFIG_AW-3:CONFIG_BTB_P_NUM], bpu_wb_is_bcc, 1'b1};

   // Update Global History Shift Register
   assign GHSR_nxt = upd_pht_we ? {ff_GHSR[CONFIG_PHT_P_NUM-2:0], bpu_wb_bcc_taken}: ff_GHSR;

   mDFF_lr #(.DW(CONFIG_PHT_P_NUM)) ff_GHSR (.CLK(clk), .RST(rst), .LOAD(upd_pht_we), .D(GHSR_nxt), .Q(ff_GHSR) );

endmodule