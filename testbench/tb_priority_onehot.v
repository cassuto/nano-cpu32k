`include "timescale.v"
`include "ncpu32k_config.h"

module tb_priority_onehot;

   localparam DW = 16;
   localparam ITERATIONS = (1<<DW);
   integer i;

   reg clk = 1'b0;
   reg [DW-1:0] P_P_din;
   wire [DW-1:0] P_P_dout;
   reg [DW-1:0] P_N_din;
   wire [DW-1:0] P_N_dout;
   reg [DW-1:0] N_P_din;
   wire [DW-1:0] N_P_dout;
   reg [DW-1:0] N_N_din;
   wire [DW-1:0] N_N_dout;
   integer randint;
   reg [DW-1:0] expected;
   
   initial forever #10 clk = ~clk;

   ncpu32k_priority_onehot
      #(
         .DW (DW),
         .POLARITY_DIN (1),
         .POLARITY_DOUT (1)
      )
   PRIORITY_ONEHOT_P_P
      (
         .DIN  (P_P_din),
         .DOUT (P_P_dout)
      );
   ncpu32k_priority_onehot
      #(
         .DW (DW),
         .POLARITY_DIN (1),
         .POLARITY_DOUT (0)
      )
   PRIORITY_ONEHOT_P_N
      (
         .DIN  (P_N_din),
         .DOUT (P_N_dout)
      );
   ncpu32k_priority_onehot
      #(
         .DW (DW),
         .POLARITY_DIN (0),
         .POLARITY_DOUT (1)
      )
   PRIORITY_ONEHOT_N_P
      (
         .DIN  (N_P_din),
         .DOUT (N_P_dout)
      );
   ncpu32k_priority_onehot
      #(
         .DW (DW),
         .POLARITY_DIN (0),
         .POLARITY_DOUT (0)
      )
   PRIORITY_ONEHOT_N_N
      (
         .DIN  (N_N_din),
         .DOUT (N_N_dout)
      );
   
   initial
      begin
         for(i=0; i<ITERATIONS; i=i+1)
            begin
               //randint = $random * $random * i;
               randint = i;

               expected = (randint[DW-1:0] & (~randint[DW-1:0]+1'b1)); // Find the first 1 in its binary format
               P_P_din = randint[DW-1:0];
               @(posedge clk);
               if (P_P_dout !== expected)
                  $fatal(1, "Bugs on P-P. Expected = ", expected, " Got = ", P_P_dout);

               expected = ~(randint[DW-1:0] & (~randint[DW-1:0]+1'b1)); // Find the first 1 in its binary format
               P_N_din = randint[DW-1:0];
               @(posedge clk);
               if (P_N_dout !== expected)
                  $fatal(1, "Bugs on P-N. Expected = ", expected, " Got = ", P_P_dout);

               expected = (randint[DW-1:0] & (~randint[DW-1:0]+1'b1)); // Find the first 1 in its binary format
               N_P_din = ~randint[DW-1:0];
               @(posedge clk);
               if (N_P_dout !== expected)
                  $fatal(1, "Bugs on N-P. Expected = ", expected, " Got = ", P_P_dout);

               expected = ~(randint[DW-1:0] & (~randint[DW-1:0]+1'b1)); // Find the first 1 in its binary format
               N_N_din = ~randint[DW-1:0];
               @(posedge clk);
               if (N_N_dout !== expected)
                  $fatal(1, "Bugs on N-N. Expected = ", expected, " Got = ", P_P_dout);
            end
         
         @(posedge clk);
         
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
      end      

endmodule
