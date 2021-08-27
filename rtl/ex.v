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
   parameter CONFIG_P_ISSUE_WIDTH = 0,
   parameter CONFIG_PHT_P_NUM = 0,
   parameter CONFIG_BTB_P_NUM = 0
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
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_imm,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand1,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand2
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   wire [CONFIG_DW-1:0]                alu_result                    [IW-1:0];
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_alus
            ex_alu
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW))
            U_ALU
               (
                  .clk                 (clk),
                  .ex_alu_opc_bus      (ex_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
                  .ex_operand1         (ex_operand1[i*CONFIG_DW +: CONFIG_DW]),
                  .ex_operand2         (ex_operand2[i*CONFIG_DW +: CONFIG_DW]),
                  .alu_result          (alu_result[i])
               );
         end
   endgenerate

endmodule
