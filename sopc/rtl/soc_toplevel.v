/**@file
 * SoC toplevel design
 */

/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module soc_toplevel
#(
   // SDRAM interface parameters
   parameter CONFIG_SDR_ADDR_BITS = 13,
   parameter CONFIG_SDR_BA_BITS = 2,
   parameter CONFIG_SDR_DQ_BITS = 16,
   parameter CONFIG_SDR_DM_BITS = 2,
   parameter CONFIG_SDR_COL_BITS = 9,
   parameter CONFIG_SDR_ROW_BITS = 13,
   parameter CONFIG_SDR_DATA_BITS = 16,
   // SDRAM timing parameters
   parameter CONFIG_SDR_tRP = 3,
   parameter CONFIG_SDR_tMRD = 2,
   parameter CONFIG_SDR_tRCD = 3,
   parameter CONFIG_SDR_tRFC = 9,
   parameter CONFIG_SDR_tREF = 64, // ms
   parameter CONFIG_SDR_pREF = 9, // = floor(log2(Fclk*tREF/(2^ROW_BW)))
   parameter CONFIG_SDR_nCAS_Latency = 3,

   // Bootrom parameters
   parameter CONFIG_BOOTM_SIZE_BYTES = 4096,
   parameter CONFIG_BOOTM_MEMH_FILE = "bootstrap.mem",

   // Core parameters
   parameter CONFIG_CORE_1_ERST_VECTOR = `NCPU_ERST_VECTOR,
   parameter CONFIG_CORE_1_ENABLE_IMMU = 1,
   parameter CONFIG_CORE_1_ENABLE_DMMU = 1,
   parameter CONFIG_CORE_1_ITLB_NSETS_LOG2 = 7,
   parameter CONFIG_CORE_1_DTLB_NSETS_LOG2 = 7,
   parameter CONFIG_CORE_1_ENABLE_ICACHE = 0,
   parameter CONFIG_CORE_1_ENABLE_DCACHE = 0,

   parameter CONFIG_PIPEBUF_BYPASS = 1,
   parameter CONFIG_IBUS_OUTSTANTING_LOG2 = 2
)
(
   input                            CPU_CLK,
   input                            SDR_CLK,
   input                            UART_CLK,
   input                            RST_L,

   // SDRAM Interface
   output                           DRAM_CKE,   // Synchronous Clock Enable
   output [CONFIG_SDR_ADDR_BITS - 1 : 0]   DRAM_ADDR,  // SDRAM Address
   output   [CONFIG_SDR_BA_BITS - 1 : 0]   DRAM_BA,    // Bank Address
   inout    [CONFIG_SDR_DQ_BITS - 1 : 0]   DRAM_DATA,  // SDRAM I/O
   output   [CONFIG_SDR_DM_BITS - 1 : 0]   DRAM_DQM,   // Data Mask
   output                           DRAM_CAS_L,
   output                           DRAM_RAS_L,
   output                           DRAM_WE_L,
   output                           DRAM_CS_L,

   // SPI Master Interface
   output                           SPI_SCK,
   output                           SPI_CS_L,
   output                           SPI_MOSI,
   input                            SPI_MISO,

   // UART TTL Interface
   input                            UART_RX_L,
   output                           UART_TX_L
);

   // Internal parameters. Not edit
   localparam DW = `NCPU_DW;
   localparam AW = `NCPU_AW;
   localparam N_BW = 1;
   localparam L2_CH_DW = `NCPU_DW;
   localparam L2_CH_AW = CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-N_BW+2;
   localparam NBUS = 4;
   localparam CPU_RESET_VECTOR = 32'h80000000; // Start from bootrom

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [3:0]           DRAM_CS_WE_RAS_CAS_L;   // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire [NBUS*`NCPU_AW-1:0] fb_bus_AADDR;       // From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW-1:0] fb_bus_ADATA;       // From fb_router of pb_fb_router.v
   wire [NBUS*2-1:0]    fb_bus_AEXC;            // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_AVALID;          // From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW/8-1:0] fb_bus_AWMSK;     // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_BREADY;          // From fb_router of pb_fb_router.v
   wire [`NCPU_AW-1:0]  fb_dbus_AADDR;          // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW-1:0]  fb_dbus_ADATA;          // From ncpu32k of ncpu32k.v
   wire [1:0]           fb_dbus_AEXC;           // From ncpu32k of ncpu32k.v
   wire                 fb_dbus_AREADY;         // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_dbus_AVALID;         // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW/8-1:0] fb_dbus_AWMSK;         // From ncpu32k of ncpu32k.v
   wire [`NCPU_IW-1:0]  fb_dbus_BDATA;          // From fb_arbi of pb_fb_arbiter.v
   wire [1:0]           fb_dbus_BEXC;           // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_dbus_BREADY;         // From ncpu32k of ncpu32k.v
   wire                 fb_dbus_BVALID;         // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_AW-1:0]  fb_ibus_AADDR;          // From ncpu32k of ncpu32k.v
   wire [1:0]           fb_ibus_AEXC;           // From ncpu32k of ncpu32k.v
   wire                 fb_ibus_AREADY;         // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_ibus_AVALID;         // From ncpu32k of ncpu32k.v
   wire [`NCPU_IW-1:0]  fb_ibus_BDATA;          // From fb_arbi of pb_fb_arbiter.v
   wire [1:0]           fb_ibus_BEXC;           // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_ibus_BREADY;         // From ncpu32k of ncpu32k.v
   wire                 fb_ibus_BVALID;         // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_AW-1:0]  fb_mbus_AADDR;          // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW-1:0]  fb_mbus_ADATA;          // From fb_arbi of pb_fb_arbiter.v
   wire [1:0]           fb_mbus_AEXC;           // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_mbus_AREADY;         // From fb_router of pb_fb_router.v
   wire                 fb_mbus_AVALID;         // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW/8-1:0] fb_mbus_AWMSK;         // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW-1:0]  fb_mbus_BDATA;          // From fb_router of pb_fb_router.v
   wire [1:0]           fb_mbus_BEXC;           // From fb_router of pb_fb_router.v
   wire                 fb_mbus_BREADY;         // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_mbus_BVALID;         // From fb_router of pb_fb_router.v
   wire                 l2_ch_AREADY;           // From L2_cache of pb_fb_L2_cache.v
   wire [L2_CH_DW-1:0]  l2_ch_BDATA;            // From L2_cache of pb_fb_L2_cache.v
   wire [1:0]           l2_ch_BEXC;             // From L2_cache of pb_fb_L2_cache.v
   wire                 l2_ch_BVALID;           // From L2_cache of pb_fb_L2_cache.v
   wire                 pb_spi_AREADY;          // From pb_spi_master of soc_pb_spi_master.v
   wire                 pb_spi_BVALID;          // From pb_spi_master of soc_pb_spi_master.v
   wire                 pb_uart_AREADY;         // From pb_uart of soc_pb_uart.v
   wire                 pb_uart_BVALID;         // From pb_uart of soc_pb_uart.v
   wire                 pb_uart_irq;            // From pb_uart of soc_pb_uart.v
   wire [L2_CH_AW-3:0]  sdr_cmd_addr;           // From L2_cache of pb_fb_L2_cache.v
   wire                 sdr_cmd_bst_rd_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_rd_req;     // From L2_cache of pb_fb_L2_cache.v
   wire                 sdr_cmd_bst_we_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_we_req;     // From L2_cache of pb_fb_L2_cache.v
   wire [L2_CH_DW/2-1:0] sdr_din;               // From L2_cache of pb_fb_L2_cache.v
   wire [CONFIG_SDR_DATA_BITS-1:0] sdr_dout;    // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_r_vld;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_w_rdy;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   // End of automatics
   wire                 clk;
   wire                 rst_n;
   wire                 sdr_clk;
   wire                 sdr_rst_n;
   wire                 uart_clk;
   wire                 uart_rst_n;
   wire [`NCPU_NIRQ-1:0] fb_irqs;
   wire [NBUS-1:0]      fb_bus_sel;
   wire [NBUS-1:0]      fb_bus_BVALID;
   wire [NBUS*`NCPU_DW-1:0] fb_bus_BDATA;
   wire [NBUS*2-1:0]    fb_bus_BEXC;
   wire [NBUS-1:0]      fb_bus_AREADY;
   wire [`NCPU_AW-1:0]  l2_ch_AADDR;
   wire [`NCPU_DW/8-1:0] l2_ch_AWMSK;
   wire [1:0]           l2_ch_AEXC;
   wire [`NCPU_DW-1:0]  l2_ch_ADATA;
   wire                 l2_ch_BREADY;
   wire                 l2_ch_AVALID;
   wire                 l2_ch_flush;
   wire                 pb_bootm_AREADY;
   wire                 pb_bootm_AVALID;
   wire [`NCPU_AW-1:0]  pb_bootm_AADDR;
   wire [`NCPU_DW/8-1:0] pb_bootm_AWMSK;
   wire [1:0]           pb_bootm_AEXC;
   wire                 pb_bootm_BREADY;
   wire                 pb_bootm_BVALID;
   wire [`NCPU_DW-1:0]  pb_bootm_BDATA;
   wire [`NCPU_DW-1:0]  pb_bootm_ADATA;
   wire                 pb_spi_AVALID;
   wire [`NCPU_AW-1:0]  pb_spi_AADDR;
   wire [4:0]           pb_spi_AWMSK;
   wire [1:0]           pb_spi_AEXC;
   wire [31:0]          pb_spi_ADATA;
   wire [31:0]          pb_spi_BDATA;
   wire                 pb_spi_BREADY;
   wire                 pb_uart_AVALID;
   wire [`NCPU_AW-1:0]  pb_uart_AADDR;
   wire [4:0]           pb_uart_AWMSK;
   wire [1:0]           pb_uart_AEXC;
   wire [31:0]          pb_uart_ADATA;
   wire [31:0]          pb_uart_BDATA;
   wire                 pb_uart_BREADY;

   /************************************************************
    * SDRAM Controller
    ************************************************************/
   /* pb_fb_DRAM_ctrl AUTO_TEMPLATE (
         .clk           (sdr_clk),        // SDRAM clk domain
         .rst_n         (sdr_rst_n),
      );*/
   pb_fb_DRAM_ctrl
     #(
       .CONFIG_SDR_COL_BITS    (CONFIG_SDR_COL_BITS),
       .CONFIG_SDR_ROW_BITS    (CONFIG_SDR_ROW_BITS),
       .CONFIG_SDR_BA_BITS     (CONFIG_SDR_BA_BITS),
       .CONFIG_SDR_DATA_BITS   (CONFIG_SDR_DATA_BITS),
       .CONFIG_SDR_ADDR_BITS   (CONFIG_SDR_ADDR_BITS),
       .N_BW            (N_BW),
       .tRP             (CONFIG_SDR_tRP),
       .tMRD            (CONFIG_SDR_tMRD),
       .tRCD            (CONFIG_SDR_tRCD),
       .tRFC            (CONFIG_SDR_tRFC),
       .tREF            (CONFIG_SDR_tREF),
       .pREF            (CONFIG_SDR_pREF),
       .nCAS_Latency    (CONFIG_SDR_nCAS_Latency)
      )
   fb_DRAM_ctrl
     (/*AUTOINST*/
      // Outputs
      .DRAM_CKE                         (DRAM_CKE),
      .DRAM_CS_WE_RAS_CAS_L             (DRAM_CS_WE_RAS_CAS_L[3:0]),
      .DRAM_BA                          (DRAM_BA[CONFIG_SDR_BA_BITS-1:0]),
      .DRAM_ADDR                        (DRAM_ADDR[CONFIG_SDR_ADDR_BITS-1:0]),
      .DRAM_DQM                         (DRAM_DQM[1:0]),
      .sdr_cmd_bst_we_ack               (sdr_cmd_bst_we_ack),
      .sdr_cmd_bst_rd_ack               (sdr_cmd_bst_rd_ack),
      .sdr_dout                         (sdr_dout[CONFIG_SDR_DATA_BITS-1:0]),
      .sdr_r_vld                        (sdr_r_vld),
      .sdr_w_rdy                        (sdr_w_rdy),
      // Inouts
      .DRAM_DATA                        (DRAM_DATA[CONFIG_SDR_DATA_BITS-1:0]),
      // Inputs
      .clk                              (sdr_clk),               // Templated
      .rst_n                            (sdr_rst_n),             // Templated
      .sdr_cmd_bst_we_req               (sdr_cmd_bst_we_req),
      .sdr_cmd_bst_rd_req               (sdr_cmd_bst_rd_req),
      .sdr_cmd_addr                     (sdr_cmd_addr[CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-N_BW-1:0]),
      .sdr_din                          (sdr_din[CONFIG_SDR_DATA_BITS-1:0]));

   assign
      {
         DRAM_CS_L,
         DRAM_WE_L,
         DRAM_RAS_L,
         DRAM_CAS_L
      } = DRAM_CS_WE_RAS_CAS_L;

   /************************************************************
    * L2 Cache
    ************************************************************/
   pb_fb_L2_cache
     #(
       .CONFIG_PIPEBUF_BYPASS          (CONFIG_PIPEBUF_BYPASS)
     )
   L2_cache
     (/*AUTOINST*/
      // Outputs
      .l2_ch_BVALID                     (l2_ch_BVALID),
      .l2_ch_AREADY                     (l2_ch_AREADY),
      .l2_ch_BDATA                      (l2_ch_BDATA[L2_CH_DW-1:0]),
      .l2_ch_BEXC                       (l2_ch_BEXC[1:0]),
      .sdr_din                          (sdr_din[L2_CH_DW/2-1:0]),
      .sdr_cmd_bst_rd_req               (sdr_cmd_bst_rd_req),
      .sdr_cmd_bst_we_req               (sdr_cmd_bst_we_req),
      .sdr_cmd_addr                     (sdr_cmd_addr[L2_CH_AW-3:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .l2_ch_BREADY                     (l2_ch_BREADY),
      .l2_ch_AVALID                     (l2_ch_AVALID),
      .l2_ch_AADDR                      (l2_ch_AADDR[L2_CH_AW-1:0]),
      .l2_ch_AEXC                       (l2_ch_AEXC[1:0]),
      .l2_ch_AWMSK                      (l2_ch_AWMSK[L2_CH_DW/8-1:0]),
      .l2_ch_ADATA                      (l2_ch_ADATA[L2_CH_DW-1:0]),
      .l2_ch_flush                      (l2_ch_flush),
      .sdr_clk                          (sdr_clk),
      .sdr_rst_n                        (sdr_rst_n),
      .sdr_dout                         (sdr_dout[L2_CH_DW/2-1:0]),
      .sdr_r_vld                        (sdr_r_vld),
      .sdr_w_rdy                        (sdr_w_rdy));

   assign l2_ch_flush = 1'b0;

   /************************************************************
    * Frontend bus arbiter
    ************************************************************/
   pb_fb_arbiter fb_arbi
     (/*AUTOINST*/
      // Outputs
      .fb_ibus_BVALID                   (fb_ibus_BVALID),
      .fb_ibus_BDATA                    (fb_ibus_BDATA[`NCPU_IW-1:0]),
      .fb_ibus_BEXC                     (fb_ibus_BEXC[1:0]),
      .fb_ibus_AREADY                   (fb_ibus_AREADY),
      .fb_dbus_BVALID                   (fb_dbus_BVALID),
      .fb_dbus_BDATA                    (fb_dbus_BDATA[`NCPU_IW-1:0]),
      .fb_dbus_BEXC                     (fb_dbus_BEXC[1:0]),
      .fb_dbus_AREADY                   (fb_dbus_AREADY),
      .fb_mbus_BREADY                   (fb_mbus_BREADY),
      .fb_mbus_ADATA                    (fb_mbus_ADATA[`NCPU_DW-1:0]),
      .fb_mbus_AVALID                   (fb_mbus_AVALID),
      .fb_mbus_AADDR                    (fb_mbus_AADDR[`NCPU_AW-1:0]),
      .fb_mbus_AWMSK                    (fb_mbus_AWMSK[`NCPU_DW/8-1:0]),
      .fb_mbus_AEXC                     (fb_mbus_AEXC[1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_ibus_BREADY                   (fb_ibus_BREADY),
      .fb_ibus_AVALID                   (fb_ibus_AVALID),
      .fb_ibus_AADDR                    (fb_ibus_AADDR[`NCPU_AW-1:0]),
      .fb_ibus_AEXC                     (fb_ibus_AEXC[1:0]),
      .fb_dbus_BREADY                   (fb_dbus_BREADY),
      .fb_dbus_ADATA                    (fb_dbus_ADATA[`NCPU_DW-1:0]),
      .fb_dbus_AVALID                   (fb_dbus_AVALID),
      .fb_dbus_AADDR                    (fb_dbus_AADDR[`NCPU_AW-1:0]),
      .fb_dbus_AWMSK                    (fb_dbus_AWMSK[`NCPU_DW/8-1:0]),
      .fb_dbus_AEXC                     (fb_dbus_AEXC[1:0]),
      .fb_mbus_BVALID                   (fb_mbus_BVALID),
      .fb_mbus_BDATA                    (fb_mbus_BDATA[`NCPU_IW-1:0]),
      .fb_mbus_BEXC                     (fb_mbus_BEXC[1:0]),
      .fb_mbus_AREADY                   (fb_mbus_AREADY));

   /************************************************************
    * Frontend bus Router
    ************************************************************/
   pb_fb_router
     #(
      .NBUS(NBUS)
     )
   fb_router
     (/*AUTOINST*/
      // Outputs
      .fb_mbus_BVALID                   (fb_mbus_BVALID),
      .fb_mbus_BDATA                    (fb_mbus_BDATA[`NCPU_DW-1:0]),
      .fb_mbus_BEXC                     (fb_mbus_BEXC[1:0]),
      .fb_mbus_AREADY                   (fb_mbus_AREADY),
      .fb_bus_BREADY                    (fb_bus_BREADY[NBUS-1:0]),
      .fb_bus_ADATA                     (fb_bus_ADATA[NBUS*`NCPU_DW-1:0]),
      .fb_bus_AVALID                    (fb_bus_AVALID[NBUS-1:0]),
      .fb_bus_AADDR                     (fb_bus_AADDR[NBUS*`NCPU_AW-1:0]),
      .fb_bus_AWMSK                     (fb_bus_AWMSK[NBUS*`NCPU_DW/8-1:0]),
      .fb_bus_AEXC                      (fb_bus_AEXC[NBUS*2-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_mbus_BREADY                   (fb_mbus_BREADY),
      .fb_mbus_ADATA                    (fb_mbus_ADATA[`NCPU_DW-1:0]),
      .fb_mbus_AVALID                   (fb_mbus_AVALID),
      .fb_mbus_AADDR                    (fb_mbus_AADDR[`NCPU_AW-1:0]),
      .fb_mbus_AWMSK                    (fb_mbus_AWMSK[`NCPU_DW/8-1:0]),
      .fb_mbus_AEXC                     (fb_mbus_AEXC[1:0]),
      .fb_bus_sel                       (fb_bus_sel[NBUS-1:0]),
      .fb_bus_BVALID                    (fb_bus_BVALID[NBUS-1:0]),
      .fb_bus_BDATA                     (fb_bus_BDATA[NBUS*`NCPU_DW-1:0]),
      .fb_bus_BEXC                      (fb_bus_BEXC[NBUS*2-1:0]),
      .fb_bus_AREADY                    (fb_bus_AREADY[NBUS-1:0]));

   // Bus address mapping
   wire bank_sys_mem = ~fb_mbus_AADDR[`NCPU_AW-1];
   wire bank_mmio = ~bank_sys_mem;
   // System memory
   assign fb_bus_sel[0] = bank_sys_mem;
   // Bootrom
   assign fb_bus_sel[1] = bank_mmio & fb_mbus_AADDR[`NCPU_AW-1:24]==8'h80;
   // SPI Master
   assign fb_bus_sel[2] = bank_mmio & fb_mbus_AADDR[`NCPU_AW-1:24]==8'h81;
   // UART
   assign fb_bus_sel[3] = bank_mmio & fb_mbus_AADDR[`NCPU_AW-1:24]==8'h82;

   assign
      {
         pb_uart_BREADY,
         pb_spi_BREADY,
         pb_bootm_BREADY,
         l2_ch_BREADY
      } = fb_bus_BREADY;

   assign
      {
         pb_uart_ADATA[`NCPU_DW-1:0],
         pb_spi_ADATA[`NCPU_DW-1:0],
         pb_bootm_ADATA[`NCPU_DW-1:0],
         l2_ch_ADATA[`NCPU_DW-1:0]
      } = fb_bus_ADATA;

   assign
      {
         pb_uart_AVALID,
         pb_spi_AVALID,
         pb_bootm_AVALID,
         l2_ch_AVALID
      } = fb_bus_AVALID;

   assign
      {
         pb_uart_AADDR[`NCPU_AW-1:0],
         pb_spi_AADDR[`NCPU_AW-1:0],
         pb_bootm_AADDR[`NCPU_AW-1:0],
         l2_ch_AADDR[`NCPU_AW-1:0]
      } = fb_bus_AADDR;

   assign
      {
         pb_uart_AWMSK[`NCPU_DW/8-1:0],
         pb_spi_AWMSK[`NCPU_DW/8-1:0],
         pb_bootm_AWMSK[`NCPU_DW/8-1:0],
         l2_ch_AWMSK[`NCPU_DW/8-1:0]
      } = fb_bus_AWMSK;

   assign
      {
         pb_uart_AEXC[1:0],
         pb_spi_AEXC[1:0],
         pb_bootm_AEXC[1:0],
         l2_ch_AEXC[1:0]
      } = fb_bus_AEXC;

   assign fb_bus_BVALID =
      {
         pb_uart_BVALID,
         pb_spi_BVALID,
         pb_bootm_BVALID,
         l2_ch_BVALID
      };

   assign fb_bus_BDATA =
      {
         pb_uart_BDATA[`NCPU_DW-1:0],
         pb_spi_BDATA[`NCPU_DW-1:0],
         pb_bootm_BDATA[`NCPU_DW-1:0],
         l2_ch_BDATA[`NCPU_DW-1:0]
      };

   assign fb_bus_BEXC =
      {
         2'b00,
         2'b00,
         2'b00,
         l2_ch_BEXC[1:0]
      };

   assign fb_bus_AREADY =
      {
         pb_uart_AREADY,
         pb_spi_AREADY,
         pb_bootm_AREADY,
         l2_ch_AREADY
      };

   /************************************************************
    * Bootrom
    ************************************************************/
   pb_fb_bootrom
      #(
         .CONFIG_BOOTROM_SIZE_BYTES    (CONFIG_BOOTM_SIZE_BYTES),
         .CONFIG_BOOTROM_MEMH_FILE     (CONFIG_BOOTM_MEMH_FILE),
         .CONFIG_PIPEBUF_BYPASS        (CONFIG_PIPEBUF_BYPASS)
      )
   fb_bootrom
      (
         .clk                          (clk),
         .rst_n                        (rst_n),
         .AREADY                       (pb_bootm_AREADY),
         .AVALID                       (pb_bootm_AVALID),
         .AADDR                        (pb_bootm_AADDR[`NCPU_AW-1:0]),
         .AWMSK                        (pb_bootm_AWMSK[`NCPU_DW/8-1:0]),
         .BREADY                       (pb_bootm_BREADY),
         .BVALID                       (pb_bootm_BVALID),
         .BDATA                        (pb_bootm_BDATA[`NCPU_DW-1:0]),
         .ADATA                        (pb_bootm_ADATA[`NCPU_DW-1:0])
      );

   /************************************************************
    * SPI Master Controller
    ************************************************************/
   soc_pb_spi_master pb_spi_master
     (/*AUTOINST*/
      // Outputs
      .pb_spi_AREADY                    (pb_spi_AREADY),
      .pb_spi_BDATA                     (pb_spi_BDATA[31:0]),
      .pb_spi_BVALID                    (pb_spi_BVALID),
      .SPI_SCK                          (SPI_SCK),
      .SPI_CS_L                         (SPI_CS_L),
      .SPI_MOSI                         (SPI_MOSI),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .pb_spi_AVALID                    (pb_spi_AVALID),
      .pb_spi_AADDR                     (pb_spi_AADDR[`NCPU_AW-1:0]),
      .pb_spi_AWMSK                     (pb_spi_AWMSK[3:0]),
      .pb_spi_ADATA                     (pb_spi_ADATA[31:0]),
      .pb_spi_BREADY                    (pb_spi_BREADY),
      .SPI_MISO                         (SPI_MISO));

   /************************************************************
    * UART Controller
    ************************************************************/
    /* soc_pb_uart AUTO_TEMPLATE (
         .clk_baud       (uart_clk),        // UART clk domain
         .rst_baud_n     (uart_rst_n),
      );*/
   soc_pb_uart pb_uart
      (/*AUTOINST*/
       // Outputs
       .pb_uart_AREADY                  (pb_uart_AREADY),
       .pb_uart_BDATA                   (pb_uart_BDATA[31:0]),
       .pb_uart_BVALID                  (pb_uart_BVALID),
       .pb_uart_irq                     (pb_uart_irq),
       .UART_TX_L                       (UART_TX_L),
       // Inputs
       .clk                             (clk),
       .clk_baud                        (uart_clk),              // Templated
       .rst_n                           (rst_n),
       .rst_baud_n                      (uart_rst_n),            // Templated
       .pb_uart_AVALID                  (pb_uart_AVALID),
       .pb_uart_AADDR                   (pb_uart_AADDR[`NCPU_AW-1:0]),
       .pb_uart_AWMSK                   (pb_uart_AWMSK[3:0]),
       .pb_uart_ADATA                   (pb_uart_ADATA[31:0]),
       .pb_uart_BREADY                  (pb_uart_BREADY),
       .UART_RX_L                       (UART_RX_L));

   /************************************************************
    * CPU Core #1
    ************************************************************/
   ncpu32k
     #(
      .CONFIG_ENABLE_IMMU              (CONFIG_CORE_1_ENABLE_IMMU),
      .CONFIG_ENABLE_DMMU              (CONFIG_CORE_1_ENABLE_DMMU),
      .CONFIG_ITLB_NSETS_LOG2          (CONFIG_CORE_1_ITLB_NSETS_LOG2),
      .CONFIG_DTLB_NSETS_LOG2          (CONFIG_CORE_1_DTLB_NSETS_LOG2),
      .CONFIG_ENABLE_ICACHE            (CONFIG_CORE_1_ENABLE_ICACHE),
      .CONFIG_ENABLE_DCACHE            (CONFIG_CORE_1_ENABLE_DCACHE),
      .CONFIG_PIPEBUF_BYPASS           (CONFIG_PIPEBUF_BYPASS),
      .CONFIG_IBUS_OUTSTANTING_LOG2    (CONFIG_IBUS_OUTSTANTING_LOG2),
      .CONFIG_IRQ_LINENO_TSC           (0), // IRQ Line number of TSC
      .CONFIG_ERST_VECTOR              (CONFIG_CORE_1_ERST_VECTOR)
     )
   ncpu32k
     (/*AUTOINST*/
      // Outputs
      .fb_ibus_BREADY                   (fb_ibus_BREADY),
      .fb_ibus_AVALID                   (fb_ibus_AVALID),
      .fb_ibus_AADDR                    (fb_ibus_AADDR[`NCPU_AW-1:0]),
      .fb_ibus_AEXC                     (fb_ibus_AEXC[1:0]),
      .fb_dbus_BREADY                   (fb_dbus_BREADY),
      .fb_dbus_ADATA                    (fb_dbus_ADATA[`NCPU_DW-1:0]),
      .fb_dbus_AVALID                   (fb_dbus_AVALID),
      .fb_dbus_AADDR                    (fb_dbus_AADDR[`NCPU_AW-1:0]),
      .fb_dbus_AWMSK                    (fb_dbus_AWMSK[`NCPU_DW/8-1:0]),
      .fb_dbus_AEXC                     (fb_dbus_AEXC[1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_ibus_BVALID                   (fb_ibus_BVALID),
      .fb_ibus_BDATA                    (fb_ibus_BDATA[`NCPU_IW-1:0]),
      .fb_ibus_BEXC                     (fb_ibus_BEXC[1:0]),
      .fb_ibus_AREADY                   (fb_ibus_AREADY),
      .fb_dbus_BVALID                   (fb_dbus_BVALID),
      .fb_dbus_BDATA                    (fb_dbus_BDATA[`NCPU_DW-1:0]),
      .fb_dbus_BEXC                     (fb_dbus_BEXC[1:0]),
      .fb_dbus_AREADY                   (fb_dbus_AREADY),
      .fb_irqs                          (fb_irqs[`NCPU_NIRQ-1:0]));

   /************************************************************
    * Interrupt Requests
    ************************************************************/
   assign fb_irqs = {{`NCPU_NIRQ-3{1'b0}}, pb_uart_irq, 1'b0, 1'b0};


   /************************************************************
    * Clock and Reset
    ************************************************************/
   assign clk = CPU_CLK;

   // Reset system flip flops
   reg [1:0] rst_r;
   always @(posedge CPU_CLK or negedge RST_L) begin
      if(~RST_L) begin
         rst_r <= 0;
      end else begin
         rst_r <= {rst_r[0],1'b1};
      end
   end
   assign rst_n = rst_r[1];

   assign sdr_clk = SDR_CLK;

   // Reset SDR controller flip flops
   reg [1:0] sdr_rst_r;
   always @(posedge SDR_CLK or negedge RST_L) begin
      if(~RST_L) begin
         sdr_rst_r <= 0;
      end else begin
         sdr_rst_r <= {sdr_rst_r[0],1'b1};
      end
   end
   assign sdr_rst_n = sdr_rst_r[1];

   assign uart_clk = UART_CLK;

   // Reset UART. flip flops
   reg [1:0] uart_rst_r;
   always @(posedge UART_CLK or negedge RST_L) begin
      if(~RST_L) begin
         uart_rst_r <= 0;
      end else begin
         uart_rst_r <= {uart_rst_r[0],1'b1};
      end
   end
   assign uart_rst_n = uart_rst_r[1];

endmodule

//Local Variables:
//verilog-library-directories:(
// "."
// "../../rtl/ncpu32k"
// "../../rtl/pb_fb_DRAM_ctrl"
// "../../rtl/pb_fb_L2_cache"
// "../../rtl/pb_fb_arbiter"
// "../../rtl/pb_fb_router"
// "../../rtl/pb_fb_bootrom"
//)
//End:
