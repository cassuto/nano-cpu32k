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

module ncpu32k_pipeline_lpu
#(
   parameter CONFIG_LPU_ISSUE_QUEUE_DEPTH,
   parameter CONFIG_ENABLE_MUL,
   parameter CONFIG_ENABLE_DIV,
   parameter CONFIG_ENABLE_DIVU,
   parameter CONFIG_ENABLE_MOD,
   parameter CONFIG_ENABLE_MODU,
   parameter CONFIG_PIPEBUF_BYPASS,
   parameter CONFIG_ROB_DEPTH_LOG2
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   // From DISPATCH
   output                     issue_lpu_AREADY,
   input                      issue_lpu_AVALID,
   input [`NCPU_LPU_UOPW-1:0] issue_lpu_uop,
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
   input                      wb_lpu_BREADY,
   output                     wb_lpu_BVALID,
   output [`NCPU_DW-1:0]      wb_lpu_BDATA,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] wb_lpu_BID
);

generate
   if (CONFIG_ENABLE_MUL || CONFIG_ENABLE_DIV || CONFIG_ENABLE_DIVU || CONFIG_ENABLE_MOD || CONFIG_ENABLE_MODU)
      begin
         /*AUTOWIRE*/
         // Beginning of automatic wires (for undeclared instantiated-module outputs)
         wire            lpu_AREADY;             // From FU_LPU of ncpu32k_lpu.v
         // End of automatics
         wire                 lpu_AVALID;
         wire [CONFIG_ROB_DEPTH_LOG2-1:0] lpu_AID;
         wire [`NCPU_LPU_UOPW-1:0] lpu_uop;
         wire [`NCPU_LPU_IOPW-1:0] lpu_opc_bus;
         wire [`NCPU_DW-1:0]  lpu_operand_1, lpu_operand_2;

         genvar i;

         ncpu32k_issue_queue
            #(
               .DEPTH      (CONFIG_LPU_ISSUE_QUEUE_DEPTH),
               .UOP_WIDTH  (`NCPU_LPU_IOPW),
               .ALGORITHM  (0) // Out of Order
            )
         ISSUE_QUEUE_LPU
            (
               .clk        (clk),
               .rst_n      (rst_n),
               .i_issue_AVALID   (issue_lpu_AVALID),
               .o_issue_AREADY   (issue_lpu_AREADY),
               .i_uop      (issue_lpu_uop),
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
               .i_fu_AREADY   (lpu_AREADY),
               .o_fu_AVALID   (lpu_AVALID),
               .o_fu_id       (lpu_AID),
               .o_fu_uop      (lpu_uop),
               .o_fu_rs1_dat  (lpu_operand_1),
               .o_fu_rs2_dat  (lpu_operand_2),
               .o_payload_w_ptr  (),
               .o_payload_r_ptr  ()
            );

         // Unpack uOP for LPU
         for(i=1;i<=`NCPU_LPU_IOPW;i=i+1)
            begin : gen_opc_bus
               assign lpu_opc_bus[i-1] = (lpu_uop == i[`NCPU_LPU_UOPW-1:0]);
            end

         /* ncpu32k_lpu AUTO_TEMPLATE (
               .lpu_BREADY    (wb_lpu_BREADY),
               .lpu_BVALID    (wb_lpu_BVALID),
               .lpu_BDATA     (wb_lpu_BDATA),
               .lpu_BID       (wb_lpu_BID),
            )
         */
         ncpu32k_lpu
            #(
               .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS)
            )
         FU_LPU
            (/*AUTOINST*/
             // Outputs
             .lpu_AREADY                (lpu_AREADY),
             .lpu_BVALID                (wb_lpu_BVALID),         // Templated
             .lpu_BID                   (wb_lpu_BID),            // Templated
             .lpu_BDATA                 (wb_lpu_BDATA),          // Templated
             // Inputs
             .clk                       (clk),
             .rst_n                     (rst_n),
             .flush                     (flush),
             .lpu_AVALID                (lpu_AVALID),
             .lpu_operand_1             (lpu_operand_1[`NCPU_DW-1:0]),
             .lpu_operand_2             (lpu_operand_2[`NCPU_DW-1:0]),
             .lpu_AID                   (lpu_AID[CONFIG_ROB_DEPTH_LOG2-1:0]),
             .lpu_opc_bus               (lpu_opc_bus[`NCPU_LPU_IOPW-1:0]),
             .lpu_BREADY                (wb_lpu_BREADY));         // Templated
      end
   else
      begin
         assign issue_lpu_AREADY = 1'b0;
         assign wb_lpu_BVALID = 1'b0;
         assign wb_lpu_BDATA = {`NCPU_DW{1'b0}};
         assign wb_lpu_BID = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
      end
   endgenerate
   
endmodule
