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

module ex_epu_irqc
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_NUM_IRQ = 0
)
(
   input                               clk,
   input                               rst,
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              irq_async,
   input                               msr_psr_ire,
   // IMR
   output [CONFIG_DW-1:0]              msr_irqc_imr,
   input [CONFIG_DW-1:0]               msr_irqc_imr_nxt,
   input                               msr_irqc_imr_we,
   // IRR
   output [CONFIG_DW-1:0]              msr_irqc_irr
);
   wire [CONFIG_DW-1:0]                imr_ff;
   wire [CONFIG_NUM_IRQ-1:0]           msr_irqc_irr_0;
   wire [CONFIG_NUM_IRQ-1:0]           irq_masked;

   // Synchronize IRQs
   mDFF_r #(CONFIG_NUM_IRQ) dff_msr_irqc_irr_0 (.CLK(clk), .RST(rst), .D(irqs), .Q(msr_irqc_irr_0) );
   mDFF_r #(CONFIG_NUM_IRQ) dff_msr_irqc_irr (.CLK(clk), .RST(rst), .D(msr_irqc_irr_0), .Q(msr_irqc_irr) );

   // IMR Register
   mDFF_lr #(.DW(CONFIG_DW), .RST_VECROR({CONFIG_DW{1'b1}})) ff_imr_ (.CLK(clk), .RST(rst), .LOAD(msr_irqc_imr_we), .D(msr_irqc_imr_nxt), .Q(imr_ff) );

   // Bypass IMR write
   assign msr_irqc_imr = (msr_irqc_imr_we) ? msr_irqc_imr_nxt : imr_ff;

   assign irq_masked = (msr_irqc_irr & ~msr_irqc_imr);
   assign irq_async = (|irq_masked & msr_psr_ire);

   // synthesis translate_off
`ifndef SYNTHESIS
   initial
      if (CONFIG_NUM_IRQ > CONFIG_DW)
         $fatal ("\n invalid value of CONFIG_NUM_IRQ\n");
`endif
   // synthesis translate_on

endmodule
