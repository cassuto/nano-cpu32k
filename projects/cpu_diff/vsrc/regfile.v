module regfile(
   input clk,
   input i_rs1_re,
   input i_rs2_re,
   input [4:0] i_rs1_addr,
   input [4:0] i_rs2_addr,
   output reg [63:0] rs1,
   output reg [63:0] rs2,
   input [4:0] i_rd,
   input i_rf_we,
   input [63:0] i_rd_dat,
   output [63:0] o_regs[31:0]
);

   reg [63:0] rf [31:0];

   always @(posedge clk)
      begin
         if (i_rs1_re)
            rs1 <= (|i_rs1_addr) ? rf[i_rs1_addr] : 64'b0;
         if (i_rs2_re)
            rs2 <= (|i_rs2_addr) ? rf[i_rs2_addr] : 64'b0;
      end

   always @(posedge clk)
      if (i_rf_we && (|i_rd))
         begin
            rf[i_rd] <= i_rd_dat;
         end

   assign o_regs = rf;

endmodule
