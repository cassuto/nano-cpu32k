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

   // Synchronize IRQs
   ncpu32k_cell_dff_r #(`NCPU_NIRQ) dff_msr_irqc_irr
                   (clk,rst_n, irqs_lvl_i[`NCPU_NIRQ-1:0], msr_irqc_irr[`NCPU_NIRQ-1:0]);

   // IMR Register
   wire [`NCPU_DW-1:0] imr_r;
   ncpu32k_cell_dff_lr #(1) dff_imr_r
                   (clk,rst_n, msr_irqc_imr_we, msr_irqc_imr_nxt, imr_r);
   // Bypass IMR write
   assign msr_irqc_imr = msr_irqc_imr_we ? msr_irqc_imr_nxt : imr_r;

   wire [`NCPU_NIRQ-1:0] irq_masked = irqs_lvl_i & imr_r[`NCPU_NIRQ-1:0];
   wire irq_raised = |irq_masked & msr_psr_ire;
   
   ncpu32k_cell_dff_r #(1) dff_irqc_intr_sync
                   (clk,rst_n, irq_raised, irqc_intr_sync);

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   initial begin
      if (`NCPU_NIRQ > `NCPU_DW)
         $fatal ("\n invalid value of `NCPU_NIRQ\n");
   end
`endif

endmodule
