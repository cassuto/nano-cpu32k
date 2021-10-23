/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

module rte64_gs
(
   input [63:0] din,
   output [5:0] dout,
   output gs
);
   wire leaf_dout [31:0];
   wire leaf_gs [31:0];
   wire [1:0] n1_dout [15:0];
   wire n1_gs [15:0];
   wire [2:0] n2_dout [7:0];
   wire n2_gs [7:0];
   wire [3:0] n3_dout [3:0];
   wire n3_gs [3:0];
   wire [4:0] n4_dout [1:0];
   wire n4_gs [1:0];
   genvar i;
   
   generate
      for(i=0;i<32;i=i+1)
         begin : gen_leaf
            assign leaf_dout[i] = (~din[2*i] & din[2*i+1]);
            assign leaf_gs[i] = (din[2*i] | din[2*i+1]);
         end
   endgenerate
   
   generate
      for(i=0;i<16;i=i+1)
         begin : gen_n1
            assign n1_dout[i] = leaf_gs[2*i] ? {1'b0, leaf_dout[2*i]} : {leaf_gs[2*i+1], leaf_dout[2*i+1]};
            assign n1_gs[i] = (leaf_gs[2*i] | leaf_gs[2*i+1]);
         end
   endgenerate
   
   generate
      for(i=0;i<8;i=i+1)
         begin : gen_n2
            assign n2_dout[i] = n1_gs[2*i] ? {1'b0, n1_dout[2*i]} : {n1_gs[2*i+1], n1_dout[2*i+1]};
            assign n2_gs[i] = (n1_gs[2*i] | n1_gs[2*i+1]);
         end
   endgenerate
   
   generate
      for(i=0;i<4;i=i+1)
         begin : gen_n3
            assign n3_dout[i] = n2_gs[2*i] ? {1'b0, n2_dout[2*i]} : {n2_gs[2*i+1], n2_dout[2*i+1]};
            assign n3_gs[i] = (n2_gs[2*i] | n2_gs[2*i+1]);
         end
   endgenerate
   
   generate
      for(i=0;i<2;i=i+1)
         begin : gen_n4
            assign n4_dout[i] = n3_gs[2*i] ? {1'b0, n3_dout[2*i]} : {n3_gs[2*i+1], n3_dout[2*i+1]};
            assign n4_gs[i] = (n3_gs[2*i] | n3_gs[2*i+1]);
         end
   endgenerate
   
   assign dout = n4_gs[0] ? {1'b0, n4_dout[0]} : {n4_gs[1], n4_dout[1]};
   assign gs = (n4_gs[0] | n4_gs[1]);
   
endmodule

