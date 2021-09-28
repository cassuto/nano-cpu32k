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

module rn
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   output                              rn_stall_req,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0]                rn_valid,
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_alu_opc_bus,
   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_imm,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_operand1,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_operand2,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] rn_lrs1,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] rn_lrs2,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd_we,
   // From commit
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0] commit_lrd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_pfree,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] commit_prd_we,
   // To Issue
   output [`NCPU_ALU_IOPW-1:0]         issue_alu_opc_bus,
   output [`NCPU_LPU_IOPW-1:0]         issue_lpu_opc_bus,
   output [`NCPU_EPU_IOPW-1:0]         issue_epu_opc_bus,
   output [`NCPU_BRU_IOPW-1:0]         issue_bru_opc_bus,
   output [`NCPU_LSU_IOPW-1:0]         issue_lsu_opc_bus,
   output [`BPU_UPD_W-1:0]             issue_bpu_upd,
   output [`PC_W-1:0]                  issue_pc,
   output [CONFIG_DW-1:0]              issue_imm,
   output [`NCPU_PRF_AW-1:0]           issue_prs1,
   output                              issue_prs1_re,
   output [`NCPU_PRF_AW-1:0]           issue_prs2,
   output                              issue_prs2_re,
   output [`NCPU_PRF_AW-1:0]           issue_prd,
   output                              issue_prd_we,
   output [`NCPU_PRF_AW-1:0]           issue_pfree,
   output [CONFIG_P_ROB_DEPTH-1:0]     issue_rob_id,
   output                              issue_push
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd;// From U_RN_FL of rn_fl.v
   wire                 fl_stall_req;           // From U_RN_FL of rn_fl.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_pfree;// From U_RN_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs1;// From U_RN_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs2;// From U_RN_RAT of rn_rat.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                fl_pop;                    // To U_RN_FL of rn_fl.v
   wire                                rollback;               // To U_RN_FL of rn_fl.v, ...
   wire                                rat_we;                     // To U_RN_RAT of rn_rat.v
   
   /* rn_fl AUTO_TEMPLATE (
      .lrd_we                          (rn_lrd_we),
      .pop                             (fl_pop),
      )
    */
   rn_fl
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH))
   U_RN_FL
      (/*AUTOINST*/
       // Outputs
       .fl_stall_req                    (fl_stall_req),
       .fl_prd                          (fl_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .pop                             (fl_pop),                // Templated
       .rollback                        (rollback),
       .lrd_we                          (rn_lrd_we),             // Templated
       .commit_prd_we                   (commit_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .commit_prd                      (commit_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .commit_pfree                    (commit_pfree[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]));
      
   /* rn_rat AUTO_TEMPLATE (
      .lrs1                            (rn_lrs1[]),
      .lrs2                            (rn_lrs2[]),
      .lrd                             (rn_lrd[]),
      .lrd_we                          (rn_lrd_we),
      .we                              (rat_we),
      )
    */
   rn_rat
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH))
   U_RN_RAT
      (/*AUTOINST*/
       // Outputs
       .rat_prs1                        (rat_prs1[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .rat_prs2                        (rat_prs2[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .rat_pfree                       (rat_pfree[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .we                              (rat_we),                // Templated
       .rollback                        (rollback),
       .lrs1                            (rn_lrs1[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0]), // Templated
       .lrs2                            (rn_lrs2[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0]), // Templated
       .lrd                             (rn_lrd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_REG_AW-1:0]), // Templated
       .lrd_we                          (rn_lrd_we),             // Templated
       .fl_prd                          (fl_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .commit_lrd                      (commit_lrd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_REG_AW-1:0]),
       .commit_prd                      (commit_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .commit_prd_we                   (commit_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]));

      
   assign rn_stall_req = (fl_stall_req);
   
endmodule
