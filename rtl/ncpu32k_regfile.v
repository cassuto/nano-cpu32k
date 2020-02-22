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
   input [`NCPU_REG_AW-1:0]      regf_rs1_addr, // Address for operand #1
   input [`NCPU_REG_AW-1:0]      regf_rs2_addr, // Address for operand #2
   input                         regf_rs1_re,   // Read Enable of operand #1
   input                         regf_rs2_re,   // Read Enable of operand #2
   input [`NCPU_REG_AW-1:0]      regf_din_addr,  // Write address
   input [`NCPU_DW-1:0]          regf_din,       // Write Input value
   input                         regf_we,    // Write Enable
   output [`NCPU_DW-1:0]         regf_rs1_dout,      // Output value of operand #1
   output [`NCPU_DW-1:0]         regf_rs2_dout       // Output value of operand #2
);
   localparam CLEAR_ON_INIT = 1;
   localparam ENABLE_BYPASS = 1;
   
   ncpu32k_cell_dpram_sclk
      #(
         .ADDR_WIDTH                   (`NCPU_REG_AW),
         .DATA_WIDTH                   (`NCPU_DW),
         .CLEAR_ON_INIT                (CLEAR_ON_INIT),
         .ENABLE_BYPASS                (ENABLE_BYPASS)
         )
      dpram_sclk0
         (
          // Outputs
          .dout                        (regf_rs1_dout),
          .dout_valid                  (),
          // Inputs
          .clk_i                       (clk),
          .rst_n_i                     (rst_n),
          .raddr                       (regf_rs1_addr),
          .re                          (regf_rs1_re),
          .waddr                       (regf_din_addr),
          .we                          (regf_we & (|regf_din_addr)),
          .din                         (regf_din)
         ); 

   ncpu32k_cell_dpram_sclk
      #(
         .ADDR_WIDTH                   (`NCPU_REG_AW),
         .DATA_WIDTH                   (`NCPU_DW),
         .CLEAR_ON_INIT                (CLEAR_ON_INIT),
         .ENABLE_BYPASS                (ENABLE_BYPASS)
         )
      dpram_sclk1
         (
          // Outputs
          .dout                        (regf_rs2_dout),
          .dout_valid                  (),
          // Inputs
          .clk_i                       (clk),
          .rst_n_i                     (rst_n),
          .raddr                       (regf_rs2_addr),
          .re                          (regf_rs2_re),
          .waddr                       (regf_din_addr),
          .we                          (regf_we & (|regf_din_addr)),
          .din                         (regf_din)
         ); 
         
endmodule
