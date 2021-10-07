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

module mRAM_s_s_be
#(
   parameter P_DW = 0,
   parameter AW = 0
)
(
   input CLK,
   input RST, /* Reset port for address register */
   input [AW-1:0] ADDR,
   input RE,
   output [(1<<P_DW)-1:0] DOUT,
   input [(1<<P_DW)/8-1:0] WE,
   input [(1<<P_DW)-1:0] DIN
);

`ifdef NCPU_USE_S011_STD_CELL_LIB
   localparam P_DW_BYTES = (P_DW-3);
   // Parameters for SMIC 128x64 bit SRAM cell
   localparam SRAM_DW = 128;
   localparam SRAM_AW = 6;
   localparam SRAM_P_DW_BYTES = 4; // = $clog2(SRAM_DW/8)
   
   wire [(1<<P_DW)-1:0] we_bmsk;
   wire [AW-1:0] re_addr_ff;
   wire [AW-1:0] addr_w;
   genvar i;
   
   // Address register
   mDFF_lr #(.DW(AW)) ff_re_addr (.CLK(CLK), .RST(RST), .LOAD(RE), .D(ADDR), .Q(re_addr_ff) );
   
   assign addr_w = (RE | (|WE)) ? ADDR : re_addr_ff;
   
   // Convert byte mask to bit mask
   for(i=0;i<(1<<P_DW_BYTES);i=i+1)
      assign we_bmsk[i*8 +: 8] = {8{WE[i]}};
   
   generate
      if (((1<<P_DW) == SRAM_DW) && (AW == SRAM_AW))
         begin
            S011HD1P_X32Y2D128_BW U_S011HD1P_X32Y2D128_BW
               (
                  .Q                      (DOUT),
                  .CLK                    (CLK),
                  .CEN                    (1'b0),     // Low active
                  .WEN                    (~|WE),     // Low active
                  .BWEN                   (~we_bmsk), // Low active
                  .A                      (addr_w),
                  .D                      (DIN)
               );
         end
      else if (((1<<P_DW) < SRAM_DW) && ((AW-(SRAM_P_DW_BYTES - P_DW_BYTES)) == SRAM_AW))
         begin
            localparam WIN_P_NUM = (SRAM_P_DW_BYTES - P_DW_BYTES);
            localparam WIN_NUM = (1<<WIN_P_NUM);
            localparam WIN_DW = (1<<P_DW);
            
            wire [SRAM_DW-1:0] sram_q;
            wire [SRAM_DW-1:0] sram_bwen;
            wire [SRAM_DW-1:0] sram_d;
            wire [WIN_DW-1:0] DOUT_win [WIN_NUM-1:0];

            // Din address encoder
            for(i=0;i<WIN_NUM;i=i+1)
               assign sram_bwen[i*WIN_DW +: WIN_DW] = (we_bmsk & {WIN_DW{addr_w[WIN_P_NUM-1:0] == i}});
            for(i=0;i<WIN_NUM;i=i+1)
               assign sram_d[i*WIN_DW +: WIN_DW] = DIN;

            S011HD1P_X32Y2D128_BW S011HD1P_X32Y2D128_BW
               (
                  .Q                      (sram_q),
                  .CLK                    (CLK),
                  .CEN                    (1'b0),        // Low active
                  .WEN                    (~|WE),        // Low active
                  .BWEN                   (~sram_bwen),  // Low active
                  .A                      (addr_w[WIN_P_NUM +: SRAM_AW]),
                  .D                      (sram_d)
               );
            
            // Dout address decoder
            for(i=0;i<WIN_NUM;i=i+1)
               assign DOUT_win[i] = sram_q[i*WIN_DW +: WIN_DW];
            assign DOUT = DOUT_win[re_addr_ff[WIN_P_NUM-1:0]];
         end
      else
         begin
            initial $fatal(1, "SRAM with the specified size is unsupported.");
         end
   endgenerate
   
`else
   // General RTL
   reg [(1<<P_DW)-1:0] mem_vector [(1<<AW)-1:0];
   reg [(1<<P_DW)-1:0] dff_rdat;
   genvar i;

   always @(posedge CLK)
      if (RE)
         dff_rdat <= mem_vector[ADDR];
   generate
      for(i=0;i<(1<<P_DW);i=i+8)
         always @(posedge CLK)
            if (WE[i/8])
               mem_vector[ADDR][i+:8] <= DIN[i+:8];
   endgenerate
   
   // The following logic is used to simulate the behavior of ASIC SRAM cell
   localparam [(1<<P_DW)-1:0] UNCERTAIN_VAL = {(1<<P_DW)/2{2'b01}};
   wire we_ff;
   mDFF #(.DW(1)) ff_we (.CLK(CLK), .D(|WE), .Q(we_ff) );
   assign DOUT = (we_ff) ? UNCERTAIN_VAL : dff_rdat;
   
`endif

endmodule
