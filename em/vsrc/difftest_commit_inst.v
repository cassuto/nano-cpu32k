
import "DPI-C" function void dpic_commit_inst(
   input int cmt_index,
   input bit valid,
   input int pc,
   input int insn,
   input bit wen,
   input byte wnum,
   input int wdata,
   input bit excp,
   input int excp_vect,
   input int irqc_irr
);

import "DPI-C" function void dpic_step();

module difftest_commit_inst
#(
   parameter CONFIG_P_ISSUE_WIDTH = 0,
   parameter CONFIG_NUM_IRQ = 0
)
(
   input clk,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] valid,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*30-1:0] pc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*32-1:0] insn,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wen,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*5-1:0] wnum,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*32-1:0] wdata,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] excp,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*32-1:0] excp_vect,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_NUM_IRQ-1:0] irqc_irr
);
   integer i;
   always @(posedge clk)
      begin
         for(i=0; i<(1<<CONFIG_P_ISSUE_WIDTH); i=i+1)
            dpic_commit_inst(
               i,
               valid[i],
               {pc[i*30 +: 30], 2'b00},
               insn[i*32 +: 32],
               wen[i],
               {3'b0, wnum[i*5 +: 5]},
               wdata[i*32 +: 32],
               excp[i],
               excp_vect[i*32 +: 32],
               irqc_irr[i*CONFIG_NUM_IRQ +: CONFIG_NUM_IRQ]
            );
         dpic_step();
      end

endmodule
