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
   parameter [0:0] RST_VALUE = 0,
   parameter CONFIG_CDC_STAGES = 2
)
(
   input A,
   input CLK_B,
   input RST_N_B,
   output B
);
   generate;
      if (CONFIG_CDC_STAGES == 1)
         begin
            wire stage_r;
            nDFF_r #(1, RST_VALUE) dff_stage_r
              (CLK_B,RST_N_B, A, stage_r);
            assign B = stage_r;
         end
      else
         begin
            wire [CONFIG_CDC_STAGES-1:0] stage_r;
            nDFF_r #(CONFIG_CDC_STAGES, {CONFIG_CDC_STAGES{RST_VALUE}}) dff_stage_r
              (CLK_B,RST_N_B, {stage_r[CONFIG_CDC_STAGES-2:0], A}, stage_r);
            assign B = stage_r[CONFIG_CDC_STAGES-1];
         end
   endgenerate

endmodule
