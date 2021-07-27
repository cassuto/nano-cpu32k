`include "defines.v"

module alu(
   input [`ALU_OPW-1:0] i_fu_sel,
   input [63:0] i_operand1,
   input [63:0] i_operand2,
   output [63:0] o_result
);

   wire [63:0] out_add, out_sub, out_and, out_or, out_xor;
   wire [63:0] out_sll, out_srl;

   assign o_result = ({64{i_fu_sel[`ALU_OP_ADD]}} & out_add) |
                     ({64{i_fu_sel[`ALU_OP_SUB]}} & out_sub) |
                     ({64{i_fu_sel[`ALU_OP_AND]}} & out_and) |
                     ({64{i_fu_sel[`ALU_OP_OR]}} & out_or) |
                     ({64{i_fu_sel[`ALU_OP_XOR]}} & out_xor) |
                     ({64{i_fu_sel[`ALU_OP_SLL]}} & out_sll) |
                     ({64{i_fu_sel[`ALU_OP_SRL]}} & out_srl);

   // Arithmetic
   assign out_add = i_operand1 + i_operand2;
   assign out_sub = i_operand1 - i_operand2;

   // Logic
   assign out_and = i_operand1 & i_operand2;
   assign out_or = i_operand1 | i_operand2;
   assign out_xor = i_operand1 ^ i_operand2;
   assign out_sll = i_operand1 << i_operand2[5:0];
   assign out_srl = i_operand1 >> i_operand2[5:0];

endmodule
