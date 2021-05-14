/**@file
 * Cell - Pipe buffer
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

module ncpu32k_cell_pipebuf
# (
   parameter CONFIG_PIPEBUF_BYPASS
   `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   input                      A_en,    // enable AREADY output
   input                      AVALID,
   output                     AREADY,
   input                      B_en,    // enable BVALID output
   output                     BVALID,
   input                      BREADY,
   output                     cke,
   output                     pending
);

   wire push = (AVALID & AREADY);
   wire pop = (BVALID & BREADY);

   //
   // Equivalent to 1-slot FIFO
   //
   wire valid_nxt = (push | ~pop) & ~flush;

   nDFF_lr #(1) dff_pending
                   (clk,rst_n, (push | pop | flush), valid_nxt, pending);

   assign BVALID = B_en & pending;

   generate
      if (CONFIG_PIPEBUF_BYPASS) begin : bypass
         assign AREADY = A_en & (~pending | pop);
      end else begin
         assign AREADY = A_en & (~pending);
      end
   endgenerate

   assign cke = push;

endmodule
