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

module fifo_fwft
#(
   parameter DW = 8, // Data Width in bits
   parameter DEPTH_WIDTH = 4 // Width of depth
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input                               push,
   input [DW-1:0]                      din,
   output                              ready,
   input                               pop,
   output [DW-1:0]                     dout,
   output                              valid
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [DEPTH_WIDTH-1:0] payload_raddr;        // From U_CTRL of fifo_fwft_ctrl.v
   wire                 payload_re;             // From U_CTRL of fifo_fwft_ctrl.v
   wire [DEPTH_WIDTH-1:0] payload_waddr;        // From U_CTRL of fifo_fwft_ctrl.v
   wire [DW-1:0]        payload_wdata;          // From U_CTRL of fifo_fwft_ctrl.v
   wire                 payload_we;             // From U_CTRL of fifo_fwft_ctrl.v
   // End of automatics
   /*AUTOINPUT*/
   wire [DW-1:0]        payload_rdata;          // To U_CTRL of fifo_fwft_ctrl.v
   
   fifo_fwft_ctrl
      #(/*AUTOINSTPARAM*/
        // Parameters
        .DW                             (DW),
        .DEPTH_WIDTH                    (DEPTH_WIDTH))
   U_CTRL
      (/*AUTOINST*/
       // Outputs
       .ready                           (ready),
       .dout                            (dout[DW-1:0]),
       .valid                           (valid),
       .payload_re                      (payload_re),
       .payload_raddr                   (payload_raddr[DEPTH_WIDTH-1:0]),
       .payload_we                      (payload_we),
       .payload_waddr                   (payload_waddr[DEPTH_WIDTH-1:0]),
       .payload_wdata                   (payload_wdata[DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .push                            (push),
       .din                             (din[DW-1:0]),
       .pop                             (pop),
       .payload_rdata                   (payload_rdata[DW-1:0]));

   `mRF_nwnr
      #(
         .DW (DW),
         .AW (DEPTH_WIDTH),
         .NUM_READ   (1),
         .NUM_WRITE  (1)
      )
   U_RF
      (
         .CLK     (clk),
         `rst
         .RE      (payload_re),
         .RADDR   (payload_raddr),
         .RDATA   (payload_rdata),
         .WE      (payload_we),
         .WADDR   (payload_waddr),
         .WDATA   (payload_wdata)
      );

endmodule
