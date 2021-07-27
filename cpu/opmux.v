`include "defines.vh"

module opmux(
   input [`OP_SEL_W-1:0] i_op_sel,
   input [63:0] i_rop1,
   input [63:0] i_rop2,
   input [11:0] i_imm12,
   output [63:0] o_rs1,
   output [63:0] o_rs2
);
   assign o_rs1 = i_rop1;

   wire [63:0] imm12_zext, imm12_sext;

   assign imm12_zext = {52'b0, i_imm12};
   assign imm12_sext = {{52{i_imm12[11]}}, i_imm12};

   assign o_rs2 = ({64{i_op_sel[`OP_SEL_IMM_ZEXT]}} & imm12_zext) |
               ({64{i_op_sel[`OP_SEL_IMM_SEXT]}} & imm12_sext) |
               ({64{i_op_sel[`OP_SEL_RF]}} & i_rop2); 

endmodule
