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
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0,
   parameter                           CONFIG_P_RS_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   // From RN
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_alu_opc_bus,
   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_imm,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1_re,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2_re,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd_we,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pfree,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_push,
   input [(1<<`NCPU_PRF_AW)-1:0]       busytable,
   // To RN
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_ready,
   // From ROB
   input                               rob_ready,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank, 
   // To ROB
   output [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_alu_opc_bus,
   output [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_lpu_opc_bus,
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_epu_opc_bus,
   output [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_bru_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_lsu_opc_bus,
   output [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_pc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pfree,
   output [CONFIG_P_COMMIT_WIDTH:0]    rob_push_size,
   // From EX
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_ready,
   // To EX
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] ex_bpu_upd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_EPU_IOPW-1:0] ex_epu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LSU_IOPW-1:0] ex_lsu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prd_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prs1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prs1_re,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prs2_re,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid
);
   localparam  IW                      = (1<<CONFIG_P_ISSUE_WIDTH)
   /*AUTOWIRE*/
   /*AUTOINPUT*/
   wire [IW-1:0]                       issue_rs_full;          // From U_RS of issue_rs.v
   wire [IW-1:0]                       ex_rs_pop;
   wire [CONFIG_P_ROB_DEPTH*IW-1:0]    issue_rob_id;           // To U_RS of issue_rs.v
   wire [CONFIG_P_COMMIT_WIDTH*IW-1:0] issue_rob_bank;         // To U_RS of issue_rs.v
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_RS
            /* issue_rs AUTO_TEMPLATE (
                  .issue_rs_full          (issue_rs_full[i]),
                  .ex_valid               (ex_valid[i]),
                  .ex_alu_opc_bus         (ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ex_lpu_opc_bus         (ex_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
                  .ex_epu_opc_bus         (ex_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
                  .ex_bru_opc_bus         (ex_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                  .ex_lsu_opc_bus         (ex_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
                  .ex_bpu_upd             (ex_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W]),
                  .ex_pc                  (ex_pc[i*`PC_W +: `PC_W]),
                  .ex_imm                 (ex_imm[i*CONFIG_DW +: CONFIG_DW]),
                  .ex_prs1                (ex_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ex_prs1_re             (ex_prs1_re[i]),
                  .ex_prs2                (ex_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ex_prs2_re             (ex_prs2_re[i]),
                  .ex_prd                 (ex_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ex_prd_we              (ex_prd_we[i]),
                  .ex_pfree               (ex_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .ex_rob_id              (ex_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
                  .issue_alu_opc_bus      (issue_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .issue_lpu_opc_bus      (issue_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
                  .issue_epu_opc_bus      (issue_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
                  .issue_bru_opc_bus      (issue_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                  .issue_lsu_opc_bus      (issue_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
                  .issue_bpu_upd          (issue_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W]),
                  .issue_pc               (issue_pc[i*`PC_W +: `PC_W]),
                  .issue_imm              (issue_imm[i*CONFIG_DW +: CONFIG_DW]),
                  .issue_prs1             (issue_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prs1_re          (issue_prs1_re[i]),
                  .issue_prs2             (issue_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prs2_re          (issue_prs2_re[i]),
                  .issue_prd              (issue_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_prd_we           (issue_prd_we[i]),
                  .issue_pfree            (issue_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]),
                  .issue_rob_id           (issue_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]),
                  .issue_rob_bank         (issue_rob_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]),
                  .issue_push             (issue_push[i]),
                  .ex_rs_pop              (ex_rs_pop[i]),
               )
             */
            issue_rs
               #(/*AUTOPARAM*/)
            U_RS
               (/*AUTOINST*/
                // Outputs
                .issue_rs_full          (issue_rs_full[i]),      // Templated
                .ex_valid               (ex_valid[i]),           // Templated
                .ex_alu_opc_bus         (ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .ex_lpu_opc_bus         (ex_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
                .ex_epu_opc_bus         (ex_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]), // Templated
                .ex_bru_opc_bus         (ex_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
                .ex_lsu_opc_bus         (ex_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]), // Templated
                .ex_bpu_upd             (ex_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W]), // Templated
                .ex_pc                  (ex_pc[i*`PC_W +: `PC_W]), // Templated
                .ex_imm                 (ex_imm[i*CONFIG_DW +: CONFIG_DW]), // Templated
                .ex_prs1                (ex_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ex_prs1_re             (ex_prs1_re[i]),         // Templated
                .ex_prs2                (ex_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ex_prs2_re             (ex_prs2_re[i]),         // Templated
                .ex_prd                 (ex_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ex_prd_we              (ex_prd_we[i]),          // Templated
                .ex_pfree               (ex_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .ex_rob_id              (ex_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .ex_rob_bank            (ex_rob_bank[CONFIG_P_COMMIT_WIDTH-1:0]),
                // Inputs
                .clk                    (clk),
                .rst                    (rst),
                .issue_alu_opc_bus      (issue_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), // Templated
                .issue_lpu_opc_bus      (issue_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), // Templated
                .issue_epu_opc_bus      (issue_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]), // Templated
                .issue_bru_opc_bus      (issue_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), // Templated
                .issue_lsu_opc_bus      (issue_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]), // Templated
                .issue_bpu_upd          (issue_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W]), // Templated
                .issue_pc               (issue_pc[i*`PC_W +: `PC_W]), // Templated
                .issue_imm              (issue_imm[i*CONFIG_DW +: CONFIG_DW]), // Templated
                .issue_prs1             (issue_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prs1_re          (issue_prs1_re[i]),      // Templated
                .issue_prs2             (issue_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prs2_re          (issue_prs2_re[i]),      // Templated
                .issue_prd              (issue_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_prd_we           (issue_prd_we[i]),       // Templated
                .issue_pfree            (issue_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]), // Templated
                .issue_rob_id           (issue_rob_id[i*CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), // Templated
                .issue_rob_bank         (issue_rob_bank[i*CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), // Templated
                .issue_push             (issue_push[i]),         // Templated
                .busytable              (busytable[(1<<`NCPU_PRF_AW)-1:0]),
                .ex_rs_pop              (ex_rs_pop[i]));          // Templated
         end
   endgenerate

   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_ready
            assign ex_rs_pop[i] = (ex_valid[i] & ex_ready[i]);
            assign issue_ready[i] = (~issue_rs_full[i]);
         end
   endgenerate
   
endmodule
