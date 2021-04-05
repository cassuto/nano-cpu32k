/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_wb_commit
#(
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDTM_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDPF_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EALIGN_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EITM_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIPF_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_ESYSCALL_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EINSN_VECTOR `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EIRQ_VECTOR `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   // From ALU
   output                     wb_alu_BREADY,
   input                      wb_alu_BVALID,
   input [`NCPU_DW-1:0]       wb_alu_BDATA,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] wb_alu_BID,
   input                      wb_alu_BBRANCH_REG_TAKEN,
   input                      wb_alu_BBRANCH_REL_TAKEN,
   input                      wb_alu_BBRANCH_OP,
   // From LPU
   output                     wb_lpu_BREADY,
   input                      wb_lpu_BVALID,
   input [`NCPU_DW-1:0]       wb_lpu_BDATA,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] wb_lpu_BID,
   // From FPU
   output                     wb_fpu_BREADY,
   input                      wb_fpu_BVALID,
   input [`NCPU_DW-1:0]       wb_fpu_BDATA,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] wb_fpu_BID,
   // From AGU
   output                     wb_agu_BREADY,
   input                      wb_agu_BVALID,
   input [`NCPU_DW-1:0]       wb_agu_BDATA,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] wb_agu_BID,
   input                      wb_agu_BEDTM,
   input                      wb_agu_BEDPF,
   input                      wb_agu_BEALIGN,
   // From EPU
   output                     wb_epu_BREADY,
   input                      wb_epu_BVALID,
   input [`NCPU_DW-1:0]       wb_epu_BDATA,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] wb_epu_BID,
   input                      wb_epu_BERET,
   input                      wb_epu_BESYSCALL,
   input                      wb_epu_BEINSN,
   input                      wb_epu_BEIPF,
   input                      wb_epu_BEITM,
   input                      wb_epu_BEIRQ,
   // To EPU & AGU
   output [CONFIG_ROB_DEPTH_LOG2-1:0] rob_commit_ptr,
   output [`NCPU_AW-3:0]      rob_commit_pc,
   // To regfile
   output [`NCPU_REG_AW-1:0]  arf_din_addr,
   output [`NCPU_DW-1:0]      arf_din,
   output                     arf_we,
   // To BYP
   output                     byp_BVALID,
   output [`NCPU_DW-1:0]      byp_BDATA,
   output                     byp_rd_we,
   output [`NCPU_REG_AW-1:0]  byp_rd_addr,
   // To all
   output                     flush,
   output [`NCPU_AW-3:0]      flush_tgt,
   // From DISPATCH
   input                      rob_disp_AVALID,
   output                     rob_disp_AREADY,
   input [`NCPU_AW-3:0]       rob_disp_pc,
   input [`NCPU_AW-3:0]       rob_disp_pred_tgt,
   input                      rob_disp_rd_we,
   input [`NCPU_REG_AW-1:0]   rob_disp_rd_addr,
   input [`NCPU_REG_AW-1:0]   rob_disp_rs1_addr,
   input [`NCPU_REG_AW-1:0]   rob_disp_rs2_addr,
   output                     rob_disp_rs1_in_ROB,
   output                     rob_disp_rs1_in_ARF,
   output [`NCPU_DW-1:0]      rob_disp_rs1_dat,
   output                     rob_disp_rs2_in_ROB,
   output                     rob_disp_rs2_in_ARF,
   output [`NCPU_DW-1:0]      rob_disp_rs2_dat,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] rob_disp_id,
   // To BPU
   output                     bpu_wb,
   output [`NCPU_AW-3:0]      bpu_wb_insn_pc,
   output                     bpu_wb_taken,
   output [`NCPU_AW-3:0]      bpu_wb_tgt
);

   localparam N_FU = 5; // EPU + ALU + LPU + AGU + FPU
   localparam EXC_WIDTH = 4;
   localparam TAG_WIDTH = 1 + EXC_WIDTH; // B + EXC
   localparam DEPTH_WIDTH = CONFIG_ROB_DEPTH_LOG2;

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  rob_commit_BDATA;       // From ROB of ncpu32k_rob.v
   wire [TAG_WIDTH-1:0] rob_commit_BTAG;        // From ROB of ncpu32k_rob.v
   wire                 rob_commit_BVALID;      // From ROB of ncpu32k_rob.v
   wire [`NCPU_AW-3:0]  rob_commit_pred_tgt;    // From ROB of ncpu32k_rob.v
   wire [`NCPU_REG_AW-1:0] rob_commit_rd_addr;  // From ROB of ncpu32k_rob.v
   wire                 rob_commit_rd_we;       // From ROB of ncpu32k_rob.v
   wire                 rob_wb_BREADY;          // From ROB of ncpu32k_rob.v
   // End of automatics
   wire [TAG_WIDTH-1:0]       wb_epu_tag;
   wire [TAG_WIDTH-1:0]       wb_alu_tag;
   wire [TAG_WIDTH-1:0]       wb_lpu_tag;
   wire [TAG_WIDTH-1:0]       wb_agu_tag;
   wire [TAG_WIDTH-1:0]       wb_fpu_tag;
   wire [EXC_WIDTH-1:0]       wb_epu_exc;
   wire [EXC_WIDTH-1:0]       wb_alu_exc;
   wire [EXC_WIDTH-1:0]       wb_lpu_exc;
   wire [EXC_WIDTH-1:0]       wb_agu_exc;
   wire [EXC_WIDTH-1:0]       wb_fpu_exc;
   wire [N_FU-1:0]            fu_wb_BVALID;
   wire [N_FU-1:0]            fu_wb_BREADY;
   wire [N_FU*`NCPU_DW-1:0]   fu_wb_BDATA;
   wire [N_FU*TAG_WIDTH-1:0]  fu_wb_BTAG;
   wire [N_FU*CONFIG_ROB_DEPTH_LOG2-1:0] fu_wb_id;
   wire                       rob_wb_BVALID;
   wire [`NCPU_DW-1:0]        rob_wb_BDATA;
   wire [TAG_WIDTH-1:0]       rob_wb_BTAG;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] rob_wb_id;
   wire                       rob_commit_BREADY;
   wire                       commit_branch_op;
   wire [EXC_WIDTH-1:0]       commit_exc;
   wire [`NCPU_AW-3:0]        pc_nxt;
   wire                       branch_taken;
   wire                       exc_taken;
   wire                       sef_taken;

   // Encode exceptions
   // Assert (2104022034)
   assign wb_epu_exc = ({EXC_WIDTH{wb_epu_BEITM}} & 4'd1) |
                        ({EXC_WIDTH{wb_epu_BEIPF}} & 4'd2) |
                        ({EXC_WIDTH{wb_epu_BEINSN}} & 4'd3) |
                        ({EXC_WIDTH{wb_epu_BESYSCALL}} & 4'd4) |
                        ({EXC_WIDTH{wb_epu_BERET}} & 4'd5) |
                        ({EXC_WIDTH{wb_epu_BEIRQ}} & 4'd6);
   localparam [EXC_WIDTH-1:0] EXC_BRANCH_REG_TAKEN = 4'd7;
   localparam [EXC_WIDTH-1:0] EXC_BRANCH_REL_TAKEN = 4'd8;
   assign wb_alu_exc = ({EXC_WIDTH{wb_alu_BBRANCH_REG_TAKEN}} & EXC_BRANCH_REG_TAKEN) |
                        ({EXC_WIDTH{wb_alu_BBRANCH_REL_TAKEN}} & EXC_BRANCH_REL_TAKEN);
   assign wb_lpu_exc = {EXC_WIDTH{1'b0}};
   assign wb_agu_exc = ({EXC_WIDTH{wb_agu_BEDTM}} & 4'd9) |
                        ({EXC_WIDTH{wb_agu_BEDPF}} & 4'd10) |
                        ({EXC_WIDTH{wb_agu_BEALIGN}} & 4'd11);
   assign wb_fpu_exc = {EXC_WIDTH{1'b0}};

   assign wb_epu_tag = {1'b0, wb_epu_exc[EXC_WIDTH-1:0]};
   assign wb_alu_tag = {wb_alu_BBRANCH_OP, wb_alu_exc[EXC_WIDTH-1:0]};
   assign wb_lpu_tag = {1'b0, wb_lpu_exc[EXC_WIDTH-1:0]};
   assign wb_agu_tag = {1'b0, wb_agu_exc[EXC_WIDTH-1:0]};
   assign wb_fpu_tag = {1'b0, wb_fpu_exc[EXC_WIDTH-1:0]};

   assign fu_wb_BVALID = {wb_fpu_BVALID, wb_agu_BVALID, wb_lpu_BVALID, wb_alu_BVALID, wb_epu_BVALID};
   assign {wb_fpu_BREADY, wb_agu_BREADY, wb_lpu_BREADY, wb_alu_BREADY, wb_epu_BREADY} = fu_wb_BREADY;
   assign fu_wb_BDATA = {wb_fpu_BDATA[`NCPU_DW-1:0], wb_agu_BDATA[`NCPU_DW-1:0], wb_lpu_BDATA[`NCPU_DW-1:0], wb_alu_BDATA[`NCPU_DW-1:0], wb_epu_BDATA[`NCPU_DW-1:0]};
   assign fu_wb_BTAG = {wb_fpu_tag[TAG_WIDTH-1:0], wb_agu_tag[TAG_WIDTH-1:0], wb_lpu_tag[TAG_WIDTH-1:0], wb_alu_tag[TAG_WIDTH-1:0], wb_epu_tag[TAG_WIDTH-1:0]};
   assign fu_wb_id = {wb_fpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0], wb_agu_BID[CONFIG_ROB_DEPTH_LOG2-1:0],
                     wb_lpu_BID[CONFIG_ROB_DEPTH_LOG2-1:0], wb_alu_BID[CONFIG_ROB_DEPTH_LOG2-1:0],
                     wb_epu_BID[CONFIG_ROB_DEPTH_LOG2-1:0]};

   ncpu32k_byp_arbiter
      #(
         .WAYS (N_FU),
         .TAG_WIDTH  (TAG_WIDTH),
         .ID_WIDTH (CONFIG_ROB_DEPTH_LOG2)
      )
   BYP_ARBITER
      (
         .clk                 (clk),
         .rst_n               (rst_n),
         .fu_wb_BVALID        (fu_wb_BVALID),
         .fu_wb_BREADY        (fu_wb_BREADY),
         .fu_wb_BDATA         (fu_wb_BDATA),
         .fu_wb_BTAG          (fu_wb_BTAG),
         .fu_wb_id            (fu_wb_id),
         .rob_wb_BVALID       (rob_wb_BVALID),
         .rob_wb_BREADY       (rob_wb_BREADY),
         .rob_wb_BDATA        (rob_wb_BDATA),
         .rob_wb_BTAG         (rob_wb_BTAG),
         .rob_wb_id           (rob_wb_id)
      );

   assign byp_BVALID = rob_wb_BVALID;
   assign byp_BDATA = rob_wb_BDATA;

   ncpu32k_rob
      #(
         .DEPTH_WIDTH (DEPTH_WIDTH),
         .TAG_WIDTH  (TAG_WIDTH)
      )
   ROB
      (/*AUTOINST*/
       // Outputs
       .rob_disp_AREADY                 (rob_disp_AREADY),
       .rob_disp_rs1_in_ROB             (rob_disp_rs1_in_ROB),
       .rob_disp_rs1_in_ARF             (rob_disp_rs1_in_ARF),
       .rob_disp_rs1_dat                (rob_disp_rs1_dat[`NCPU_DW-1:0]),
       .rob_disp_rs2_in_ROB             (rob_disp_rs2_in_ROB),
       .rob_disp_rs2_in_ARF             (rob_disp_rs2_in_ARF),
       .rob_disp_rs2_dat                (rob_disp_rs2_dat[`NCPU_DW-1:0]),
       .rob_disp_id                     (rob_disp_id[DEPTH_WIDTH-1:0]),
       .rob_wb_BREADY                   (rob_wb_BREADY),
       .byp_rd_we                       (byp_rd_we),
       .byp_rd_addr                     (byp_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_commit_BVALID               (rob_commit_BVALID),
       .rob_commit_pc                   (rob_commit_pc[`NCPU_AW-3:0]),
       .rob_commit_pred_tgt             (rob_commit_pred_tgt[`NCPU_AW-3:0]),
       .rob_commit_rd_we                (rob_commit_rd_we),
       .rob_commit_rd_addr              (rob_commit_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_commit_BDATA                (rob_commit_BDATA[`NCPU_DW-1:0]),
       .rob_commit_BTAG                 (rob_commit_BTAG[TAG_WIDTH-1:0]),
       .rob_commit_ptr                  (rob_commit_ptr[DEPTH_WIDTH-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .rob_disp_AVALID                 (rob_disp_AVALID),
       .rob_disp_pc                     (rob_disp_pc[`NCPU_AW-3:0]),
       .rob_disp_pred_tgt               (rob_disp_pred_tgt[`NCPU_AW-3:0]),
       .rob_disp_rd_we                  (rob_disp_rd_we),
       .rob_disp_rd_addr                (rob_disp_rd_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs1_addr               (rob_disp_rs1_addr[`NCPU_REG_AW-1:0]),
       .rob_disp_rs2_addr               (rob_disp_rs2_addr[`NCPU_REG_AW-1:0]),
       .rob_wb_BVALID                   (rob_wb_BVALID),
       .rob_wb_BDATA                    (rob_wb_BDATA[`NCPU_DW-1:0]),
       .rob_wb_BTAG                     (rob_wb_BTAG[TAG_WIDTH-1:0]),
       .rob_wb_id                       (rob_wb_id[DEPTH_WIDTH-1:0]),
       .rob_commit_BREADY               (rob_commit_BREADY));

   assign {commit_branch_op, commit_exc[EXC_WIDTH-1:0]} = rob_commit_BTAG;

   //
   // Flush Request
   //

   assign pc_nxt = ({`NCPU_AW-2{commit_exc==4'd1}} & CONFIG_EITM_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd2}} &  CONFIG_EIPF_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd3}} & CONFIG_EINSN_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd4}} & CONFIG_ESYSCALL_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd5}} & rob_commit_BDATA[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd6}} & CONFIG_EIRQ_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd7}} & rob_commit_BDATA[`NCPU_AW-1:2]) | // JMPREG
                     ({`NCPU_AW-2{commit_exc==4'd8}} & (rob_commit_pc + rob_commit_BDATA[`NCPU_AW-1:2])) | // JMPREL
                     ({`NCPU_AW-2{commit_exc==4'd9}} & CONFIG_EDTM_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd10}} & CONFIG_EDPF_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd11}} & CONFIG_EALIGN_VECTOR[`NCPU_AW-1:2]) |
                     ({`NCPU_AW-2{commit_exc==4'd0}} & (rob_commit_pc + 1'b1));

   // The actually calculated result of the branch insn
   assign branch_taken = (commit_exc==EXC_BRANCH_REG_TAKEN) | (commit_exc==EXC_BRANCH_REL_TAKEN);
   // Tell if an exception raised.
   assign exc_taken = (|commit_exc) & ~branch_taken;
   // Check if speculative execution (SE) failed
   assign sef_taken = ~exc_taken & (rob_commit_pred_tgt != pc_nxt);

   // Assert (2104032354)
   assign flush = rob_commit_BVALID & (exc_taken | sef_taken);
   assign flush_tgt = pc_nxt;


   //
   // Commit
   //

   assign bpu_wb = rob_commit_BVALID & commit_branch_op;
   assign bpu_wb_insn_pc = rob_commit_pc;
   assign bpu_wb_taken = branch_taken;
   assign bpu_wb_tgt = pc_nxt;

   assign arf_we = rob_commit_BVALID & rob_commit_rd_we & ~exc_taken;
   assign arf_din_addr = rob_commit_rd_addr;
   assign arf_din = rob_commit_BDATA;

   // ARF, BPU and flush logics are always ready
   assign rob_commit_BREADY = 1'b1;

// synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertion 2104022034
         if (count_1({wb_epu_BEITM, wb_epu_BEIPF,
                        wb_epu_BEINSN,
                        wb_epu_BESYSCALL, wb_epu_BERET,
                        wb_epu_BEIRQ}) > 1 ||
            count_1({wb_alu_BBRANCH_REG_TAKEN, wb_alu_BBRANCH_REL_TAKEN}) > 1 ||
            count_1({wb_agu_BEDTM, wb_agu_BEDPF, wb_agu_BEALIGN}) > 1
         )
            $fatal(1, "\n Bugs on exception sources (IMMU, IDU, AGU and DMMU)\n");
         // Assertion 2104032354
         if (sef_taken & exc_taken)
            $fatal(1, "\n Bugs on SE and exception\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
