module ifu #(
   parameter IRAM_AW
)
(
   input clk,
   input rst,
   output [IRAM_AW-1:0] o_iram_addr,
   output [63:0] o_pc
);

   wire [61:0] pc;

   pc PC
   (
      .clk     (clk),
      .rst     (rst),
      .o_pc    (pc)
   );

   assign o_iram_addr = pc[IRAM_AW-1:0];
   assign o_pc = {pc[61:0], 2'b00};

endmodule
