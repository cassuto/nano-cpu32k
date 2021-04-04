`timescale 1ns / 1ps
//////////////////////////////////////////////////////////////////////////////////
// Company: 
// Engineer: 
// 
// Create Date:    19:16:42 03/21/2020 
// Design Name: toplevel
// Module Name:    toplevel 
// Project Name: ncpu32k SoPC on FPGA
// Target Devices: Spartan-6
// Tool versions: 
// Description: 
//
// Dependencies: 
//
// Revision: 
// Revision 0.01 - File Created
// Additional Comments: 
//
//////////////////////////////////////////////////////////////////////////////////
module toplevel
#(
   // SDRAM interface parameters
   parameter SDR_ADDR_BITS = 13,
   parameter SDR_BA_BITS = 2,
   parameter SDR_DQ_BITS = 16,
   parameter SDR_DM_BITS = 2,
   parameter SDR_COL_BITS = 9,
   parameter SDR_ROW_BITS = 13,
   parameter SDR_DATA_BITS = 16,
   // SDRAM timing parameters
   parameter SDR_tRP = 3,
   parameter SDR_tMRD = 2,
   parameter SDR_tRCD = 3,
   parameter SDR_tRFC = 9,
   parameter SDR_tREF = 64, // ms
   parameter SDR_pREF = 9, // = floor(log2(Fclk*tREF/(2^SDR_ROW_BITS)))
   parameter SDR_nCAS_Latency = 3
)
(
   // System input signals
   input                      CLK_50M_IN,
   input                      SYS_RST_N,
   // SDRAM signals
   output                     DRAM_CLK,
   output                     DRAM_CKE,
   output [SDR_ADDR_BITS - 1 : 0] DRAM_ADDR,
   output   [SDR_BA_BITS - 1 : 0] DRAM_BA,
   inout    [SDR_DQ_BITS - 1 : 0] DRAM_DATA,
   output   [SDR_DM_BITS - 1 : 0] DRAM_DQM,
   output                     DRAM_CAS_L,
   output                     DRAM_RAS_L,
   output                     DRAM_WE_L,
   output                     DRAM_CS_L,
   // SPI signals
   output                     SPI_SCK,
   output                     SPI_CS_L,
   output                     SPI_MOSI,
   input                      SPI_MISO,
   // UART signals
   output                     UART_TX_L,
   input                      UART_RX_L,
   
   // LED indicator
   output [1:0]               LED_INC
);

   wire CLK_50M_buf;
   wire clk;
   wire sdr_clk;
   wire dram_clk;
   wire uart_clk;
   wire smpl_clk;
   wire pll_locked;
   reg rst_n_r;
   wire rst_n;
  
   ODDR2 #(
      .DDR_ALIGNMENT("NONE"), // Sets output alignment to "NONE", "C0" or "C1" 
      .INIT(1'b0),    // Sets initial state of the Q output to 1'b0 or 1'b1
      .SRTYPE("SYNC") // Specifies "SYNC" or "ASYNC" set/reset
   ) ODDR2_inst 
	(
      .Q(DRAM_CLK), // 1-bit DDR output data
      .C0(dram_clk),  // 1-bit clock input
      .C1(~dram_clk), // 1-bit clock input
      .CE(1'b1), 		// 1-bit clock enable input
      .D0(1'b1), 		// 1-bit data input (associated with C0)
      .D1(1'b0), 		// 1-bit data input (associated with C1)
      .R(1'b0),   	// 1-bit reset input
      .S(1'b0)    	// 1-bit set input
   );
   
   IBUFG #(.IOSTANDARD("DEFAULT")) IBUFG_inst 
   (
      .O(CLK_50M_buf),
      .I(CLK_50M_IN)
   );

   // DCM
   dcm_clktree dcm_clkt
	(
		.CLK_IN1(CLK_50M_buf),
      .CLK_OUT1(clk),
		.CLK_OUT2(sdr_clk),
		.CLK_OUT3(dram_clk),
		.CLK_OUT4(uart_clk),
      .CLK_OUT5(smpl_clk),
      .RESET(~SYS_RST_N),
      .LOCKED(pll_locked)
    );
    
   // SoC Core
   soc_toplevel
   #(
      .CONFIG_SDR_COL_BITS    (SDR_COL_BITS),
      .CONFIG_SDR_ROW_BITS    (SDR_ROW_BITS),
      .CONFIG_SDR_BA_BITS     (SDR_BA_BITS),
      .CONFIG_SDR_DATA_BITS   (SDR_DATA_BITS),
      .CONFIG_SDR_ADDR_BITS   (SDR_ADDR_BITS),
      .CONFIG_SDR_tRP         (SDR_tRP),
      .CONFIG_SDR_tMRD        (SDR_tMRD),
      .CONFIG_SDR_tRCD        (SDR_tRCD),
      .CONFIG_SDR_tRFC        (SDR_tRFC),
      .CONFIG_SDR_tREF        (SDR_tREF),
      .CONFIG_SDR_pREF        (SDR_pREF),
      .CONFIG_SDR_nCAS_Latency (SDR_nCAS_Latency)
   )
   soc
   (
      .CPU_CLK    (clk),
      .SDR_CLK    (sdr_clk),
      .UART_CLK   (uart_clk),
      .RST_L      (rst_n),

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
      .SPI_MISO   (SPI_MISO),
      
      .UART_RX_L  (UART_RX_L),
      .UART_TX_L  (UART_TX_L)
   );
   
   always @(posedge clk or negedge pll_locked)
      if(~pll_locked)
         rst_n_r <= 0;
      else
         rst_n_r <= 1;

   // Global RST
   assign rst_n = rst_n_r;

   reg [4:0] led_cnt;
   
   always @(posedge SPI_SCK or negedge rst_n)
      if (~rst_n)
         led_cnt <= 'b0;
      else if (SPI_CS_L)
         led_cnt <= led_cnt + 'b1;

   assign LED_INC[0] = 1'b0;
   assign LED_INC[1] = led_cnt[4] & SPI_CS_L;
   
endmodule
