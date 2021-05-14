/**@file
 * Cell - CDC (Clock Domain Crossing) Synchronizer for Valid-ready handshake
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

module ncpu32k_cdc_sync_hds
#(
   parameter CONFIG_CDC_STAGES = 2
)
(
   input clk_a,
   input rst_a_n,
   input AVALID,
   output AREADY,
   input clk_b,
   input rst_b_n,
   output BVALID,
   input BREADY
);
   wire flag_a, flag_b;
   wire b_flag_a, a_flag_b;

   nDFF_lr #(1) dff_flag_a
      (clk_a, rst_a_n, (AVALID & AREADY), ~flag_a, flag_a);

   nDFF_lr #(1) dff_flag_b
      (clk_b, rst_b_n, (BVALID & BREADY), ~flag_b, flag_b);

   // A to B
   ncpu32k_cdc_sync
      #(
         .RST_VALUE ('b0),
         .CONFIG_CDC_STAGES (CONFIG_CDC_STAGES)
      )
   CDC_A_B
      (
         .A       (flag_a),
         .CLK_B   (clk_b),
         .RST_N_B (rst_b_n),
         .B       (b_flag_a)
      );

   // B to A
   ncpu32k_cdc_sync
      #(
         .RST_VALUE ('b0),
         .CONFIG_CDC_STAGES (CONFIG_CDC_STAGES)
      )
   CDC_B_A
      (
         .A       (flag_b),
         .CLK_B   (clk_a),
         .RST_N_B (rst_a_n),
         .B       (a_flag_b)
      );

   assign AREADY = (flag_a == a_flag_b);

   assign BVALID = (flag_b ^ b_flag_a);

endmodule
