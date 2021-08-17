module lsu_wb(
   input clk,
   input rst,
   input lsu_i_wb_sel,
   input [4:0] lsu_i_rd,
   input lsu_i_rf_we,
   input [63:0] lsu_i_alu_result,
   input [63:0] lsu_o_lsu_result,
   input lsu_i_valid,
   input [63:0] lsu_i_pc,
   input [31:0] lsu_i_insn,
   output reg wb_i_wb_sel,
   output reg [4:0] wb_i_rd,
   output reg wb_i_rf_we,
   output reg [63:0] wb_i_alu_result,
   output reg [63:0] wb_i_lsu_result,
   output reg wb_i_valid,
   output reg [63:0] wb_i_pc,
   output reg [31:0] wb_i_insn
);

   always @(posedge clk)
      if (rst)
         begin
            wb_i_rf_we <= 'b0;
            wb_i_valid <= 'b0;
         end
      else
         begin
            wb_i_wb_sel <= lsu_i_wb_sel;
            wb_i_rd <= lsu_i_rd;
            wb_i_rf_we <= lsu_i_rf_we;
            wb_i_alu_result <= lsu_i_alu_result;
            wb_i_lsu_result <= lsu_o_lsu_result;
            wb_i_valid <= lsu_i_valid;
            wb_i_pc <= lsu_i_pc;
            wb_i_insn <= lsu_i_insn;
         end
endmodule
