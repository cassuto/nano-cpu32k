module forward(
   input clk,
   input i_re,
   input [4:0] i_operand_addr,
   input [63:0] i_rf_operand,
   output [63:0] o_operand,
   output o_stall_from_forward,
   // LISTENING EXU
   input exu_i_op_load,
   input [4:0] exu_i_rd,
   input exu_i_rf_we,
   input [63:0] exu_i_rd_dat,
   // LISTENING LSU
   input [4:0] lsu_i_rd,
   input lsu_i_rf_we,
   input [63:0] lsu_i_rd_dat,
   input [63:0] lsu_i_lsu_dat,
   input lsu_i_lsu_op_load,
   // LISTENING WB
   input [4:0] wb_i_rd,
   input wb_i_rf_we,
   input [63:0] wb_i_rd_dat
);
   reg raw_dep_exu_r, raw_dep_lsu_alu_r, raw_dep_lsu_lsu_r, raw_dep_wb_r;
   reg [63:0] exu_i_rd_dat_r, lsu_i_rd_dat_r, lsu_i_lsu_dat_r, wb_i_rd_dat_r;

   // Stall the frontend pipeline if it has RAW dependency with LSU
   assign o_stall_from_forward = (exu_i_rf_we & exu_i_op_load & (i_operand_addr==exu_i_rd) & (|exu_i_rd));

   /////////////////////////////////////////////////////////////////////////////////////////
   // Decode stage
   always @(posedge clk)
      begin
         if (i_re)
            begin
               raw_dep_exu_r <= (exu_i_rf_we & (i_operand_addr==exu_i_rd) & (|exu_i_rd));
               raw_dep_lsu_alu_r <= ~lsu_i_lsu_op_load & (lsu_i_rf_we & (i_operand_addr==lsu_i_rd) & (|lsu_i_rd));
               raw_dep_lsu_lsu_r <= lsu_i_lsu_op_load & (lsu_i_rf_we & (i_operand_addr==lsu_i_rd) & (|lsu_i_rd));
               raw_dep_wb_r <= (wb_i_rf_we & (i_operand_addr==wb_i_rd) & (|wb_i_rd));

               exu_i_rd_dat_r <= exu_i_rd_dat;
               lsu_i_rd_dat_r <= lsu_i_rd_dat;
               lsu_i_lsu_dat_r <= lsu_i_lsu_dat;
               wb_i_rd_dat_r <= wb_i_rd_dat;
            end
      end

   /////////////////////////////////////////////////////////////////////////////////////////
   // Execute stage
   assign o_operand = raw_dep_exu_r 
                        ? exu_i_rd_dat_r
                        : raw_dep_lsu_alu_r // LSU Stage (ALU)
                           ? lsu_i_rd_dat_r
                           : raw_dep_lsu_lsu_r // LSU Stage (LSU)
                              ? lsu_i_lsu_dat_r
                              : raw_dep_wb_r
                                 ? wb_i_rd_dat_r
                                 : i_rf_operand;

endmodule
