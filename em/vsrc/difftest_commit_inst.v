
import "DPI-C" function void dpic_commit_inst(
   input int cmt_index,
   input bit valid,
   input int pc,
   input int insn,
   input bit wen,
   input byte wnum,
   input int wdata
);

import "DPI-C" function void dpic_step();

module difftest_commit_inst
#(
   parameter CONFIG_P_COMMIT_WIDTH = 0,
   parameter CONFIG_NUM_IRQ = 0
)
(
   input clk,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] valid,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*30-1:0] pc,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*32-1:0] insn,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] wen,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*5-1:0] wnum,
   input [(1<<CONFIG_P_COMMIT_WIDTH)*32-1:0] wdata
);
   integer i;
   always @(posedge clk)
      begin
         for(i=0; i<(1<<CONFIG_P_COMMIT_WIDTH); i=i+1)
            dpic_commit_inst(
               i,
               valid[i],
               {pc[i*30 +: 30], 2'b00},
               insn[i*32 +: 32],
               wen[i],
               {3'b0, wnum[i*5 +: 5]},
               wdata[i*32 +: 32]
            );
         dpic_step();
      end

endmodule
