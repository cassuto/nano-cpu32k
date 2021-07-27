`include "defines.vh"

module cpu(
   input clk,
   input rst
);
   localparam IRAM_AW = 16; // (2^ILEN) * 64 KiB
   localparam DRAM_AW = 16; // 64 KiB

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
   wire [4:0] wb_i_rd;
   wire wb_i_rf_we;
   wire [63:0] wb_i_alu_result;
   wire [63:0] wb_i_lsu_result;
   wire [63:0] wb_i_rd_dat;
   wire wb_i_valid;
   wire [63:0] wb_i_pc;
   wire [31:0] wb_i_insn;

   // IRAM
   wire [IRAM_AW-1:0] iram_addr;
   wire [31:0] insn;
   // DRAM
   wire [DRAM_AW-1:0] dram_addr;
   wire [7:0] dram_we;
   wire dram_re;
   wire [63:0] dram_din;
   wire [63:0] dram_dout;

   // Data RAM
   dram
      #(
      .DRAM_AW       (DRAM_AW)
      )
   DRAM
      (
         .clk        (clk),
         .rst        (rst),
         .o_dat      (dram_dout),
         .i_dat      (dram_din),
         .i_we       (dram_we),
         .i_re       (dram_re),
         .i_addr     (dram_addr)
      );

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
         .o_iram_addr   (iram_addr),
         .o_pc          (idu_o_pc)
      );

   // Insn RAM
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

   //////////////////////////////////////////////////////////////
   // Stage #2: Decode
   //////////////////////////////////////////////////////////////

   idu IDU
      (
         .i_insn     (insn),
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
         .i_rf_we       (wb_i_rf_we),
         .i_rd_dat      (wb_i_rd_dat)
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
      .lsu_i_rop2       (lsu_i_rop2),
      .lsu_i_alu_result (lsu_i_alu_result),
      .lsu_op_load      (lsu_i_lsu_op_load),
      .lsu_op_store     (lsu_i_lsu_op_store),
      .lsu_sigext       (lsu_i_lsu_sigext),
      .lsu_size         (lsu_i_lsu_size),
      .wb_i_lsu_result  (wb_i_lsu_result),

      .dram_addr        (dram_addr),
      .dram_we          (dram_we),
      .dram_re          (dram_re),
      .dram_din         (dram_din),
      .dram_dout        (dram_dout)
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
      .wb_i_wb_sel      (lsu_i_wb_sel),
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

   DifftestInstrCommit U_inst_commit(
      .clock         (clk),
      .coreid        (8'd0),
      .index         (8'd0),
      .valid         (wb_i_valid),
      .pc            (wb_i_pc),//64bit
      .instr         (wb_i_insn),//32bit
      .skip          (1'b0),
      .isRVC         (1'b0),
      .scFailed      (1'b0),
      .wen           (wb_i_rf_we & (|wb_i_rd)),
      .wdest         ({3'b0, wb_i_rd[4:0]}),//8bit
      .wdata         (wb_i_rd_dat) //64bit
   );

endmodule
