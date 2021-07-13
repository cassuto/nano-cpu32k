module pc(
   input clk,
   input rst,
   output [63:0] iram_addr
);

   reg [61:0] pc_r;
   wire [61:0] pc_nxt;

   always @(posedge clk)
      if (rst)
         begin
            pc_r <= 62'b0;
         end
      else
         begin
            pc_r <= pc_nxt;
         end

   assign pc_nxt = pc_r + 'b1;

   assign iram_addr = {pc_nxt[61:0], 2'b00};

endmodule
