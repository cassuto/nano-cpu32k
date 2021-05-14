/**@file
 * single-clk-cycle Regfile implementation
 */

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

module ncpu32k_regfile(
   input                         clk,
   input                         rst_n,
   input [`NCPU_REG_AW-1:0]      arf_1_rs1_addr, // Address for operand #1
   input [`NCPU_REG_AW-1:0]      arf_1_rs2_addr, // Address for operand #2
   input                         arf_1_rs1_re,   // Read Enable of operand #1
   input                         arf_1_rs2_re,   // Read Enable of operand #2
   input [`NCPU_REG_AW-1:0]      arf_2_rs1_addr, // Address for operand #1
   input [`NCPU_REG_AW-1:0]      arf_2_rs2_addr, // Address for operand #2
   input                         arf_2_rs1_re,   // Read Enable of operand #1
   input                         arf_2_rs2_re,   // Read Enable of operand #2
   input [`NCPU_REG_AW-1:0]      arf_1_waddr,    // Write address
   input [`NCPU_DW-1:0]          arf_1_wdat,     // Write Input value
   input                         arf_1_we,       // Write Enable
   input [`NCPU_REG_AW-1:0]      arf_2_waddr,    // Write address
   input [`NCPU_DW-1:0]          arf_2_wdat,     // Write Input value
   input                         arf_2_we,       // Write Enable
   output [`NCPU_DW-1:0]         arf_1_rs1_dout, // Output value of operand #1
   output [`NCPU_DW-1:0]         arf_1_rs2_dout, // Output value of operand #2
   output [`NCPU_DW-1:0]         arf_2_rs1_dout, // Output value of operand #1
   output [`NCPU_DW-1:0]         arf_2_rs2_dout  // Output value of operand #2
);

   ncpu32k_cell_mpram_2w4r
      #(
         .AW                     (`NCPU_REG_AW),
         .DW                     (`NCPU_DW),
         // Bypass is handled outside the regfile, disable it.
         .ENABLE_BYPASS_W1_R1    (0),
         .ENABLE_BYPASS_W1_R2    (0),
         .ENABLE_BYPASS_W1_R3    (0),
         .ENABLE_BYPASS_W1_R4    (0),
         .ENABLE_BYPASS_W2_R1    (0),
         .ENABLE_BYPASS_W2_R2    (0),
         .ENABLE_BYPASS_W2_R3    (0),
         .ENABLE_BYPASS_W2_R4    (0)
      )
   REG_MEM
      (
         .clk                    (clk),
         .rst_n                  (rst_n),
         
         .raddr_1                (arf_1_rs1_addr),
         .re_1                   (arf_1_rs1_re),
         .dout_1                 (arf_1_rs1_dout),
         .raddr_2                (arf_1_rs2_addr),
         .re_2                   (arf_1_rs2_re),
         .dout_2                 (arf_1_rs2_dout),

         .raddr_3                (arf_2_rs1_addr),
         .re_3                   (arf_2_rs1_re),
         .dout_3                 (arf_2_rs1_dout),
         .raddr_4                (arf_2_rs2_addr),
         .re_4                   (arf_2_rs2_re),
         .dout_4                 (arf_2_rs2_dout),

         .we_1                   (arf_1_we),
         .waddr_1                (arf_1_waddr),
         .din_1                  (arf_1_wdat),

         .we_2                   (arf_2_we),
         .waddr_2                (arf_2_waddr),
         .din_2                  (arf_2_wdat)
      );

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if ( (arf_1_we & ~|arf_1_waddr) |
               (arf_2_we & ~|arf_2_waddr) )
            $fatal ("BUG ON: Writing to nil register");
      end
`endif

`endif
   // synthesis translate_on

endmodule
