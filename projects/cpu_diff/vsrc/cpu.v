`include "defines.v"

module cpu #(
   parameter IRAM_AW = 62,
   parameter DRAM_AW = 64
)
(
   input clk,
   input rst,
   // IRAM
   output [IRAM_AW-1:0] o_iram_addr,
   output o_iram_re,
   input [31:0] i_iram_insn,
   input i_iram_valid,
   // DRAM
   output [DRAM_AW-1:0] o_dram_addr,
   output [7:0] o_dram_we,
   output o_dram_re,
   output [63:0] o_dram_din,
   input [63:0] i_dram_dout,
   // Debug
   output wb_i_valid,
   output [63:0] wb_i_pc,
   output [31:0] wb_i_insn,
   output [4:0] wb_i_rd,
   output wb_i_rf_we,
   output [63:0] wb_i_rd_dat,
   output [63:0] rf_regs [31:0]
);
   // IDU
   wire idu_o_rf_we;
   wire [4:0] idu_o_rd;
   wire [4:0] idu_o_rs1_addr;
   wire [4:0] idu_o_rs2_addr;
   wire [`OP_SEL_W-1:0] idu_o_op_sel;
   wire [`ALU_OPW-1:0] idu_o_fu_sel;
   wire idu_o_lsu_op_load;
   wire idu_o_lsu_op_store;
   wire idu_o_lsu_sigext;
   wire [3:0] idu_o_lsu_size;
   wire idu_o_wb_sel;
   wire [11:0] idu_o_imm12;
   wire idu_o_valid;
   wire [63:0] idu_o_pc;
   wire [31:0] idu_o_insn;
   // EXU
   wire exu_i_rf_we;
   wire [4:0] exu_i_rd;
   wire [4:0] exu_i_rs1_addr;
   wire [4:0] exu_i_rs2_addr;
   wire [63:0] exu_i_rf_rs1;
   wire [63:0] exu_i_rf_rs2;
   wire [`OP_SEL_W-1:0] exu_i_op_sel;
   wire [`ALU_OPW-1:0] exu_i_fu_sel;
   wire exu_i_lsu_op_load;
   wire exu_i_lsu_op_store;
   wire exu_i_lsu_sigext;
   wire [3:0] exu_i_lsu_size;
   wire exu_i_wb_sel;
   wire [11:0] exu_i_imm12;
   wire [63:0] exu_o_alu_result;
   wire [63:0] exu_i_rop1, exu_i_rop2;
   wire [63:0] exu_i_rs1, exu_i_rs2;
   wire exu_i_valid;
   wire [63:0] exu_i_pc;
   wire [31:0] exu_i_insn;
   // LSU
   wire lsu_i_wb_sel;
   wire lsu_i_lsu_op_load;
   wire lsu_i_lsu_op_store;
   wire lsu_i_lsu_sigext;
   wire [3:0] lsu_i_lsu_size;
   wire [63:0] lsu_i_rop2;
   wire [4:0] lsu_i_rd;
   wire lsu_i_rf_we;
   wire [63:0] lsu_i_alu_result;
   wire lsu_i_valid;
   wire [63:0] lsu_i_pc;
   wire [31:0] lsu_i_insn;
   // WB
   wire wb_i_wb_sel;
   wire [63:0] wb_i_alu_result;
   wire [63:0] wb_i_lsu_result;

   //////////////////////////////////////////////////////////////
   // Stage #1: Fetch
   //////////////////////////////////////////////////////////////
   ifu
      #(
         .IRAM_AW       (IRAM_AW)
      )
   IFU
      (
         .clk           (clk),
         .rst           (rst),
         .o_iram_addr   (o_iram_addr),
         .o_iram_re     (o_iram_re),
         .o_pc          (idu_o_pc)
      );

   //////////////////////////////////////////////////////////////
   // Stage #2: Decode
   //////////////////////////////////////////////////////////////

   idu IDU
      (
         .i_insn     (i_iram_insn),
         .i_valid    (i_iram_valid),
         .o_rf_we    (idu_o_rf_we),
         .o_rd       (idu_o_rd),
         .o_rs1_addr (idu_o_rs1_addr),
         .o_rs2_addr (idu_o_rs2_addr),
         .op_sel     (idu_o_op_sel),
         .fu_sel     (idu_o_fu_sel),
         .lsu_op_load(idu_o_lsu_op_load),
         .lsu_op_store(idu_o_lsu_op_store),
         .lsu_sigext (idu_o_lsu_sigext),
         .lsu_size   (idu_o_lsu_size),
         .wb_sel     (idu_o_wb_sel),
         .imm12      (idu_o_imm12),
         .o_valid    (idu_o_valid),
         .o_insn     (idu_o_insn)
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
      .idu_o_lsu_op_load(idu_o_lsu_op_load),
      .idu_o_lsu_op_store(idu_o_lsu_op_store),
      .idu_o_lsu_sigext (idu_o_lsu_sigext),
      .idu_o_lsu_size (idu_o_lsu_size),
      .idu_o_wb_sel  (idu_o_wb_sel),
      .idu_o_imm12   (idu_o_imm12),
      .idu_o_valid   (idu_o_valid),
      .idu_o_pc      (idu_o_pc),
      .idu_o_insn    (idu_o_insn),
      .exu_i_rf_we   (exu_i_rf_we),
      .exu_i_rd      (exu_i_rd),
      .exu_i_rs1_addr(exu_i_rs1_addr),
      .exu_i_rs2_addr(exu_i_rs2_addr),
      .exu_i_op_sel  (exu_i_op_sel),
      .exu_i_fu_sel  (exu_i_fu_sel),
      .exu_i_lsu_op_load   (exu_i_lsu_op_load),
      .exu_i_lsu_op_store  (exu_i_lsu_op_store),
      .exu_i_lsu_sigext    (exu_i_lsu_sigext),
      .exu_i_lsu_size      (exu_i_lsu_size),
      .exu_i_wb_sel  (exu_i_wb_sel),
      .exu_i_imm12   (exu_i_imm12),
      .exu_i_valid   (exu_i_valid),
      .exu_i_pc      (exu_i_pc),
      .exu_i_insn    (exu_i_insn)
   );

   regfile RF
      (
         .clk           (clk),
         .i_rs1_addr    (idu_o_rs1_addr),
         .i_rs2_addr    (idu_o_rs2_addr),
         .rs1           (exu_i_rf_rs1),
         .rs2           (exu_i_rf_rs2),
         .i_rd          (wb_i_rd),
         .i_rf_we       (wb_i_rf_we & wb_i_valid),
         .i_rd_dat      (wb_i_rd_dat),
         .o_regs        (rf_regs)
      );

   //////////////////////////////////////////////////////////////
   // Stage #3: Execute
   //////////////////////////////////////////////////////////////

   forward FORWARD_ROP1(
      .i_operand_addr   (exu_i_rs1_addr),
      .i_rf_operand     (exu_i_rf_rs1),
      .o_operand        (exu_i_rop1),
      // Listening LSU
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_rd_dat     (lsu_i_alu_result), // FIXME stall pipeline if RAW
      // Listening WB
      .wb_i_rd          (wb_i_rd),
      .wb_i_rf_we       (wb_i_rf_we),
      .wb_i_rd_dat      (wb_i_rd_dat)
   );
   forward FORWARD_ROP2(
      .i_operand_addr   (exu_i_rs2_addr),
      .i_rf_operand     (exu_i_rf_rs2),
      .o_operand        (exu_i_rop2),
      // Listening LSU
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_rd_dat     (lsu_i_alu_result), // FIXME stall pipeline if RAW
      // Listening WB
      .wb_i_rd          (wb_i_rd),
      .wb_i_rf_we       (wb_i_rf_we),
      .wb_i_rd_dat      (wb_i_rd_dat)
   );

   opmux OP_MUX
      (
         .i_op_sel        (exu_i_op_sel),
         .i_rop1          (exu_i_rop1),
         .i_rop2          (exu_i_rop2),
         .i_imm12         (exu_i_imm12),
         .o_rs1           (exu_i_rs1),
         .o_rs2           (exu_i_rs2)
      );

   alu ALU
      (
         .i_fu_sel      (exu_i_fu_sel),
         .i_operand1    (exu_i_rs1),
         .i_operand2    (exu_i_rs2),
         .o_result      (exu_o_alu_result)
      );

   exu_lsu EXU_LSU
   (
      .clk                 (clk),
      .rst                 (rst),
      .exu_i_lsu_op_load   (exu_i_lsu_op_load),
      .exu_i_lsu_op_store  (exu_i_lsu_op_store),
      .exu_i_lsu_sigext    (exu_i_lsu_sigext),
      .exu_i_lsu_size      (exu_i_lsu_size),
      .exu_i_wb_sel        (exu_i_wb_sel),
      .exu_i_rd            (exu_i_rd),
      .exu_i_rf_we         (exu_i_rf_we),
      .exu_o_alu_result    (exu_o_alu_result),
      .exu_i_rop2          (exu_i_rop2),
      .exu_i_valid         (exu_i_valid),
      .exu_i_pc            (exu_i_pc),
      .exu_i_insn          (exu_i_insn),
      .lsu_i_wb_sel        (lsu_i_wb_sel),
      .lsu_i_lsu_op_load   (lsu_i_lsu_op_load),
      .lsu_i_lsu_op_store  (lsu_i_lsu_op_store),
      .lsu_i_lsu_sigext    (lsu_i_lsu_sigext),
      .lsu_i_lsu_size      (lsu_i_lsu_size),
      .lsu_i_rd            (lsu_i_rd),
      .lsu_i_rf_we         (lsu_i_rf_we),
      .lsu_i_alu_result    (lsu_i_alu_result),
      .lsu_i_rop2          (lsu_i_rop2),
      .lsu_i_valid         (lsu_i_valid),
      .lsu_i_pc            (lsu_i_pc),
      .lsu_i_insn          (lsu_i_insn)
   );

   //////////////////////////////////////////////////////////////
   // Stage #4: Load & Store
   //////////////////////////////////////////////////////////////

   lsu LSU
   (
      .lsu_i_valid      (lsu_i_valid),
      .lsu_i_rop2       (lsu_i_rop2),
      .lsu_i_alu_result (lsu_i_alu_result),
      .lsu_op_load      (lsu_i_lsu_op_load),
      .lsu_op_store     (lsu_i_lsu_op_store),
      .lsu_sigext       (lsu_i_lsu_sigext),
      .lsu_size         (lsu_i_lsu_size),
      .wb_i_lsu_result  (wb_i_lsu_result),

      .o_dram_addr      (o_dram_addr),
      .o_dram_we        (o_dram_we),
      .o_dram_re        (o_dram_re),
      .o_dram_din       (o_dram_din),
      .i_dram_dout      (i_dram_dout)
   );

   lsu_wb LSU_WB
   (
      .clk              (clk),
      .rst              (rst),
      .lsu_i_wb_sel     (lsu_i_wb_sel),
      .lsu_i_rd         (lsu_i_rd),
      .lsu_i_rf_we      (lsu_i_rf_we),
      .lsu_i_alu_result (lsu_i_alu_result),
      .lsu_i_valid      (lsu_i_valid),
      .lsu_i_pc         (lsu_i_pc),
      .lsu_i_insn       (lsu_i_insn),
      .wb_i_wb_sel      (wb_i_wb_sel),
      .wb_i_rd          (wb_i_rd),
      .wb_i_rf_we       (wb_i_rf_we),
      .wb_i_alu_result  (wb_i_alu_result),
      .wb_i_valid       (wb_i_valid),
      .wb_i_pc          (wb_i_pc),
      .wb_i_insn        (wb_i_insn)
   );

   //////////////////////////////////////////////////////////////
   // Stage #5: Write back
   //////////////////////////////////////////////////////////////

   wbmux WB_MUX
   (
      .wb_sel        (wb_i_wb_sel),
      .alu_result    (wb_i_alu_result),
      .lsu_result    (wb_i_lsu_result),
      .rd_dat        (wb_i_rd_dat)
   );

endmodule