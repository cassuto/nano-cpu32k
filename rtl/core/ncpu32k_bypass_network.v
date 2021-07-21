/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_bypass_network(
   input                               clk,
   output                              byp_stall,
   // From ARF
   input                               arf_1_rs1_re,
   input [`NCPU_REG_AW-1:0]            arf_1_rs1_addr,
   input [`NCPU_DW-1:0]                arf_1_rs1_dout,
   input                               arf_1_rs2_re,
   input [`NCPU_REG_AW-1:0]            arf_1_rs2_addr,
   input [`NCPU_DW-1:0]                arf_1_rs2_dout,
   input                               arf_2_rs1_re,
   input [`NCPU_REG_AW-1:0]            arf_2_rs1_addr,
   input [`NCPU_DW-1:0]                arf_2_rs1_dout,
   input                               arf_2_rs2_re,
   input [`NCPU_REG_AW-1:0]            arf_2_rs2_addr,
   input [`NCPU_DW-1:0]                arf_2_rs2_dout,
   // From scheduler
   input                               alu_2_operand1_frm_alu_1,
   input                               alu_2_operand2_frm_alu_1,
   input                               bru_operand1_frm_alu_1,
   input                               bru_operand2_frm_alu_1,
   input                               lsu_operand1_frm_alu_1,
   input                               lsu_operand2_frm_alu_1,
   input [`NCPU_DW-1:0]                alu_2_operand1_nobyp,
   input [`NCPU_DW-1:0]                alu_2_operand2_nobyp,
   input [`NCPU_DW-1:0]                bru_operand1_nobyp,
   input [`NCPU_DW-1:0]                bru_operand2_nobyp,
   input [`NCPU_DW-1:0]                lsu_operand1_nobyp,
   input [`NCPU_DW-1:0]                lsu_operand2_nobyp,
   input                               lsu_AVALID,
   input                               lsu_in_slot_1,
   // From ALU #1
   input [`NCPU_DW-1:0]                wb_alu_1_dout,
   // From stage 1 of backend
   input                               s1i_slot_BVALID_1,
   input                               s1i_slot_rd_we_1,
   input [`NCPU_REG_AW-1:0]            s1i_slot_rd_addr_1,
   input [`NCPU_DW-1:0]                s1i_slot_dout_1,
   input                               s1i_slot_BVALID_2,
   input                               s1i_slot_rd_we_2,
   input [`NCPU_REG_AW-1:0]            s1i_slot_rd_addr_2,
   input [`NCPU_DW-1:0]                s1i_slot_dout_2,
   // From stage 2 of backend
   input                               s2i_slot_BVALID_1,
   input                               s2i_slot_rd_we_1,
   input [`NCPU_REG_AW-1:0]            s2i_slot_rd_addr_1,
   input [`NCPU_DW-1:0]                s2i_slot_dout_1,
   input                               s2i_slot_BVALID_2,
   input                               s2i_slot_rd_we_2,
   input [`NCPU_REG_AW-1:0]            s2i_slot_rd_addr_2,
   input [`NCPU_DW-1:0]                s2i_slot_dout_2,
   // Output
   output [`NCPU_DW-1:0]               arf_1_rs1_dout_bypass,
   output [`NCPU_DW-1:0]               arf_1_rs2_dout_bypass,
   output [`NCPU_DW-1:0]               arf_2_rs1_dout_bypass,
   output [`NCPU_DW-1:0]               arf_2_rs2_dout_bypass,
   output [`NCPU_DW-1:0]               alu_2_operand1,
   output [`NCPU_DW-1:0]               alu_2_operand2,
   output [`NCPU_DW-1:0]               bru_operand1,
   output [`NCPU_DW-1:0]               bru_operand2,
   output [`NCPU_DW-1:0]               lsu_operand1,
   output [`NCPU_DW-1:0]               lsu_operand2
);

   wire [4:1]                          byp_op_stall;

   //
   // *** Bypass path: Backend stage2->Backend stage1 ***
   // *** Bypass path: Backend stage1->Scheduler ***
   //
   `define BYPASS_OP_PORTS \
      .lsu_AVALID                      (lsu_AVALID), \
      .lsu_in_slot_1                   (lsu_in_slot_1), \
      .s1i_slot_1_BVALID               (s1i_slot_BVALID_1), \
      .s1i_slot_1_rd_we                (s1i_slot_rd_we_1), \
      .s1i_slot_1_rd_addr              (s1i_slot_rd_addr_1), \
      .s1i_slot_1_dout                 (s1i_slot_dout_1), \
      .s1i_slot_2_BVALID               (s1i_slot_BVALID_2), \
      .s1i_slot_2_rd_we                (s1i_slot_rd_we_2), \
      .s1i_slot_2_rd_addr              (s1i_slot_rd_addr_2), \
      .s1i_slot_2_dout                 (s1i_slot_dout_2), \
      .s2i_slot_1_BVALID               (s2i_slot_BVALID_1), \
      .s2i_slot_1_rd_we                (s2i_slot_rd_we_1), \
      .s2i_slot_1_rd_addr              (s2i_slot_rd_addr_1), \
      .s2i_slot_1_dout                 (s2i_slot_dout_1), \
      .s2i_slot_2_BVALID               (s2i_slot_BVALID_2), \
      .s2i_slot_2_rd_we                (s2i_slot_rd_we_2), \
      .s2i_slot_2_rd_addr              (s2i_slot_rd_addr_2), \
      .s2i_slot_2_dout                 (s2i_slot_dout_2)

   ncpu32k_bypass_op BYPASS_OP_1
      (
         .clk                          (clk),
         .en                           (arf_1_rs1_re),
         .i_operand_rf_addr            (arf_1_rs1_addr),
         .i_operand                    (arf_1_rs1_dout),
         .o_operand                    (arf_1_rs1_dout_bypass),
         .byp_op_stall                 (byp_op_stall[1]),
         `BYPASS_OP_PORTS
      );
   ncpu32k_bypass_op BYPASS_OP_2
      (
         .clk                          (clk),
         .en                           (arf_1_rs2_re),
         .i_operand_rf_addr            (arf_1_rs2_addr),
         .i_operand                    (arf_1_rs2_dout),
         .o_operand                    (arf_1_rs2_dout_bypass),
         .byp_op_stall                 (byp_op_stall[2]),
         `BYPASS_OP_PORTS
      );
   ncpu32k_bypass_op BYPASS_OP_3
      (
         .clk                          (clk),
         .en                           (arf_2_rs1_re),
         .i_operand_rf_addr            (arf_2_rs1_addr),
         .i_operand                    (arf_2_rs1_dout),
         .o_operand                    (arf_2_rs1_dout_bypass),
         .byp_op_stall                 (byp_op_stall[3]),
         `BYPASS_OP_PORTS
      );
   ncpu32k_bypass_op BYPASS_OP_4
      (
         .clk                          (clk),
         .en                           (arf_2_rs2_re),
         .i_operand_rf_addr            (arf_2_rs2_addr),
         .i_operand                    (arf_2_rs2_dout),
         .o_operand                    (arf_2_rs2_dout_bypass),
         .byp_op_stall                 (byp_op_stall[4]),
         `BYPASS_OP_PORTS
      );
      
   
   //
   // *** Bypass path: ALU1->ALU2 ***
   // Assert (2105110002)
   //
   assign alu_2_operand1 = alu_2_operand1_frm_alu_1 ? wb_alu_1_dout : alu_2_operand1_nobyp;
   assign alu_2_operand2 = alu_2_operand2_frm_alu_1 ? wb_alu_1_dout : alu_2_operand2_nobyp;

   //
   // *** Bypass path: ALU1->BRU ***
   // Assert (2105051653)
   //
   assign bru_operand1 = bru_operand1_frm_alu_1 ? wb_alu_1_dout : bru_operand1_nobyp;
   assign bru_operand2 = bru_operand2_frm_alu_1 ? wb_alu_1_dout : bru_operand2_nobyp;

   //
   // *** Bypass path: ALU1->LSU ***
   // Assert (2105051655)
   //
   assign lsu_operand1 = lsu_operand1_frm_alu_1 ? wb_alu_1_dout : lsu_operand1_nobyp;
   assign lsu_operand2 = lsu_operand2_frm_alu_1 ? wb_alu_1_dout : lsu_operand2_nobyp;

   assign byp_stall = |byp_op_stall;
   
endmodule
