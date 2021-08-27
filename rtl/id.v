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

module id
#(
   parameter CONFIG_AW = 0,
   parameter CONFIG_DW = 0,
   parameter CONFIG_P_ISSUE_WIDTH = 0,
   parameter CONFIG_PHT_P_NUM = 0,
   parameter CONFIG_BTB_P_NUM = 0,
   parameter CONFIG_AW = 0,
   parameter CONFIG_DW = 0,
   parameter CONFIG_ENABLE_MUL = 0,
   parameter CONFIG_ENABLE_DIV = 0,
   parameter CONFIG_ENABLE_DIVU = 0,
   parameter CONFIG_ENABLE_MOD = 0,
   parameter CONFIG_ENABLE_MODU = 0,
   parameter CONFIG_ENABLE_ASR = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   // From frontend
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid,
   output [CONFIG_P_ISSUE_WIDTH:0]      id_pop_cnt,
   input [`NCPU_INSN_DW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   input [CONFIG_AW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc,
   input [`FNT_EXC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd,
   // IRQ
   input                               id_irq
   // To EX
   
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   
   wire                                single_issue                  [IW-1:0];
   wire [CONFIG_DW-1:0]                imm                           [IW-1:0];
   wire [`NCPU_ALU_IOPW-1:0]           alu_opc_bus                   [IW-1:0];
   wire [`NCPU_LPU_IOPW-1:0]           lpu_opc_bus                   [IW-1:0];
   wire [`NCPU_EPU_IOPW-1:0]           epu_opc_bus                   [IW-1:0];
   wire [`NCPU_BRU_IOPW-1:0]           bru_opc_bus                   [IW-1:0];
   wire                                op_lsu_load                   [IW-1:0];
   wire                                op_lsu_store                  [IW-1:0];
   wire                                lsu_sign_ext                  [IW-1:0];
   wire                                op_lsu_barr                   [IW-1:0];
   wire [2:0]                          lsu_store_size                [IW-1:0];
   wire [2:0]                          lsu_load_size                 [IW-1:0];
   wire                                rf_we                         [IW-1:0];
   wire [`NCPU_REG_AW-1:0]             rf_waddr                      [IW-1:0];
   wire                                rf_rs1_re                     [IW-1:0];
   wire [`NCPU_REG_AW-1:0]             rf_rs1_addr                   [IW-1:0];
   wire                                rf_rs2_re                     [IW-1:0];
   wire [`NCPU_REG_AW-1:0]             rf_rs2_addr                   [IW-1:0];
   
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin
            id_dec
               #(/*AUTOINSTPARAM*/)
            U_DEC
               (
                  .id_valid            (id_valid[i]),
                  .id_ins              (id_ins[i*`NCPU_INSN_DW +: `NCPU_INSN_DW]),
                  .id_exc              (id_exc[i*`FNT_EXC_W]),
                  .id_irq              (id_irq),
                  .single_issue        (single_issue[i]),
                  .imm                 (imm[i]),
                  .alu_opc_bus         (alu_opc_bus[i]),
                  .lpu_opc_bus         (lpu_opc_bus[i]),
                  .epu_opc_bus         (epu_opc_bus[i]),
                  .bru_opc_bus         (bru_opc_bus[i]),
                  .op_lsu_load         (op_lsu_load[i]),
                  .op_lsu_store        (op_lsu_store[i]),
                  .lsu_sign_ext        (lsu_sign_ext[i]),
                  .op_lsu_barr         (op_lsu_barr[i]),
                  .lsu_store_size      (lsu_store_size[i]),
                  .lsu_load_size       (lsu_load_size[i]),
                  .rf_we               (rf_we[i]),
                  .rf_waddr            (rf_waddr[i]),
                  .rf_rs1_re           (rf_rs1_re[i]),
                  .rf_rs1_addr         (rf_rs1_addr[i]),
                  .rf_rs2_re           (rf_rs2_re[i]),
                  .rf_rs2_addr         (rf_rs2_addr[i])
               );
         end
   endgenerate

endmodule
