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

`include "ncpu64k_config.vh"

module ex_add
#(
   parameter                           CONFIG_DW = 0
)
(
   input [CONFIG_DW-1:0]               a,
   input [CONFIG_DW-1:0]               b,
   input                               s,
   output [CONFIG_DW-1:0]              sum,
   output                              carry,
   output                              overflow
);
   wire [CONFIG_DW-1:0]                op2;

   assign op2 = (s) ? (~b + 'b1) : b;
   assign {carry, sum} = a + op2;
   assign overflow = ((b[CONFIG_DW-1] == op2[CONFIG_DW-1]) &
                        (b[CONFIG_DW-1] ^ sum[CONFIG_DW-1]));

endmodule