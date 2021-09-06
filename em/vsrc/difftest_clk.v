
import "DPI-C" function void dpic_clk(
   input int msr_tsc_count
);

module difftest_clk
(
   input clk,
   input [31:0] msr_tsc_count
);

   always @(posedge clk)
      dpic_clk(msr_tsc_count);

endmodule
