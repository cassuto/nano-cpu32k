module iram #(
   parameter IRAM_AW
)
(
   input clk,
   input rst,
   input i_re,
   output reg [31:0] o_insn,
   output reg o_valid,
   input [IRAM_AW-1:0] i_addr
);

   reg [31:0] imem[1<<IRAM_AW];
   
   always @(posedge clk)
      begin
         if (rst)
            begin
               o_insn <= 'b0;
               o_valid <= 'b0;
            end
         else if (i_re)
            begin
               o_insn <= imem[i_addr];
               o_valid <= i_re;
            end
      end

   initial
      $readmemh("../../testcase/addi.memh", imem, 0);

endmodule
