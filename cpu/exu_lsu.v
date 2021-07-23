module exu_lsu(
   input clk,
   input rst,
   input [4:0] exu_i_rd,
   input exu_i_rf_we,
   input [63:0] exu_o_rd_dat,
   output reg [4:0] lsu_i_rd,
   output reg lsu_i_rf_we,
   output reg [63:0] lsu_i_rd_dat
);

   always @(posedge clk)
      if (rst)
         begin
            lsu_i_rf_we <= 'b0;
         end
      else
         begin
            lsu_i_rd <= exu_i_rd;
            lsu_i_rf_we <= exu_i_rf_we;
            lsu_i_rd_dat <= exu_o_rd_dat;
         end

endmodule
