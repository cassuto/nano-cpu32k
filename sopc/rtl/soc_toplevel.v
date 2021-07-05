/**@file
 * SoC toplevel design
 */

/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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
   parameter CONFIG_SDR_DATA_BYTES_LOG2 = 1,
   // SDRAM timing parameters
   parameter CONFIG_SDR_tRP = 3,
   parameter CONFIG_SDR_tMRD = 2,
   parameter CONFIG_SDR_tRCD = 3,
   parameter CONFIG_SDR_tRFC = 9,
   parameter CONFIG_SDR_tREF = 64, // ms
   parameter CONFIG_SDR_pREF = 9, // = floor(log2(Fclk*tREF/(2^ROW_BW)))
   parameter CONFIG_SDR_nCAS_Latency = 3,

   // Bootrom parameters
   parameter CONFIG_BOOTM_AW = 12, // 4096 KiB
   parameter CONFIG_BOOTM_MEMH_FILE = "bootstrap.mem",
   parameter [`NCPU_AW-1:0] CONFIG_BOOTM_ERST = 'h02000000,

   // Core parameters
   parameter CONFIG_CORE_1_ICACHE_P_LINE = 6,
   parameter CONFIG_CORE_1_ICACHE_P_SETS = 6,
   parameter CONFIG_CORE_1_ICACHE_P_WAYS = 2,
   parameter CONFIG_CORE_1_ITLB_NSETS_LOG2 = 7,
   parameter CONFIG_CORE_1_IMMU_PAGE_SIZE_LOG2 = 13, // 8 KiB
   parameter CONFIG_CORE_1_GSHARE_PHT_NUM_LOG2 = 10,
   parameter CONFIG_CORE_1_BTB_NUM_LOG2 = 10,
   parameter CONFIG_CORE_1_ENABLE_MUL = 0,
   parameter CONFIG_CORE_1_ENABLE_DIV = 0,
   parameter CONFIG_CORE_1_ENABLE_DIVU = 0,
   parameter CONFIG_CORE_1_ENABLE_MOD = 0,
   parameter CONFIG_CORE_1_ENABLE_MODU = 0,
   parameter CONFIG_CORE_1_ENABLE_ASR = 1,
   parameter CONFIG_CORE_1_DMMU_PAGE_SIZE_LOG2 = 13, // 8 KiB
   parameter CONFIG_CORE_1_DTLB_NSETS_LOG2 = 7,
   parameter CONFIG_CORE_1_DCACHE_P_LINE = 6,
   parameter CONFIG_CORE_1_DCACHE_P_SETS = 6,
   parameter CONFIG_CORE_1_DCACHE_P_WAYS = 2
)
(
   input                            CPU_CLK,
   input                            SDR_CLK,
   input                            UART_CLK,
   input                            RST_L,

   // SDRAM Interface
   output                           DRAM_CKE,   // Synchronous Clock Enable
   output [CONFIG_SDR_ADDR_BITS - 1 : 0]  DRAM_ADDR,  // SDRAM Address
   output [CONFIG_SDR_BA_BITS - 1 : 0]    DRAM_BA,    // Bank Address
   inout  [CONFIG_SDR_DQ_BITS - 1 : 0]    DRAM_DATA,  // SDRAM I/O
   output [CONFIG_SDR_DM_BITS - 1 : 0]    DRAM_DQM,   // Data Mask
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

   localparam CONFIG_IBUS_DW = CONFIG_SDR_DATA_BITS;
   localparam CONFIG_IBUS_BYTES_LOG2 = CONFIG_SDR_DATA_BYTES_LOG2;
   localparam CONFIG_IBUS_AW = CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS + CONFIG_SDR_DATA_BYTES_LOG2 + 1;
   localparam CONFIG_DBUS_DW = CONFIG_IBUS_DW;
   localparam CONFIG_DBUS_BYTES_LOG2 = CONFIG_IBUS_BYTES_LOG2;
   localparam CONFIG_DBUS_AW = CONFIG_IBUS_AW;
   localparam CONFIG_DCACHE_P_LINE = CONFIG_CORE_1_DCACHE_P_LINE; // TODO: We have only one core.
   localparam CONFIG_ICACHE_P_LINE = CONFIG_CORE_1_ICACHE_P_LINE; // TODO: We have only one core.
   localparam NBUS = 3; // UART + SPI Master + NULL Device

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [3:0]           DRAM_CS_WE_RAS_CAS_L;   // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire [CONFIG_DBUS_AW-1:0] dbus_ARWADDR;      // From ncpu32k of ncpu32k.v
   wire                 dbus_ARWREADY;          // From UMA_SUBSYS of UMA_subsystem.v
   wire                 dbus_ARWVALID;          // From ncpu32k of ncpu32k.v
   wire                 dbus_AWE;               // From ncpu32k of ncpu32k.v
   wire                 dbus_BREADY;            // From ncpu32k of ncpu32k.v
   wire                 dbus_BVALID;            // From UMA_SUBSYS of UMA_subsystem.v
   wire [CONFIG_DBUS_DW-1:0] dbus_RDATA;        // From UMA_SUBSYS of UMA_subsystem.v
   wire                 dbus_RREADY;            // From ncpu32k of ncpu32k.v
   wire                 dbus_RVALID;            // From UMA_SUBSYS of UMA_subsystem.v
   wire [CONFIG_DBUS_DW-1:0] dbus_WDATA;        // From ncpu32k of ncpu32k.v
   wire                 dbus_WREADY;            // From UMA_SUBSYS of UMA_subsystem.v
   wire                 dbus_WVALID;            // From ncpu32k of ncpu32k.v
   wire [NBUS*`NCPU_AW-1:0] fb_bus_AADDR;       // From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW-1:0] fb_bus_ADATA;       // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_AVALID;          // From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW/8-1:0] fb_bus_AWMSK;     // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_BREADY;          // From fb_router of pb_fb_router.v
   wire [`NCPU_AW-1:0]  fb_mbus_AADDR;          // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW-1:0]  fb_mbus_ADATA;          // From ncpu32k of ncpu32k.v
   wire                 fb_mbus_AREADY;         // From fb_router of pb_fb_router.v
   wire                 fb_mbus_AVALID;         // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW/8-1:0] fb_mbus_AWMSK;         // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW-1:0]  fb_mbus_BDATA;          // From fb_router of pb_fb_router.v
   wire                 fb_mbus_BREADY;         // From ncpu32k of ncpu32k.v
   wire                 fb_mbus_BVALID;         // From fb_router of pb_fb_router.v
   wire [CONFIG_IBUS_AW-1:0] ibus_ARADDR;       // From ncpu32k of ncpu32k.v
   wire                 ibus_ARREADY;           // From UMA_SUBSYS of UMA_subsystem.v
   wire                 ibus_ARVALID;           // From ncpu32k of ncpu32k.v
   wire [CONFIG_IBUS_DW-1:0] ibus_RDATA;        // From UMA_SUBSYS of UMA_subsystem.v
   wire                 ibus_RREADY;            // From ncpu32k of ncpu32k.v
   wire                 ibus_RVALID;            // From UMA_SUBSYS of UMA_subsystem.v
   wire                 pb_null_AREADY;         // From pb_null of pb_fb_null.v
   wire [31:0]          pb_null_BDATA;          // From pb_null of pb_fb_null.v
   wire                 pb_null_BVALID;         // From pb_null of pb_fb_null.v
   wire                 pb_spi_AREADY;          // From pb_spi_master of soc_pb_spi_master.v
   wire                 pb_spi_BVALID;          // From pb_spi_master of soc_pb_spi_master.v
   wire                 pb_uart_AREADY;         // From pb_uart of soc_pb_uart.v
   wire                 pb_uart_BVALID;         // From pb_uart of soc_pb_uart.v
   wire                 pb_uart_irq;            // From pb_uart of soc_pb_uart.v
   wire [CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-1:0] sdr_cmd_addr;// From UMA_SUBSYS of UMA_subsystem.v
   wire                 sdr_cmd_bst_rd_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_rd_req;     // From UMA_SUBSYS of UMA_subsystem.v
   wire                 sdr_cmd_bst_we_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_we_req;     // From UMA_SUBSYS of UMA_subsystem.v
   wire [CONFIG_SDR_DATA_BITS-1:0] sdr_din;     // From UMA_SUBSYS of UMA_subsystem.v
   wire [CONFIG_SDR_DATA_BITS-1:0] sdr_dout;    // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_r_vld;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_w_rdy;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   // End of automatics
   /*AUTOINPUT*/
   wire                 rst_n;
   wire                 sdr_rst_n;
   wire                 uart_clk;
   wire                 uart_rst_n;
   wire [`NCPU_NIRQ-1:0] irqs;
   wire                 ibus_ASEL_BOOTROM;      // To DRAM_SUBSYS of DRAM_subsystem.v
   wire                 dbus_ASEL_BOOTROM;      // To UMA_SUBSYS of UMA_subsystem.v
   wire [NBUS-1:0]      fb_bus_sel;
   wire [NBUS-1:0]      fb_bus_BVALID;
   wire [NBUS*`NCPU_DW-1:0] fb_bus_BDATA;
   wire [NBUS-1:0]      fb_bus_AREADY;
   wire                       bootrom_en;
   wire [CONFIG_IBUS_AW-1:0]  bootrom_addr;
   wire [CONFIG_IBUS_DW-1:0]  bootrom_dout;
   wire                 pb_spi_AVALID;
   wire [`NCPU_AW-1:0]  pb_spi_AADDR;
   wire [3:0]           pb_spi_AWMSK;
   wire [31:0]          pb_spi_ADATA;
   wire [31:0]          pb_spi_BDATA;
   wire                 pb_spi_BREADY;
   wire                 pb_uart_AVALID;
   wire [`NCPU_AW-1:0]  pb_uart_AADDR;
   wire [3:0]           pb_uart_AWMSK;
   wire [31:0]          pb_uart_ADATA;
   wire [31:0]          pb_uart_BDATA;
   wire                 pb_uart_BREADY;
   wire [`NCPU_AW-1:0]  pb_null_AADDR;          // To pb_null of soc_pb_null.v
   wire [31:0]          pb_null_ADATA;          // To pb_null of soc_pb_null.v
   wire                 pb_null_AVALID;         // To pb_null of soc_pb_null.v
   wire [3:0]           pb_null_AWMSK;          // To pb_null of soc_pb_null.v
   wire                 pb_null_BREADY;         // To pb_null of soc_pb_null.v

   /************************************************************
    * Memory Subsystem
    ************************************************************/
   /* UMA_subsystem AUTO_TEMPLATE (
         .sdr_clk       (SDR_CLK),        // SDRAM clk domain
         .cpu_clk       (CPU_CLK),        // CPU clk domain
         .cpu_rst_n     (rst_n),
      );*/
   UMA_subsystem
      #(
         .CONFIG_SDR_ROW_BITS          (CONFIG_SDR_ROW_BITS),
         .CONFIG_SDR_BA_BITS           (CONFIG_SDR_BA_BITS),
         .CONFIG_SDR_COL_BITS          (CONFIG_SDR_COL_BITS),
         .CONFIG_SDR_DATA_BYTES_LOG2   (CONFIG_SDR_DATA_BYTES_LOG2),
         .CONFIG_SDR_DATA_BITS         (CONFIG_SDR_DATA_BITS),
         .CONFIG_ICACHE_P_LINE         (CONFIG_ICACHE_P_LINE),
         .CONFIG_IBUS_AW               (CONFIG_IBUS_AW),
         .CONFIG_IBUS_DW               (CONFIG_IBUS_DW),
         .CONFIG_DBUS_AW               (CONFIG_DBUS_AW),
         .CONFIG_DBUS_DW               (CONFIG_DBUS_DW),
         .CONFIG_DCACHE_P_LINE         (CONFIG_CORE_1_DCACHE_P_LINE)
      )
   UMA_SUBSYS
      (/*AUTOINST*/
       // Outputs
       .ibus_ARREADY                    (ibus_ARREADY),
       .ibus_RVALID                     (ibus_RVALID),
       .ibus_RDATA                      (ibus_RDATA[CONFIG_IBUS_DW-1:0]),
       .dbus_ARWREADY                   (dbus_ARWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[CONFIG_DBUS_DW-1:0]),
       .sdr_cmd_bst_we_req              (sdr_cmd_bst_we_req),
       .sdr_cmd_bst_rd_req              (sdr_cmd_bst_rd_req),
       .sdr_cmd_addr                    (sdr_cmd_addr[CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-1:0]),
       .sdr_din                         (sdr_din[CONFIG_SDR_DATA_BITS-1:0]),
       .bootrom_en                      (bootrom_en),
       .bootrom_addr                    (bootrom_addr[CONFIG_IBUS_AW-1:0]),
       // Inputs
       .sdr_clk                         (SDR_CLK),               // Templated
       .sdr_rst_n                       (sdr_rst_n),
       .cpu_clk                         (CPU_CLK),               // Templated
       .cpu_rst_n                       (rst_n),                 // Templated
       .ibus_ARVALID                    (ibus_ARVALID),
       .ibus_ARADDR                     (ibus_ARADDR[CONFIG_IBUS_AW-1:0]),
       .ibus_ASEL_BOOTROM               (ibus_ASEL_BOOTROM),
       .ibus_RREADY                     (ibus_RREADY),
       .dbus_ARWVALID                   (dbus_ARWVALID),
       .dbus_ARWADDR                    (dbus_ARWADDR[CONFIG_DBUS_AW-1:0]),
       .dbus_ASEL_BOOTROM               (dbus_ASEL_BOOTROM),
       .dbus_AWE                        (dbus_AWE),
       .dbus_WVALID                     (dbus_WVALID),
       .dbus_WDATA                      (dbus_WDATA[CONFIG_DBUS_DW-1:0]),
       .dbus_BREADY                     (dbus_BREADY),
       .dbus_RREADY                     (dbus_RREADY),
       .sdr_cmd_bst_we_ack              (sdr_cmd_bst_we_ack),
       .sdr_cmd_bst_rd_ack              (sdr_cmd_bst_rd_ack),
       .sdr_dout                        (sdr_dout[CONFIG_SDR_DATA_BITS-1:0]),
       .sdr_r_vld                       (sdr_r_vld),
       .sdr_w_rdy                       (sdr_w_rdy),
       .bootrom_dout                    (bootrom_dout[CONFIG_IBUS_DW-1:0]));

   /************************************************************
    * Bootrom
    ************************************************************/
   pb_fb_bootrom
      #(
         .CONFIG_IBUS_DW               (CONFIG_IBUS_DW),
         .CONFIG_IBUS_BYTES_LOG2       (CONFIG_IBUS_BYTES_LOG2),
         .CONFIG_IBUS_AW               (CONFIG_IBUS_AW),
         .CONFIG_BOOTROM_AW            (CONFIG_BOOTM_AW),
         .CONFIG_BOOTROM_MEMH_FILE     (CONFIG_BOOTM_MEMH_FILE)
      )
   BOOTROM
      (
         .clk                          (CPU_CLK),
         .en                           (bootrom_en),
         .addr                         (bootrom_addr),
         .dout                         (bootrom_dout)
      );

   /************************************************************
    * SDRAM Controller
    ************************************************************/
   /* pb_fb_DRAM_ctrl AUTO_TEMPLATE (
         .sdr_clk       (SDR_CLK),        // SDRAM clk domain
         .rst_n         (sdr_rst_n),
      );*/
   pb_fb_DRAM_ctrl
     #(
       .CONFIG_SDR_COL_BITS            (CONFIG_SDR_COL_BITS),
       .CONFIG_SDR_ROW_BITS            (CONFIG_SDR_ROW_BITS),
       .CONFIG_SDR_BA_BITS             (CONFIG_SDR_BA_BITS),
       .CONFIG_SDR_DATA_BITS           (CONFIG_SDR_DATA_BITS),
       .CONFIG_SDR_ADDR_BITS           (CONFIG_SDR_ADDR_BITS),
       .tRP                            (CONFIG_SDR_tRP),
       .tMRD                           (CONFIG_SDR_tMRD),
       .tRCD                           (CONFIG_SDR_tRCD),
       .tRFC                           (CONFIG_SDR_tRFC),
       .tREF                           (CONFIG_SDR_tREF),
       .pREF                           (CONFIG_SDR_pREF),
       .nCAS_Latency                   (CONFIG_SDR_nCAS_Latency)
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
      .sdr_clk                          (SDR_CLK),               // Templated
      .sdr_rst_n                        (sdr_rst_n),
      .sdr_cmd_bst_we_req               (sdr_cmd_bst_we_req),
      .sdr_cmd_bst_rd_req               (sdr_cmd_bst_rd_req),
      .sdr_cmd_addr                     (sdr_cmd_addr[CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-1:0]),
      .sdr_din                          (sdr_din[CONFIG_SDR_DATA_BITS-1:0]));

   assign
      {
         DRAM_CS_L,
         DRAM_WE_L,
         DRAM_RAS_L,
         DRAM_CAS_L
      } = DRAM_CS_WE_RAS_CAS_L;

   /************************************************************
    * Frontend bus Router
    ************************************************************/
   /* pb_fb_router AUTO_TEMPLATE (
         .clk           (CPU_CLK),        // CPU clk domain
      );*/
   pb_fb_router
     #(
      .NBUS(NBUS)
     )
   fb_router
     (/*AUTOINST*/
      // Outputs
      .fb_mbus_BVALID                   (fb_mbus_BVALID),
      .fb_mbus_BDATA                    (fb_mbus_BDATA[`NCPU_DW-1:0]),
      .fb_mbus_AREADY                   (fb_mbus_AREADY),
      .fb_bus_BREADY                    (fb_bus_BREADY[NBUS-1:0]),
      .fb_bus_ADATA                     (fb_bus_ADATA[NBUS*`NCPU_DW-1:0]),
      .fb_bus_AVALID                    (fb_bus_AVALID[NBUS-1:0]),
      .fb_bus_AADDR                     (fb_bus_AADDR[NBUS*`NCPU_AW-1:0]),
      .fb_bus_AWMSK                     (fb_bus_AWMSK[NBUS*`NCPU_DW/8-1:0]),
      // Inputs
      .clk                              (CPU_CLK),               // Templated
      .rst_n                            (rst_n),
      .fb_mbus_BREADY                   (fb_mbus_BREADY),
      .fb_mbus_ADATA                    (fb_mbus_ADATA[`NCPU_DW-1:0]),
      .fb_mbus_AVALID                   (fb_mbus_AVALID),
      .fb_mbus_AADDR                    (fb_mbus_AADDR[`NCPU_AW-1:0]),
      .fb_mbus_AWMSK                    (fb_mbus_AWMSK[`NCPU_DW/8-1:0]),
      .fb_bus_sel                       (fb_bus_sel[NBUS-1:0]),
      .fb_bus_BVALID                    (fb_bus_BVALID[NBUS-1:0]),
      .fb_bus_BDATA                     (fb_bus_BDATA[NBUS*`NCPU_DW-1:0]),
      .fb_bus_AREADY                    (fb_bus_AREADY[NBUS-1:0]));

   wire pb_sel_spi, pb_sel_uart;

   // Bus address mapping
   //             (Type Start       End   )
   // BootROM     (I/D 0x02000000~)
   assign ibus_ASEL_BOOTROM = ibus_ARADDR[CONFIG_IBUS_AW-1];
   assign dbus_ASEL_BOOTROM = dbus_ARWADDR[CONFIG_DBUS_AW-1];
   // SPI Master  (D 0x80000000~0x80FFFFFF)
   assign pb_sel_spi = fb_mbus_AADDR[`NCPU_AW-1 -:8]==8'h80;
   // UART        (D 0x81000000~0x81FFFFFF)
   assign pb_sel_uart = fb_mbus_AADDR[`NCPU_AW-1 -:8]==8'h81;
   // NULL        (D Others)
   assign fb_bus_sel[0] = ~(pb_sel_spi | pb_sel_uart);
   assign fb_bus_sel[1] = pb_sel_spi;
   assign fb_bus_sel[2] = pb_sel_uart;

   assign
      {
         pb_uart_BREADY,
         pb_spi_BREADY,
         pb_null_BREADY
      } = fb_bus_BREADY;

   assign
      {
         pb_uart_ADATA[`NCPU_DW-1:0],
         pb_spi_ADATA[`NCPU_DW-1:0],
         pb_null_ADATA[`NCPU_DW-1:0]
      } = fb_bus_ADATA;

   assign
      {
         pb_uart_AVALID,
         pb_spi_AVALID,
         pb_null_AVALID
      } = fb_bus_AVALID;

   assign
      {
         pb_uart_AADDR[`NCPU_AW-1:0],
         pb_spi_AADDR[`NCPU_AW-1:0],
         pb_null_AADDR[`NCPU_AW-1:0]
      } = fb_bus_AADDR;

   assign
      {
         pb_uart_AWMSK[`NCPU_DW/8-1:0],
         pb_spi_AWMSK[`NCPU_DW/8-1:0],
         pb_null_AWMSK[`NCPU_DW/8-1:0]
      } = fb_bus_AWMSK;

   assign fb_bus_BVALID =
      {
         pb_uart_BVALID,
         pb_spi_BVALID,
         pb_null_BVALID
      };

   assign fb_bus_BDATA =
      {
         pb_uart_BDATA[`NCPU_DW-1:0],
         pb_spi_BDATA[`NCPU_DW-1:0],
         pb_null_BDATA[`NCPU_DW-1:0]
      };

   assign fb_bus_AREADY =
      {
         pb_uart_AREADY,
         pb_spi_AREADY,
         pb_null_AREADY
      };

   /************************************************************
    * SPI Master Controller
    ************************************************************/
   /* soc_pb_spi_master AUTO_TEMPLATE (
         .clk           (CPU_CLK),        // CPU clk domain
      );*/
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
      .clk                              (CPU_CLK),               // Templated
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
         .clk            (CPU_CLK),         // CPU clk domain
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
       .clk                             (CPU_CLK),               // Templated
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
    * NULL Device
    ************************************************************/
   /* pb_fb_null AUTO_TEMPLATE (
         .clk           (CPU_CLK),        // CPU clk domain
      );*/
   pb_fb_null pb_null
      (/*AUTOINST*/
       // Outputs
       .pb_null_AREADY                  (pb_null_AREADY),
       .pb_null_BDATA                   (pb_null_BDATA[31:0]),
       .pb_null_BVALID                  (pb_null_BVALID),
       // Inputs
       .clk                             (CPU_CLK),               // Templated
       .rst_n                           (rst_n),
       .pb_null_AVALID                  (pb_null_AVALID),
       .pb_null_AADDR                   (pb_null_AADDR[`NCPU_AW-1:0]),
       .pb_null_AWMSK                   (pb_null_AWMSK[3:0]),
       .pb_null_ADATA                   (pb_null_ADATA[31:0]),
       .pb_null_BREADY                  (pb_null_BREADY));

   /************************************************************
    * CPU Core #1
    ************************************************************/
   /* ncpu32k AUTO_TEMPLATE (
         .clk                          (CPU_CLK), // CPU clk domain
         .uncached_dbus_AVALID         (fb_mbus_AVALID),
         .uncached_dbus_AREADY         (fb_mbus_AREADY),
         .uncached_dbus_AADDR          (fb_mbus_AADDR[`NCPU_AW-1:0]),
         .uncached_dbus_AWMSK          (fb_mbus_AWMSK[`NCPU_DW/8-1:0]),
         .uncached_dbus_ADATA          (fb_mbus_ADATA[`NCPU_DW-1:0]),
         .uncached_dbus_BREADY         (fb_mbus_BREADY),
         .uncached_dbus_BVALID         (fb_mbus_BVALID),
         .uncached_dbus_BDATA          (fb_mbus_BDATA[`NCPU_DW-1:0]),
      );*/
   ncpu32k
     #(
      .CONFIG_IBUS_DW                  (CONFIG_IBUS_DW),
      .CONFIG_IBUS_BYTES_LOG2          (CONFIG_IBUS_BYTES_LOG2),
      .CONFIG_IBUS_AW                  (CONFIG_IBUS_AW),
      .CONFIG_ICACHE_P_LINE            (CONFIG_CORE_1_ICACHE_P_LINE),
      .CONFIG_ICACHE_P_SETS            (CONFIG_CORE_1_ICACHE_P_SETS),
      .CONFIG_ICACHE_P_WAYS            (CONFIG_CORE_1_ICACHE_P_WAYS),
      .CONFIG_ITLB_NSETS_LOG2          (CONFIG_CORE_1_ITLB_NSETS_LOG2),
      .CONFIG_IMMU_PAGE_SIZE_LOG2      (CONFIG_CORE_1_IMMU_PAGE_SIZE_LOG2),
      .CONFIG_GSHARE_PHT_NUM_LOG2      (CONFIG_CORE_1_GSHARE_PHT_NUM_LOG2),
      .CONFIG_BTB_NUM_LOG2             (CONFIG_CORE_1_BTB_NUM_LOG2),
      .CONFIG_ENABLE_MUL               (CONFIG_CORE_1_ENABLE_MUL),
      .CONFIG_ENABLE_DIV               (CONFIG_CORE_1_ENABLE_DIV),
      .CONFIG_ENABLE_DIVU              (CONFIG_CORE_1_ENABLE_DIVU),
      .CONFIG_ENABLE_MOD               (CONFIG_CORE_1_ENABLE_MOD),
      .CONFIG_ENABLE_MODU              (CONFIG_CORE_1_ENABLE_MODU),
      .CONFIG_ENABLE_ASR               (CONFIG_CORE_1_ENABLE_ASR),
      .CONFIG_DBUS_DW                  (CONFIG_DBUS_DW),
      .CONFIG_DBUS_BYTES_LOG2          (CONFIG_DBUS_BYTES_LOG2),
      .CONFIG_DBUS_AW                  (CONFIG_DBUS_AW),
      .CONFIG_DMMU_PAGE_SIZE_LOG2      (CONFIG_CORE_1_DMMU_PAGE_SIZE_LOG2),
      .CONFIG_DMMU_ENABLE_UNCACHED_SEG (1), // Needed for MMIO peripherals
      .CONFIG_DTLB_NSETS_LOG2          (CONFIG_CORE_1_DTLB_NSETS_LOG2),
      .CONFIG_DCACHE_P_LINE            (CONFIG_CORE_1_DCACHE_P_LINE),
      .CONFIG_DCACHE_P_SETS            (CONFIG_CORE_1_DCACHE_P_SETS),
      .CONFIG_DCACHE_P_WAYS            (CONFIG_CORE_1_DCACHE_P_WAYS),
      .CONFIG_ERST_VECTOR              (CONFIG_BOOTM_ERST)
     )
   ncpu32k
     (/*AUTOINST*/
      // Outputs
      .ibus_ARVALID                     (ibus_ARVALID),
      .ibus_ARADDR                      (ibus_ARADDR[CONFIG_IBUS_AW-1:0]),
      .ibus_RREADY                      (ibus_RREADY),
      .dbus_ARWVALID                    (dbus_ARWVALID),
      .dbus_ARWADDR                     (dbus_ARWADDR[CONFIG_DBUS_AW-1:0]),
      .dbus_AWE                         (dbus_AWE),
      .dbus_WVALID                      (dbus_WVALID),
      .dbus_WDATA                       (dbus_WDATA[CONFIG_DBUS_DW-1:0]),
      .dbus_BREADY                      (dbus_BREADY),
      .dbus_RREADY                      (dbus_RREADY),
      .uncached_dbus_AVALID             (fb_mbus_AVALID),        // Templated
      .uncached_dbus_AADDR              (fb_mbus_AADDR[`NCPU_AW-1:0]), // Templated
      .uncached_dbus_AWMSK              (fb_mbus_AWMSK[`NCPU_DW/8-1:0]), // Templated
      .uncached_dbus_ADATA              (fb_mbus_ADATA[`NCPU_DW-1:0]), // Templated
      .uncached_dbus_BREADY             (fb_mbus_BREADY),        // Templated
      // Inputs
      .clk                              (CPU_CLK),               // Templated
      .rst_n                            (rst_n),
      .ibus_ARREADY                     (ibus_ARREADY),
      .ibus_RVALID                      (ibus_RVALID),
      .ibus_RDATA                       (ibus_RDATA[CONFIG_IBUS_DW-1:0]),
      .dbus_ARWREADY                    (dbus_ARWREADY),
      .dbus_WREADY                      (dbus_WREADY),
      .dbus_BVALID                      (dbus_BVALID),
      .dbus_RVALID                      (dbus_RVALID),
      .dbus_RDATA                       (dbus_RDATA[CONFIG_DBUS_DW-1:0]),
      .uncached_dbus_AREADY             (fb_mbus_AREADY),        // Templated
      .uncached_dbus_BVALID             (fb_mbus_BVALID),        // Templated
      .uncached_dbus_BDATA              (fb_mbus_BDATA[`NCPU_DW-1:0]), // Templated
      .irqs                             (irqs[`NCPU_NIRQ-1:0]));

   /************************************************************
    * Interrupt Requests
    ************************************************************/
   assign irqs = {{`NCPU_NIRQ-3{1'b0}}, pb_uart_irq, 1'b0, 1'b0};

   /************************************************************
    * Clock and Reset
    ************************************************************/

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
// "../../rtl/core"
// "../../rtl/pb"
//)
//End:
