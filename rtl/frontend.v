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

module frontend
#(
   parameter                           CONFIG_AW = 32,
   parameter                           CONFIG_DW = 32,
   parameter                           CONFIG_P_FETCH_WIDTH = 1,
   parameter                           CONFIG_P_ISSUE_WIDTH = 1,
   parameter                           CONFIG_P_IQ_DEPTH = 4,
   parameter                           CONFIG_P_PAGE_SIZE = 13,
   parameter                           CONFIG_ITLB_P_SETS = 0,
   parameter                           CONFIG_IC_P_LINE = 6,
   parameter                           CONFIG_IC_P_SETS = 6,
   parameter                           CONFIG_IC_P_WAYS = 2,
   parameter                           CONFIG_PHT_P_NUM = 9,
   parameter                           CONFIG_BTB_P_NUM = 9,
   parameter [CONFIG_AW-1:0]           CONFIG_ERST_VECTOR = 0,
   parameter                           CONFIG_IMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           AXI_P_DW_BYTES = 3,
   parameter                           AXI_UNCACHED_P_DW_BYTES = 2,
   parameter                           AXI_ADDR_WIDTH = 64,
   parameter                           AXI_ID_WIDTH = 4,
   parameter                           AXI_USER_WIDTH = 1
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input [`PC_W-1:0]                   flush_tgt,
   // To ID
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid,
   input [CONFIG_P_ISSUE_WIDTH:0]      id_pop_cnt,
   output [`NCPU_INSN_DW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   output [`PC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc,
   output [`FNT_EXC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc,
   output [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd,
   // From EX
   input                               bpu_wb,
   input                               bpu_wb_is_bcc,
   input                               bpu_wb_is_breg,
   input                               bpu_wb_is_brel,
   input                               bpu_wb_taken,
   input [`PC_W-1:0]                   bpu_wb_pc,
   input [`PC_W-1:0]                   bpu_wb_npc_act,
   input [`BPU_UPD_W-1:0]              bpu_wb_upd,
   // To EX
   output                              icop_stall_req,
   // PSR
   input                               msr_psr_imme,
   input                               msr_psr_rm,
   // IMMID
   output [CONFIG_DW-1:0]              msr_immid,
   // TLBL
   input [CONFIG_ITLB_P_SETS-1:0]      msr_imm_tlbl_idx,
   input [CONFIG_DW-1:0]               msr_imm_tlbl_nxt,
   input                               msr_imm_tlbl_we,
   // TLBH
   input [CONFIG_ITLB_P_SETS-1:0]      msr_imm_tlbh_idx,
   input [CONFIG_DW-1:0]               msr_imm_tlbh_nxt,
   input                               msr_imm_tlbh_we,
   // ICID
   output [CONFIG_DW-1:0]              msr_icid,
   // ICINV
   input [CONFIG_DW-1:0]               msr_icinv_nxt,
   input                               msr_icinv_we,
   // AXI Master
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
   input  [1:0]                        ibus_RRESP,
   input                               ibus_RLAST,
   input  [AXI_ID_WIDTH-1:0]           ibus_RID,
   input  [AXI_USER_WIDTH-1:0]         ibus_RUSER
);
   localparam P_FETCH_DW_BYTES         = (`NCPU_P_INSN_LEN + CONFIG_P_FETCH_WIDTH);
   localparam FW                       = (1<<CONFIG_P_FETCH_WIDTH);

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 ic_stall_req;           // From U_ICACHE of icache.v
   wire                 iq_ready;               // From U_IQ of iq.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                p_ce;
   wire [CONFIG_P_PAGE_SIZE-1:0]       vpo;
   wire [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] ppn_s2;
   wire                                uncached_s2;
   wire                                kill_req_s2;
   wire                                pred_branch_taken;
   wire [`PC_W-1:0]                    pred_branch_tgt;
   wire [CONFIG_AW-1:0]                pc;
   reg [CONFIG_AW-1:0]                 pc_nxt;
   // Stage 1 Input
   wire [CONFIG_AW-1:0]                s1i_fetch_vaddr;
   wire [FW-1:0]                       s1i_fetch_valid;
   reg [FW-1:0]                        s1i_valid_msk;
   wire [`PC_W-1:0]                    s1i_pc                           [FW-1:0];
   wire [`PC_W*FW-1:0]                 s1i_bpu_pc;
   wire [CONFIG_P_FETCH_WIDTH:0]       s1i_push_cnt;
   // Stage 2 Input / Stage 1 Output
   wire [`PC_W-1:0]                    s1o_pc                           [FW-1:0];
   wire [`FNT_EXC_W-1:0]               s1o_exc;
   wire [CONFIG_P_FETCH_WIDTH:0]       s1o_push_cnt;
   wire [`PC_W*FW-1:0]                 s1o_bpu_npc_packed;
   wire [`BPU_UPD_W*FW-1:0]            s1o_bpu_upd_packed;
   wire [`BPU_UPD_W-1:0]               s1o_bpu_upd                      [FW-1:0];
   wire [FW-1:0]                       s1o_bpu_taken;
   wire [`BPU_UPD_W-1:0]               s2i_bpu_upd                      [FW-1:0];
   // Stage 3 Input / Stage 2 Output
   wire [`PC_W-1:0]                    s2o_pc                           [FW-1:0];
   wire [`FNT_EXC_W-1:0]               s2o_exc;
   wire [`BPU_UPD_W-1:0]               s2o_bpu_upd                      [FW-1:0];
   wire                                s2o_valid;
   wire [CONFIG_P_FETCH_WIDTH:0]       s2o_push_cnt;
   wire [`NCPU_INSN_DW*FW-1:0]         iq_ins;
   wire [`PC_W*FW-1:0]                 iq_pc;
   wire [`FNT_EXC_W*FW-1:0]            iq_exc;
   wire [`BPU_UPD_W*FW-1:0]            iq_bpu_upd;
   wire [CONFIG_P_FETCH_WIDTH:0]       iq_push_cnt;

   genvar i;
   integer j;

   /* icache AUTO_TEMPLATE (
      .stall_req                       (ic_stall_req),
      .ins                             (iq_ins),
      .valid                           (s2o_valid),
      .stall_ex_req                    (icop_stall_req),
      )
   */
   icache
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_FETCH_WIDTH           (CONFIG_P_FETCH_WIDTH),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_IC_P_LINE               (CONFIG_IC_P_LINE),
        .CONFIG_IC_P_SETS               (CONFIG_IC_P_SETS),
        .CONFIG_IC_P_WAYS               (CONFIG_IC_P_WAYS),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_UNCACHED_P_DW_BYTES        (AXI_UNCACHED_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_ICACHE
      (/*AUTOINST*/
       // Outputs
       .stall_req                       (ic_stall_req),          // Templated
       .stall_ex_req                    (icop_stall_req),        // Templated
       .ins                             (iq_ins),                // Templated
       .valid                           (s2o_valid),             // Templated
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .ibus_ARVALID                    (ibus_ARVALID),
       .ibus_ARADDR                     (ibus_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .ibus_ARPROT                     (ibus_ARPROT[2:0]),
       .ibus_ARID                       (ibus_ARID[AXI_ID_WIDTH-1:0]),
       .ibus_ARUSER                     (ibus_ARUSER[AXI_USER_WIDTH-1:0]),
       .ibus_ARLEN                      (ibus_ARLEN[7:0]),
       .ibus_ARSIZE                     (ibus_ARSIZE[2:0]),
       .ibus_ARBURST                    (ibus_ARBURST[1:0]),
       .ibus_ARLOCK                     (ibus_ARLOCK),
       .ibus_ARCACHE                    (ibus_ARCACHE[3:0]),
       .ibus_ARQOS                      (ibus_ARQOS[3:0]),
       .ibus_ARREGION                   (ibus_ARREGION[3:0]),
       .ibus_RREADY                     (ibus_RREADY),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .vpo                             (vpo[CONFIG_P_PAGE_SIZE-1:0]),
       .ppn_s2                          (ppn_s2[CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0]),
       .uncached_s2                     (uncached_s2),
       .kill_req_s2                     (kill_req_s2),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .ibus_ARREADY                    (ibus_ARREADY),
       .ibus_RVALID                     (ibus_RVALID),
       .ibus_RDATA                      (ibus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .ibus_RLAST                      (ibus_RLAST),
       .ibus_RRESP                      (ibus_RRESP[1:0]),
       .ibus_RID                        (ibus_RID[AXI_ID_WIDTH-1:0]),
       .ibus_RUSER                      (ibus_RUSER[AXI_USER_WIDTH-1:0]));

   bpu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_FETCH_WIDTH           (CONFIG_P_FETCH_WIDTH))
   U_BPU
      (
         .clk                           (clk),
         .rst                           (rst),
         .re                            (p_ce),
         .pc                            (s1i_bpu_pc),
         .npc                           (s1o_bpu_npc_packed),
         .upd                           (s1o_bpu_upd_packed),
         // WB
         .bpu_wb                        (bpu_wb),
         .bpu_wb_is_bcc                 (bpu_wb_is_bcc),
         .bpu_wb_is_breg                (bpu_wb_is_breg),
         .bpu_wb_is_brel                (bpu_wb_is_brel),
         .bpu_wb_taken                  (bpu_wb_taken),
         .bpu_wb_pc                     (bpu_wb_pc),
         .bpu_wb_npc_act                (bpu_wb_npc_act),
         .bpu_wb_upd                    (bpu_wb_upd)
      );

   immu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_IMMU_ENABLE_UNCACHED_SEG(CONFIG_IMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS))
   U_I_MMU
      (
         .clk                             (clk),
         .rst                             (rst),
         .re                              (p_ce),
         .vpn                             (s1i_fetch_vaddr[CONFIG_P_PAGE_SIZE +: CONFIG_AW-CONFIG_P_PAGE_SIZE]),
         .ppn                             (ppn_s2),
         .EITM                            (s1o_exc[`FNT_EXC_EITM]),
         .EIPF                            (s1o_exc[`FNT_EXC_EIPF]),
         .uncached                        (uncached_s2),
         // PSR
         .msr_psr_imme                    (msr_psr_imme),
         .msr_psr_rm                      (msr_psr_rm),
         // IMMID
         .msr_immid                       (msr_immid),
         // TLBL
         .msr_imm_tlbl_idx                (msr_imm_tlbl_idx),
         .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt),
         .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
         // TLBH
         .msr_imm_tlbh_idx                (msr_imm_tlbh_idx),
         .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt),
         .msr_imm_tlbh_we                 (msr_imm_tlbh_we)
      );
      
   assign kill_req_s2 = (|s1o_exc);

   // Collect branch predication info
   generate
      for(i=0;i<FW;i=i+1)
         begin
            assign s1i_bpu_pc[i*`PC_W +: `PC_W] = s1i_pc[i];
            assign s1o_bpu_upd[i] = s1o_bpu_upd_packed[i*`BPU_UPD_W +: `BPU_UPD_W];
            assign s1o_bpu_taken[i] = s1o_bpu_upd[i][`BPU_UPD_TAKEN];
         end
   endgenerate

   // Generate valid mask
   always @(*)
      begin
         s1i_valid_msk[0] = 'b1;
         for(j=1;j<FW;j=j+1)
            s1i_valid_msk[j] = s1i_valid_msk[j-1] & ~s1o_bpu_taken[j-1];
      end

   // Process unaligned access
   generate
      for(i=0;i<FW;i=i+1)
         assign s1i_fetch_valid[i] = (pc_nxt[`NCPU_P_INSN_LEN +: CONFIG_P_FETCH_WIDTH] <= i);
   endgenerate

   pmux #(.SELW(FW), .DW(`PC_W)) pmux_s1o_bpu_npc (.sel(s1o_bpu_taken), .din(s1o_bpu_npc_packed), .dout(pred_branch_tgt), .valid(pred_branch_taken) );

   // NPC Generator
   always @(*)
      if (flush)
         pc_nxt = {flush_tgt, {`NCPU_P_INSN_LEN{1'b0}}};
      else if (~p_ce)
         pc_nxt = pc;
      else if (pred_branch_taken)
         pc_nxt = {pred_branch_tgt, {`NCPU_P_INSN_LEN{1'b0}}};
      else
         pc_nxt = pc + {{CONFIG_AW-CONFIG_P_FETCH_WIDTH-1-`NCPU_P_INSN_LEN{1'b0}}, s1o_push_cnt, {`NCPU_P_INSN_LEN{1'b0}}};

   // PC Register
   mDFF_r # (.DW(CONFIG_AW), .RST_VECTOR(CONFIG_ERST_VECTOR)) ff_pc (.CLK(clk), .RST(rst), .D(pc_nxt), .Q(pc) );

   assign p_ce = (~ic_stall_req & iq_ready);

   assign s1i_fetch_vaddr = {pc_nxt[CONFIG_AW-1:P_FETCH_DW_BYTES], {P_FETCH_DW_BYTES{1'b0}}}; // Aligned by fetch window

   // Count the number of valid inst
   popcnt #(.DW(FW), .P_DW(CONFIG_P_FETCH_WIDTH)) U_CLO (.bitmap(s1i_fetch_valid & s1i_valid_msk), .count(s1i_push_cnt) );

   assign vpo = s1i_fetch_vaddr[CONFIG_P_PAGE_SIZE-1:0];

   // Control path
   mDFF_lr # (.DW(CONFIG_P_FETCH_WIDTH+1)) ff_s1o_push_cnt (.CLK(clk), .RST(rst), .LOAD(p_ce|flush), .D(s1i_push_cnt & {CONFIG_P_FETCH_WIDTH+1{~flush}}), .Q(s1o_push_cnt) );
   mDFF_lr # (.DW(CONFIG_P_FETCH_WIDTH+1)) ff_s2o_push_cnt (.CLK(clk), .RST(rst), .LOAD(p_ce|flush), .D(s1o_push_cnt & {CONFIG_P_FETCH_WIDTH+1{~flush}}), .Q(s2o_push_cnt) );

   // Data path
   mDFF_lr # (.DW(`FNT_EXC_W)) ff_s2o_exc (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_exc), .Q(s2o_exc) );

   generate
      for(i=0;i<FW;i=i+1)
         begin
            // Restore PC of each inst
            // We need re-align PC and related attributes(if any) here.
            wire [CONFIG_P_FETCH_WIDTH:0] align_offset = (FW-s1i_push_cnt);
            assign s1i_pc[i] = (pc_nxt[CONFIG_AW-1: `NCPU_P_INSN_LEN] + i - {{`PC_W-CONFIG_P_FETCH_WIDTH-1{1'b0}}, align_offset});

            mDFF_lr # (.DW(`PC_W)) ff_s1o_pc (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1i_pc[i]), .Q(s1o_pc[i]) );
            mDFF_lr # (.DW(`PC_W)) ff_s2o_pc (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_pc[i]), .Q(s2o_pc[i]) );
            mDFF_lr # (.DW(`BPU_UPD_W)) ff_s2o_bpu_upd (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1o_bpu_upd[i]), .Q(s2o_bpu_upd[i]) );

            // Pack signals
            assign iq_pc[i*`PC_W +: `PC_W] = s2o_pc[i];
            assign iq_exc[i*`FNT_EXC_W +: `FNT_EXC_W] = s2o_exc;
            assign iq_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W] = s2o_bpu_upd[i];
         end
   endgenerate

   assign iq_push_cnt = (s2o_push_cnt & {CONFIG_P_FETCH_WIDTH+1{s2o_valid & p_ce}});

   // Fetch Buffer
   iq
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_FETCH_WIDTH           (CONFIG_P_FETCH_WIDTH),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_IQ_DEPTH              (CONFIG_P_IQ_DEPTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM))
   U_IQ
      (/*AUTOINST*/
       // Outputs
       .iq_ready                        (iq_ready),
       .id_valid                        (id_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_ins                          (id_ins[`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_pc                           (id_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_exc                          (id_exc[`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_bpu_upd                      (id_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .iq_ins                          (iq_ins[`NCPU_INSN_DW*(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
       .iq_pc                           (iq_pc[`PC_W*(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
       .iq_exc                          (iq_exc[`FNT_EXC_W*(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
       .iq_bpu_upd                      (iq_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
       .iq_push_cnt                     (iq_push_cnt[CONFIG_P_FETCH_WIDTH:0]),
       .id_pop_cnt                      (id_pop_cnt[CONFIG_P_ISSUE_WIDTH:0]));

endmodule
