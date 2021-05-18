/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_dcache_ram
#(
   parameter AW
   `PARAM_NOT_SPECIFIED ,
   parameter DW
   `PARAM_NOT_SPECIFIED
)
(
   input clk,
   input [AW-1:0] addr_a,
   input [DW/8-1:0] we_a,
   input [DW-1:0] din_a,
   output [DW-1:0] dout_a,
   input en_a,
   input [AW-1:0] addr_b,
   input [DW/8-1:0] we_b,
   input [DW-1:0] din_b,
   output [DW-1:0] dout_b,
   input en_b
);

`ifdef PLATFORM_XILINX_XC6
   // Port A: Write-First
   // Port B: Read first
   // WARNING: You should ensure `ip_dcache_bram` matches your parameterized configuration
   // Check this manually...
   ip_dcache_bram RAM
      (
         .clk     (clk),
         .addra   (addr_a),
         .wea     (we_a),
         .dina    (din_a),
         .douta   (dout_a),
         .ena     (en_a),
         .addrb   (addr_b),
         .web     (we_b),
         .dinb    (din_b),
         .doutb   (dout_b),
         .enb     (en_b)
      );
`else
   ncpu32k_cell_tdpram_aclkd_sclk
      #(
         .WRITE_FIRST_A (1),
         .WRITE_FIRST_B (0), // Read first
         .AW   (AW),
         .DW   (DW)
      )
   RAM
      (
         .clk_a   (clk),
         .addr_a  (addr_a),
         .we_a    (we_a),
         .din_a   (din_a),
         .dout_a  (dout_a),
         .en_a    (en_a),
         .clk_b   (clk),
         .addr_b  (addr_b),
         .we_b    (we_b),
         .din_b   (din_b),
         .dout_b  (dout_b),
         .en_b    (en_b)
      );

   initial $display("Warning: ncpu32k_dcache_ram is configured for simulation only.");
`endif

endmodule
