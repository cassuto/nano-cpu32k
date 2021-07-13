`include "defines.vh"

module top(
   input clk,
   input rst
);
   localparam IRAM_AW = 16; // 64 KiB

   wire [IRAM_AW-1:0] iram_addr;
   wire [31:0] insn;
   wire rf_we;
   wire [4:0] rd;
   wire [4:0] rs1_addr, rs2_addr;
   wire [63:0] rf_rs1, rf_rs2;
   wire [63:0] rs1, rs2;
   wire [`OP_SEL_W-1:0] op_sel;
   wire [`ALU_OPW-1:0] fu_sel;
   wire wb_sel;
   wire [11:0] imm12;
   wire [63:0] rd_dat;
   wire [63:0] alu_result;

   pc
      #(
      .IRAM_AW       (IRAM_AW)
      )
   PC
      (
         .clk        (clk),
         .rst        (rst),
         .iram_addr  (iram_addr)
      );

   iram
      #(
      .IRAM_AW       (IRAM_AW)
      )
   IRAM
      (
         .clk        (clk),
         .rst        (rst),
         .i_addr     (iram_addr[15:0]),
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

   regfile RF
      (
         .clk           (clk),
         .i_rs1_addr    (rs1_addr),
         .i_rs2_addr    (rs2_addr),
         .rs1           (rf_rs1),
         .rs2           (rf_rs2),
         .i_rd          (rd),
         .i_rf_we       (rf_we),
         .i_rd_dat      (rd_dat)
      );

   opmux OP_MUX
      (
         .op_sel        (op_sel),
         .rf_rs1        (rf_rs1),
         .rf_rs2        (rf_rs2),
         .imm12         (imm12),
         .rs1           (rs1),
         .rs2           (rs2)
      );

   alu ALU
      (
         .i_fu_sel      (fu_sel),
         .i_operand1    (rs1),
         .i_operand2    (rs2),
         .o_result      (alu_result)
      );

   wbmux WB_MUX
      (
         .wb_sel        (wb_sel),
         .alu_result    (alu_result),
         .lsu_result    (64'b0), // TODO
         .rd_dat        (rd_dat)
      );

endmodule
