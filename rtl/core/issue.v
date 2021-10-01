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

module issue
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_RS_DEPTH = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   // From RN
   input                               issue_p_ce,
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_alu_opc_bus,
   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lsu_opc_bus,
   input [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_fe,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_imm,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1_re,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2_re,
   input [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lrd,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd_we,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pfree,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_push,
   input [CONFIG_P_ISSUE_WIDTH:0]      issue_push_size,
   input [(1<<`NCPU_PRF_AW)-1:0]       busytable,
   // To RN
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_ready,
   // From ROB
   input                               rob_ready,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank, 
   // To ROB
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_epu_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_lsu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] rob_push_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pc,
   output [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_lrd,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_bcc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_brel,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_breg,
   output [CONFIG_P_COMMIT_WIDTH:0]    rob_push_size,
   // From RO
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ready,
   // To RO
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ro_alu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_bpu_pred_taken,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_bpu_pred_tgt,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ro_bru_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_epu_op,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ro_imm,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ro_lpu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_lsu_op,
   output [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_fe,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ro_pc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prd_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs1_re,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs2_re,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ro_rob_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ro_rob_bank,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_valid
);
   localparam  IW                      = (1<<CONFIG_P_ISSUE_WIDTH);
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   wire [IW-1:0]                       issue_rs_full;          // From U_RS of issue_rs.v
   wire [IW-1:0]                       ro_rs_pop;
   wire [IW-1:0]                       rs_push;
   wire [CONFIG_P_ROB_DEPTH*IW-1:0]    issue_rob_id;           // To U_RS of issue_rs.v
   wire [CONFIG_P_COMMIT_WIDTH*IW-1:0] issue_rob_bank;         // To U_RS of issue_rs.v
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_RS
            wire [`BPU_UPD_W-1:0]      bpu_upd_bundle;

            assign bpu_upd_bundle = issue_bpu_upd[i * `BPU_UPD_W +: `BPU_UPD_W];
            
            /* issue_rs AUTO_TEMPLATE (
                  .issue_rs_full          (issue_rs_full[i]),
                  .ro_valid               (ro_valid[i]),
                  .ro_alu_opc_bus         (ro_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ro_lpu_opc_bus         (ro_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
                  .ro_epu_op              (ro_epu_op[i]),
                  .ro_bru_opc_bus         (ro_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                  .ro_lsu_op              (ro_lsu_op[i]),
                  .ro_bpu_pred_taken      (ro_bpu_pred_taken[i]),
                  .ro_bpu_pred_tgt        (ro_bpu_pred_tgt[i * `PC_W +: `PC_W]),
                  .ro_fe                  (ro_fe[i*`NCPU_FE_W +: `NCPU_FE_W]),
                  .ro_pc                  (ro_pc[i*`PC_W +: `PC_W]),
                  .ro_imm                 (ro_imm[i*CONFIG_DW +: CONFIG_DW]),
                  .ro_prs1                (ro_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ro_prs1_re             (ro_prs1_re[i]),
                  .ro_prs2                (ro_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ro_prs2_re             (ro_prs2_re[i]),
                  .ro_prd                 (ro_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ro_prd_we              (ro_prd_we[i]),
                  .ro_pfree               (ro_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ro_rob_id              (ro_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
                  .ro_rob_bank            (ro_rob_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
                  .issue_alu_opc_bus      (issue_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .issue_lpu_opc_bus      (issue_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
                  .issue_epu_op           (|issue_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
                  .issue_bru_opc_bus      (issue_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                  .issue_lsu_op           (|issue_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
                  .issue_bpu_pred_taken   (bpu_upd_bundle[`BPU_UPD_TAKEN]),
                  .issue_bpu_pred_tgt     (bpu_upd_bundle[`BPU_UPD_TGT]),
                  .issue_pc               (issue_pc[i*`PC_W +: `PC_W]),
                  .issue_imm              (issue_imm[i*CONFIG_DW +: CONFIG_DW]),
                  .issue_prs1             (issue_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prs1_re          (issue_prs1_re[i]),
                  .issue_prs2             (issue_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prs2_re          (issue_prs2_re[i]),
                  .issue_prd              (issue_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prd_we           (issue_prd_we[i]),
                  .issue_pfree            (issue_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_rob_id           (rob_free_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
                  .issue_rob_bank         (rob_free_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
                  .issue_push             (rs_push[i]),
                  .ro_rs_pop              (ro_rs_pop[i]),
               )
             */
            issue_rs
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW),
                 .CONFIG_AW             (CONFIG_AW),
                 .CONFIG_P_ISSUE_WIDTH  (CONFIG_P_ISSUE_WIDTH),
                 .CONFIG_P_COMMIT_WIDTH (CONFIG_P_COMMIT_WIDTH),
                 .CONFIG_P_ROB_DEPTH    (CONFIG_P_ROB_DEPTH),
                 .CONFIG_P_RS_DEPTH     (CONFIG_P_RS_DEPTH))
            U_RS
               (/*AUTOINST*/
                // Outputs
                .issue_rs_full          (issue_rs_full[i]),      // Templated
                .ro_valid               (ro_valid[i]),           // Templated
                .ro_alu_opc_bus         (ro_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .ro_lpu_opc_bus         (ro_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
                .ro_epu_op              (ro_epu_op[i]),          // Templated
                .ro_bru_opc_bus         (ro_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
                .ro_bpu_pred_taken      (ro_bpu_pred_taken[i]),  // Templated
                .ro_bpu_pred_tgt        (ro_bpu_pred_tgt[i * `PC_W +: `PC_W]), // Templated
                .ro_lsu_op              (ro_lsu_op[i]),          // Templated
                .ro_fe                  (ro_fe[i*`NCPU_FE_W +: `NCPU_FE_W]), // Templated
                .ro_pc                  (ro_pc[i*`PC_W +: `PC_W]), // Templated
                .ro_imm                 (ro_imm[i*CONFIG_DW +: CONFIG_DW]), // Templated
                .ro_prs1                (ro_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ro_prs1_re             (ro_prs1_re[i]),         // Templated
                .ro_prs2                (ro_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ro_prs2_re             (ro_prs2_re[i]),         // Templated
                .ro_prd                 (ro_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ro_prd_we              (ro_prd_we[i]),          // Templated
                .ro_rob_id              (ro_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .ro_rob_bank            (ro_rob_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
                // Inputs
                .clk                    (clk),
                .rst                    (rst),
                .flush                  (flush),
                .issue_alu_opc_bus      (issue_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .issue_lpu_opc_bus      (issue_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
                .issue_epu_op           (|issue_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]), // Templated
                .issue_bru_opc_bus      (issue_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
                .issue_lsu_op           (|issue_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]), // Templated
                .issue_fe               (issue_fe[`NCPU_FE_W-1:0]),
                .issue_bpu_pred_taken   (bpu_upd_bundle[`BPU_UPD_TAKEN]), // Templated
                .issue_bpu_pred_tgt     (bpu_upd_bundle[`BPU_UPD_TGT]), // Templated
                .issue_pc               (issue_pc[i*`PC_W +: `PC_W]), // Templated
                .issue_imm              (issue_imm[i*CONFIG_DW +: CONFIG_DW]), // Templated
                .issue_prs1             (issue_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prs1_re          (issue_prs1_re[i]),      // Templated
                .issue_prs2             (issue_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prs2_re          (issue_prs2_re[i]),      // Templated
                .issue_prd              (issue_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prd_we           (issue_prd_we[i]),       // Templated
                .issue_rob_id           (rob_free_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .issue_rob_bank         (rob_free_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
                .issue_push             (rs_push[i]),            // Templated
                .busytable              (busytable[(1<<`NCPU_PRF_AW)-1:0]),
                .ro_rs_pop              (ro_rs_pop[i]));          // Templated
         end
   endgenerate

   assign issue_ready = (~issue_rs_full & {IW{rob_ready}});
   assign rs_push = (issue_push & {IW{issue_p_ce}});
   
   assign rob_push_epu_opc_bus = issue_epu_opc_bus;
   assign rob_push_lsu_opc_bus = issue_lsu_opc_bus;
   assign rob_push_bpu_upd = issue_bpu_upd;
   assign rob_push_pc = issue_pc;
   assign rob_push_lrd = issue_lrd;
   assign rob_push_prd = issue_prd;
   assign rob_push_prd_we = issue_prd_we;
   assign rob_push_pfree = issue_pfree;
   assign rob_push_size = (issue_push_size & {CONFIG_P_ISSUE_WIDTH+1{issue_p_ce}});
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_dec_br
               assign rob_push_is_bcc[i] = (issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BEQ] |
                                             issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BNE] |
                                             issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BGT] |
                                             issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BGTU] |
                                             issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BLE] |
                                             issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_BLEU]);
               assign rob_push_is_brel[i] = issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_JMPREL];
               assign rob_push_is_breg[i] = issue_bru_opc_bus[i*`NCPU_BRU_IOPW + `NCPU_BRU_JMPREG];
         end
   endgenerate
   
   assign ro_rs_pop = (ro_valid & ro_ready);
   
`ifdef ENABLE_DIFFTEST
   wire [31:0] dbg_issue_pc[IW-1:0];
   generate
      for(i=0;i<IW;i=i+1)  
         begin
            assign dbg_issue_pc[i] = {issue_pc[i*`PC_W +: `PC_W], 2'b00};
         end
   endgenerate
`endif

endmodule
