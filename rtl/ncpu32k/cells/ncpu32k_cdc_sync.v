/**@file
 * Cell - CDC (Clock Domain Crossing) Synchronizer
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

module ncpu32k_cdc_sync #(
   parameter RST_VALUE = 1'b0
)
(
   input CLK_A,
   input CLK_B,
   input RST_N_A,
   input RST_N_B,
   input A,
   output B
);

   wire stage1_r, stage2_r;

   // Stage 1
   nDFF_r #(1, RST_VALUE) dff_stage1_r
         (CLK_A,RST_N_A, A, stage1_r);

   // Stage 2
   nDFF_r #(1, RST_VALUE) dff_stage2_r
         (CLK_B,RST_N_B, stage1_r, stage2_r);

   assign B = stage2_r;
endmodule
