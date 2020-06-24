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

module ncpu32k_irqc(         
   input                      clk,
   input                      rst_n,
   input [`NCPU_NIRQ-1:0]     irqs_lvl_i, /* Level-triggered IRQs input (allow async) */
   output                     irqc_intr_sync,
   input                      msr_psr_ire,
   // IMR
   output [`NCPU_DW-1:0]      msr_irqc_imr,
   input [`NCPU_DW-1:0]       msr_irqc_imr_nxt,
   input                      msr_irqc_imr_we,
   // IRR
   output [`NCPU_DW-1:0]      msr_irqc_irr
);
   wire [`NCPU_DW-1:0] imr_r;
   wire [`NCPU_NIRQ-1:0] msr_irqc_irr_0;
   
   // Synchronize IRQs
   nDFF_r #(`NCPU_NIRQ) dff_msr_irqc_irr_0
                   (clk,rst_n, irqs_lvl_i[`NCPU_NIRQ-1:0], msr_irqc_irr_0[`NCPU_NIRQ-1:0]);
   nDFF_r #(`NCPU_NIRQ) dff_msr_irqc_irr
                   (clk,rst_n, msr_irqc_irr_0[`NCPU_NIRQ-1:0], msr_irqc_irr[`NCPU_NIRQ-1:0]);
                   
   // IMR Register
   nDFF_lr #(`NCPU_DW, {`NCPU_DW{1'b1}}) dff_imr_r
                   (clk,rst_n, msr_irqc_imr_we, msr_irqc_imr_nxt[`NCPU_DW-1:0], imr_r[`NCPU_DW-1:0]);

   // Bypass IMR write
   assign msr_irqc_imr = msr_irqc_imr_we ? msr_irqc_imr_nxt : imr_r;

   wire [`NCPU_NIRQ-1:0] irq_masked = msr_irqc_irr & ~msr_irqc_imr[`NCPU_NIRQ-1:0];
   assign irqc_intr_sync = |irq_masked & msr_psr_ire;

   // synthesis translate_off
`ifndef SYNTHESIS
   
   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if (`NCPU_NIRQ > `NCPU_DW)
         $fatal ("\n invalid value of `NCPU_NIRQ\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
