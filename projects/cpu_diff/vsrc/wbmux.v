`include "defines.v"

module wbmux(
   input wb_sel,
   input [63:0] alu_result,
   input [63:0] lsu_result,
   output [63:0] rd_dat
);

   assign rd_dat = wb_sel ? alu_result : lsu_result;

endmodule
