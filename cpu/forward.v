module forward(
   input [4:0] i_operand_addr,
   input [63:0] i_rf_operand,
   output [63:0] o_operand,
   input [4:0] lsu_i_rd,
   input lsu_i_rf_we,
   input [63:0] lsu_i_rd_dat
);

   assign o_operand = (lsu_i_rf_we & (i_operand_addr==lsu_i_rd))
                        ? lsu_i_rd_dat
                        : i_rf_operand;

endmodule
