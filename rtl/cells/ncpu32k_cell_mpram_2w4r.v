/**@file
 * Cell - Multi-port Static RAM
 */

/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module ncpu32k_cell_mpram_2w4r
#(
   parameter AW
   `PARAM_NOT_SPECIFIED ,
   parameter DW
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W1_R1
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W1_R2
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W1_R3
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W1_R4
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W2_R1
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W2_R2
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W2_R3
   `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS_W2_R4
   `PARAM_NOT_SPECIFIED
)
(
   input                         clk,
   input                         rst_n,
   input [AW-1:0]                raddr_1,
   input                         re_1,
   input [AW-1:0]                raddr_2,
   input                         re_2,
   input [AW-1:0]                raddr_3,
   input                         re_3,
   input [AW-1:0]                raddr_4,
   input                         re_4,
   input                         we_1,
   input                         we_2,
   input [AW-1:0]                waddr_1,
   input [AW-1:0]                waddr_2,
   input [DW-1:0]                din_1,
   input [DW-1:0]                din_2,
   output [DW-1:0]               dout_1,
   output [DW-1:0]               dout_2,
   output [DW-1:0]               dout_3,
   output [DW-1:0]               dout_4
);

   //
   // FPGA timing optimized version
   //

   ncpu32k_cell_mpram_2w1r
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS_W1 (ENABLE_BYPASS_W1_R1),
         .ENABLE_BYPASS_W2 (ENABLE_BYPASS_W2_R1)
      )
   RAM_1
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .we1     (we_1),
         .waddr1  (waddr_1),
         .wdata1  (din_1),
         .we2     (we_2),
         .waddr2  (waddr_2),
         .wdata2  (din_2),
         .re      (re_1),
         .raddr   (raddr_1),
         .rdata   (dout_1)
      );

   ncpu32k_cell_mpram_2w1r
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS_W1 (ENABLE_BYPASS_W1_R2),
         .ENABLE_BYPASS_W2 (ENABLE_BYPASS_W2_R2)
      )
   RAM_2
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .we1     (we_1),
         .waddr1  (waddr_1),
         .wdata1  (din_1),
         .we2     (we_2),
         .waddr2  (waddr_2),
         .wdata2  (din_2),
         .re      (re_2),
         .raddr   (raddr_2),
         .rdata   (dout_2)
      );

   ncpu32k_cell_mpram_2w1r
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS_W1 (ENABLE_BYPASS_W1_R3),
         .ENABLE_BYPASS_W2 (ENABLE_BYPASS_W2_R3)
      )
   RAM_3
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .we1     (we_1),
         .waddr1  (waddr_1),
         .wdata1  (din_1),
         .we2     (we_2),
         .waddr2  (waddr_2),
         .wdata2  (din_2),
         .re      (re_3),
         .raddr   (raddr_3),
         .rdata   (dout_3)
      );

   ncpu32k_cell_mpram_2w1r
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS_W1 (ENABLE_BYPASS_W1_R4),
         .ENABLE_BYPASS_W2 (ENABLE_BYPASS_W2_R4)
      )
   RAM_4
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .we1     (we_1),
         .waddr1  (waddr_1),
         .wdata1  (din_1),
         .we2     (we_2),
         .waddr2  (waddr_2),
         .wdata2  (din_2),
         .re      (re_4),
         .raddr   (raddr_4),
         .rdata   (dout_4)
      );

endmodule
