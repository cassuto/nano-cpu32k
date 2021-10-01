
import "DPI-C" function void dpic_sync_irqc(
   input int irqc_irr
);

module difftest_sync_irqc
#(
   parameter CONFIG_NUM_IRQ = 0
)
(
   input clk,
   input [CONFIG_NUM_IRQ-1:0] irqc_irr
);
   reg [CONFIG_NUM_IRQ-1:0] irqc_irr_ff = 'b0;

   always @(posedge clk)
      begin
         irqc_irr_ff <= irqc_irr;
         if (irqc_irr_ff != irqc_irr)
            dpic_sync_irqc(irqc_irr);
      end
endmodule
