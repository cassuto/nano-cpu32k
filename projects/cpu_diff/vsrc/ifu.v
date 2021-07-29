module ifu #(
   parameter IRAM_AW
)
(
   input clk,
   input rst,
   input i_flush,
   input [61:0] i_pc_tgt,
   output [IRAM_AW-1:0] o_iram_addr,
   output o_iram_re,
   output reg [63:0] o_pc
);

   wire [61:0] pc;

   pc PC
   (
      .clk     (clk),
      .rst     (rst),
      .flush   (i_flush),
      .pc_tgt  (i_pc_tgt),
      .o_pc    (pc)
   );

   assign o_iram_addr = pc[IRAM_AW-1:0];
   assign o_iram_re = 1'b1;

   always @(posedge clk)
      o_pc <= {pc[61:0], 2'b00};

endmodule
