
`include "ncpu32k_config.h"

module tb_sopc_flash_config();
   `include "include/DevParam.h"
endmodule

module tb_sopc();

   reg clk = 0;
   reg sdr_clk = 0;
   reg rst_n = 0;
   reg DRAM_CLK = 0;
   
   // DRAM clk 100MHz
   localparam tCK = 10; // ns
   initial begin
      // phrase +0.8ns (+28.8deg)
      #0.8 forever #(tCK/2) sdr_clk = ~sdr_clk;
   end
   initial begin
      forever #(tCK/2) DRAM_CLK = ~DRAM_CLK;
   end
   // Cache clk 80MHz
   initial begin
      forever #(12.5/2) clk = ~clk;
   end

   // Generate reset
   initial begin
      #10 rst_n= 1'b1;
   end
   
   localparam ADDR_BITS = 13;
   localparam BA_BITS = 2;
   localparam DQ_BITS = 16;
   localparam DM_BITS = 2;
   
   wire                     DRAM_CKE;                           // Synchronous Clock Enable
   wire [ADDR_BITS - 1 : 0] DRAM_ADDR;                          // SDRAM Address
   wire   [BA_BITS - 1 : 0] DRAM_BA;                            // Bank Address
   wire   [DQ_BITS - 1 : 0] DRAM_DATA;                            // SDRAM I/O
   wire   [DM_BITS - 1 : 0] DRAM_DQM;                           // Data Mask
   wire                     DRAM_CAS_L;
   wire                     DRAM_RAS_L;
   wire                     DRAM_WE_L;
   wire                     DRAM_CS_L;
   
   wire                     SPI_SCK;
   wire                     SPI_CS_L;
   wire                     SPI_MOSI;
   wire                     SPI_MISO;
   
   reg [`VoltageRange] SF_Vcc; 
   wire SF_DQ0, SF_DQ1;
   wire SF_Vpp_W_DQ2; 
   wire SF_HOLD_DQ3; 
   
   // SDRAM
   sdr
   #(
      .MEMH_FILE_B0 ("insn_b0.mem"),
      .MEMH_FILE_B1 ("insn_b1.mem"),
      .MEMH_FILE_B2 ("insn_b2.mem"),
      .MEMH_FILE_B3 ("insn_b3.mem")
   )
      sdram0
   (
      DRAM_DATA, DRAM_ADDR, DRAM_BA,
      DRAM_CLK, DRAM_CKE,
      DRAM_CS_L, DRAM_RAS_L, DRAM_CAS_L, DRAM_WE_L,
      DRAM_DQM
   );

   // SPI FLASH
   N25Qxxx spi_flash (SPI_CS_L, SPI_SCK, SF_HOLD_DQ3, SF_DQ0, SF_DQ1, SF_Vcc, SF_Vpp_W_DQ2);
   
   assign SF_DQ0 = SPI_MOSI;
   assign SPI_MISO = SF_DQ1;
   
   // SoC
   soc_toplevel soc
   (
      .CPU_CLK (clk),
      .SDR_CLK (sdr_clk),
      .RST_L   (rst_n),

      .DRAM_CKE   (DRAM_CKE),   // Synchronous Clock Enable
      .DRAM_ADDR  (DRAM_ADDR),  // SDRAM Address
      .DRAM_BA    (DRAM_BA),    // Bank Address
      .DRAM_DATA  (DRAM_DATA),  // SDRAM I/O
      .DRAM_DQM   (DRAM_DQM),   // Data Mask
      .DRAM_CAS_L (DRAM_CAS_L),
      .DRAM_RAS_L (DRAM_RAS_L),
      .DRAM_WE_L  (DRAM_WE_L),
      .DRAM_CS_L  (DRAM_CS_L),

      .SPI_SCK    (SPI_SCK),
      .SPI_CS_L   (SPI_CS_L),
      .SPI_MOSI   (SPI_MOSI),
      .SPI_MISO   (SPI_MISO)
   );
   
   assign SF_Vpp_W_DQ2=0; // Disable WP
   assign SF_HOLD_DQ3=1; // Disable HOLD
   
   // SPI FLASH power up
   initial begin
     SF_Vcc='d3000;  // 3.000V 
   end
   
endmodule
