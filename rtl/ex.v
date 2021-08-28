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

module ex
#(
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0
)
(
   input                               clk,
   input                               rst,
   input                               stall,
   input                               flush,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0]                ex_valid,
   input [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_alu_opc_bus,
   input [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lpu_opc_bus,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_opc_bus,
   input [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bru_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_imm,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand1,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand2,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_waddr,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_we,
   // To LS
   output                              ls_se_flush,
   output [`PC_W-1:0]                  ls_se_flush_tgt,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ls_valid,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ls_rf_dout,
   output [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ls_rf_waddr,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ls_rf_we

);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   
   wire                                add_s                         [IW-1:0];
   wire [CONFIG_DW-1:0]                add_sum                       [IW-1:0];
   wire                                add_carry                     [IW-1:0];
   wire                                add_overflow                  [IW-1:0];
   wire                                b_taken;
   wire [`PC_W-1:0]                    b_tgt;
   wire [`BPU_UPD_W-1:0]               ex_bpu_upd_unpacked           [IW-1:0];
   wire [IW-1:0]                       se_fail_vec;
   wire [`PC_W*IW-1:0]                 se_tgt_vec;
   wire                                se_fail;
   wire [`PC_W-1:0]                    se_tgt;
   wire [IW-1:0]                       s1i_valid;
   wire [CONFIG_DW*IW-1:0]             s1i_rf_dout;
   genvar i;
   
   //
   // FUs
   //
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_alus
            assign add_s[i] =
               (
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_ALU_SUB] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BEQ] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BNE] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BGTU] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BGT] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BLEU] |
                  ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW][`NCPU_BRU_BLE]
               );
               
            assign ex_bpu_upd_unpacked[i] = ex_bpu_upd[i*`BPU_UPD_W +: `BPU_UPD_W];
            
            ex_add
               #(/*AUTOINSTPARAM*/)
            U_ADD
               (
                  .a                   (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                  .b                   (ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                  .s                   (add_s[i]),
                  .sum                 (add_sum[i]),
                  .carry               (add_carry[i]),
                  .overflow            (add_overflow[i])
               );
               
            ex_alu
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW))
            U_ALU
               (
                  .ex_alu_opc_bus      (ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ex_operand1         (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                  .ex_operand2         (ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                  .add_sum             (add_sum[i]),
                  .alu_result          (s1i_rf_dout[i*CONFIG_DW +: CONFIG_DW])
               );
            
            // The first FU
            if (i == 0)
               begin
                  ex_bru
                     #(/*AUTOINSTPARAM*/)
                  U_BRU
                     (
                        .clk              (clk),
                        .ex_valid         (ex_valid[i]),
                        .ex_bru_opc_bus   (ex_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                        .ex_pc            (ex_pc[i*`PC_W +: `PC_W]),
                        .ex_imm           (ex_imm[i*CONFIG_DW +: CONFIG_DW]),
                        .ex_operand1      (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                        .ex_operand2      (ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                        .add_sum          (add_sum[i]),
                        .add_carry        (add_carry[i]),
                        .add_overflow     (add_overflow[i]),
                        .b_taken          (b_taken),
                        .b_tgt            (b_tgt)
                     );
               end
         end
   endgenerate
   
   // Speculative execution check point
   assign se_fail_vec[0] = (b_taken ^ ex_bpu_upd_unpacked[i][`BPU_UPD_TAKEN]) | (b_tgt != ex_bpu_upd_unpacked[i][`BPU_UPD_TGT]);
   assign se_tgt_vec[0] = (b_taken) ? b_tgt : (ex_pc[0]+'b1);
   generate
      for(i=1;i<IW;i=i+1)
         begin
            assign se_fail_vec[i] = (ex_bpu_upd_unpacked[i][`BPU_UPD_TAKEN]);
            assign se_tgt_vec[i] = (ex_pc[i]+'b1);
         end
   endgenerate
   
   pmux #(.SELW(FW), .DW(`PC_W)) U_PMUX_SE_TGT (.sel(se_fail_vec), .din(se_tgt_vec), .dout(se_tgt), .valid(se_fail) );
   
   assign s1i_valid = (ex_valid & ~se_fail);
   
   //
   // Pipeline stage
   //
   mDFF_lr # (.DW(1)) ff_ls_se_flush (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(se_fail), .Q(ls_se_flush) );
   mDFF_l # (.DW(`PC_W)) ff_ls_se_flush_tgt (.CLK(clk), .LOAD(p_ce), .D(se_tgt), .Q(ls_se_flush_tgt) );
   mDFF_lr # (.DW(IW)) ff_ls_valid (.CLK(clk), .RST(rst), .LOAD(p_ce), .D(s1i_valid), .Q(ls_valid) );
   mDFF_l # (.DW(`NCPU_REG_AW*IW)) ff_ls_rf_waddr (.CLK(clk), .LOAD(p_ce), .D(ex_rf_waddr), .Q(ls_rf_waddr) );
   mDFF_l # (.DW(IW)) ff_ls_rf_waddr (.CLK(clk), .LOAD(p_ce), .D(ex_rf_we), .Q(ls_rf_we) );
   mDFF_l # (.DW(CONFIG_DW*IW)) ff_ls_rf_dout (.CLK(clk), .LOAD(p_ce), .D(s1i_rf_dout), .Q(ls_rf_dout) );
   
   
endmodule
