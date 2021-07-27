module exu_lsu(
   input clk,
   input rst,
   
   input exu_i_wb_sel,
   input exu_i_lsu_op_load,
   input exu_i_lsu_op_store,
   input exu_i_lsu_sigext,
   input [3:0] exu_i_lsu_size,
   input [4:0] exu_i_rd,
   input exu_i_rf_we,
   input [63:0] exu_o_alu_result,
   input [63:0] exu_i_rop2,
   input exu_i_valid,
   input [63:0] exu_i_pc,
   input [31:0] exu_i_insn,

   output reg lsu_i_wb_sel,
   output reg lsu_i_lsu_op_load,
   output reg lsu_i_lsu_op_store,
   output reg lsu_i_lsu_sigext,
   output reg [3:0] lsu_i_lsu_size,
   output reg [4:0] lsu_i_rd,
   output reg lsu_i_rf_we,
   output reg [63:0] lsu_i_alu_result,
   output reg [63:0] lsu_i_rop2,
   output reg lsu_i_valid,
   output reg [63:0] lsu_i_pc,
   output reg [31:0] lsu_i_insn
);

   always @(posedge clk)
      if (rst)
         begin
            lsu_i_lsu_op_load <= 'b0;
            lsu_i_lsu_op_store <= 'b0;
            lsu_i_rf_we <= 'b0;
            lsu_i_valid <= 'b0;
         end
      else
         begin
            lsu_i_lsu_op_load <= exu_i_lsu_op_load;
            lsu_i_lsu_op_store <= exu_i_lsu_op_store;
            lsu_i_lsu_sigext <= exu_i_lsu_sigext;
            lsu_i_lsu_size <= exu_i_lsu_size;
            lsu_i_rd <= exu_i_rd;
            lsu_i_rf_we <= exu_i_rf_we;
            lsu_i_alu_result <= exu_o_alu_result;
            lsu_i_wb_sel <= exu_i_wb_sel;
            lsu_i_rop2 <= exu_i_rop2;
            lsu_i_valid <= exu_i_valid;
            lsu_i_pc <= exu_i_pc;
            lsu_i_insn <= exu_i_insn;
         end

endmodule
