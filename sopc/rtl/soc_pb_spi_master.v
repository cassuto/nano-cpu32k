/**@file
 * Simple SPI master controller without FIFO queue
 * Not timing strict
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

module soc_pb_spi_master
(
   input                      clk,
   input                      rst_n,
   input                      pb_spi_AVALID,
   output                     pb_spi_AREADY,
   input [`NCPU_AW-1:0]       pb_spi_AADDR,
   input [3:0]                pb_spi_AWMSK,
   input [31:0]               pb_spi_ADATA,
   output [31:0]              pb_spi_BDATA,
   output reg                 pb_spi_BVALID,
   input                      pb_spi_BREADY,
   // SPI Interface
   output reg                 SPI_SCK,
   output reg                 SPI_CS_L,
   output                     SPI_MOSI,
   input                      SPI_MISO
);

   wire hds_cmd = pb_spi_AVALID & pb_spi_AREADY;
   wire hds_dout = pb_spi_BVALID & pb_spi_BREADY;

   wire we_CR = pb_spi_AWMSK==4'b0011;
   wire we_DR = pb_spi_AWMSK==4'b0001;

   // CLK Generator
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         SPI_SCK <= 1'b0;
      else
         SPI_SCK <= hds_cmd & we_DR;
   end

   assign SPI_MOSI = pb_spi_ADATA[7];

   reg [7:0] sh_reg;

   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         SPI_CS_L <= 1'b1;
      else if(hds_cmd) begin
         if(we_CR) begin
            // Generate Chip sel
            SPI_CS_L <= ~pb_spi_ADATA[8];
         end else if(we_DR) begin
            // Read out a bit from slaver
            sh_reg <= {sh_reg[6:0], SPI_MISO};
         end
      end
   end

   assign pb_spi_BDATA = {24'b0, sh_reg[7:0]};

   always @(posedge clk or negedge rst_n)
      if(~rst_n)
         pb_spi_BVALID <= 1'b0;
      else if (hds_cmd | hds_dout)
         pb_spi_BVALID <= (hds_cmd | ~hds_dout);

   assign pb_spi_AREADY = ~pb_spi_BVALID;

endmodule
