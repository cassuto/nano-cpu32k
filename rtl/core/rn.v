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
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           WRITEBACK_WIDTH = 0
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
   input [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_fe,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_imm,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs1,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs1_re,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs2,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs2_re,
   input [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd_we,
   // From CMT
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] commit_lrd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_pfree,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] commit_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] commit_prd_we,
   // From WB
   input [WRITEBACK_WIDTH*`NCPU_PRF_AW-1:0] wb_lrd,
   input [WRITEBACK_WIDTH-1:0]         wb_lrd_we,
   // From issue
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_ready,
   // To issue
   output [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_alu_opc_bus,
   output [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lpu_opc_bus,
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_epu_opc_bus,
   output [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bru_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lsu_opc_bus,
   output [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_fe,
   output [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pc,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_imm,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1_re,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2_re,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_push,
   // Busytable
   output [(1<<`NCPU_PRF_AW)-1:0]       busytable
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd;// From U_RN_FL of rn_fl.v
   wire                 fl_stall_req;           // From U_RN_FL of rn_fl.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_pfree;// From U_RN_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs1;// From U_RN_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs2;// From U_RN_RAT of rn_rat.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                p_ce_s1;
   wire                                p_ce_s2;
   wire                                fl_pop;                    // To U_RN_FL of rn_fl.v
   wire                                rollback;               // To U_RN_FL of rn_fl.v, ...
   wire                                rat_we;                     // To U_RN_RAT of rn_rat.v
   wire [IW-1:0]                       s1o_valid;
   
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
       .lrs1                            (rn_lrs1[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0]), // Templated
       .lrs2                            (rn_lrs2[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0]), // Templated
       .lrd                             (rn_lrd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LRF_AW-1:0]), // Templated
       .lrd_we                          (rn_lrd_we),             // Templated
       .fl_prd                          (fl_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .commit_lrd                      (commit_lrd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0]),
       .commit_prd                      (commit_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .commit_prd_we                   (commit_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]));

   /* rn_busytable AUTO_TEMPLATE (
      .lrd                             (rn_lrd[]),
      .lrd_we                          (rn_lrd_we[]),
   ) */
   rn_busytable
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .WRITEBACK_WIDTH                (WRITEBACK_WIDTH))
   U_BUSYTABLE
      (/*AUTOINST*/
       // Outputs
       .busytable                       (busytable[(1<<`NCPU_PRF_AW)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .lrd                             (rn_lrd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]), // Templated
       .lrd_we                          (rn_lrd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]), // Templated
       .wb_lrd                          (wb_lrd[WRITEBACK_WIDTH*`NCPU_PRF_AW-1:0]),
       .wb_lrd_we                       (wb_lrd_we[WRITEBACK_WIDTH-1:0]));

   // Request stall if there is no free PR or reservation station is full
   assign rn_stall_req = (fl_stall_req | ~issue_ready);
   
   assign p_ce_s1 = ~(rn_stall_req);
   assign p_ce_s2 = ~(rn_stall_req);
   
   assign fl_pop = (rn_valid & {IW{p_ce_s1}});
   assign rat_we = fl_pop;
   
   assign rollback = flush;
   
   //
   // Pipeline stage
   //
   mDFF_lr # (.DW(IW)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush), .D(issue_valid & {IW{~flush}}), .Q(s1o_valid) );
   mDFF_l # (.DW(`NCPU_ALU_IOPW*IW)) ff_issue_alu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_alu_opc_bus), .Q(issue_alu_opc_bus) );
   mDFF_l # (.DW(`NCPU_LPU_IOPW*IW)) ff_issue_lpu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lpu_opc_bus), .Q(issue_lpu_opc_bus) );
   mDFF_l # (.DW(`NCPU_EPU_IOPW*IW)) ff_issue_epu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_epu_opc_bus), .Q(issue_epu_opc_bus) );
   mDFF_l # (.DW(`NCPU_BRU_IOPW*IW)) ff_issue_bru_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_bru_opc_bus), .Q(issue_bru_opc_bus) );
   mDFF_l # (.DW(`NCPU_LSU_IOPW*IW)) ff_issue_lsu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lsu_opc_bus), .Q(issue_lsu_opc_bus) );
   mDFF_l # (.DW(`NCPU_FE_W*IW)) ff_issue_fe (.CLK(clk), .LOAD(p_ce_s1), .D(rn_fe), .Q(issue_fe) );
   mDFF_l # (.DW(`BPU_UPD_W*IW)) ff_issue_bpu_upd (.CLK(clk), .LOAD(p_ce_s1), .D(rn_bpu_upd), .Q(issue_bpu_upd) );
   mDFF_l # (.DW(`PC_W*IW)) ff_issue_pc (.CLK(clk), .LOAD(p_ce_s1), .D(rn_pc), .Q(issue_pc) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_issue_imm (.CLK(clk), .LOAD(p_ce_s1), .D(rn_imm), .Q(issue_imm) );
   mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_issue_lrs1 (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs1), .Q(issue_lrs1) );
   mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_issue_lrs2 (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs2), .Q(issue_lrs2) );
   mDFF_l # (.DW(IW)) ff_issue_lrs1_re (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs1_re), .Q(issue_lrs1_re) );
   mDFF_l # (.DW(IW)) ff_issue_lrs2_re (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs2_re), .Q(issue_lrs2_re) );
   mDFF_l # (.DW(IW)) ff_issue_lrd_we (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrd_we), .Q(issue_lrd_we) );
   mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_issue_lrd (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrd), .Q(issue_lrd) );
   
   assign issue_push = (s1o_valid & {IW{p_ce_s2}});
   
endmodule
