module forward(
   input [4:0] i_operand_addr,
   input [63:0] i_rf_operand,
   output [63:0] o_operand,
   // LISTENING LSU
   input [4:0] lsu_i_rd,
   input lsu_i_rf_we,
   input [63:0] lsu_i_rd_dat,
   // LISTENING WB
   input [4:0] wb_i_rd,
   input wb_i_rf_we,
   input [63:0] wb_i_rd_dat
);

   // do not bypass zero register
   assign o_operand = (wb_i_rf_we & (i_operand_addr==wb_i_rd) & (|i_operand_addr & |wb_i_rd))
                        ? wb_i_rd_dat
                        : (lsu_i_rf_we & (i_operand_addr==lsu_i_rd) & (|i_operand_addr & |lsu_i_rd))
                           ? lsu_i_rd_dat
                           : i_rf_operand;

endmodule
