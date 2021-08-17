module top(
   input clk,
   input rst
);

   localparam IRAM_AW = 16; // (2^ILEN) * 64 KiB
   localparam DRAM_AW = 16; // 64 KiB

   // IRAM
   wire [IRAM_AW-1:0] iram_addr;
   wire iram_re;
   wire [31:0] iram_insn;
   wire iram_valid;
   // DRAM
   wire [DRAM_AW-1:0] dram_addr;
   wire [7:0] dram_we;
   wire dram_re;
   wire [63:0] dram_din;
   wire [63:0] dram_dout;
   // Debug
   /* verilator lint_off UNUSED */
   wire wb_i_valid;
   wire [63:0] wb_i_pc;
   wire [31:0] wb_i_insn;
   wire [4:0] wb_i_rd;
   wire wb_i_rf_we;
   wire [63:0] wb_i_rd_dat;
   wire [63:0] rf_regs [31:0];
   /* verilator lint_on UNUSED */

   cpu
      #(
         .IRAM_AW          (IRAM_AW),
         .DRAM_AW          (DRAM_AW)
      )
   CPU
      (
         .clk              (clk),
         .rst              (rst),

         .o_iram_addr      (iram_addr),
         .o_iram_re        (iram_re),
         .i_iram_insn      (iram_insn),
         .i_iram_valid     (iram_valid),

         .o_dram_addr      (dram_addr),
         .o_dram_we        (dram_we),
         .o_dram_re        (dram_re),
         .o_dram_din       (dram_din),
         .i_dram_dout      (dram_dout),

         .wb_i_valid       (wb_i_valid),
         .wb_i_pc          (wb_i_pc),
         .wb_i_insn        (wb_i_insn),
         .wb_i_rd          (wb_i_rd),
         .wb_i_rf_we       (wb_i_rf_we),
         .wb_i_rd_dat      (wb_i_rd_dat),
         .rf_regs          (rf_regs)
      );

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
         .i_re       (iram_re),
         .o_insn     (iram_insn),
         .o_valid    (iram_valid)
      );

endmodule
