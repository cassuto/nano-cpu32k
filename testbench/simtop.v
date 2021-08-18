module simtop(
   input clk,
   input rst
);

   ncpu64k DUT(
      .clk(clk),
      .rst(rst)
   );

endmodule
