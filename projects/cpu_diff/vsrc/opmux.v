`include "defines.v"

module opmux(
   input [`OP_SEL_W-1:0] i_op_sel,
   input [63:0] i_rop1,
   input [63:0] i_rop2,
   input [11:0] i_imm12,
   input [12:0] i_imm13,
   input [19:0] i_imm20,
   input [20:0] i_imm21,
   output [63:0] o_rs1,
   output [63:0] o_rs2
);
   assign o_rs1 = i_rop1;

   wire [63:0] imm12_zext, imm12_sext, imm13_sext, imm20_sext_sl12, imm21_sext_sl12;

   assign imm12_zext = {52'b0, i_imm12};
   assign imm12_sext = {{52{i_imm12[11]}}, i_imm12};
   assign imm13_sext = {{51{i_imm13[12]}}, i_imm13};
   assign imm20_sext_sl12 = {{32{i_imm20[19]}}, i_imm20, 12'b0};
   assign imm21_sext_sl12 = {{31{i_imm21[20]}}, i_imm21, 12'b0};

   assign o_rs2 = ({64{i_op_sel[`OP_SEL_IMM12_ZEXT]}} & imm12_zext) |
               ({64{i_op_sel[`OP_SEL_IMM12_SEXT]}} & imm12_sext) |
               ({64{i_op_sel[`OP_SEL_IMM13_SEXT]}} & imm13_sext) |
               ({64{i_op_sel[`OP_SEL_IMM20_SEXT_SL12]}} & imm20_sext_sl12) |
               ({64{i_op_sel[`OP_SEL_IMM21_SEXT_SL12]}} & imm21_sext_sl12) |
               ({64{i_op_sel[`OP_SEL_RF]}} & i_rop2); 

endmodule
