module idu_exu(
   input clk,
   input rst,
   input idu_o_rf_we,
   input [4:0] idu_o_rd,
   input [4:0] idu_o_rs1_addr,
   input [4:0] idu_o_rs2_addr,
   input [`OP_SEL_W-1:0] idu_o_op_sel,
   input [`ALU_OPW-1:0] idu_o_fu_sel,
   input idu_o_lsu_op_load,
   input idu_o_lsu_op_store,
   input idu_o_lsu_sigext,
   input [3:0] idu_o_lsu_size,
   input idu_o_wb_sel,
   input [11:0] idu_o_imm12,
   input [12:0] idu_o_imm13,
   input [19:0] idu_o_imm20,
   input [20:0] idu_o_imm21,
   input [5:0] idu_o_shamt,
   input idu_o_valid,
   input [63:0] idu_o_pc,
   input [31:0] idu_o_insn,
   output reg exu_i_rf_we,
   output reg [4:0] exu_i_rd,
   output reg [4:0] exu_i_rs1_addr,
   output reg [4:0] exu_i_rs2_addr,
   output reg [`OP_SEL_W-1:0] exu_i_op_sel,
   output reg [`ALU_OPW-1:0] exu_i_fu_sel,
   output reg exu_i_lsu_op_load,
   output reg exu_i_lsu_op_store,
   output reg exu_i_lsu_sigext,
   output reg [3:0] exu_i_lsu_size,
   output reg exu_i_wb_sel,
   output reg [11:0] exu_i_imm12,
   output reg [12:0] exu_i_imm13,
   output reg [19:0] exu_i_imm20,
   output reg [20:0] exu_i_imm21,
   output reg [5:0] exu_i_shmat,
   output reg exu_i_valid,
   output reg [63:0] exu_i_pc,
   output reg [31:0] exu_i_insn
);

   always @(posedge clk)
      if (rst)
         begin
            exu_i_rf_we <= 'b0;
            exu_i_op_sel <= 'b0;
            exu_i_fu_sel <= 'b0;
            exu_i_lsu_op_load <= 'b0;
            exu_i_lsu_op_store <= 'b0;
            exu_i_wb_sel <= 'b0;
            exu_i_valid <= 'b0;
         end
      else
         begin
            exu_i_rf_we <= idu_o_rf_we;
            exu_i_rd <= idu_o_rd;
            exu_i_rs1_addr <= idu_o_rs1_addr;
            exu_i_rs2_addr <= idu_o_rs2_addr;
            exu_i_op_sel <= idu_o_op_sel;
            exu_i_fu_sel <= idu_o_fu_sel;
            exu_i_lsu_op_load <= idu_o_lsu_op_load;
            exu_i_lsu_op_store <= idu_o_lsu_op_store;
            exu_i_lsu_sigext <= idu_o_lsu_sigext;
            exu_i_lsu_size <= idu_o_lsu_size;
            exu_i_wb_sel <= idu_o_wb_sel;
            exu_i_imm12 <= idu_o_imm12;
            exu_i_imm13 <= idu_o_imm13;
            exu_i_imm20 <= idu_o_imm20;
            exu_i_imm21 <= idu_o_imm21;
            exu_i_shmat <= idu_o_shamt;
            exu_i_valid <= idu_o_valid;
            exu_i_pc <= idu_o_pc;
            exu_i_insn <= idu_o_insn;
         end

endmodule
