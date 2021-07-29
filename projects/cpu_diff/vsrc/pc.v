module pc
(
   input clk,
   input rst,
   input flush,
   input [61:0] pc_tgt,
   output [61:0] o_pc
);

   reg [61:0] pc_r;
   wire [61:0] pc_nxt;

   always @(posedge clk)
      if (rst)
         begin
            pc_r <= {62{1'b1}};
         end
      else
         begin
            pc_r <= pc_nxt;
         end

   assign pc_nxt = flush ? pc_tgt : (pc_r + 'b1);

   assign o_pc = pc_nxt;

endmodule
