/**@file
 * Regfile implementation
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
   input                         clk_i,
   input                         rst_n_i,
   input [`NCPU_REG_AW-1:0]      rs1_addr_i, // Address for operand #1
   input [`NCPU_REG_AW-1:0]      rs2_addr_i, // Address for operand #2
   input                         rs1_re_i,   // Read Enable of operand #1
   input                         rs2_re_i,   // Read Enable of operand #2
   input [`NCPU_REG_AW-1:0]      rd_addr_i,  // Write address
   input [`NCPU_DW-1:0]          rd_i,       // Write Input value
   input                         rd_we_i,    // Write Enable
   output [`NCPU_DW-1:0]         rs1_o,      // Output value of operand #1
   output [`NCPU_DW-1:0]         rs2_o       // Output value of operand #2
);

   ncpu32k_cell_dpram_sclk
      #(
         .ADDR_WIDTH                   (`NCPU_REG_AW),
         .DATA_WIDTH                   (`NCPU_DW),
         .CLEAR_ON_INIT                (1),
         .SYNC_READ                    (1),
         .ENABLE_BYPASS                (1)
         )
      dpram_sclk0
         (
          // Outputs
          .dout                        (rs1_o),
          // Inputs
          .clk_i                       (clk_i),
          .rst_n_i                     (rst_n_i),
          .raddr                       (rs1_addr_i),
          .re                          (rs1_re_i),
          .waddr                       (rd_addr_i),
          .we                          (rd_we_i),
          .din                         (rd_i)
         ); 

   ncpu32k_cell_dpram_sclk
      #(
         .ADDR_WIDTH                   (`NCPU_REG_AW),
         .DATA_WIDTH                   (`NCPU_DW),
         .CLEAR_ON_INIT                (1),
         .SYNC_READ                    (0),
         .ENABLE_BYPASS                (1)
         )
      dpram_sclk1
         (
          // Outputs
          .dout                        (rs2_o),
          // Inputs
          .clk_i                       (clk_i),
          .rst_n_i                     (rst_n_i),
          .raddr                       (rs2_addr_i),
          .re                          (rs2_re_i),
          .waddr                       (rd_addr_i),
          .we                          (rd_we_i),
          .din                         (rd_i)
         ); 
         
endmodule
