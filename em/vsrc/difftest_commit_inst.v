
import "DPI-C" function void dpic_commit_inst(
   input bit valid1,
   input int pc1,
   input int insn1,
   input bit wen1,
   input byte wnum1,
   input int wdata1,
   input bit valid2,
   input int pc2,
   input int insn2,
   input bit wen2,
   input byte wnum2,
   input int wdata2,
   input bit EINT1,
   input bit EINT2
);

module difftest_commit_inst(
   input clk,
   input valid1,
   input [31:0] pc1,
   input [31:0] insn1,
   input wen1,
   input [4:0] wnum1,
   input [31:0] wdata1,
   input valid2,
   input [31:0] pc2,
   input [31:0] insn2,
   input wen2,
   input [4:0] wnum2,
   input [31:0] wdata2,
   input EINT1,
   input EINT2
);
   always @(posedge clk)
      dpic_commit_inst(
         valid1, pc1, insn1, wen1, {3'b0, wnum1}, wdata1,
         valid2, pc2, insn2, wen2, {3'b0, wnum2}, wdata2,
         EINT1, EINT2
      );

endmodule
