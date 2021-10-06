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
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_WRITEBACK_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   output                              rn_stall_req,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0]                rn_valid,
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_alu_opc_bus,
//   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lsu_opc_bus,
   input [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_fe,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_imm,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs1,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rn_lrs1_re,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] rn_lrs2,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rn_lrs2_re,
   input [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd_we,
   input [CONFIG_P_ISSUE_WIDTH:0] rn_push_size,
   // From CMT
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0] cmt_lrd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] cmt_pfree,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0] cmt_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we,
   // From WB
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)*`NCPU_PRF_AW-1:0] prf_WADDR,
   input [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WE,
   // From issue
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_ready,
   // To issue
   output                              issue_p_ce,
   output [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_alu_opc_bus,
//   output [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lpu_opc_bus,
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
   output [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lrd,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd_we,
   output [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pfree,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_push,
   output [CONFIG_P_ISSUE_WIDTH:0] issue_push_size,
   // Busytable
   output [(1<<`NCPU_PRF_AW)-1:0]       busytable
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] fl_prd;// From U_FL of rn_fl.v
   wire                 fl_stall_req;           // From U_FL of rn_fl.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_pfree;// From U_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs1;// From U_RAT of rn_rat.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] rat_prs2;// From U_RAT of rn_rat.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                p_ce_s1;
   wire                                p_ce_s2;
   wire [IW-1:0]                       fl_pop;                    // To U_RN_FL of rn_fl.v
   wire                                rollback;               // To U_RN_FL of rn_fl.v, ...
   wire [IW-1:0]                       rat_we;                     // To U_RN_RAT of rn_rat.v
   wire [IW-1:0]                       s1o_valid;
   
   /* rn_fl AUTO_TEMPLATE (
      .lrd_we                          (rn_lrd_we),
      .pop                             (fl_pop[]),
      )
    */
   rn_fl
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH))
   U_FL
      (/*AUTOINST*/
       // Outputs
       .fl_stall_req                    (fl_stall_req),
       .fl_prd                          (fl_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .pop                             (fl_pop[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]), // Templated
       .rollback                        (rollback),
       .lrd_we                          (rn_lrd_we),             // Templated
       .cmt_fire                        (cmt_fire[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd_we                      (cmt_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd                         (cmt_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .cmt_pfree                       (cmt_pfree[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]));
      
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
   U_RAT
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
       .cmt_fire                        (cmt_fire[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_lrd                         (cmt_lrd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0]),
       .cmt_prd                         (cmt_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .cmt_prd_we                      (cmt_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]));

   /* rn_busytable AUTO_TEMPLATE (
      .prd                             (fl_prd[]),
      .prd_we                          (rn_lrd_we[]),
   ) */
   rn_busytable
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_WRITEBACK_WIDTH       (CONFIG_P_WRITEBACK_WIDTH))
   U_BUSYTABLE
      (/*AUTOINST*/
       // Outputs
       .busytable                       (busytable[(1<<`NCPU_PRF_AW)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .prd                             (fl_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]), // Templated
       .prd_we                          (rn_lrd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]), // Templated
       .prf_WADDR                       (prf_WADDR[(1<<CONFIG_P_WRITEBACK_WIDTH)*`NCPU_PRF_AW-1:0]),
       .prf_WE                          (prf_WE[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]));

   // Request stall if there is no free PR or reservation station is full
   assign rn_stall_req = (fl_stall_req | ~(&issue_ready));
   
   assign p_ce_s1 = ~(rn_stall_req);
   assign p_ce_s2 = ~(rn_stall_req);
   
   assign fl_pop = (rn_valid & {IW{p_ce_s1}});
   assign rat_we = fl_pop;
   
   assign rollback = flush;
   
   //
   // Pipeline stage
   //
   mDFF_lr # (.DW(IW)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush), .D(rn_valid & {IW{~flush}}), .Q(s1o_valid) );
   mDFF_l # (.DW(`NCPU_ALU_IOPW*IW)) ff_issue_alu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_alu_opc_bus), .Q(issue_alu_opc_bus) );
//   mDFF_l # (.DW(`NCPU_LPU_IOPW*IW)) ff_issue_lpu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lpu_opc_bus), .Q(issue_lpu_opc_bus) );
   mDFF_l # (.DW(`NCPU_EPU_IOPW*IW)) ff_issue_epu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_epu_opc_bus), .Q(issue_epu_opc_bus) );
   mDFF_l # (.DW(`NCPU_BRU_IOPW*IW)) ff_issue_bru_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_bru_opc_bus), .Q(issue_bru_opc_bus) );
   mDFF_l # (.DW(`NCPU_LSU_IOPW*IW)) ff_issue_lsu_opc_bus (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lsu_opc_bus), .Q(issue_lsu_opc_bus) );
   mDFF_l # (.DW(`NCPU_FE_W*IW)) ff_issue_fe (.CLK(clk), .LOAD(p_ce_s1), .D(rn_fe), .Q(issue_fe) );
   mDFF_l # (.DW(`BPU_UPD_W*IW)) ff_issue_bpu_upd (.CLK(clk), .LOAD(p_ce_s1), .D(rn_bpu_upd), .Q(issue_bpu_upd) );
   mDFF_l # (.DW(`PC_W*IW)) ff_issue_pc (.CLK(clk), .LOAD(p_ce_s1), .D(rn_pc), .Q(issue_pc) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_issue_imm (.CLK(clk), .LOAD(p_ce_s1), .D(rn_imm), .Q(issue_imm) );
   mDFF_l # (.DW(`NCPU_PRF_AW*IW)) ff_issue_prs1 (.CLK(clk), .LOAD(p_ce_s1), .D(rat_prs1), .Q(issue_prs1) );
   mDFF_l # (.DW(`NCPU_PRF_AW*IW)) ff_issue_prs2 (.CLK(clk), .LOAD(p_ce_s1), .D(rat_prs2), .Q(issue_prs2) );
   mDFF_l # (.DW(IW)) ff_issue_prs1_re (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs1_re), .Q(issue_prs1_re) );
   mDFF_l # (.DW(IW)) ff_issue_prs2_re (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrs2_re), .Q(issue_prs2_re) );
   mDFF_l # (.DW(`NCPU_PRF_AW*IW)) ff_issue_prd (.CLK(clk), .LOAD(p_ce_s1), .D(fl_prd), .Q(issue_prd) );
   mDFF_l # (.DW(`NCPU_PRF_AW*IW)) ff_issue_pfree (.CLK(clk), .LOAD(p_ce_s1), .D(rat_pfree), .Q(issue_pfree) );
   mDFF_l # (.DW(IW)) ff_issue_prd_we (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrd_we), .Q(issue_prd_we) );
   mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_issue_lrd (.CLK(clk), .LOAD(p_ce_s1), .D(rn_lrd), .Q(issue_lrd) );
   mDFF_lr # (.DW(CONFIG_P_ISSUE_WIDTH+1)) ff_issue_push_size (.CLK(clk), .RST(rst), .LOAD(p_ce_s1|flush), .D(rn_push_size & {CONFIG_P_ISSUE_WIDTH+1{~flush}}), .Q(issue_push_size) );
   
   assign issue_push = s1o_valid;
   
   assign issue_p_ce = p_ce_s2;
   
`ifdef ENABLE_DIFFTEST
   wire [31:0] dbg_rn_pc [IW-1:0];
   wire [`NCPU_LRF_AW-1:0] dbg_rn_lrs1 [IW-1:0];
   wire [`NCPU_LRF_AW-1:0] dbg_rn_lrs2 [IW-1:0];
   wire [`NCPU_LRF_AW-1:0] dbg_rn_lrd [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_rat_prs1 [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_rat_prs2 [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_fl_prd [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_rat_pfree [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_issue_prs1 [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_issue_prs2 [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_issue_prd [IW-1:0];
   wire [`NCPU_PRF_AW-1:0] dbg_issue_pfree [IW-1:0];
   generate
      for(genvar i=0;i<IW;i=i+1)  
         begin
            assign dbg_rn_pc[i] = {rn_pc[i*`PC_W +: `PC_W], 2'b00};
            assign dbg_rn_lrs1[i] = rn_lrs1[i*`NCPU_LRF_AW +: `NCPU_LRF_AW];
            assign dbg_rn_lrs2[i] = rn_lrs2[i*`NCPU_LRF_AW +: `NCPU_LRF_AW];
            assign dbg_rn_lrd[i] = rn_lrd[i*`NCPU_LRF_AW +: `NCPU_LRF_AW];
            assign dbg_rat_prs1[i] = rat_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_rat_prs2[i] = rat_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_fl_prd[i] = fl_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_rat_pfree[i] = rat_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_issue_prs1[i] = issue_prs1[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_issue_prs2[i] = issue_prs2[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_issue_prd[i] = issue_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
            assign dbg_issue_pfree[i] = issue_pfree[i*`NCPU_PRF_AW +: `NCPU_PRF_AW];
         end
   endgenerate
`endif

endmodule
