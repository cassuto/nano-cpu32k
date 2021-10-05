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

module align_w
#(
   parameter                           IN_P_DW_BYTES = 0,
   parameter                           OUT_P_DW_BYTES = 0,
   parameter                           IN_AW = 0
)
(
   input [(1<<OUT_P_DW_BYTES)*8-1:0]   i_dat,
   input [(1<<OUT_P_DW_BYTES)-1:0]     i_be,
   input [IN_AW-1:0]                   i_addr,
   output [(1<<IN_P_DW_BYTES)-1:0]     o_be,
   output [(1<<IN_P_DW_BYTES)*8-1:0]   o_out_wdat
);
   localparam IN_BYTES                 = (1<<IN_P_DW_BYTES);
   localparam OUT_BYTES                = (1<<OUT_P_DW_BYTES);
   genvar i;
   
   generate
      if (OUT_P_DW_BYTES == IN_P_DW_BYTES)
         begin
            assign o_be = i_be;
            assign o_out_wdat = i_dat;
         end
      else if (OUT_P_DW_BYTES <= IN_P_DW_BYTES)
         begin
            localparam WIN_NUM = (IN_BYTES/OUT_BYTES);
            localparam WIN_P_NUM = (IN_P_DW_BYTES - OUT_P_DW_BYTES);
            localparam WIN_DW = (OUT_BYTES*8);
            localparam WIN_P_DW_BYTES = (OUT_P_DW_BYTES);
         
            for(i=0;i<WIN_NUM;i=i+1)
               assign o_be[i*(WIN_DW/8) +: (WIN_DW/8)] = ({(WIN_DW/8){i_addr[WIN_P_DW_BYTES +: WIN_P_NUM] == i}} & i_be);
            
            for(i=0;i<WIN_NUM;i=i+1)
               assign o_out_wdat[i*WIN_DW +: WIN_DW] = i_dat;
         end
      else
         begin
            localparam WIN_NUM = (OUT_BYTES/IN_BYTES);
            localparam WIN_P_NUM = (OUT_P_DW_BYTES - IN_P_DW_BYTES);
            localparam WIN_DW = (IN_BYTES*8);
            localparam WIN_P_DW_BYTES = (IN_P_DW_BYTES);
            wire [WIN_DW-1:0] i_axi_din_win [WIN_NUM-1:0];
            wire [WIN_DW/8-1:0] i_be_win [WIN_NUM-1:0];
            
            for(i=0;i<WIN_NUM;i=i+1)
               begin
                  assign i_axi_din_win[i] = i_dat[i*WIN_DW +: WIN_DW];
                  assign i_be_win[i] = i_be[i*(WIN_DW/8) +: (WIN_DW/8)];
               end
               
            assign o_be = i_be_win[i_addr[WIN_P_DW_BYTES +: WIN_P_NUM]];
            assign o_out_wdat = i_axi_din_win[i_addr[WIN_P_DW_BYTES +: WIN_P_NUM]];
         end
   endgenerate

endmodule
