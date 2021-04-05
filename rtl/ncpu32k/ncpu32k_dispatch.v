/**@file
 * Rename and dispatch stage
 */

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

module ncpu32k_dispatch
#(
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   output                     disp_AREADY,
   input                      disp_AVALID,
   input [`NCPU_AW-3:0]       disp_pc,
   input [`NCPU_AW-3:0]       disp_pred_tgt,
   input [`NCPU_ALU_IOPW-1:0] disp_alu_opc_bus,
   input [`NCPU_LPU_IOPW-1:0] disp_lpu_opc_bus,
   input [`NCPU_EPU_IOPW-1:0] disp_epu_opc_bus,
   input                      disp_agu_load,
   input                      disp_agu_store,
   input                      disp_agu_sign_ext,
   input                      disp_agu_barr,
   input [2:0]                disp_agu_store_size,
   input [2:0]                disp_agu_load_size,
   input                      disp_rs1_re,
   input [`NCPU_REG_AW-1:0]   disp_rs1_addr,
   input                      disp_rs2_re,
   input [`NCPU_REG_AW-1:0]   disp_rs2_addr,
   input [`NCPU_DW-1:0]       disp_imm32,
   input [14:0]               disp_rel15,
   input                      disp_rd_we,
   input [`NCPU_REG_AW-1:0]   disp_rd_addr,
   // To ROB
   output                     rob_disp_AVALID,
   input                      rob_disp_AREADY,
   output [`NCPU_AW-3:0]      rob_disp_pc,
   output [`NCPU_AW-3:0]      rob_disp_pred_tgt,
   output                     rob_disp_rd_we,
   output [`NCPU_REG_AW-1:0]  rob_disp_rd_addr,
   output [`NCPU_REG_AW-1:0]  rob_disp_rs1_addr,
   output [`NCPU_REG_AW-1:0]  rob_disp_rs2_addr,
   input                      rob_disp_rs1_in_ROB,
   input                      rob_disp_rs1_in_ARF,
   input [`NCPU_DW-1:0]       rob_disp_rs1_dat,
   input                      rob_disp_rs2_in_ROB,
   input                      rob_disp_rs2_in_ARF,
   input [`NCPU_DW-1:0]       rob_disp_rs2_dat,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] rob_disp_id,
   // To ARF
   output                     arf_rs1_re,
   output [`NCPU_REG_AW-1:0]  arf_rs1_addr,
   input [`NCPU_DW-1:0]       arf_rs1_dout,
   output                     arf_rs2_re,
   output [`NCPU_REG_AW-1:0]  arf_rs2_addr,
   input [`NCPU_DW-1:0]       arf_rs2_dout,
   // To Issue Queue
   input                      issue_alu_AREADY,
   output                     issue_alu_AVALID,
   output [`NCPU_ALU_UOPW-1:0] issue_alu_uop,
   input                      issue_lpu_AREADY,
   output                     issue_lpu_AVALID,
   output [`NCPU_LPU_UOPW-1:0] issue_lpu_uop,
   input                      issue_agu_AREADY,
   output                     issue_agu_AVALID,
   output [`NCPU_AGU_UOPW-1:0] issue_agu_uop,
   input                      issue_fpu_AREADY,
   output                     issue_fpu_AVALID,
   output [`NCPU_FPU_UOPW-1:0] issue_fpu_uop,
   input                      issue_epu_AREADY,
   output                     issue_epu_AVALID,
   output [`NCPU_EPU_UOPW-1:0] issue_epu_uop,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] issue_id,
   output                     issue_rs1_rdy,
   output [`NCPU_DW-1:0]      issue_rs1_dat,
   output [`NCPU_REG_AW-1:0]  issue_rs1_addr,
   output                     issue_rs2_rdy,
   output [`NCPU_DW-1:0]      issue_rs2_dat,
   output [`NCPU_REG_AW-1:0]  issue_rs2_addr,
   output [`NCPU_DW-1:0]      issue_imm32
);
   wire pipe_issue_AREADY;
   wire pipe_issue_AVALID;
   wire pipe_issue_BREADY;
   wire pipe_issue_BVALID;
   wire pipe_issue_cke;
   wire issue_alu_r;
   wire issue_lpu_r;
   wire issue_agu_r;
   wire issue_fpu_r;
   wire issue_epu_r;
   reg [`NCPU_EPU_UOPW-1:0] epu_uop_nxt;
   reg [`NCPU_ALU_UOPW_OPC-1:0] alu_uop_opc_nxt;
   wire [`NCPU_ALU_UOPW-1:0] alu_uop_nxt;
   reg [`NCPU_LPU_UOPW-1:0] lpu_uop_nxt;
   wire [`NCPU_AGU_UOPW-1:0] agu_uop_nxt;
   wire [`NCPU_FPU_UOPW-1:0] fpu_uop_nxt;
   wire [2:0] agu_size;
   wire rs1_re_r;
   wire rs2_re_r;
   wire rs1_in_ROB_r, rs2_in_ROB_r;
   wire rs1_in_ARF_r, rs2_in_ARF_r;
   wire [`NCPU_DW-1:0] rob_rs1_dat_r, rob_rs2_dat_r;
   wire [`NCPU_DW-1:0] ARF_ROB_rs1_dout, ARF_ROB_rs2_dout;
   
   // Assert (2103281250)
   assign disp_AREADY = rob_disp_AREADY & pipe_issue_AREADY;
   assign rob_disp_AVALID = disp_AVALID & pipe_issue_AREADY;
   assign pipe_issue_AVALID = disp_AVALID & rob_disp_AREADY;
   
   always @(*)
      casez(disp_alu_opc_bus)
      17'b?_????_????_????_???1: alu_uop_opc_nxt = 5'd1;
      17'b?_????_????_????_??10: alu_uop_opc_nxt = 5'd2;
      17'b?_????_????_????_?100: alu_uop_opc_nxt = 5'd3;
      17'b?_????_????_????_1000: alu_uop_opc_nxt = 5'd4;
      17'b?_????_????_???1_0000: alu_uop_opc_nxt = 5'd5;
      17'b?_????_????_??10_0000: alu_uop_opc_nxt = 5'd6;
      17'b?_????_????_?100_0000: alu_uop_opc_nxt = 5'd7;
      17'b?_????_????_1000_0000: alu_uop_opc_nxt = 5'd8;
      17'b?_????_???1_0000_0000: alu_uop_opc_nxt = 5'd9;
      17'b?_????_??10_0000_0000: alu_uop_opc_nxt = 5'd10;
      17'b?_????_?100_0000_0000: alu_uop_opc_nxt = 5'd11;
      17'b?_????_1000_0000_0000: alu_uop_opc_nxt = 5'd12;
      17'b?_???1_0000_0000_0000: alu_uop_opc_nxt = 5'd13;
      17'b?_??10_0000_0000_0000: alu_uop_opc_nxt = 5'd14;
      17'b?_?100_0000_0000_0000: alu_uop_opc_nxt = 5'd15;
      17'b?_1000_0000_0000_0000: alu_uop_opc_nxt = 5'd16;
      17'b1_0000_0000_0000_0000: alu_uop_opc_nxt = 5'd17;
      default: alu_uop_opc_nxt = 5'd0;
      endcase

   assign alu_uop_nxt = {disp_rel15[14:0], alu_uop_opc_nxt[`NCPU_ALU_UOPW_OPC-1:0]};
      
   always @(*)
      casez(disp_lpu_opc_bus)
      5'b?_???1: lpu_uop_nxt = 3'd1;
      5'b?_??10: lpu_uop_nxt = 3'd2;
      5'b?_?100: lpu_uop_nxt = 3'd3;
      5'b?_1000: lpu_uop_nxt = 3'd4;
      5'b1_0000: lpu_uop_nxt = 3'd5;
      default: lpu_uop_nxt = 3'd0;
      endcase
   
   assign agu_size = disp_agu_load ? disp_agu_load_size : disp_agu_store_size;
   assign agu_uop_nxt = {disp_agu_load, disp_agu_store, disp_agu_barr, disp_agu_sign_ext, agu_size[2:0]};
   
   assign fpu_uop_nxt = {`NCPU_FPU_UOPW{1'b0}};

   always @(*)
      casez(disp_epu_opc_bus)
      8'b????_???1: epu_uop_nxt = 4'd1;
      8'b????_??10: epu_uop_nxt = 4'd2;
      8'b????_?100: epu_uop_nxt = 4'd3;
      8'b????_1000: epu_uop_nxt = 4'd4;
      8'b???1_0000: epu_uop_nxt = 4'd5;
      8'b??10_0000: epu_uop_nxt = 4'd6;
      8'b?100_0000: epu_uop_nxt = 4'd7;
      8'b1000_0000: epu_uop_nxt = 4'd8;
      default: epu_uop_nxt = 4'd0;
      endcase
   
   // Read operands from ARF
   // ARF can be consider as a DFF in the pipeline stage,
   // so the clock-enable signal should be applied to it.
   assign arf_rs1_re = disp_rs1_re & pipe_issue_cke;
   assign arf_rs1_addr = disp_rs1_addr;
   assign arf_rs2_re = disp_rs2_re & pipe_issue_cke;
   assign arf_rs2_addr = disp_rs2_addr;
   
   // Read operands from ROB
   assign rob_disp_rs1_addr = arf_rs1_addr;
   assign rob_disp_rs2_addr = arf_rs2_addr;
   
   // Allocate entry in ROB
   assign rob_disp_pc = disp_pc;
   assign rob_disp_pred_tgt = disp_pred_tgt;
   assign rob_disp_rd_we = disp_rd_we;
   assign rob_disp_rd_addr = disp_rd_addr;

   // Pipeline stage
   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
      )
   PIPE_DISPATCH
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .flush   (flush),
         .A_en    (1'b1),
         .AVALID  (pipe_issue_AVALID),
         .AREADY  (pipe_issue_AREADY),
         .B_en    (1'b1),
         .BVALID  (pipe_issue_BVALID),
         .BREADY  (pipe_issue_BREADY),
         .cke     (pipe_issue_cke),
         .pending ()
      );

   // Assert (2103281331)
   assign issue_alu_AVALID = pipe_issue_BVALID & issue_alu_r;
   assign issue_lpu_AVALID = pipe_issue_BVALID & issue_lpu_r;
   assign issue_agu_AVALID = pipe_issue_BVALID & issue_agu_r;
   assign issue_fpu_AVALID = pipe_issue_BVALID & issue_fpu_r;
   assign issue_epu_AVALID = pipe_issue_BVALID & issue_epu_r;

   assign pipe_issue_BREADY = (~issue_alu_r | issue_alu_AREADY) &
                        (~issue_lpu_r | issue_lpu_AREADY) &
                        (~issue_agu_r | issue_agu_AREADY) &
                        (~issue_epu_r | issue_epu_AREADY) &
                        (~issue_fpu_r | issue_fpu_AREADY);

   // DFFs for pipeline stage
   nDFF_lr #(1) dff_issue_alu_r
     (clk,rst_n, pipe_issue_cke, |alu_uop_opc_nxt, issue_alu_r);
   nDFF_lr #(1) dff_issue_lpu_r
     (clk,rst_n, pipe_issue_cke, |lpu_uop_nxt, issue_lpu_r);
   nDFF_lr #(1) dff_issue_agu_r
     (clk,rst_n, pipe_issue_cke, |agu_uop_nxt, issue_agu_r);
   nDFF_lr #(1) dff_issue_fpu_r
     (clk,rst_n, pipe_issue_cke, |fpu_uop_nxt, issue_fpu_r);
   nDFF_lr #(1) dff_issue_epu_r
     (clk,rst_n, pipe_issue_cke, |epu_uop_nxt, issue_epu_r);
   nDFF_lr #(CONFIG_ROB_DEPTH_LOG2) dff_issue_id
     (clk,rst_n, pipe_issue_cke, rob_disp_id, issue_id);
   nDFF_lr #(`NCPU_EPU_UOPW) dff_issue_epu_uop
     (clk,rst_n, pipe_issue_cke, epu_uop_nxt, issue_epu_uop);
   nDFF_lr #(`NCPU_ALU_UOPW) dff_issue_alu_uop
     (clk,rst_n, pipe_issue_cke, alu_uop_nxt, issue_alu_uop);
   nDFF_lr #(`NCPU_LPU_UOPW) dff_issue_lpu_uop
     (clk,rst_n, pipe_issue_cke, lpu_uop_nxt, issue_lpu_uop);
   nDFF_lr #(`NCPU_AGU_UOPW) dff_issue_agu_uop
     (clk,rst_n, pipe_issue_cke, agu_uop_nxt, issue_agu_uop);
   nDFF_lr #(`NCPU_FPU_UOPW) dff_issue_fpu_uop
     (clk,rst_n, pipe_issue_cke, fpu_uop_nxt, issue_fpu_uop);

   nDFF_lr #(1) dff_rs1_re_r
     (clk,rst_n, pipe_issue_cke, disp_rs1_re, rs1_re_r);
   nDFF_lr #(1) dff_rs2_re_r
     (clk,rst_n, pipe_issue_cke, disp_rs2_re, rs2_re_r);
     
   nDFF_lr #(1) dff_rs1_in_ROB_r
     (clk,rst_n, pipe_issue_cke, rob_disp_rs1_in_ROB, rs1_in_ROB_r);
   nDFF_lr #(1) dff_rs2_in_ROB_r
     (clk,rst_n, pipe_issue_cke, rob_disp_rs2_in_ROB, rs2_in_ROB_r);
   nDFF_lr #(1) dff_rs1_in_ARF_r
     (clk,rst_n, pipe_issue_cke, rob_disp_rs1_in_ARF, rs1_in_ARF_r);
   nDFF_lr #(1) dff_rs2_in_ARF_r
     (clk,rst_n, pipe_issue_cke, rob_disp_rs2_in_ARF, rs2_in_ARF_r);

   // Data path: no need to reset
   nDFF_l #(`NCPU_DW) dff_imm32_r
     (clk, pipe_issue_cke, disp_imm32, issue_imm32);

   nDFF_l #(`NCPU_REG_AW) dff_issue_rs1_addr
     (clk, pipe_issue_cke, disp_rs1_addr, issue_rs1_addr);
   nDFF_l #(`NCPU_REG_AW) dff_issue_rs2_addr
     (clk, pipe_issue_cke, disp_rs2_addr, issue_rs2_addr);
     
   nDFF_l #(`NCPU_DW) dff_rob_rs1_dar_r
     (clk, pipe_issue_cke, rob_disp_rs1_dat, rob_rs1_dat_r);
   nDFF_l #(`NCPU_DW) dff_rob_rs2_dar_r
     (clk, pipe_issue_cke, rob_disp_rs2_dat, rob_rs2_dat_r);
     
   
   // Final operands
   // Assert (2103280032)
   assign ARF_ROB_rs1_dout = ({`NCPU_DW{rs1_in_ARF_r}} & arf_rs1_dout) |
                             ({`NCPU_DW{rs1_in_ROB_r}} & rob_rs1_dat_r);
   assign ARF_ROB_rs2_dout = ({`NCPU_DW{rs2_in_ARF_r}} & arf_rs2_dout) |
                             ({`NCPU_DW{rs2_in_ROB_r}} & rob_rs2_dat_r);
                              
   assign issue_rs1_dat = rs1_re_r ? ARF_ROB_rs1_dout : issue_imm32;
   assign issue_rs2_dat = rs2_re_r ? ARF_ROB_rs2_dout : issue_imm32;
   
   // If the insn do not need to read operand from regfile, then it uses immediate number
   // coded in the insn, and the operand is marked "ready".
   // If the operand is neither in ROB nor ARF, then the operand is marked "not ready".
   assign issue_rs1_rdy = ~rs1_re_r | rs1_in_ARF_r | rs1_in_ROB_r;
   assign issue_rs2_rdy = ~rs2_re_r | rs2_in_ARF_r | rs2_in_ROB_r;
   
   // synthesis translate_off
`ifndef SYNTHESIS
 `include "ncpu32k_assert.h"

   // Assertions
 `ifdef NCPU_ENABLE_ASSERT
   initial
      begin
         if ((`NCPU_EPU_IOPW != 8) |
            (`NCPU_EPU_UOPW != 4) |
            (`NCPU_ALU_IOPW != 17) |
            (`NCPU_ALU_UOPW_OPC != 5) |
            (`NCPU_LPU_IOPW != 5) |
            (`NCPU_LPU_UOPW != 3)
            )
            $fatal(1, "\n Please update this module.\n");
      end
      
   always @(posedge clk)
      begin
         // Assertion 2103281250
         if ((disp_AREADY & disp_AVALID) ^ (rob_disp_AREADY & rob_disp_AVALID))
            $fatal("\n Bugs on handshake logic between the upstream module and ROB\n");
         if ((disp_AREADY & disp_AVALID) ^ (pipe_issue_AREADY & pipe_issue_AVALID))
            $fatal("\n Bugs on handshake logic between the upstream module and PIPE_ISSUE\n");
         // Assertion 2103281331
         if (pipe_issue_BVALID & ~(issue_alu_r | issue_lpu_r | issue_agu_r | issue_fpu_r | issue_epu_r))
            $fatal("\n Bugs on DISPATCH. Some insns are unhandled. \n");
         // Assertion 2103280032
         if ((rs1_in_ARF_r & rs1_in_ROB_r) | (rs2_in_ARF_r & rs2_in_ROB_r))
            $fatal("\n Bugs on ROB\n");
      end
 `endif

`endif
// synthesis translate_on

endmodule
