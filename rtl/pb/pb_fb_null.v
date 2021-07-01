/**
 * @brief Null device
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

module pb_fb_null
(
   input                      clk,
   input                      rst_n,
   input                      pb_null_AVALID,
   output                     pb_null_AREADY,
   input [`NCPU_AW-1:0]       pb_null_AADDR,
   input [3:0]                pb_null_AWMSK,
   input [31:0]               pb_null_ADATA,
   output [31:0]              pb_null_BDATA,
   output                     pb_null_BVALID,
   input                      pb_null_BREADY
);

   wire hds_cmd = pb_null_AVALID & pb_null_AREADY;
   wire hds_dout = pb_null_BVALID & pb_null_BREADY;

   nDFF_lr #(1) dff_pb_null_BVALID
      (clk, rst_n, (hds_cmd | hds_dout), (hds_cmd | ~hds_dout), pb_null_BVALID);

   assign pb_null_AREADY = ~pb_null_BVALID;

   assign pb_null_BDATA = 32'b0;


   // synthesis translate_off
`ifndef SYNTHESIS
   
   always @(posedge clk)
      begin
         if (hds_cmd & (|pb_null_AWMSK))
            $display("Warning: Writing to null device, addr=%x", pb_null_AADDR, "mask=%x", pb_null_AWMSK, "data=%x", pb_null_ADATA);
         if (hds_cmd & (~|pb_null_AWMSK))
            $display("Warning: Reading from null device, addr=%x", pb_null_AADDR);
      end

`endif
   // synthesis translate_on

endmodule
