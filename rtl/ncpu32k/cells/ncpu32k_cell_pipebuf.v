/**@file
 * Cell - Pipe buffer
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

module ncpu32k_cell_pipebuf
# (
   parameter ENABLE_BYPASS = `NCPU_PIPEBUF_BYPASS // bypass when popping
)
(
   input                      clk,
   input                      rst_n,
   input                      a_en,    // enable ready output
   input                      a_valid,
   output                     a_ready,
   input                      b_en,    // enable valid output
   output                     b_valid,
   input                      b_ready,
   output                     cke,
   output                     pending
);

   wire push = (a_valid & a_ready);
   wire pop = (b_valid & b_ready);
   
   //
   // Equivalent to 1-slot FIFO
   //
   wire valid_nxt = (push | ~pop);
   
   nDFF_lr #(1) dff_pending
                   (clk,rst_n, (push | pop), valid_nxt, pending);
   
   assign b_valid = b_en & pending;
   
   generate
      if (ENABLE_BYPASS) begin : bypass
         assign a_ready = a_en & (~pending | pop);
      end else begin
         assign a_ready = a_en & (~pending);
      end
   endgenerate
   
   assign cke = push;
   
endmodule
