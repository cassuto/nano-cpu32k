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

module ncpu32k_tsc
  (
   input                         clk,
   input                         rst_n,
   output                        tsc_irq,
   // TSR
   output [`NCPU_DW-1:0]         msr_tsc_tsr,
   input [`NCPU_DW-1:0]          msr_tsc_tsr_nxt,
   input                         msr_tsc_tsr_we,
   // TCR
   output [`NCPU_DW-1:0]         msr_tsc_tcr,
   input [`NCPU_DW-1:0]          msr_tsc_tcr_nxt,
   input                         msr_tsc_tcr_we
   );

   wire [`NCPU_DW-1:0]           tcr_r;
   wire [`NCPU_DW-1:0]           msr_tsc_tcr_r;
   wire [`NCPU_TSC_CNT_DW-1:0]   tcr_cnt;
   wire                          tcr_en;
   wire                          tcr_i;
   wire                          tcr_p;
   wire                          count;
   wire                          count_clk;
   wire [`NCPU_DW-1:0]           tsr_nxt;
   wire                          irq_set;
   wire                          irq_clr;

   // TCR
   nDFF_lr #(`NCPU_DW) dff_tcr_r
     (clk,rst_n, msr_tsc_tcr_we, msr_tsc_tcr_nxt[`NCPU_DW-1:0], tcr_r[`NCPU_DW-1:0]);

   // Pack TCR
   assign msr_tsc_tcr_r[`NCPU_TSC_CNT_DW-1:0] = tcr_r[`NCPU_TSC_CNT_DW-1:0];
   assign msr_tsc_tcr_r[`NCPU_MSR_TSC_TCR_EN] = tcr_r[`NCPU_MSR_TSC_TCR_EN];
   assign msr_tsc_tcr_r[`NCPU_MSR_TSC_TCR_I] = tcr_r[`NCPU_MSR_TSC_TCR_I];
   assign msr_tsc_tcr_r[`NCPU_MSR_TSC_TCR_P] = tsc_irq;
   assign msr_tsc_tcr_r[`NCPU_MSR_TSC_TCR_RB1] = tcr_r[`NCPU_MSR_TSC_TCR_RB1];

   // Bypass TCR wite
   assign msr_tsc_tcr = msr_tsc_tcr_we ? msr_tsc_tcr_nxt : msr_tsc_tcr_r;

   // Unpack TCR
   assign tcr_cnt = msr_tsc_tcr[`NCPU_TSC_CNT_DW-1:0];
   assign tcr_en = msr_tsc_tcr[`NCPU_MSR_TSC_TCR_EN];
   assign tcr_i = msr_tsc_tcr[`NCPU_MSR_TSC_TCR_I];
   assign tcr_p = msr_tsc_tcr[`NCPU_MSR_TSC_TCR_P];

   // TSR Counter
   assign count = tcr_en;
   assign count_clk = clk;
   // Next counter of TSR
   // Priority MUX
   assign tsr_nxt = msr_tsc_tsr_we ? msr_tsc_tsr_nxt : msr_tsc_tsr+1'b1;

   nDFF_lr #(`NCPU_NIRQ) dff_tsr_r
     (count_clk,rst_n, msr_tsc_tsr_we|count, tsr_nxt[`NCPU_DW-1:0], msr_tsc_tsr[`NCPU_DW-1:0]);

   // Raise IRQ if
   // Counter is triggered and TSC interrupt is enabled
   assign irq_set = (msr_tsc_tsr[`NCPU_TSC_CNT_DW-1:0]==tcr_cnt) & tcr_i;
   // Clear IRQ when clear P
   assign irq_clr = msr_tsc_tcr_we & ~tcr_p;

   nDFF_lr #(1) dff_tsc_irq
     (clk,rst_n, irq_set|irq_clr, (irq_set & ~irq_clr), tsc_irq);

endmodule
