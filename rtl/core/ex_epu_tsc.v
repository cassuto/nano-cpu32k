/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module ex_epu_tsc
#(
   parameter                           CONFIG_DW = 0
)
(
   input                               clk,
   input                               rst,
   output                              tsc_irq,
   // TSR
   output [CONFIG_DW-1:0]              msr_tsc_tsr,
   input [CONFIG_DW-1:0]               msr_tsc_tsr_nxt,
   input                               msr_tsc_tsr_we,
   // TCR
   output [CONFIG_DW-1:0]              msr_tsc_tcr,
   input [CONFIG_DW-1:0]               msr_tsc_tcr_nxt,
   input                               msr_tsc_tcr_we
);

   wire [CONFIG_DW-1:0]                tcr_ff;
   wire [CONFIG_DW-1:0]                msr_tsc_tcr_ff;
   wire [`NCPU_TSC_CNT_DW-1:0]         tcr_cnt;
   wire                                tcr_en;
   wire                                tcr_i;
   wire                                tcr_p;
   wire                                count;
   wire                                count_clk;
   wire [CONFIG_DW-1:0]                tsr_nxt;
   wire                                irq_set;
   wire                                irq_clr;

   // TCR
   mDFF_lr #(.DW(CONFIG_DW)) ff_tcr (.CLK(clk), .RST(rst), .LOAD(msr_tsc_tcr_we), .D(msr_tsc_tcr_nxt), .Q(tcr_ff) );

   // Pack TCR
   assign msr_tsc_tcr_ff[`NCPU_TSC_CNT_DW-1:0] = tcr_ff[`NCPU_TSC_CNT_DW-1:0];
   assign msr_tsc_tcr_ff[`NCPU_MSR_TSC_TCR_EN] = tcr_ff[`NCPU_MSR_TSC_TCR_EN];
   assign msr_tsc_tcr_ff[`NCPU_MSR_TSC_TCR_I] = tcr_ff[`NCPU_MSR_TSC_TCR_I];
   assign msr_tsc_tcr_ff[`NCPU_MSR_TSC_TCR_P] = tsc_irq;
   assign msr_tsc_tcr_ff[`NCPU_MSR_TSC_TCR_RB1] = tcr_ff[`NCPU_MSR_TSC_TCR_RB1];

   // Bypass TCR wite
   assign msr_tsc_tcr = msr_tsc_tcr_we ? msr_tsc_tcr_nxt : msr_tsc_tcr_ff;

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

   mDFF_lr #(.DW(CONFIG_DW)) ff_msr_tsc_tsr (.CLK(count_clk), .RST(rst), .LOAD(msr_tsc_tsr_we|count), .D(tsr_nxt), .Q(msr_tsc_tsr) );

   // Raise IRQ if
   // Counter is triggered and TSC interrupt is enabled
   assign irq_set = (msr_tsc_tsr[`NCPU_TSC_CNT_DW-1:0]==tcr_cnt) & tcr_i;
   // Clear IRQ when clear P
   assign irq_clr = msr_tsc_tcr_we & ~tcr_p;

   mDFF_lr #(1) ff_tsc_irq (.CLK(clk), .RST(rst), .LOAD(irq_set|irq_clr), .D(irq_set & ~irq_clr), .Q(tsc_irq) );

endmodule
