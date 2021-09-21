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

module align_r
#(
   parameter                           AXI_P_DW_BYTES = 0,
   parameter                           PAYLOAD_P_DW_BYTES = 0,
   parameter                           RAM_AW = 0
)
(
   input [(1<<AXI_P_DW_BYTES)*8-1:0]   i_axi_RDATA,
   input [(1<<AXI_P_DW_BYTES)-1:0]     i_axi_rbe,
   input [RAM_AW-1:0]                  i_ram_addr,
   output [(1<<PAYLOAD_P_DW_BYTES)-1:0] o_ram_wmsk,
   output [(1<<PAYLOAD_P_DW_BYTES)*8-1:0] o_ram_din
);
   localparam AXI_BYTES                = (1<<AXI_P_DW_BYTES);
   localparam PAYLOAD_BYTES            = (1<<PAYLOAD_P_DW_BYTES);
   genvar i;
   
   generate
      if (PAYLOAD_P_DW_BYTES == AXI_P_DW_BYTES)
         begin
            assign o_ram_din = i_axi_RDATA;
            assign o_ram_wmsk = i_axi_rbe;
         end
      else if (PAYLOAD_P_DW_BYTES < AXI_P_DW_BYTES)
         begin
            localparam WIN_NUM = (AXI_BYTES/PAYLOAD_BYTES);
            localparam WIN_P_NUM = (AXI_P_DW_BYTES - PAYLOAD_P_DW_BYTES);
            localparam WIN_DW = (PAYLOAD_BYTES*8);
            localparam WIN_P_DW_BYTES = (PAYLOAD_P_DW_BYTES);
            
            wire [WIN_DW-1:0] RDATA_win [WIN_NUM-1:0];
            wire [WIN_DW/8-1:0] RBE_win [WIN_NUM-1:0];
            
            for(i=0;i<WIN_NUM;i=i+1)
               begin
                  assign RDATA_win[i] = i_axi_RDATA[i*WIN_DW +: WIN_DW];
                  assign RBE_win[i] = i_axi_rbe[i*(WIN_DW/8) +: WIN_DW/8];
               end
            
            assign o_ram_din = RDATA_win[i_ram_addr[WIN_P_DW_BYTES +: WIN_P_NUM]];
            assign o_ram_wmsk = RBE_win[i_ram_addr[WIN_P_DW_BYTES +: WIN_P_NUM]];
         end
      else
         begin
            localparam WIN_NUM = (PAYLOAD_BYTES/AXI_BYTES);
            localparam WIN_P_NUM = (PAYLOAD_P_DW_BYTES - AXI_P_DW_BYTES);
            localparam WIN_DW = (AXI_BYTES*8);
            localparam WIN_P_DW_BYTES = (AXI_P_DW_BYTES);

            for(i=0;i<WIN_NUM;i=i+1)
               assign o_ram_wmsk[i*(WIN_DW/8) +: (WIN_DW/8)] = {(WIN_DW/8){i_ram_addr[WIN_P_DW_BYTES +: WIN_P_NUM] == i}} & i_axi_rbe;

            for(i=0;i<WIN_NUM;i=i+1)
               assign o_ram_din[i*WIN_DW +: WIN_DW] = i_axi_RDATA;
         end
   endgenerate

endmodule
