`include "defines.vh"

module top(
   input clk,
   input rst
);
   localparam IRAM_AW = 16; // (2^ILEN) * 64 KiB

   wire [IRAM_AW-1:0] iram_addr;
   wire [31:0] insn;
   // From IDU
   wire idu_o_rf_we;
   wire [4:0] idu_o_rd;
   wire [4:0] idu_o_rs1_addr;
   wire [4:0] idu_o_rs2_addr;
   wire [`OP_SEL_W-1:0] idu_o_op_sel;
   wire [`ALU_OPW-1:0] idu_o_fu_sel;
   wire idu_o_wb_sel;
   wire [11:0] idu_o_imm12;
   // To EXU
   wire exu_i_rf_we;
   wire [4:0] exu_i_rd;
   wire [4:0] exu_i_rs1_addr;
   wire [4:0] exu_i_rs2_addr;
   wire [63:0] exu_i_rop1;
   wire [63:0] exu_i_rop2;
   wire [`OP_SEL_W-1:0] exu_i_op_sel;
   wire [`ALU_OPW-1:0] exu_i_fu_sel;
   wire exu_i_wb_sel;
   wire [11:0] exu_i_imm12;
   wire [63:0] exu_o_rd_dat;

   wire [63:0] rf_rs1, rf_rs2;
   wire [63:0] rs1, rs2;
   
   wire [4:0] lsu_i_rd;
   wire lsu_i_rf_we;
   wire [63:0] lsu_i_rd_dat;
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
         .o_rf_we    (idu_o_rf_we),
         .o_rd       (idu_o_rd),
         .o_rs1_addr (idu_o_rs1_addr),
         .o_rs2_addr (idu_o_rs2_addr),
         .op_sel     (idu_o_op_sel),
         .fu_sel     (idu_o_fu_sel),
         .wb_sel     (idu_o_wb_sel),
         .imm12      (idu_o_imm12)
      );

   idu_exu IDU_EXU
      (
      .clk           (clk),
      .rst           (rst),
      .idu_o_rf_we   (idu_o_rf_we),
      .idu_o_rd      (idu_o_rd),
      .idu_o_rs1_addr(idu_o_rs1_addr),
      .idu_o_rs2_addr(idu_o_rs2_addr),
      .idu_o_op_sel  (idu_o_op_sel),
      .idu_o_fu_sel  (idu_o_fu_sel),
      .idu_o_wb_sel  (idu_o_wb_sel),
      .idu_o_imm12   (idu_o_imm12),
      .exu_i_rf_we   (exu_i_rf_we),
      .exu_i_rd      (exu_i_rd),
      .exu_i_rs1_addr(exu_i_rs1_addr),
      .exu_i_rs2_addr(exu_i_rs2_addr),
      .exu_i_op_sel  (exu_i_op_sel),
      .exu_i_fu_sel  (exu_i_fu_sel),
      .exu_i_wb_sel  (exu_i_wb_sel),
      .exu_i_imm12   (exu_i_imm12)
   );

   regfile RF
      (
         .clk           (clk),
         .i_rs1_addr    (idu_o_rs1_addr),
         .i_rs2_addr    (idu_o_rs2_addr),
         .rs1           (rf_rs1),
         .rs2           (rf_rs2),
         .i_rd          (lsu_i_rd),
         .i_rf_we       (lsu_i_rf_we),
         .i_rd_dat      (lsu_i_rd_dat)
      );

   forward FORWARD_ROP1(
      .i_operand_addr   (exu_i_rs1_addr),
      .i_rf_operand     (rf_rs1),
      .o_operand        (exu_i_rop1),
      // Listening LSU
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_rd_dat     (lsu_i_rd_dat)
   );
   forward FORWARD_ROP2(
      .i_operand_addr   (exu_i_rs2_addr),
      .i_rf_operand     (rf_rs2),
      .o_operand        (exu_i_rop2),
      // Listening LSU
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_rd_dat     (lsu_i_rd_dat)
   );

   opmux OP_MUX
      (
         .op_sel        (exu_i_op_sel),
         .rf_rs1        (exu_i_rop1),
         .rf_rs2        (exu_i_rop2),
         .imm12         (exu_i_imm12),
         .rs1           (rs1),
         .rs2           (rs2)
      );

   alu ALU
      (
         .i_fu_sel      (exu_i_fu_sel),
         .i_operand1    (rs1),
         .i_operand2    (rs2),
         .o_result      (alu_result)
      );

   wbmux WB_MUX
      (
         .wb_sel        (exu_i_wb_sel),
         .alu_result    (alu_result),
         .lsu_result    (64'b0), // TODO
         .rd_dat        (exu_o_rd_dat)
      );

   exu_lsu EXU_LSU
   (
      .clk              (clk),
      .rst              (rst),
      .exu_i_rd         (exu_i_rd),
      .exu_i_rf_we      (exu_i_rf_we),
      .exu_o_rd_dat     (exu_o_rd_dat),
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_rd_dat     (lsu_i_rd_dat)
   );

endmodule
