/**@file
 * single-clk-cycle Regfile implementation
 */

/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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
   input [`NCPU_REG_AW-1:0]      arf_rs1_addr, // Address for operand #1
   input [`NCPU_REG_AW-1:0]      arf_rs2_addr, // Address for operand #2
   input                         arf_rs1_re,   // Read Enable of operand #1
   input                         arf_rs2_re,   // Read Enable of operand #2
   input [`NCPU_REG_AW-1:0]      arf_din_addr,  // Write address
   input [`NCPU_DW-1:0]          arf_din,       // Write Input value
   input                         arf_we,    // Write Enable
   output [`NCPU_DW-1:0]         arf_rs1_dout,      // Output value of operand #1
   output [`NCPU_DW-1:0]         arf_rs2_dout       // Output value of operand #2
);

   ncpu32k_cell_mpram_1w2r
      #(
         .AW      (`NCPU_REG_AW),
         .DW      (`NCPU_DW),
         // Bypass is not necessary.
         // When operands are being committed to ARF, they are still in ROB
         // and the bypass is handled by ROB.
         .ENABLE_BYPASS (0)
      )
   REG_MEM
      (
         // Outputs
         .dout_1  (arf_rs1_dout),
         .dout_2  (arf_rs2_dout),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr_1 (arf_rs1_addr),
         .re_1    (arf_rs1_re),
         .raddr_2 (arf_rs2_addr),
         .re_2    (arf_rs2_re),
         .waddr   (arf_din_addr),
         .we      (arf_we & (|arf_din_addr)),
         .din     (arf_din)
      );

endmodule
