module forward(
   input clk,
   input i_re,
   input [4:0] i_operand_addr,
   input [63:0] i_rf_operand,
   output [63:0] o_operand,
   // LISTENING EXU
   input [4:0] exu_i_rd,
   input exu_i_rf_we,
   input [63:0] exu_i_rd_dat,
   // LISTENING LSU
   input [4:0] lsu_i_rd,
   input lsu_i_rf_we,
   input [63:0] lsu_i_rd_dat,
   // LISTENING WB
   input [4:0] wb_i_rd,
   input wb_i_rf_we,
   input [63:0] wb_i_rd_dat
);
   reg raw_dep_exu_r, raw_dep_lsu_r, raw_dep_wb_r;
   reg [63:0] exu_i_rd_dat_r, lsu_i_rd_dat_r, wb_i_rd_dat_r;

   /////////////////////////////////////////////////////////////////////////////////////////
   // Decode stage
   always @(posedge clk)
      begin
         if (i_re)
            begin
               raw_dep_exu_r <= (exu_i_rf_we & (i_operand_addr==exu_i_rd) & (|exu_i_rd));
               raw_dep_lsu_r <= (lsu_i_rf_we & (i_operand_addr==lsu_i_rd) & (|lsu_i_rd));
               raw_dep_wb_r <= (wb_i_rf_we & (i_operand_addr==wb_i_rd) & (|i_operand_addr & |wb_i_rd));

               exu_i_rd_dat_r <= exu_i_rd_dat;
               lsu_i_rd_dat_r <= lsu_i_rd_dat;
               wb_i_rd_dat_r <= wb_i_rd_dat;
            end
      end

   /////////////////////////////////////////////////////////////////////////////////////////
   // Execute stage
   assign o_operand = raw_dep_exu_r 
                        ? exu_i_rd_dat_r
                        : raw_dep_lsu_r
                           ? lsu_i_rd_dat_r
                           : raw_dep_wb_r
                              ? wb_i_rd_dat_r
                              : i_rf_operand;

endmodule
