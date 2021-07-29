`ifndef DEFINES_H_
`define DEFINES_H_

`define ALU_OPW 19

`define ALU_OP_ADD 0
`define ALU_OP_SUB 1
`define ALU_OP_AND 2
`define ALU_OP_OR 3
`define ALU_OP_XOR 4
`define ALU_OP_SLL 5
`define ALU_OP_SRL 6
`define ALU_OP_LUI 7
`define ALU_OP_AUIPC 8
`define ALU_OP_JAL 9
`define ALU_OP_JALR 10
`define ALU_OP_BEQ 11
`define ALU_OP_BNE 12
`define ALU_OP_BLT 13
`define ALU_OP_BGE 14
`define ALU_OP_BLTU 15
`define ALU_OP_BGEU 16
`define ALU_OP_SLTI 17
`define ALU_OP_SLTIU 18

`define OP_SEL_W 6

`define OP_SEL_RF 0
`define OP_SEL_IMM12_ZEXT 1
`define OP_SEL_IMM12_SEXT 2
`define OP_SEL_IMM13_SEXT 3
`define OP_SEL_IMM20_SEXT_SL12 4
`define OP_SEL_IMM21_SEXT 5

`endif
