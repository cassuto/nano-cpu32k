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

module ex_alu
#(
   parameter                           CONFIG_DW = 0
)
(
   input                               clk,
   input [`NCPU_ALU_IOPW-1:0]          ex_alu_opc_bus,
   input [CONFIG_DW-1:0]               ex_operand1,
   input [CONFIG_DW-1:0]               ex_operand2,
   output [CONFIG_DW-1:0]              alu_result
);
   wire [CONFIG_DW-1:0]                dat_adder;
   wire [CONFIG_DW-1:0]                dat_and;
   wire [CONFIG_DW-1:0]                dat_or;
   wire [CONFIG_DW-1:0]                dat_xor;
   wire [CONFIG_DW-1:0]                dat_shifter;
   wire [CONFIG_DW-1:0]                dat_move;
   wire [CONFIG_DW-1:0]                dat_branch;
   wire                                sel_adder;
   wire                                sel_and;
   wire                                sel_or;
   wire                                sel_xor;
   wire                                sel_shifter;
   wire                                sel_move;

   //
   // Adder
   //
   assign dat_adder = (ex_alu_opc_bus[`NCPU_ALU_ADD])
                        ? ex_operand1 + ex_operand2
                        : ex_operand1 - ex_operand2;
   assign sel_adder = (ex_alu_opc_bus[`NCPU_ALU_ADD] | ex_alu_opc_bus[`NCPU_ALU_SUB]);

   //
   // Logic Arithmetic
   //
   assign dat_and = (ex_operand1 & ex_operand2);
   assign dat_or = (ex_operand1 | ex_operand2);
   assign dat_xor = (ex_operand1 ^ ex_operand2);
   assign sel_and = ex_alu_opc_bus[`NCPU_ALU_AND];
   assign sel_or = ex_alu_opc_bus[`NCPU_ALU_OR];
   assign sel_xor = ex_alu_opc_bus[`NCPU_ALU_XOR];

   //
   // Shifter
   //

   wire [CONFIG_DW-1:0] shift_right;
   wire [CONFIG_DW-1:0] shift_lsw;

   function [CONFIG_DW-1:0] reverse_bits;
      input [CONFIG_DW-1:0] a;
	   integer 			       i;
	   begin
         for(i=0; i<CONFIG_DW; i=i+1)
            reverse_bits[CONFIG_DW-1-i] = a[i];
      end
   endfunction

   assign shift_lsw = ex_alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(ex_operand1) : ex_operand1;
   generate
      if (CONFIG_ENABLE_ASR)
         begin : gen_asr
            wire [CONFIG_DW-1:0] shift_msw;
            wire [CONFIG_DW*2-1:0] shift_wide;
            assign shift_msw = ex_alu_opc_bus[`NCPU_ALU_ASR] ? {CONFIG_DW{ex_operand1[CONFIG_DW-1]}} : {CONFIG_DW{1'b0}};
            assign shift_wide = {shift_msw, shift_lsw} >> ex_operand2[4:0];
            assign shift_right = shift_wide[CONFIG_DW-1:0];
         end
      else
         assign shift_right = shift_lsw >> ex_operand2[4:0];
   endgenerate
   assign dat_shifter = ex_alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign sel_shifter = ex_alu_opc_bus[`NCPU_ALU_LSL] | ex_alu_opc_bus[`NCPU_ALU_LSR] | ex_alu_opc_bus[`NCPU_ALU_ASR];

   //
   // Move
   //
   assign sel_move = ex_alu_opc_bus[`NCPU_ALU_MHI];
   assign dat_move = {ex_operand2[16:0], 15'b0};
   
   // MUX
   assign alu_result =
      ({CONFIG_DW{sel_adder}} & dat_adder) |
      ({CONFIG_DW{sel_and}} & dat_and) |
      ({CONFIG_DW{sel_or}} & dat_or) |
      ({CONFIG_DW{sel_xor}} & dat_xor) |
      ({CONFIG_DW{sel_shifter}} & dat_shifter) |
      ({CONFIG_DW{sel_move}} & dat_move);


endmodule
