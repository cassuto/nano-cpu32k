`include "defines.vh"

module idu(
   input [31:0] i_insn,
   output o_rf_we,
   output [4:0] o_rd,
   output [4:0] o_rs1_addr,
   output [4:0] o_rs2_addr,
   output [`OP_SEL_W-1:0] op_sel,
   output [`ALU_OPW-1:0] fu_sel,
   output wb_sel, // 0 = ALU, 1 = LSU
   output [11:0] imm12
);

   wire [6:0] opcode;
   wire [4:0] rd;
   wire [2:0] funct3;
   wire [4:0] rs1;

   assign opcode = i_insn[6:0];
   assign rd = i_insn[11:7];
   assign funct3 = i_insn[14:12];
   assign rs1 = i_insn[19:15];
   assign imm12 = i_insn[31:20];

   wire op_addi = (opcode == 7'b0010011) & (funct3 == 3'b000);

   //
   // Generate control signals
   //

   assign o_rf_we = op_addi;

   assign o_rd = rd;

   assign o_rs1_addr = rs1;

   assign o_rs2_addr = 5'd0;

   assign op_sel[`OP_SEL_IMM_SEXT] = op_addi;
   assign op_sel[`OP_SEL_IMM_ZEXT] = 'b0;
   assign op_sel[`OP_SEL_RF] = 'b0;

   assign fu_sel[`ALU_OP_ADD] = op_addi;
   assign fu_sel[`ALU_OP_SUB] = 'b0;
   assign fu_sel[`ALU_OP_AND] = 'b0;
   assign fu_sel[`ALU_OP_OR] = 'b0;
   assign fu_sel[`ALU_OP_XOR] = 'b0;
   assign fu_sel[`ALU_OP_SLL] = 'b0;
   assign fu_sel[`ALU_OP_SRL] = 'b0;

   assign wb_sel = op_addi;

endmodule
