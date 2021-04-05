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

module ncpu32k_pipeline_fpu
#(
   parameter CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2,
   parameter CONFIG_ENABLE_FPU,
   parameter CONFIG_PIPEBUF_BYPASS,
   parameter CONFIG_ROB_DEPTH_LOG2
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   // From DISPATCH
   output                     issue_fpu_AREADY,
   input                      issue_fpu_AVALID,
   input [`NCPU_FPU_UOPW-1:0] issue_fpu_uop,
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
   input                      wb_fpu_BREADY,
   output                     wb_fpu_BVALID,
   output [`NCPU_DW-1:0]      wb_fpu_BDATA,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] wb_fpu_BID
);

generate
   if (CONFIG_ENABLE_FPU)
      begin
         /*AUTOWIRE*/
         // Beginning of automatic wires (for undeclared instantiated-module outputs)
         wire            fpu_AREADY;             // From FU_FPU of ncpu32k_fpu.v
         // End of automatics
         wire                 fpu_AVALID;
         wire [CONFIG_ROB_DEPTH_LOG2-1:0] fpu_AID;
         wire [`NCPU_FPU_UOPW-1:0] fpu_uop;
         wire [`NCPU_FPU_IOPW-1:0] fpu_opc_bus;
         wire [`NCPU_DW-1:0]  fpu_operand_1, fpu_operand_2;

         genvar i;

         ncpu32k_issue_queue
            #(
               .DEPTH      (1<<CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2),
               .DEPTH_WIDTH (CONFIG_FPU_ISSUE_QUEUE_DEPTH_LOG2),
               .UOP_WIDTH  (`NCPU_FPU_IOPW),
               .ALGORITHM  (0), // Out of Order
               .CONFIG_ROB_DEPTH_LOG2 (CONFIG_ROB_DEPTH_LOG2)
            )
         ISSUE_QUEUE_FPU
            (
               .clk        (clk),
               .rst_n      (rst_n),
               .i_issue_AVALID   (issue_fpu_AVALID),
               .o_issue_AREADY   (issue_fpu_AREADY),
               .i_flush       (flush),
               .i_uop         (issue_fpu_uop),
               .i_id          (issue_id),
               .i_rs1_rdy     (issue_rs1_rdy),
               .i_rs1_dat     (issue_rs1_dat),
               .i_rs1_addr    (issue_rs1_addr),
               .i_rs2_rdy     (issue_rs2_rdy),
               .i_rs2_dat     (issue_rs2_dat),
               .i_rs2_addr    (issue_rs2_addr),
               .byp_BVALID    (byp_BVALID),
               .byp_BDATA     (byp_BDATA),
               .byp_rd_we     (byp_rd_we),
               .byp_rd_addr   (byp_rd_addr),
               .i_fu_AREADY   (fpu_AREADY),
               .o_fu_AVALID   (fpu_AVALID),
               .o_fu_id       (fpu_AID),
               .o_fu_uop      (fpu_uop),
               .o_fu_rs1_dat  (fpu_operand_1),
               .o_fu_rs2_dat  (fpu_operand_2),
               .o_payload_w_ptr  (),
               .o_payload_r_ptr  ()
            );

         // Unpack uOP for FPU
         for(i=1;i<=`NCPU_FPU_IOPW;i=i+1)
            begin : gen_opc_bus
               assign fpu_opc_bus[i-1] = (fpu_uop == i[`NCPU_FPU_UOPW-1:0]);
            end
         

         /* ncpu32k_fpu AUTO_TEMPLATE (
               .fpu_BREADY    (wb_fpu_BREADY),
               .fpu_BVALID    (wb_fpu_BVALID),
               .fpu_BDATA     (wb_fpu_BDATA),
               .fpu_BID       (wb_fpu_BID),
            )
         */
         ncpu32k_fpu
            #(
               .CONFIG_PIPEBUF_BYPASS  (CONFIG_PIPEBUF_BYPASS)
            )
         FU_FPU
            (/*AUTOINST*/
             // Outputs
             .fpu_AREADY                (fpu_AREADY),
             .fpu_BVALID                (wb_fpu_BVALID),         // Templated
             .fpu_BID                   (wb_fpu_BID),            // Templated
             .fpu_BDATA                 (wb_fpu_BDATA),          // Templated
             // Inputs
             .clk                       (clk),
             .rst_n                     (rst_n),
             .flush                     (flush),
             .fpu_AVALID                (fpu_AVALID),
             .fpu_operand_1             (fpu_operand_1[`NCPU_DW-1:0]),
             .fpu_operand_2             (fpu_operand_2[`NCPU_DW-1:0]),
             .fpu_AID                   (fpu_AID[CONFIG_ROB_DEPTH_LOG2-1:0]),
             .fpu_opc_bus               (fpu_opc_bus[`NCPU_FPU_IOPW-1:0]),
             .fpu_BREADY                (wb_fpu_BREADY));         // Templated
      end
   else
      begin
         assign issue_fpu_AREADY = 1'b0;
         assign wb_fpu_BVALID = 1'b0;
         assign wb_fpu_BDATA = {`NCPU_DW{1'b0}};
         assign wb_fpu_BID = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
      end
   endgenerate
   
endmodule
