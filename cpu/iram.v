module iram #(
   parameter IRAM_AW
)
(
   input clk,
   input rst,
   output reg [31:0] o_insn,
   input [IRAM_AW-1:0] i_addr
);

   reg [31:0] imem[1<<IRAM_AW];
   
   always @(posedge clk)
      begin
         if (rst)
            o_insn <= 'b0;
         else
            o_insn <= imem[i_addr];
      end

   initial
      $readmemb("testcase/addi.bin", imem, 0);

endmodule
