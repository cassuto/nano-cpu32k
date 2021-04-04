/**@file
 * Priority one-hot arbiter.
 */

/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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

module ncpu32k_priority_onehot
#(
   parameter DW,
   parameter POLARITY_DIN, // Not zero = High level active, 0 = Low level active
   parameter POLARITY_DOUT // Not zero = High level active, 0 = Low level active
)
(
   input [DW-1:0] DIN, // LSB (0) has the highest priority, MSB (DW-1) has the lowest priority.
   output [DW-1:0] DOUT // one-hot code
);
   genvar i;

   generate
      wire [DW-1:0] prefixsum;
      assign prefixsum[0] = POLARITY_DIN ? 1'b0 : 1'b1;
      for(i=1;i<DW;i=i+1)
         begin : gen_prefixsum
            if (POLARITY_DIN)
               assign prefixsum[i] = prefixsum[i-1] | DIN[i-1];
            else
               assign prefixsum[i] = prefixsum[i-1] & DIN[i-1];
         end
      for(i=0;i<DW;i=i+1)
         begin : gen_dout
            if (POLARITY_DIN && POLARITY_DOUT)
               assign DOUT[i] = ~prefixsum[i] & DIN[i];
            else if (!POLARITY_DIN && POLARITY_DOUT)
               assign DOUT[i] = prefixsum[i] & ~DIN[i];
            else if (POLARITY_DIN && !POLARITY_DOUT)
               assign DOUT[i] = prefixsum[i] | ~DIN[i];
            else if (!POLARITY_DIN && !POLARITY_DOUT)
               assign DOUT[i] = ~prefixsum[i] | DIN[i];
         end
   endgenerate

endmodule
