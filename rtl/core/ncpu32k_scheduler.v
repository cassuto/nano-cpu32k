/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_scheduler
#(
   parameter CONFIG_ENABLE_MUL
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIV
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_DIVU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MOD
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_MODU
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ENABLE_ASR
   `PARAM_NOT_SPECIFIED ,
   parameter BPU_UPD_DW
   `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   // Stall
   output                     sch_stall,
   input                      stall_fnt,
   input                      stall_bck,
   // Flush
   input                      flush,
   // IRQ
   input                      irq_sync,
   // From IFU
   input                      idu_1_insn_vld,
   input [`NCPU_IW-1:0]       idu_1_insn,
   input [`NCPU_AW-3:0]       idu_1_pc,
   input [`NCPU_AW-3:0]       idu_1_pc_4,
   input [BPU_UPD_DW-1:0]     idu_1_bpu_upd,
   input                      idu_1_EITM,
   input                      idu_1_EIPF,
   input                      idu_2_insn_vld,
   input [`NCPU_IW-1:0]       idu_2_insn,
   input [`NCPU_AW-3:0]       idu_2_pc,
   input [`NCPU_AW-3:0]       idu_2_pc_4,
   input [BPU_UPD_DW-1:0]     idu_2_bpu_upd,
   input                      idu_2_EITM,
   input                      idu_2_EIPF,
   input [`NCPU_AW-3:0]       idu_bpu_pc_nxt,
   // Slot #1
   output                     slot_1_rd_we,
   output [`NCPU_REG_AW-1:0]  slot_1_rd_addr,
   output [`NCPU_AW-3:0]      slot_1_pc,
   output [`NCPU_AW-3:0]      slot_1_pc_4,
   output [BPU_UPD_DW-1:0]    slot_1_bpu_upd,
   // Slot #2
   output                     slot_2_rd_we,
   output [`NCPU_REG_AW-1:0]  slot_2_rd_addr,
   output [`NCPU_AW-3:0]      slot_2_pc,
   output [`NCPU_AW-3:0]      slot_2_pc_4,
   output [BPU_UPD_DW-1:0]    slot_2_bpu_upd,
   output [`NCPU_AW-3:0]      slot_bpu_pc_nxt,
   input                      slot_2_inv,
   // FU - ALU 1
   output                     alu_1_AVALID,
   output [`NCPU_ALU_IOPW-1:0] alu_1_opc_bus,
   output [`NCPU_DW-1:0]      alu_1_operand1,
   output [`NCPU_DW-1:0]      alu_1_operand2,
   // FU - ALU 2
   output                     alu_2_AVALID,
   output [`NCPU_ALU_IOPW-1:0] alu_2_opc_bus,
   output [`NCPU_DW-1:0]      alu_2_operand1,
   output                     alu_2_operand1_frm_alu_1,
   output [`NCPU_DW-1:0]      alu_2_operand2,
   output                     alu_2_operand2_frm_alu_1,
   // FU - LPU
   output                     lpu_AVALID,
   output [`NCPU_LPU_IOPW-1:0] lpu_opc_bus,
   output [`NCPU_DW-1:0]      lpu_operand1,
   output [`NCPU_DW-1:0]      lpu_operand2,
   output                     lpu_in_slot_1,
   // FU - BRU
   output                     bru_AVALID,
   output [`NCPU_AW-3:0]      bru_pc,
   output [`NCPU_BRU_IOPW-1:0] bru_opc_bus,
   output [`NCPU_DW-1:0]      bru_operand1,
   output                     bru_operand1_frm_alu_1,
   output [`NCPU_DW-1:0]      bru_operand2,
   output                     bru_operand2_frm_alu_1,
   output [14:0]              bru_rel15,
   output                     bru_in_slot_1,
   // FU - EPU
   output                     epu_AVALID,
   output [`NCPU_AW-3:0]      epu_pc,
   output [`NCPU_EPU_IOPW-1:0] epu_opc_bus,
   output [`NCPU_DW-1:0]      epu_operand1,
   output [`NCPU_DW-1:0]      epu_operand2,
   output [`NCPU_DW-1:0]      epu_imm32,
   output                     epu_in_slot_1,
   // FU -LSU
   output                     lsu_AVALID,
   output                     lsu_load,
   output                     lsu_store,
   output                     lsu_sign_ext,
   output                     lsu_barr,
   output [2:0]               lsu_store_size,
   output [2:0]               lsu_load_size,
   output [`NCPU_DW-1:0]      lsu_operand1,
   output                     lsu_operand1_frm_alu_1,
   output [`NCPU_DW-1:0]      lsu_operand2,
   output                     lsu_operand2_frm_alu_1,
   output [`NCPU_DW-1:0]      lsu_imm32,
   output [`NCPU_AW-3:0]      lsu_pc,
   output                     lsu_in_slot_1,
   // Regfile channel #1
   output                     arf_1_rs1_re,
   output [`NCPU_REG_AW-1:0]  arf_1_rs1_addr,
   input [`NCPU_DW-1:0]       arf_1_rs1_dout,
   output                     arf_1_rs2_re,
   output [`NCPU_REG_AW-1:0]  arf_1_rs2_addr,
   input [`NCPU_DW-1:0]       arf_1_rs2_dout,
   // Regfile channel #2
   output                     arf_2_rs1_re,
   output [`NCPU_REG_AW-1:0]  arf_2_rs1_addr,
   input [`NCPU_DW-1:0]       arf_2_rs1_dout,
   output                     arf_2_rs2_re,
   output [`NCPU_REG_AW-1:0]  arf_2_rs2_addr,
   input [`NCPU_DW-1:0]       arf_2_rs2_dout
);
   wire                       pipe_cke;
   wire [`NCPU_IW-1:0]        id_insn [1:0];
   wire                       id_EITM [1:0];
   wire                       id_EIPF[1:0];
   wire                       id_EIRQ [1:0];
   wire [`NCPU_ALU_IOPW-1:0]  id_alu_opc_bus [1:0];
   wire [`NCPU_LPU_IOPW-1:0]  id_lpu_opc_bus [1:0];
   wire [`NCPU_EPU_IOPW-1:0]  id_epu_opc_bus [1:0];
   wire [`NCPU_BRU_IOPW-1:0]  id_bru_opc_bus [1:0];
   wire                       id_op_lsu_load [1:0];
   wire                       id_op_lsu_store [1:0];
   wire                       id_lsu_sign_ext [1:0];
   wire                       id_op_lsu_barr [1:0];
   wire [2:0]                 id_lsu_store_size [1:0];
   wire [2:0]                 id_lsu_load_size [1:0];
   wire                       id_wb_regf [1:0];
   wire [`NCPU_REG_AW-1:0]    id_wb_reg_addr [1:0];
   wire [`NCPU_DW-1:0]        id_imm32 [1:0];
   wire                       id_rf_rs1_re [1:0];
   wire [`NCPU_REG_AW-1:0]    id_rf_rs1_addr [1:0];
   wire                       id_rf_rs2_re [1:0];
   wire [`NCPU_REG_AW-1:0]    id_rf_rs2_addr [1:0];
   wire                       byp_alu_1_alu_2_rs1_nxt;
   wire                       byp_alu_1_alu_2_rs2_nxt;
   wire                       byp_alu_1_bru_rs1_nxt;
   wire                       byp_alu_1_bru_rs2_nxt;
   wire                       byp_alu_1_lsu_rs1_nxt;
   wire                       byp_alu_1_lsu_rs2_nxt;

   wire                       alu_1_sel_r, alu_1_sel_nxt;
   wire                       alu_2_sel_r, alu_2_sel_nxt;
   wire                       lpu_sel_1_r, lpu_sel_1_nxt;
   wire                       lpu_sel_2_r, lpu_sel_2_nxt;
   wire                       epu_sel_1_r, epu_sel_1_nxt;
   wire                       epu_sel_2_r, epu_sel_2_nxt;
   wire                       bru_sel_1_r, bru_sel_1_nxt;
   wire                       bru_sel_2_r, bru_sel_2_nxt;
   wire                       lsu_sel_1_r, lsu_sel_1_nxt;
   wire                       lsu_sel_2_r, lsu_sel_2_nxt;
   wire                       slot_1_rdy;
   wire                       slot_1_vld;
   wire                       slot_2_rdy;
   wire                       slot_2_vld;
   wire                       slot_2_RAW_hazard;
   wire                       slot_2_hazard;
   wire                       slot_2_could_byp;
   wire                       slot_2_struct_hazard;
   wire                       sel_1_lpu;
   wire                       sel_1_bru;
   wire                       sel_1_epu;
   wire                       sel_1_lsu;

   wire [`NCPU_AW-3:0]        fu_pc     [1:0];
   wire [`NCPU_AW-3:0]        fu_pc_4   [1:0];
   wire [`NCPU_DW-1:0]        fu_imm32  [1:0];
   wire                       rf_rs1_re_r [1:0];
   wire                       rf_rs2_re_r [1:0];
   wire [`NCPU_REG_AW-1:0]    rf_rs1_addr_r [1:1];
   wire [`NCPU_REG_AW-1:0]    rf_rs2_addr_r [1:1];
   wire [`NCPU_ALU_IOPW-1:0]  fu_alu_opc_bus [1:0];
   wire [`NCPU_LPU_IOPW-1:0]  fu_lpu_opc_bus [1:0];
   wire [`NCPU_EPU_IOPW-1:0]  fu_epu_opc_bus [1:0];
   wire [`NCPU_BRU_IOPW-1:0]  fu_bru_opc_bus [1:0];
   wire                       fu_lsu_load [1:0];
   wire                       fu_lsu_store [1:0];
   wire                       fu_lsu_barr [1:0];
   wire                       fu_lsu_sign_ext [1:0];
   wire [2:0]                 fu_lsu_load_size [1:0];
   wire [2:0]                 fu_lsu_store_size [1:0];
   wire                       fu_rd_we [1:0];
   wire [`NCPU_REG_AW-1:0]    fu_rd_addr [1:0];
   wire [BPU_UPD_DW-1:0]      fu_bpu_upd [1:0];
   genvar i;

   assign id_insn[0] = idu_1_insn;
   assign id_EITM[0] = idu_1_EITM;
   assign id_EIPF[0] = idu_1_EIPF;
   assign id_EIRQ[0] = irq_sync;

   assign id_insn[1] = idu_2_insn;
   assign id_EITM[1] = idu_2_EITM;
   assign id_EIPF[1] = idu_2_EIPF;
   assign id_EIRQ[1] = 1'b0;

   assign pipe_cke = ~stall_bck;

   generate
      for(i=0; i<2; i=i+1)
         begin : gen_dec
            ncpu32k_idu
               #(
                  .CONFIG_ENABLE_MUL      (CONFIG_ENABLE_MUL),
                  .CONFIG_ENABLE_DIV      (CONFIG_ENABLE_DIV),
                  .CONFIG_ENABLE_DIVU     (CONFIG_ENABLE_DIVU),
                  .CONFIG_ENABLE_MOD      (CONFIG_ENABLE_MOD),
                  .CONFIG_ENABLE_MODU     (CONFIG_ENABLE_MODU),
                  .CONFIG_ENABLE_ASR      (CONFIG_ENABLE_ASR)
               )
            DECODE
               (
               `ifdef NCPU_ENABLE_ASSERT
                  .clk                    (clk),
               `endif
                  // Inputs
                  .idu_insn               (id_insn[i]),
                  .idu_EITM               (id_EITM[i]),
                  .idu_EIPF               (id_EIPF[i]),
                  .idu_EIRQ               (id_EIRQ[i]),
                  // Outputs
                  .alu_opc_bus            (id_alu_opc_bus[i]),
                  .lpu_opc_bus            (id_lpu_opc_bus[i]),
                  .epu_opc_bus            (id_epu_opc_bus[i]),
                  .bru_opc_bus            (id_bru_opc_bus[i]),
                  .op_lsu_load            (id_op_lsu_load[i]),
                  .op_lsu_store           (id_op_lsu_store[i]),
                  .lsu_sign_ext           (id_lsu_sign_ext[i]),
                  .op_lsu_barr            (id_op_lsu_barr[i]),
                  .lsu_store_size         (id_lsu_store_size[i]),
                  .lsu_load_size          (id_lsu_load_size[i]),
                  .wb_regf                (id_wb_regf[i]),
                  .wb_reg_addr            (id_wb_reg_addr[i]),
                  .imm32                  (id_imm32[i]),
                  .rf_rs1_re              (id_rf_rs1_re[i]),
                  .rf_rs1_addr            (id_rf_rs1_addr[i]),
                  .rf_rs2_re              (id_rf_rs2_re[i]),
                  .rf_rs2_addr            (id_rf_rs2_addr[i])
               );
            
            // Data path
            nDFF_l #(`NCPU_DW) dff_imm32_r
               (clk, pipe_cke, id_imm32[i], fu_imm32[i]);

            nDFF_l #(1) dff_rf_rs1_re_r
               (clk, pipe_cke, id_rf_rs1_re[i], rf_rs1_re_r[i]);
            nDFF_l #(1) dff_rf_rs2_re_r
               (clk, pipe_cke, id_rf_rs2_re[i], rf_rs2_re_r[i]);

            nDFF_l #(3) dff_fu_lsu_store_size
               (clk, pipe_cke, id_lsu_store_size[i], fu_lsu_store_size[i]);
            nDFF_l #(3) dff_fu_lsu_load_size
               (clk, pipe_cke, id_lsu_load_size[i], fu_lsu_load_size[i]);
            
            nDFF_l #(`NCPU_REG_AW) dff_fu_rd_addr
               (clk, pipe_cke, id_wb_reg_addr[i], fu_rd_addr[i]);
            
            nDFF_l #(`NCPU_ALU_IOPW) dff_fu_alu_opc_bus
               (clk, pipe_cke, id_alu_opc_bus[i], fu_alu_opc_bus[i]);
            nDFF_l #(`NCPU_LPU_IOPW) dff_fu_lpu_opc_bus
               (clk, pipe_cke, id_lpu_opc_bus[i], fu_lpu_opc_bus[i]);
            nDFF_l #(`NCPU_BRU_IOPW) dff_fu_bru_opc_bus
               (clk, pipe_cke, id_bru_opc_bus[i], fu_bru_opc_bus[i]);
            nDFF_l #(`NCPU_EPU_IOPW) dff_fu_epu_opc_bus
               (clk, pipe_cke, id_epu_opc_bus[i], fu_epu_opc_bus[i]);

            nDFF_l #(1) dff_fu_lsu_load
               (clk, pipe_cke, id_op_lsu_load[i], fu_lsu_load[i]);
            nDFF_l #(1) dff_fu_lsu_store
               (clk, pipe_cke, id_op_lsu_store[i], fu_lsu_store[i]);
            nDFF_l #(1) dff_fu_lsu_barr
               (clk, pipe_cke, id_op_lsu_barr[i], fu_lsu_barr[i]);
            nDFF_l #(1) dff_fu_lsu_sign_ext
               (clk, pipe_cke, id_lsu_sign_ext[i], fu_lsu_sign_ext[i]);

            nDFF_l #(1) dff_fu_rd_we
               (clk, pipe_cke, id_wb_regf[i], fu_rd_we[i]);
         end
   endgenerate
   
   // Data path
   nDFF_l #(`NCPU_AW-2) dff_fu_pc_0
      (clk, pipe_cke, idu_1_pc, fu_pc[0]);
   nDFF_l #(`NCPU_AW-2) dff_fu_pc_1
      (clk, pipe_cke, idu_2_pc, fu_pc[1]);
   nDFF_l #(`NCPU_AW-2) dff_fu_pc_4_0
      (clk, pipe_cke, idu_1_pc_4, fu_pc_4[0]);
   nDFF_l #(`NCPU_AW-2) dff_fu_pc_4_1
      (clk, pipe_cke, idu_2_pc_4, fu_pc_4[1]);
   nDFF_l #(`NCPU_REG_AW) dff_rf_rs1_addr_r
      (clk, pipe_cke, id_rf_rs1_addr[1], rf_rs1_addr_r[1]);
   nDFF_l #(`NCPU_REG_AW) dff_rf_rs2_addr_r
      (clk, pipe_cke, id_rf_rs2_addr[1], rf_rs2_addr_r[1]);

   nDFF_l #(BPU_UPD_DW) dff_fu_bpu_upd_0
      (clk, pipe_cke, idu_1_bpu_upd, fu_bpu_upd[0]);
   nDFF_l #(BPU_UPD_DW) dff_fu_bpu_upd_1
      (clk, pipe_cke, idu_2_bpu_upd, fu_bpu_upd[1]);

   nDFF_l #(`NCPU_AW-2) dff_slot_bpu_pc_nxt
      (clk, pipe_cke, idu_bpu_pc_nxt, slot_bpu_pc_nxt);

   assign arf_1_rs1_re     = pipe_cke & id_rf_rs1_re[0];
   assign arf_1_rs2_re     = pipe_cke & id_rf_rs2_re[0];
   assign arf_2_rs1_re     = pipe_cke & id_rf_rs1_re[1];
   assign arf_2_rs2_re     = pipe_cke & id_rf_rs2_re[1];

   assign arf_1_rs1_addr    = id_rf_rs1_addr[0];
   assign arf_1_rs2_addr    = id_rf_rs2_addr[0];
   assign arf_2_rs1_addr    = id_rf_rs1_addr[1];
   assign arf_2_rs2_addr    = id_rf_rs2_addr[1];

   assign slot_1_rd_we     = fu_rd_we[0];
   assign slot_1_rd_addr   = fu_rd_addr[0];
   assign slot_1_pc        = fu_pc[0];
   assign slot_1_pc_4      = fu_pc_4[0];
   assign slot_1_bpu_upd   = fu_bpu_upd[0];

   assign slot_2_rd_we     = fu_rd_we[1];
   assign slot_2_rd_addr   = fu_rd_addr[1];
   assign slot_2_pc        = fu_pc[1];
   assign slot_2_pc_4      = fu_pc_4[1];
   assign slot_2_bpu_upd   = fu_bpu_upd[1];


   // Detect RAW dependency
   assign slot_2_RAW_hazard = idu_1_insn_vld & idu_2_insn_vld & id_wb_regf[0] & (
                                 (id_rf_rs1_re[1] & (id_rf_rs1_addr[1] == id_wb_reg_addr[0])) |
                                 (id_rf_rs2_re[1] & (id_rf_rs2_addr[1] == id_wb_reg_addr[0]))
                              );

   // Describe bypass paths (which depends on the design of pipeline) here...
   assign slot_2_could_byp =  // ALU1->ALU2
                              (alu_1_sel_nxt & alu_2_sel_nxt) |
                              // ALU1->BRU
                              (alu_1_sel_nxt & bru_sel_2_nxt) | // Assert (2105022229)
                              // ALU1->LSU
                              (alu_1_sel_nxt & lsu_sel_2_nxt);

   // Detect structure hazard
   assign slot_2_struct_hazard = (bru_sel_1_nxt & bru_sel_2_nxt) |
                                 (lpu_sel_1_nxt & lpu_sel_2_nxt) |
                                 (epu_sel_1_nxt & epu_sel_2_nxt) |
                                 (lsu_sel_1_nxt & lsu_sel_2_nxt);

   assign slot_2_hazard = (slot_2_RAW_hazard & ~slot_2_could_byp) |
                           slot_2_struct_hazard;

   // ALU1->ALU2
   assign byp_alu_1_alu_2_rs1_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                       alu_1_sel_nxt & alu_2_sel_nxt &
                                       id_wb_regf[0] & id_rf_rs1_re[1] & (id_rf_rs1_addr[1] == id_wb_reg_addr[0]));
   assign byp_alu_1_alu_2_rs2_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                       alu_1_sel_nxt & alu_2_sel_nxt &
                                       id_wb_regf[0] & id_rf_rs2_re[1] & (id_rf_rs2_addr[1] == id_wb_reg_addr[0]));

   // ALU1->BRU
   assign byp_alu_1_bru_rs1_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                    alu_1_sel_nxt & bru_sel_2_nxt &
                                    id_wb_regf[0] & id_rf_rs1_re[1] & (id_rf_rs1_addr[1] == id_wb_reg_addr[0]));
   assign byp_alu_1_bru_rs2_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                    alu_1_sel_nxt & bru_sel_2_nxt &
                                    id_wb_regf[0] & id_rf_rs2_re[1] & (id_rf_rs2_addr[1] == id_wb_reg_addr[0]));

   // ALU1->LSU
   assign byp_alu_1_lsu_rs1_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                    alu_1_sel_nxt & lsu_sel_2_nxt &
                                    id_wb_regf[0] & id_rf_rs1_re[1] & (id_rf_rs1_addr[1] == id_wb_reg_addr[0]));
   assign byp_alu_1_lsu_rs2_nxt = (idu_1_insn_vld & idu_2_insn_vld &
                                    alu_1_sel_nxt & lsu_sel_2_nxt &
                                    id_wb_regf[0] & id_rf_rs2_re[1] & (id_rf_rs2_addr[1] == id_wb_reg_addr[0]));

   //
   // Issue the insns serially, if there is hazard between two slots
   //
   wire [1:0] issue_state_r;
   reg [1:0] issue_state_nxt;
   wire force_single_issue;

   localparam [1:0] S_ISSUE_FULL = 2'b00;
   localparam [1:0] S_ISSUE_1 = 2'b01;
   localparam [1:0] S_ISSUE_2 = 2'b11;
   localparam [1:0] S_ISSUE_NONE = 2'b10;

   assign force_single_issue = (idu_2_insn_vld & ~flush & slot_2_hazard);

   always @(*)
      case(issue_state_r)
         S_ISSUE_FULL:
            if (force_single_issue)
               issue_state_nxt = S_ISSUE_1;
            else
               issue_state_nxt = S_ISSUE_FULL;

         S_ISSUE_1:
            if (slot_2_inv)
               issue_state_nxt = S_ISSUE_NONE;
            else
               issue_state_nxt = S_ISSUE_2;

         S_ISSUE_NONE, S_ISSUE_2:
            // Allow skip S_ISSUE_FULL and goto S_ISSUE_1 directly.
            // This happens when two consecutive insn packets are both single-issue.
            if (force_single_issue)
               issue_state_nxt = S_ISSUE_1;
            else
               issue_state_nxt = S_ISSUE_FULL;

         default:
            issue_state_nxt = issue_state_r;
      endcase

   nDFF_lr #(2, S_ISSUE_FULL) dff_issue_state_r
      (clk, rst_n, pipe_cke, issue_state_nxt, issue_state_r);

   assign sch_stall = (issue_state_nxt==S_ISSUE_1);

   assign slot_1_rdy = (issue_state_r==S_ISSUE_FULL) | (issue_state_r==S_ISSUE_1);
   assign slot_2_rdy = (issue_state_r==S_ISSUE_FULL) | (issue_state_r==S_ISSUE_2);


   nDFF_lr #(1) dff_slot_1_vld
      (clk, rst_n, pipe_cke, idu_1_insn_vld & ~flush, slot_1_vld);
   nDFF_lr #(1) dff_slot_2_vld
      (clk, rst_n, pipe_cke, idu_2_insn_vld & ~flush, slot_2_vld);

   assign alu_1_sel_nxt = idu_1_insn_vld & (|id_alu_opc_bus[0]);
   assign alu_2_sel_nxt = idu_2_insn_vld & (|id_alu_opc_bus[1]);
   assign lpu_sel_1_nxt = idu_1_insn_vld & (|id_lpu_opc_bus[0]);
   assign lpu_sel_2_nxt = idu_2_insn_vld & (|id_lpu_opc_bus[1]);
   assign epu_sel_1_nxt = idu_1_insn_vld & (|id_epu_opc_bus[0]);
   assign epu_sel_2_nxt = idu_2_insn_vld & (|id_epu_opc_bus[1]);
   assign bru_sel_1_nxt = idu_1_insn_vld & (|id_bru_opc_bus[0]);
   assign bru_sel_2_nxt = idu_2_insn_vld & (|id_bru_opc_bus[1]);
   assign lsu_sel_1_nxt = idu_1_insn_vld & (id_op_lsu_barr[0] | id_op_lsu_load[0] | id_op_lsu_store[0]);
   assign lsu_sel_2_nxt = idu_2_insn_vld & (id_op_lsu_barr[1] | id_op_lsu_load[1] | id_op_lsu_store[1]);
   
   nDFF_l #(1) dff_alu_1_sel_r
      (clk, pipe_cke, alu_1_sel_nxt, alu_1_sel_r);
   nDFF_l #(1) dff_alu_2_sel_r
      (clk, pipe_cke, alu_2_sel_nxt, alu_2_sel_r);
   nDFF_l #(1) dff_lpu_1_sel_r
      (clk, pipe_cke, lpu_sel_1_nxt, lpu_sel_1_r);
   nDFF_l #(1) dff_lpu_2_sel_r
      (clk, pipe_cke, lpu_sel_2_nxt, lpu_sel_2_r);
   nDFF_l #(1) dff_epu_sel_1_r
      (clk, pipe_cke, epu_sel_1_nxt, epu_sel_1_r);
   nDFF_l #(1) dff_epu_sel_2_r
      (clk, pipe_cke, epu_sel_2_nxt, epu_sel_2_r);
   nDFF_l #(1) dff_bru_sel_1_r
      (clk, pipe_cke, bru_sel_1_nxt, bru_sel_1_r);
   nDFF_l #(1) dff_bru_sel_2_r
      (clk, pipe_cke, bru_sel_2_nxt, bru_sel_2_r);
   nDFF_l #(1) dff_lsu_sel_1_r
      (clk, pipe_cke, lsu_sel_1_nxt, lsu_sel_1_r);
   nDFF_l #(1) dff_lsu_sel_2_r
      (clk, pipe_cke, lsu_sel_2_nxt, lsu_sel_2_r);

   nDFF_l #(1) dff_alu_2_operand1_frm_alu_1
      (clk, pipe_cke, byp_alu_1_alu_2_rs1_nxt, alu_2_operand1_frm_alu_1);
   nDFF_l #(1) dff_alu_2_operand2_frm_alu_1
      (clk, pipe_cke, byp_alu_1_alu_2_rs2_nxt, alu_2_operand2_frm_alu_1);

   nDFF_l #(1) dff_bru_operand1_frm_alu_1
      (clk, pipe_cke, byp_alu_1_bru_rs1_nxt, bru_operand1_frm_alu_1);
   nDFF_l #(1) dff_bru_operand2_frm_alu_1
      (clk, pipe_cke, byp_alu_1_bru_rs2_nxt, bru_operand2_frm_alu_1);

   nDFF_l #(1) dff_lsu_operand1_frm_alu_1
      (clk, pipe_cke, byp_alu_1_lsu_rs1_nxt, lsu_operand1_frm_alu_1);
   nDFF_l #(1) dff_lsu_operand2_frm_alu_1
      (clk, pipe_cke, byp_alu_1_lsu_rs2_nxt, lsu_operand2_frm_alu_1);

   assign sel_1_lpu  = (slot_1_rdy & slot_1_vld & lpu_sel_1_r);
   assign sel_1_bru  = (slot_1_rdy & slot_1_vld & bru_sel_1_r);
   assign sel_1_epu  = (slot_1_rdy & slot_1_vld & epu_sel_1_r);
   assign sel_1_lsu  = (slot_1_rdy & slot_1_vld & lsu_sel_1_r);

   assign alu_1_AVALID = (slot_1_rdy & slot_1_vld & alu_1_sel_r);
   assign alu_2_AVALID = (slot_2_rdy & slot_2_vld & alu_2_sel_r);

   assign lpu_AVALID = sel_1_lpu |
                        (slot_2_rdy & slot_2_vld & lpu_sel_2_r);

   assign epu_AVALID = sel_1_epu |
                        (slot_2_rdy & slot_2_vld & epu_sel_2_r);

   assign bru_AVALID =  sel_1_bru |
                        (slot_2_rdy & slot_2_vld & bru_sel_2_r);

   assign lsu_AVALID = sel_1_lsu |
                        (slot_2_rdy & slot_2_vld & lsu_sel_2_r);

   assign alu_1_opc_bus    = fu_alu_opc_bus[0];
   assign alu_1_operand1   = rf_rs1_re_r[0] ? arf_1_rs1_dout : fu_imm32[0];
   assign alu_1_operand2   = rf_rs2_re_r[0] ? arf_1_rs2_dout : fu_imm32[0];

   assign alu_2_opc_bus    = fu_alu_opc_bus[1];
   assign alu_2_operand1   = rf_rs1_re_r[1] ? arf_2_rs1_dout : fu_imm32[1];
   assign alu_2_operand2   = rf_rs2_re_r[1] ? arf_2_rs2_dout : fu_imm32[1];

   assign lpu_opc_bus      = sel_1_lpu ? fu_lpu_opc_bus[0] : fu_lpu_opc_bus[1];
   assign lpu_operand1     = sel_1_lpu ? alu_1_operand1 : alu_2_operand1;
   assign lpu_operand2     = sel_1_lpu ? alu_1_operand2 : alu_2_operand2;
   assign lpu_in_slot_1    = sel_1_lpu;

   assign bru_pc           = sel_1_bru ? fu_pc[0] : fu_pc[1];
   assign bru_opc_bus      = sel_1_bru ? fu_bru_opc_bus[0] : fu_bru_opc_bus[1];
   assign bru_operand1     = sel_1_bru ? alu_1_operand1 : alu_2_operand1;
   assign bru_operand2     = sel_1_bru ? alu_1_operand2 : alu_2_operand2;
   assign bru_rel15        = sel_1_bru ? fu_imm32[0][14:0] : fu_imm32[1][14:0];
   assign bru_in_slot_1    = sel_1_bru;

   assign epu_pc           = sel_1_epu ? fu_pc[0] : fu_pc[1];
   assign epu_opc_bus      = sel_1_epu ? fu_epu_opc_bus[0] : fu_epu_opc_bus[1];
   assign epu_operand1     = sel_1_epu ? alu_1_operand1 : alu_2_operand1;
   assign epu_operand2     = sel_1_epu ? alu_1_operand2 : alu_2_operand2;
   assign epu_imm32        = sel_1_epu ? fu_imm32[0] : fu_imm32[1];
   assign epu_in_slot_1    = sel_1_epu;

   assign lsu_pc           = sel_1_lsu ? fu_pc[0] : fu_pc[1];
   assign { lsu_load,
            lsu_store,
            lsu_sign_ext,
            lsu_barr,
            lsu_store_size,
            lsu_load_size
         } = 
            (slot_1_rdy & lsu_sel_1_r)
               ? {   fu_lsu_load[0],
                     fu_lsu_store[0],
                     fu_lsu_sign_ext[0],
                     fu_lsu_barr[0],
                     fu_lsu_store_size[0],
                     fu_lsu_load_size[0]
                  }
               : {   fu_lsu_load[1],
                     fu_lsu_store[1],
                     fu_lsu_sign_ext[1],
                     fu_lsu_barr[1],
                     fu_lsu_store_size[1],
                     fu_lsu_load_size[1]
                  };
   assign lsu_operand1     = sel_1_lsu ? alu_1_operand1 : alu_2_operand1;
   assign lsu_operand2     = sel_1_lsu ? alu_1_operand2 : alu_2_operand2;
   assign lsu_imm32        = sel_1_lsu ? fu_imm32[0] : fu_imm32[1];
   assign lsu_in_slot_1    = sel_1_lsu;

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertion 2105022229
         if ((alu_1_sel_nxt & bru_sel_1_nxt) | (alu_2_sel_nxt & bru_sel_2_nxt))
            $fatal(1, "Bugs on scheduler for ALU and BRU");
         if (slot_1_rdy & slot_1_vld & ~(alu_1_sel_r|lpu_sel_1_r|bru_sel_1_r|epu_sel_1_r|lsu_sel_1_r))
            $fatal(1, "Bugs on scheduler: unhandled FU type for slot 1");
         if (slot_2_rdy & slot_2_vld & ~(alu_2_sel_r|lpu_sel_2_r|bru_sel_2_r|epu_sel_2_r|lsu_sel_2_r))
            $fatal(1, "Bugs on scheduler: unhandled FU type for slot 2");
      end
`endif

`endif
   // synthesis translate_on
endmodule
