/**@file
 * Cell - Multi-port Static RAM
 */

/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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

module ncpu32k_cell_mpram_1w2r
#(
   parameter AW `PARAM_NOT_SPECIFIED ,
   parameter DW `PARAM_NOT_SPECIFIED ,
   parameter ENABLE_BYPASS `PARAM_NOT_SPECIFIED
)
(
   input                         clk,
   input                         rst_n,
   input [AW-1:0]                raddr_1,
   input                         re_1,
   input [AW-1:0]                raddr_2,
   input                         re_2,
   input [AW-1:0]                waddr,
   input                         we,
   input [DW-1:0]                din,
   output [DW-1:0]               dout_1,
   output [DW-1:0]               dout_2
);

   // FPGA timing optimized implement
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS (ENABLE_BYPASS)
      )
   RAM_1
      (
         // Outputs
         .dout    (dout_1),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (raddr_1),
         .re      (re_1),
         .waddr   (waddr),
         .we      (we),
         .din     (din)
      );
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (AW),
         .DW (DW),
         .ENABLE_BYPASS (ENABLE_BYPASS)
      )
   RAM_2
      (
         // Outputs
         .dout    (dout_2),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (raddr_2),
         .re      (re_2),
         .waddr   (waddr),
         .we      (we),
         .din     (din)
      );

endmodule
