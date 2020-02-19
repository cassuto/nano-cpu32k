module tb_ncpu32k_cell_pipebuf;

   reg clk;
   reg rst_n;
   reg [3:0] din;
   
   initial begin
      din =4'b0;
      clk = 1'b0;
      rst_n = 1'b0;
      #15 rst_n = 1'b1;
      forever #10 clk = ~clk;
   end
   
   reg in_valid = 1'b1;
   wire in_ready;
   wire out_valid;
   reg out_ready = 0;
   wire [3:0] dout;
   
   always @(posedge clk) begin
      if(in_ready) begin
         din<=din + 1'b1;
      end
   end
   
   ncpu32k_cell_pipebuf #(4) p0(
      .clk(clk),
      .rst_n(rst_n),
      .din(din),
      .dout(dout),
      .in_valid(in_valid),
      .in_ready(in_ready),
      .out_ready(out_ready),
      .out_valid(out_valid)
   );
   
   always @(posedge clk) begin
      if(out_valid) begin
         out_ready <= 1;
      end
   end

endmodule