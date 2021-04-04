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

module ncpu32k_pipeline_alu
#(
   parameter CONFIG_ALU_ISSUE_QUEUE_DEPTH,
   parameter CONFIG_ALU_INSERT_REG,
   parameter CONFIG_PIPEBUF_BYPASS,
   parameter CONFIG_ROB_DEPTH_LOG2
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   // From DISPATCH
   output                     issue_alu_AREADY,
   input                      issue_alu_AVALID,
   input [`NCPU_ALU_UOPW-1:0] issue_alu_uop,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] issue_id,
   input                      issue_rs1_rdy,
   input [`NCPU_DW-1:0]       issue_rs1_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs1_addr,
   input                      issue_rs2_rdy,
   input [`NCPU_DW-1:0]       issue_rs2_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs2_addr,
   // From BYP
   input                      byp_BVALID,
   input [`NCPU_DW-1:0]       byp_BDATA,
   input                      byp_rd_we,
   input [`NCPU_REG_AW-1:0]   byp_rd_addr,
   // To WRITEBACK
   input                      wb_alu_BREADY,
   output                     wb_alu_BVALID,
   output [`NCPU_DW-1:0]      wb_alu_BDATA,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] wb_alu_BID,
   output                     wb_alu_BBRANCH_REG_TAKEN,
   output                     wb_alu_BBRANCH_REL_TAKEN,
   output                     wb_alu_BBRANCH_OP
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 alu_AREADY;             // From FU_ALU of ncpu32k_alu.v
   wire                 alu_BBRANCH_REG_TAKEN;  // From FU_ALU of ncpu32k_alu.v
   wire                 alu_BBRANCH_REL_TAKEN;  // From FU_ALU of ncpu32k_alu.v
   // End of automatics
   wire                 alu_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] alu_AID;
   wire [`NCPU_ALU_UOPW-1:0] alu_uop;
   wire [`NCPU_ALU_UOPW_OPC-1:0] alu_uop_opc;
   wire [14:0]          alu_rel15;
   wire [`NCPU_ALU_IOPW-1:0] alu_opc_bus;
   wire [`NCPU_DW-1:0]  alu_operand_1, alu_operand_2;

   genvar i;

   ncpu32k_issue_queue
      #(
         .DEPTH      (CONFIG_ALU_ISSUE_QUEUE_DEPTH),
         .UOP_WIDTH  (`NCPU_ALU_IOPW),
         .ALGORITHM  (0) // Out of Order
      )
   ISSUE_QUEUE_ALU
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .i_issue_AVALID   (issue_alu_AVALID),
         .o_issue_AREADY   (issue_alu_AREADY),
         .i_uop      (issue_alu_uop),
         .i_id       (issue_id),
         .i_rs1_rdy  (issue_rs1_rdy),
         .i_rs1_dat  (issue_rs1_dat),
         .i_rs1_addr (issue_rs1_addr),
         .i_rs2_rdy  (issue_rs2_rdy),
         .i_rs2_dat  (issue_rs2_dat),
         .i_rs2_addr (issue_rs2_addr),
         .byp_BVALID (byp_BVALID),
         .byp_BDATA  (byp_BDATA),
         .byp_rd_we  (byp_rd_we),
         .byp_rd_addr   (byp_rd_addr),
         .i_fu_AREADY   (alu_AREADY),
         .o_fu_AVALID   (alu_AVALID),
         .o_fu_id       (alu_AID),
         .o_fu_uop      (alu_uop),
         .o_fu_rs1_dat  (alu_operand_1),
         .o_fu_rs2_dat  (alu_operand_2),
         .o_payload_w_ptr  (),
         .o_payload_r_ptr  ()
      );

   // Unpack uOP for ALU
   assign {alu_rel15[14:0], alu_uop_opc[`NCPU_ALU_UOPW_OPC-1:0]} = alu_uop;
   generate
      for(i=1;i<=`NCPU_ALU_IOPW;i=i+1)
         begin : gen_opc_bus
            assign alu_opc_bus[i-1] = (alu_uop_opc == i[`NCPU_ALU_UOPW_OPC-1:0]);
         end
   endgenerate

   /* ncpu32k_alu AUTO_TEMPLATE (
         .alu_BREADY          (wb_alu_BREADY),
         .alu_BVALID          (wb_alu_BVALID),
         .alu_BDATA           (wb_alu_BDATA),
         .alu_BID             (wb_alu_BID),
         .alu_BBRANCH_REG     (wb_alu_BBRANCH_REG_TAKEN),
         .alu_BBRANCH_REL     (wb_alu_BBRANCH_REL_TAKEN),
         .alu_BBRANCH_OP      (wb_alu_BBRANCH_OP),
      )
   */
   ncpu32k_alu
      #(
         .CONFIG_ALU_INSERT_REG  (CONFIG_ALU_INSERT_REG),
         .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS)
      )
   FU_ALU
      (/*AUTOINST*/
       // Outputs
       .alu_AREADY                      (alu_AREADY),
       .alu_BVALID                      (wb_alu_BVALID),         // Templated
       .alu_BID                         (wb_alu_BID),            // Templated
       .alu_BDATA                       (wb_alu_BDATA),          // Templated
       .alu_BBRANCH_REG_TAKEN           (alu_BBRANCH_REG_TAKEN),
       .alu_BBRANCH_REL_TAKEN           (alu_BBRANCH_REL_TAKEN),
       .alu_BBRANCH_OP                  (wb_alu_BBRANCH_OP),     // Templated
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .flush                           (flush),
       .alu_AVALID                      (alu_AVALID),
       .alu_operand_1                   (alu_operand_1[`NCPU_DW-1:0]),
       .alu_operand_2                   (alu_operand_2[`NCPU_DW-1:0]),
       .alu_rel15                       (alu_rel15[14:0]),
       .alu_AID                         (alu_AID[CONFIG_ROB_DEPTH_LOG2-1:0]),
       .alu_opc_bus                     (alu_opc_bus[`NCPU_ALU_IOPW-1:0]),
       .alu_BREADY                      (wb_alu_BREADY));         // Templated

endmodule
