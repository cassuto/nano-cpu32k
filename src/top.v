module top(
   input       clock, reset,
   input [31:0]   io_a,
   input [31:0]   io_b,
   output[31:0]   io_out
);

`ifdef RANDOMIZE_REG_INIT
   reg [31: 0] _RAND_0;
`endif   //RANDOMIZE_REG_INIT

   reg [31:0] reg_result;
   wire[31:0] _T_1 = io_a + io_b;
   assign io_out = reg_result;
   always @(posedge clock) begin
      if (reset)  begin
         reg_result <= 32'h0;
      end else begin
         reg_result <= _T_1;
      end
   end
endmodule
