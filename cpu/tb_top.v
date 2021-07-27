module tb_top(
   input clk,
   input rst
);

   localparam IRAM_AW = 16; // (2^ILEN) * 64 KiB
   localparam DRAM_AW = 16; // 64 KiB

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

endmodule
