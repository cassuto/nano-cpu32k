`include "defines.vh"

module opmux(
   input [`OP_SEL_W-1:0] op_sel,
   input [63:0] rf_rs1,
   input [63:0] rf_rs2,
   input [11:0] imm12,
   output [63:0] rs1,
   output [63:0] rs2
);
   assign rs1 = rf_rs1;

   wire [63:0] imm12_zext, imm12_sext;

   assign imm12_zext = {52'b0, imm12};
   assign imm12_sext = {{52{imm12[11]}}, imm12};

   assign rs2 = ({64{op_sel[`OP_SEL_IMM_ZEXT]}} & imm12_zext) |
               ({64{op_sel[`OP_SEL_IMM_SEXT]}} & imm12_sext) |
               ({64{op_sel[`OP_SEL_RF]}} & rf_rs2); 

endmodule
