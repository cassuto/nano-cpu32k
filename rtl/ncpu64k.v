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

module ncpu64k
#(
   parameter CONFIG_AW = 32,
   parameter CONFIG_DW = 32,
   parameter CONFIG_P_FETCH_WIDTH = 2,
   parameter CONFIG_P_ISSUE_WIDTH = 1,
   parameter CONFIG_P_PAGE_SIZE = 13,
   parameter CONFIG_IC_P_LINE = 6,
   parameter CONFIG_IC_P_SETS = 6,
   parameter CONFIG_IC_P_WAYS = 2,
   parameter CONFIG_PHT_P_NUM = 9,
   parameter CONFIG_BTB_P_NUM = 9,
   parameter CONFIG_P_IQ_DEPTH = 4,
   parameter AXI_P_DW_BYTES    = 3,
   parameter AXI_ADDR_WIDTH    = 64,
   parameter AXI_ID_WIDTH      = 4,
   parameter AXI_USER_WIDTH    = 1
)
(
   input                               clk,
   input                               rst,
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
   input  [1:0]                        axi_r_resp_i,
   input                               axi_r_last_i,
   input  [AXI_ID_WIDTH-1:0]           axi_r_id_i,
   input  [AXI_USER_WIDTH-1:0]         axi_r_user_i,
   
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
   input [1:0]                         axi_b_resp_i,
   input [AXI_ID_WIDTH-1:0]            axi_b_id_i,
   input [AXI_USER_WIDTH-1:0]          axi_b_user_i
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 icop_stall_req;         // From U_IFU of ifu.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd;// From U_IFU of ifu.v
   wire [`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc;// From U_IFU of ifu.v
   wire [`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins;// From U_IFU of ifu.v
   wire [CONFIG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc;// From U_IFU of ifu.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid;// From U_IFU of ifu.v
   // End of automatics
   wire                                flush;
   wire [CONFIG_AW-1:0]                flush_tgt;
   wire                                icop_inv;
   wire [CONFIG_AW-1:0]                icop_inv_paddr;
   wire [CONFIG_P_ISSUE_WIDTH:0]       id_pop_cnt;
   wire                                bpu_wb;
   wire                                bpu_wb_is_bcc;
   wire                                bpu_wb_is_breg;
   wire                                bpu_wb_bcc_taken;
   wire [CONFIG_AW-3:0]                bpu_wb_pc;
   wire [CONFIG_AW-3:0]                bpu_wb_npc_act;
   wire [`BPU_UPD_W-1:0]               bpu_wb_upd;

   ifu
   #(/*AUTOINSTPARAM*/
     // Parameters
     .CONFIG_AW                         (CONFIG_AW),
     .CONFIG_P_FETCH_WIDTH              (CONFIG_P_FETCH_WIDTH),
     .CONFIG_P_ISSUE_WIDTH              (CONFIG_P_ISSUE_WIDTH),
     .CONFIG_P_IQ_DEPTH                 (CONFIG_P_IQ_DEPTH),
     .CONFIG_P_PAGE_SIZE                (CONFIG_P_PAGE_SIZE),
     .CONFIG_IC_P_LINE                  (CONFIG_IC_P_LINE),
     .CONFIG_IC_P_SETS                  (CONFIG_IC_P_SETS),
     .CONFIG_IC_P_WAYS                  (CONFIG_IC_P_WAYS),
     .CONFIG_PHT_P_NUM                  (CONFIG_PHT_P_NUM),
     .CONFIG_BTB_P_NUM                  (CONFIG_BTB_P_NUM),
     .AXI_P_DW_BYTES                    (AXI_P_DW_BYTES),
     .AXI_ADDR_WIDTH                    (AXI_ADDR_WIDTH),
     .AXI_ID_WIDTH                      (AXI_ID_WIDTH),
     .AXI_USER_WIDTH                    (AXI_USER_WIDTH))
   U_IFU
   (/*AUTOINST*/
    // Outputs
    .id_valid                           (id_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
    .id_ins                             (id_ins[`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
    .id_pc                              (id_pc[CONFIG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
    .id_exc                             (id_exc[`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
    .id_bpu_upd                         (id_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
    .icop_stall_req                     (icop_stall_req),
    .axi_ar_valid_o                     (axi_ar_valid_o),
    .axi_ar_addr_o                      (axi_ar_addr_o[AXI_ADDR_WIDTH-1:0]),
    .axi_ar_prot_o                      (axi_ar_prot_o[2:0]),
    .axi_ar_id_o                        (axi_ar_id_o[AXI_ID_WIDTH-1:0]),
    .axi_ar_user_o                      (axi_ar_user_o[AXI_USER_WIDTH-1:0]),
    .axi_ar_len_o                       (axi_ar_len_o[7:0]),
    .axi_ar_size_o                      (axi_ar_size_o[2:0]),
    .axi_ar_burst_o                     (axi_ar_burst_o[1:0]),
    .axi_ar_lock_o                      (axi_ar_lock_o),
    .axi_ar_cache_o                     (axi_ar_cache_o[3:0]),
    .axi_ar_qos_o                       (axi_ar_qos_o[3:0]),
    .axi_ar_region_o                    (axi_ar_region_o[3:0]),
    .axi_r_ready_o                      (axi_r_ready_o),
    // Inputs
    .clk                                (clk),
    .rst                                (rst),
    .flush                              (flush),
    .flush_tgt                          (flush_tgt[CONFIG_AW-1:0]),
    .id_pop_cnt                         (id_pop_cnt[CONFIG_P_ISSUE_WIDTH:0]),
    .icop_inv                           (icop_inv),
    .icop_inv_paddr                     (icop_inv_paddr[CONFIG_AW-1:0]),
    .bpu_wb                             (bpu_wb),
    .bpu_wb_is_bcc                      (bpu_wb_is_bcc),
    .bpu_wb_is_breg                     (bpu_wb_is_breg),
    .bpu_wb_bcc_taken                   (bpu_wb_bcc_taken),
    .bpu_wb_pc                          (bpu_wb_pc[CONFIG_AW-3:0]),
    .bpu_wb_npc_act                     (bpu_wb_npc_act[CONFIG_AW-3:0]),
    .bpu_wb_upd                         (bpu_wb_upd[`BPU_UPD_W-1:0]),
    .axi_ar_ready_i                     (axi_ar_ready_i),
    .axi_r_valid_i                      (axi_r_valid_i),
    .axi_r_data_i                       (axi_r_data_i[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .axi_r_resp_i                       (axi_r_resp_i[1:0]),
    .axi_r_last_i                       (axi_r_last_i),
    .axi_r_id_i                         (axi_r_id_i[AXI_ID_WIDTH-1:0]),
    .axi_r_user_i                       (axi_r_user_i[AXI_USER_WIDTH-1:0]));

   // TODO
   assign flush = 'b0;
   assign flush_tgt = 'b0;
   assign icop_inv = 'b0;
   assign icop_inv_paddr = 'b0;
   assign id_pop_cnt = 'b0;
   assign bpu_wb = 'b0;
   assign bpu_wb_is_bcc = 'b0;
   assign bpu_wb_is_breg = 'b0;
   assign bpu_wb_bcc_taken = 'b0;
   assign bpu_wb_pc = 'b0;
   assign bpu_wb_npc_act = 'b0;
   assign bpu_wb_upd = 'b0;
   
   // TOOD lsu
   assign axi_aw_valid_o = 'b0;
   assign axi_aw_addr_o = 'b0;
   assign axi_aw_prot_o = 'b0;
   assign axi_aw_id_o = 'b0;
   assign axi_aw_user_o = 'b0;
   assign axi_aw_len_o = 'b0;
   assign axi_aw_size_o = 'b0;
   assign axi_aw_burst_o = 'b0;
   assign axi_aw_lock_o = 'b0;
   assign axi_aw_cache_o = 'b0;
   assign axi_aw_qos_o = 'b0;
   assign axi_aw_region_o = 'b0;
   assign axi_w_valid_o = 'b0;
   assign axi_w_data_o = 'b0;
   assign axi_w_strb_o = 'b0;
   assign axi_w_last_o = 'b0;
   assign axi_w_user_o = 'b0;
   assign axi_b_ready_o = 'b0;
   
endmodule
