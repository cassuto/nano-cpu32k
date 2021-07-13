module pc #(
   parameter IRAM_AW
)
(
   input clk,
   input rst,
   output [IRAM_AW-1:0] iram_addr
);

   reg [IRAM_AW-3:0] pc_r;
   wire [IRAM_AW-3:0] pc_nxt;

   always @(posedge clk)
      if (rst)
         begin
            pc_r <= 'b0;
         end
      else
         begin
            pc_r <= pc_nxt;
         end

   assign pc_nxt = pc_r + 'b1;

   assign iram_addr = {pc_nxt[IRAM_AW-3:0], 2'b00};

endmodule
