`include "defines.v"

module idu(
   input [31:0] i_insn,
   input i_valid,
   output o_rf_we,
   output [4:0] o_rd,
   output [4:0] o_rs1_addr,
   output [4:0] o_rs2_addr,
   output o_rs1_re,
   output o_rs2_re,
   output [`OP_SEL_W-1:0] op_sel,
   output [`ALU_OPW-1:0] fu_sel,
   output lsu_op_load,
   output lsu_op_store,
   output lsu_sigext,
   output [3:0] lsu_size,
   output o_wb_sel, // 0 = ALU, 1 = LSU
   output [11:0] o_imm12,
   output [12:0] o_imm13,
   output [19:0] o_imm20,
   output [20:0] o_imm21,
   output o_valid,
   output [31:0] o_insn
);

   wire [6:0] opcode;
   wire [4:0] rd;
   wire [2:0] funct3;
   wire [4:0] rs1, rs2;
   wire [6:0] funct7;

   assign opcode = i_insn[6:0];
   assign rd = i_insn[11:7];
   assign funct3 = i_insn[14:12];
   assign rs1 = i_insn[19:15];
   assign rs2 = i_insn[24:20];
   assign funct7 = i_insn[31:25];

   wire op_lui = (opcode == 7'b0110111);
   wire op_auipc = (opcode == 7'b0010111);
   wire op_jal = (opcode == 7'b1101111);
   wire op_jalr = (opcode == 7'b1100111) & (funct3 == 3'b000);
   wire op_beq = (opcode == 7'b1100011) & (funct3 == 3'b000);
   wire op_bne = (opcode == 7'b1100011) & (funct3 == 3'b001);
   wire op_blt = (opcode == 7'b1100011) & (funct3 == 3'b100);
   wire op_bge = (opcode == 7'b1100011) & (funct3 == 3'b101);
   wire op_bltu = (opcode == 7'b1100011) & (funct3 == 3'b110);
   wire op_bgeu = (opcode == 7'b1100011) & (funct3 == 3'b111);
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
   wire op_addi = (opcode == 7'b0010011) & (funct3 == 3'b000);
   wire op_slti = (opcode == 7'b0010011) & (funct3 == 3'b010);
   wire op_sltiu = (funct3 == 3'b011) & (opcode ==7'b0010011);
   wire op_xori = (funct3 == 3'b100) & (opcode ==7'b0010011);
   wire op_ori = (funct3 == 3'b110) & (opcode ==7'b0010011);
   wire op_andi = (funct3 == 3'b111) & (opcode ==7'b0010011);
   wire op_slli = (funct7 == 7'b0000000) & (funct3 == 3'b001) & (opcode == 7'b0010011);
   wire op_srli = (funct7 == 7'b0000000) & (funct3 == 3'b101) & (opcode == 7'b0010011);
   wire op_srai = (funct7 == 7'b0100000) & (funct3 == 3'b101) & (opcode == 7'b0010011);
   wire op_add = (funct7 == 7'b0000000) & (funct3 == 3'b000) & (opcode == 7'b0110011);
   wire op_sub = (funct7 == 7'b0100000) & (funct3 == 3'b000) & (opcode == 7'b0110011);
   wire op_sll = (funct7 == 7'b0000000) & (funct3 == 3'b001) & (opcode == 7'b0110011);
   wire op_slt = (funct7 == 7'b0000000) & (funct3 == 3'b010) & (opcode == 7'b0110011);
   wire op_sltu = (funct7 == 7'b0000000) & (funct3 == 3'b011) & (opcode == 7'b0110011);
   wire op_xor = (funct7 == 7'b0000000) & (funct3 == 3'b100) & (opcode == 7'b0110011);
   wire op_srl = (funct7 == 7'b0000000) & (funct3 == 3'b101) & (opcode == 7'b0110011);
   wire op_sra = (funct7 == 7'b0100000) & (funct3 == 3'b101) & (opcode == 7'b0110011);
   wire op_or = (funct7 == 7'b0000000) & (funct3 == 3'b110) & (opcode == 7'b0110011);
   wire op_and = (funct7 == 7'b0000000) & (funct3 == 3'b111) & (opcode == 7'b0110011);
//fm pred succ rs1 000 rd 0001111 FENCE
//000000000000 00000 000 00000 1110011 ECALL
//000000000001 00000 000 00000 1110011 EBREAK

   wire op_addiw = (funct3 == 3'b000) & (opcode == 7'b0011011);
   wire op_slliw = (funct7 == 7'b0000000) & (funct3 == 3'b001) & (opcode == 7'b0011011);
   wire op_srliw = (funct7 == 7'b0000000) & (funct3 == 3'b101) & (opcode == 7'b0011011);
   wire op_sraiw = (funct7 == 7'b0100000) & (funct3 == 3'b101) & (opcode == 7'b0011011);
   wire op_addw = (funct7 == 7'b0000000) & (funct3 == 3'b000) & (opcode == 7'b0111011);
   wire op_subw = (funct7 == 7'b0100000) & (funct3 == 3'b000) & (opcode == 7'b0111011);
   wire op_sllw = (funct7 == 7'b0000000) & (funct3 == 3'b001) & (opcode == 7'b0111011);
   wire op_srlw = (funct7 == 7'b0000000) & (funct3 == 3'b101) & (opcode == 7'b0111011);
   wire op_sraw = (funct7 == 7'b0100000) & (funct3 == 3'b101) & (opcode == 7'b0111011);

   /*
   31 27 26 25 24 20 19 15 14 12 11 7 6 0
   funct7 rs2 rs1 funct3 rd opcode R-type
   imm[11:0] rs1 funct3 rd opcode I-type
   imm[11:5] rs2 rs1 funct3 imm[4:0] opcode S-type
   imm[12|10:5] rs2 rs1 funct3 imm[4:1|11] opcode B-type
   imm[31:12] rd opcode U-type
   imm[20|10:1|11|19:12] rd opcode J-type
   */
   wire R_type = (op_add|op_sub|op_sll|op_slt|op_sltu|op_xor|op_srl|op_sra|op_or|op_and|
                  op_addw|op_subw|op_sllw|op_srlw|op_sraw);
   wire I_type = (op_jalr|op_lb|op_lh|op_lw|op_lbu|op_lhu|op_addi|op_slti|op_sltiu|op_xori|
                  op_ori|op_andi|op_lwu|op_ld|op_addiw|op_slli|op_srli|op_srai|op_slliw|op_srliw|op_sraiw);
   wire S_type = (op_sb|op_sh|op_sw|op_sd);
   wire B_type = (op_beq|op_bne|op_blt|op_bge|op_bltu|op_bgeu);
   wire U_type = (op_lui|op_auipc);
   wire J_type = (op_jal);
   
   assign o_imm12 = S_type
                     ? {i_insn[31:25], i_insn[11:7]}
                     : i_insn[31:20]; /* I_type */
   
   assign o_imm13 = {i_insn[31], i_insn[7], i_insn[30:25], i_insn[11:8], 1'b0}; /* B_type */

   assign o_imm20 = i_insn[31:12]; /* U_type */

   assign o_imm21 = {i_insn[31], i_insn[19:12], i_insn[20], i_insn[30:21], 1'b0}; /* J_type*/

   //
   // Generate control signals
   //

   assign o_wb_sel = ~lsu_op_load;

   assign o_rf_we = (R_type|I_type|U_type|J_type);

   assign o_rd = rd;

   assign o_rs1_re = (R_type|I_type|S_type|B_type);
   assign o_rs2_re = (R_type|S_type|B_type);

   assign o_rs1_addr = rs1;

   assign o_rs2_addr = (R_type|S_type|B_type) ? rs2 : 5'd0;

   assign op_sel[`OP_SEL_RF] = (R_type); // B_type and S_type use `rop2` as operand
   assign op_sel[`OP_SEL_IMM12_SEXT] = op_addi|op_jalr|op_ori|lsu_op_load|lsu_op_store;
   assign op_sel[`OP_SEL_IMM12_ZEXT] = op_slli;
   assign op_sel[`OP_SEL_IMM13_SEXT] = B_type;
   assign op_sel[`OP_SEL_IMM20_SEXT_SL12] = op_lui|op_auipc;
   assign op_sel[`OP_SEL_IMM21_SEXT] = op_jal;

   assign fu_sel[`ALU_OP_LUI] = op_lui;
   assign fu_sel[`ALU_OP_AUIPC] = op_auipc;
   assign fu_sel[`ALU_OP_JAL] = op_jal;
   assign fu_sel[`ALU_OP_JALR] = op_jalr;
   assign fu_sel[`ALU_OP_BEQ] = op_beq;
   assign fu_sel[`ALU_OP_BNE] = op_bne;
   assign fu_sel[`ALU_OP_BLT] = op_blt;
   assign fu_sel[`ALU_OP_BGE] = op_bge;
   assign fu_sel[`ALU_OP_BLTU] = op_bltu;
   assign fu_sel[`ALU_OP_BGEU] = op_bgeu;
   assign fu_sel[`ALU_OP_ADD] = op_add|op_addi | lsu_op_load|lsu_op_store; // ALU is used as address generator
   assign fu_sel[`ALU_OP_SUB] = 'b0;
   assign fu_sel[`ALU_OP_AND] = 'b0;
   assign fu_sel[`ALU_OP_OR] = op_or|op_ori;
   assign fu_sel[`ALU_OP_XOR] = 'b0;
   assign fu_sel[`ALU_OP_SLL] = op_sll|op_slli;
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

   assign o_valid = i_valid;
   assign o_insn = i_insn;

endmodule
