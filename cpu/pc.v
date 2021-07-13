module pc(
   input clk,
   input rst,
   output [63:0] iram_addr
);

   reg [61:0] pc_r;

   always @(posedge clk)
      if (rst)
         begin
            pc_r <= 62'b0;
         end
      else
         begin
            pc_r <= pc_r + 'b1;
         end

   assign iram_addr = {pc_r[61:0], 2'b00};

endmodule
