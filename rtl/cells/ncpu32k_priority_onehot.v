/**@file
 * Priority one-hot arbiter.
 */

/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_priority_onehot
#(
   parameter DW
   `PARAM_NOT_SPECIFIED ,
   parameter POLARITY_DIN
   `PARAM_NOT_SPECIFIED , // Not zero = High level active, 0 = Low level active
   parameter POLARITY_DOUT
   `PARAM_NOT_SPECIFIED // Not zero = High level active, 0 = Low level active
)
(
   input [DW-1:0] DIN, // LSB (0) has the highest priority, MSB (DW-1) has the lowest priority.
   output reg [DW-1:0] DOUT // one-hot code
);
   integer i;

   reg prefixsum;
   generate
      always @(*)
         for(i=0;i<DW;i=i+1)
            begin : gen_prefixsum
               if (i==0)
                  prefixsum = POLARITY_DIN ? 1'b0 : 1'b1;
               else if (POLARITY_DIN)
                  prefixsum = prefixsum | DIN[i-1];
               else
                  prefixsum = prefixsum & DIN[i-1];
               if (POLARITY_DIN && POLARITY_DOUT)
                  DOUT[i] = ~prefixsum & DIN[i];
               else if (!POLARITY_DIN && POLARITY_DOUT)
                  DOUT[i] = prefixsum & ~DIN[i];
               else if (POLARITY_DIN && !POLARITY_DOUT)
                  DOUT[i] = prefixsum | ~DIN[i];
               else if (!POLARITY_DIN && !POLARITY_DOUT)
                  DOUT[i] = ~prefixsum | DIN[i];
            end
   endgenerate

endmodule
