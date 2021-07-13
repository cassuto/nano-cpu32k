module top(
   input clk,
   input rst
);
   wire [63:0] iram_addr;
   wire [31:0] insn;
   wire rf_we;
   wire [4:0] rd;
   wire [4:0] rs1_addr;
   wire [4:0] rs2_addr;
   wire [`OP_SEL_W-1:0] op_sel;
   wire [`ALU_OPW-1:0] fu_sel;
   wire wb_sel;
   wire [11:0] imm12;

   pc PC
      (
         .clk        (clk),
         .rst        (rst),
         .iram_addr  (iram_addr)
      );

   iram IRAM
      (
         .clk        (clk),
         .rst        (rst),
         .i_addr     (iram_addr),
         .o_insn     (insn)
      );

   idu IDU
      (
         .i_insn     (insn),
         .o_rf_we    (rf_we),
         .o_rd       (rd),
         .o_rs1_addr (rs1_addr),
         .o_rs2_addr (rs2_addr),
         .op_sel     (op_sel),
         .fu_sel     (fu_sel),
         .wb_sel     (wb_sel),
         .imm12      (imm12)
      );

endmodule
