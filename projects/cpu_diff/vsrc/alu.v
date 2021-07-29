`include "defines.v"

module alu(
   input [`ALU_OPW-1:0] i_fu_sel,
   input [63:0] i_pc,
   input [63:0] i_operand1,
   input [63:0] i_operand2,
   input [63:0] i_rop2,
   output [63:0] o_result,
   output o_flush,
   output reg [61:0] o_pc_tgt
);

   wire [63:0] out_lui, out_auipc, out_jal, out_add, out_sub, out_and, out_or, out_xor;
   wire [63:0] out_slti, out_sltiu;
   wire [63:0] out_sll, out_srl;

   assign o_result = ({64{i_fu_sel[`ALU_OP_LUI]}} & out_lui) |
                     ({64{i_fu_sel[`ALU_OP_AUIPC]}} & out_auipc) |
                     ({64{i_fu_sel[`ALU_OP_JAL] | i_fu_sel[`ALU_OP_JALR]}} & out_jal) |
                     ({64{i_fu_sel[`ALU_OP_ADD]}} & out_add) |
                     ({64{i_fu_sel[`ALU_OP_SUB]}} & out_sub) |
                     ({64{i_fu_sel[`ALU_OP_AND]}} & out_and) |
                     ({64{i_fu_sel[`ALU_OP_OR]}} & out_or) |
                     ({64{i_fu_sel[`ALU_OP_XOR]}} & out_xor) |
                     ({64{i_fu_sel[`ALU_OP_SLL]}} & out_sll) |
                     ({64{i_fu_sel[`ALU_OP_SRL]}} & out_srl) |
                     ({64{i_fu_sel[`ALU_OP_SLTI]}} & out_slti) |
                     ({64{i_fu_sel[`ALU_OP_SLTIU]}} & out_sltiu);

   assign out_lui = i_operand2;
   assign out_auipc = i_operand2 + i_pc;

   // Arithmetic
   assign out_add = i_operand1 + i_operand2;
   assign out_sub = i_operand1 - i_operand2;

   // Logic
   assign out_and = i_operand1 & i_operand2;
   assign out_or = i_operand1 | i_operand2;
   assign out_xor = i_operand1 ^ i_operand2;
   assign out_sll = $unsigned(i_operand1) << i_operand2[6:0];
   assign out_srl = $unsigned(i_operand1) >> i_operand2[6:0];

   // Branch
   assign out_jal = {i_pc[63:2] + 'b1, 2'b0};

   // Compator
   assign out_slti = ($signed(i_operand1) < $signed(i_operand2)) ? 64'd1 : 64'd0;
   assign out_sltiu = ($unsigned(i_operand1) < $unsigned(i_operand2)) ? 64'd1 : 64'd0;

   reg bcc;
   always @(*)
      begin
         bcc = 1'b0;
         if (i_fu_sel[`ALU_OP_BEQ])
            bcc = (i_operand1 == i_rop2);
         else if (i_fu_sel[`ALU_OP_BNE])
            bcc = (i_operand1 != i_rop2);
         else if (i_fu_sel[`ALU_OP_BLT])
            bcc = ($signed(i_operand1) < $signed(i_rop2));
         else if (i_fu_sel[`ALU_OP_BGE])
            bcc = ($signed(i_operand1) >= $signed(i_rop2));
         else if (i_fu_sel[`ALU_OP_BLTU])
            bcc = ($unsigned(i_operand1) < $unsigned(i_rop2));
         else if (i_fu_sel[`ALU_OP_BGEU])
            bcc = ($unsigned(i_operand1) >= $unsigned(i_rop2));
         else begin
            bcc = 1'b0;
         end
      end

   assign o_flush = i_fu_sel[`ALU_OP_JAL] | i_fu_sel[`ALU_OP_JALR] | bcc;

   always @(*)
      if (i_fu_sel[`ALU_OP_JAL] | bcc)
         o_pc_tgt = i_pc[63:2] + i_operand2[63:2];
      else if (i_fu_sel[`ALU_OP_JALR])
         o_pc_tgt = i_operand1[63:2] + i_operand2[63:2];
      else
         o_pc_tgt = 62'b0;

endmodule
