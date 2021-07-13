module regfile(
   input clk,
   input [4:0] i_rs1_addr,
   input [4:0] i_rs2_addr,
   output [63:0] rs1,
   output [63:0] rs2,
   input [4:0] i_rd,
   input i_rf_we,
   input [63:0] i_rd_dat
);

   reg [63:0] rf [31:0];

   assign rs1 = (|i_rs1_addr) ? rf[i_rs1_addr] : 64'b0;
   assign rs2 = (|i_rs2_addr) ? rf[i_rs2_addr] : 64'b0;

   always @(posedge clk)
      if (i_rf_we && (|i_rd))
         begin
            rf[i_rd] <= i_rd_dat;
         end

endmodule
