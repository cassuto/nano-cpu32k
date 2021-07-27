`include "defines.vh"

module idu(
   input [31:0] i_insn,
   output o_rf_we,
   output [4:0] o_rd,
   output [4:0] o_rs1_addr,
   output [4:0] o_rs2_addr,
   output [`OP_SEL_W-1:0] op_sel,
   output [`ALU_OPW-1:0] fu_sel,
   output lsu_op_load,
   output lsu_op_store,
   output lsu_sigext,
   output [3:0] lsu_size,
   output wb_sel, // 0 = ALU, 1 = LSU
   output [11:0] imm12,
   output o_valid,
   output [31:0] o_insn
);

   wire [6:0] opcode;
   wire [4:0] rd;
   wire [2:0] funct3;
   wire [4:0] rs1, rs2;

   assign opcode = i_insn[6:0];
   assign rd = i_insn[11:7];
   assign funct3 = i_insn[14:12];
   assign rs1 = i_insn[19:15];
   assign rs2 = i_insn[24:20];

   wire op_addi = (opcode == 7'b0010011) & (funct3 == 3'b000);
   wire op_lb = (opcode == 7'b0000011) & (funct3 == 3'b000);
   wire op_lh = (opcode == 7'b0000011) & (funct3 == 3'b001);
   wire op_lw = (opcode == 7'b0000011) & (funct3 == 3'b010);
   wire op_lwu =  (opcode == 7'b0000011) & (funct3 == 3'b110);
   wire op_ld =  (opcode == 7'b0000011) & (funct3 == 3'b011);
   wire op_lbu = (opcode == 7'b0000011) & (funct3 == 3'b100);
   wire op_lhu = (opcode == 7'b0000011) & (funct3 == 3'b101);
   wire op_sb = (opcode == 7'b0100011) & (funct3 == 3'b000);
   wire op_sh = (opcode == 7'b0100011) & (funct3 == 3'b001);
   wire op_sw = (opcode == 7'b0100011) & (funct3 == 3'b010);
   wire op_sd = (opcode == 7'b0100011) & (funct3 == 3'b011);

   wire S_type = (opcode == 7'b0100011);

   assign imm12 = S_type
                     ? {i_insn[31:25], i_insn[11:7]}
                     : i_insn[31:20];

   //
   // Generate control signals
   //

   assign o_rf_we = op_addi | lsu_op_load;

   assign o_rd = rd;

   assign o_rs1_addr = rs1;

   assign o_rs2_addr = (lsu_op_store)
                        ? rs2
                        : 5'd0;

   assign op_sel[`OP_SEL_IMM_SEXT] = op_addi;
   assign op_sel[`OP_SEL_IMM_ZEXT] = 'b0;
   assign op_sel[`OP_SEL_RF] = 'b0;

   assign fu_sel[`ALU_OP_ADD] = op_addi | lsu_op_load|lsu_op_store; // ALU is used as address generator
   assign fu_sel[`ALU_OP_SUB] = 'b0;
   assign fu_sel[`ALU_OP_AND] = 'b0;
   assign fu_sel[`ALU_OP_OR] = 'b0;
   assign fu_sel[`ALU_OP_XOR] = 'b0;
   assign fu_sel[`ALU_OP_SLL] = 'b0;
   assign fu_sel[`ALU_OP_SRL] = 'b0;

   assign lsu_op_load = op_lb|op_lbu | op_lh|op_lhu | op_lw|op_lwu |op_ld;
   assign lsu_op_store = op_sb|op_sh|op_sw|op_sd;
   assign lsu_size = (op_lb|op_lbu|op_sb)
                        ? 4'd1
                        : (op_lh|op_lhu|op_sh)
                           ? 4'd2
                           : (op_lw|op_lwu|op_sw)
                              ? 4'd4
                              : 4'd8;
   assign lsu_sigext = (op_lb|op_lh|op_lw);

   assign wb_sel = op_addi;

   assign o_valid = 1'b1;

endmodule
