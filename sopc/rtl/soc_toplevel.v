/**@file
 * Simple SPI master controller without FIFO queue
 * Not timing strict
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
   parameter SDR_tRC = 9,
   parameter SDR_tREF = 64, // ms
   parameter SDR_pREF = 9, // = floor(log2(Fclk*tREF/(2^ROW_BW)))
   parameter SDR_nCAS_Latency = 3,
   
   // Bootrom parameters
   parameter BOOTM_SIZE_BYTES = 512,
   parameter BOOTM_MEMH_FILE = ""
)
(
   input                            CPU_CLK,
   input                            SDR_CLK,
   input                            RST_L,
   
   // SDRAM Interface
   output                           DRAM_CKE,   // Synchronous Clock Enable
   output [SDR_ADDR_BITS - 1 : 0]   DRAM_ADDR,  // SDRAM Address
   output   [SDR_BA_BITS - 1 : 0]   DRAM_BA,    // Bank Address
   inout    [SDR_DQ_BITS - 1 : 0]   DRAM_DATA,  // SDRAM I/O
   output   [SDR_DM_BITS - 1 : 0]   DRAM_DQM,   // Data Mask
   output                           DRAM_CAS_L,
   output                           DRAM_RAS_L,
   output                           DRAM_WE_L,
   output                           DRAM_CS_L,
   
   // SPI Master Interface
   output                           SPI_SCK,
   output                           SPI_CS_L,
   output                           SPI_MOSI,
   input                            SPI_MISO
);

   // Internal parameters. Not edit
   localparam DW = `NCPU_DW;
   localparam AW = `NCPU_AW;
   localparam N_BW = 1;
   localparam L2_CH_DW = `NCPU_DW;
   localparam L2_CH_AW = SDR_ROW_BITS+SDR_BA_BITS+SDR_COL_BITS-N_BW+2;
   localparam NBUS = 4;
   localparam CPU_RSET_VECTOR = 32'h80000000; // Start from bootrom

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [3:0]           DRAM_CS_WE_RAS_CAS_L;   // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire [NBUS*`NCPU_AW-1:0] fb_bus_cmd_addr;    // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_cmd_valid;       // From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW/8-1:0] fb_bus_cmd_we_msk;// From fb_router of pb_fb_router.v
   wire [NBUS*`NCPU_DW-1:0] fb_bus_din;         // From fb_router of pb_fb_router.v
   wire [NBUS-1:0]      fb_bus_ready;           // From fb_router of pb_fb_router.v
   wire [`NCPU_AW-1:0]  fb_dbus_cmd_addr;       // From ncpu32k of ncpu32k.v
   wire                 fb_dbus_cmd_ready;      // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_dbus_cmd_valid;      // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW/8-1:0] fb_dbus_cmd_we_msk;    // From ncpu32k of ncpu32k.v
   wire [`NCPU_DW-1:0]  fb_dbus_din;            // From ncpu32k of ncpu32k.v
   wire [`NCPU_IW-1:0]  fb_dbus_dout;           // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_dbus_ready;          // From ncpu32k of ncpu32k.v
   wire                 fb_dbus_valid;          // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_AW-1:0]  fb_ibus_cmd_addr;       // From ncpu32k of ncpu32k.v
   wire                 fb_ibus_cmd_ready;      // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_ibus_cmd_valid;      // From ncpu32k of ncpu32k.v
   wire [`NCPU_IW-1:0]  fb_ibus_dout;           // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_ibus_ready;          // From ncpu32k of ncpu32k.v
   wire                 fb_ibus_valid;          // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_AW-1:0]  fb_mbus_cmd_addr;       // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_mbus_cmd_ready;      // From fb_router of pb_fb_router.v
   wire                 fb_mbus_cmd_valid;      // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW/8-1:0] fb_mbus_cmd_we_msk;    // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW-1:0]  fb_mbus_din;            // From fb_arbi of pb_fb_arbiter.v
   wire [`NCPU_DW-1:0]  fb_mbus_dout;           // From fb_router of pb_fb_router.v
   wire                 fb_mbus_ready;          // From fb_arbi of pb_fb_arbiter.v
   wire                 fb_mbus_valid;          // From fb_router of pb_fb_router.v
   wire                 l2_ch_cmd_ready;        // From L2_cache of pb_fb_L2_cache.v
   wire [L2_CH_DW-1:0]  l2_ch_dout;             // From L2_cache of pb_fb_L2_cache.v
   wire                 l2_ch_valid;            // From L2_cache of pb_fb_L2_cache.v
   wire                 pb_spi_cmd_ready;       // From pb_spi_master of soc_pb_spi_master.v
   wire                 pb_spi_valid;           // From pb_spi_master of soc_pb_spi_master.v
   wire [L2_CH_AW-3:0]  sdr_cmd_addr;           // From L2_cache of pb_fb_L2_cache.v
   wire                 sdr_cmd_bst_rd_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_rd_req;     // From L2_cache of pb_fb_L2_cache.v
   wire                 sdr_cmd_bst_we_ack;     // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_cmd_bst_we_req;     // From L2_cache of pb_fb_L2_cache.v
   wire [L2_CH_DW/2-1:0] sdr_din;               // From L2_cache of pb_fb_L2_cache.v
   wire [SDR_DATA_BITS-1:0] sdr_dout;           // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_r_vld;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   wire                 sdr_w_rdy;              // From fb_DRAM_ctrl of pb_fb_DRAM_ctrl.v
   // End of automatics
   wire                 clk;
   wire                 rst_n;
   wire                 sdr_clk;
   wire                 sdr_rst_n;
   wire [`NCPU_NIRQ-1:0] fb_irqs;
   wire [NBUS-1:0]      fb_bus_sel;
   wire [NBUS-1:0]      fb_bus_valid;
   wire [NBUS*`NCPU_DW-1:0] fb_bus_dout;
   wire [NBUS-1:0]      fb_bus_cmd_ready;
   wire [`NCPU_AW-1:0]  l2_ch_cmd_addr;
   wire [`NCPU_DW/8-1:0] l2_ch_cmd_we_msk;
   wire [`NCPU_DW-1:0]  l2_ch_din;
   wire                 pb_bootm_cmd_ready;
   wire                 pb_bootm_cmd_valid;
   wire [`NCPU_AW-1:0]  pb_bootm_cmd_addr;
   wire [`NCPU_DW/8-1:0] pb_bootm_cmd_we_msk;
   wire                 pb_bootm_ready;
   wire                 pb_bootm_valid;
   wire [`NCPU_DW-1:0]  pb_bootm_dout;
   wire [`NCPU_DW-1:0]  pb_bootm_din;
   wire                 pb_spi_cmd_valid;
   wire [`NCPU_AW-1:0]  pb_spi_cmd_addr;
   wire [4:0]           pb_spi_cmd_we_msk;
   wire [31:0]          pb_spi_din;
   wire [31:0]          pb_spi_dout;
   wire                 pb_spi_ready;
   wire                 pb_uart_cmd_valid;
   wire [`NCPU_AW-1:0]  pb_uart_cmd_addr;
   wire [4:0]           pb_uart_cmd_we_msk;
   wire [31:0]          pb_uart_din;
   wire [31:0]          pb_uart_dout;
   wire                 pb_uart_ready;
   
   /************************************************************
    * SDRAM Controller
    ************************************************************/
   /* pb_fb_DRAM_ctrl AUTO_TEMPLATE (
         .clk           (sdr_clk),        // SDRAM clk domain
         .rst_n         (sdr_rst_n),
      );*/
   pb_fb_DRAM_ctrl
     #(
       .SDR_COL_BITS    (SDR_COL_BITS),
       .SDR_ROW_BITS    (SDR_ROW_BITS),
       .SDR_BA_BITS     (SDR_BA_BITS),
       .SDR_DATA_BITS   (SDR_DATA_BITS),
       .SDR_ADDR_BITS   (SDR_ADDR_BITS),
       .N_BW            (N_BW),
       .tRP             (SDR_tRP),
       .tMRD            (SDR_tMRD),
       .tRCD            (SDR_tRCD),
       .tRC             (SDR_tRC),
       .tREF            (SDR_tREF),
       .pREF            (SDR_pREF),
       .nCAS_Latency    (SDR_nCAS_Latency)
      )
   fb_DRAM_ctrl
     (/*AUTOINST*/
      // Outputs
      .DRAM_CKE                         (DRAM_CKE),
      .DRAM_CS_WE_RAS_CAS_L             (DRAM_CS_WE_RAS_CAS_L[3:0]),
      .DRAM_BA                          (DRAM_BA[SDR_BA_BITS-1:0]),
      .DRAM_ADDR                        (DRAM_ADDR[SDR_ADDR_BITS-1:0]),
      .DRAM_DQM                         (DRAM_DQM[1:0]),
      .sdr_cmd_bst_we_ack               (sdr_cmd_bst_we_ack),
      .sdr_cmd_bst_rd_ack               (sdr_cmd_bst_rd_ack),
      .sdr_dout                         (sdr_dout[SDR_DATA_BITS-1:0]),
      .sdr_r_vld                        (sdr_r_vld),
      .sdr_w_rdy                        (sdr_w_rdy),
      // Inouts
      .DRAM_DATA                        (DRAM_DATA[SDR_DATA_BITS-1:0]),
      // Inputs
      .clk                              (SDR_CLK),               // Templated
      .rst_n                            (sdr_rst_n),             // Templated
      .sdr_cmd_bst_we_req               (sdr_cmd_bst_we_req),
      .sdr_cmd_bst_rd_req               (sdr_cmd_bst_rd_req),
      .sdr_cmd_addr                     (sdr_cmd_addr[SDR_ROW_BITS+SDR_BA_BITS+SDR_COL_BITS-N_BW-1:0]),
      .sdr_din                          (sdr_din[SDR_DATA_BITS-1:0]));
   
   /************************************************************
    * L2 Cache
    ************************************************************/
   pb_fb_L2_cache
     #(
       .ENABLE_BYPASS(0)
     )
   L2_cache
     (/*AUTOINST*/
      // Outputs
      .l2_ch_valid                      (l2_ch_valid),
      .l2_ch_cmd_ready                  (l2_ch_cmd_ready),
      .l2_ch_dout                       (l2_ch_dout[L2_CH_DW-1:0]),
      .sdr_din                          (sdr_din[L2_CH_DW/2-1:0]),
      .sdr_cmd_bst_rd_req               (sdr_cmd_bst_rd_req),
      .sdr_cmd_bst_we_req               (sdr_cmd_bst_we_req),
      .sdr_cmd_addr                     (sdr_cmd_addr[L2_CH_AW-3:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .l2_ch_ready                      (l2_ch_ready),
      .l2_ch_cmd_valid                  (l2_ch_cmd_valid),
      .l2_ch_cmd_addr                   (l2_ch_cmd_addr[L2_CH_AW-1:0]),
      .l2_ch_cmd_we_msk                 (l2_ch_cmd_we_msk[L2_CH_DW/8-1:0]),
      .l2_ch_din                        (l2_ch_din[L2_CH_DW-1:0]),
      .l2_ch_flush                      (l2_ch_flush),
      .sdr_clk                          (sdr_clk),
      .sdr_dout                         (sdr_dout[L2_CH_DW/2-1:0]),
      .sdr_r_vld                        (sdr_r_vld),
      .sdr_w_rdy                        (sdr_w_rdy));
   
   /************************************************************
    * Frontend bus arbiter
    ************************************************************/
   pb_fb_arbiter fb_arbi
     (/*AUTOINST*/
      // Outputs
      .fb_ibus_valid                    (fb_ibus_valid),
      .fb_ibus_dout                     (fb_ibus_dout[`NCPU_IW-1:0]),
      .fb_ibus_cmd_ready                (fb_ibus_cmd_ready),
      .fb_dbus_valid                    (fb_dbus_valid),
      .fb_dbus_dout                     (fb_dbus_dout[`NCPU_IW-1:0]),
      .fb_dbus_cmd_ready                (fb_dbus_cmd_ready),
      .fb_mbus_ready                    (fb_mbus_ready),
      .fb_mbus_din                      (fb_mbus_din[`NCPU_DW-1:0]),
      .fb_mbus_cmd_valid                (fb_mbus_cmd_valid),
      .fb_mbus_cmd_addr                 (fb_mbus_cmd_addr[`NCPU_AW-1:0]),
      .fb_mbus_cmd_we_msk               (fb_mbus_cmd_we_msk[`NCPU_DW/8-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_ibus_ready                    (fb_ibus_ready),
      .fb_ibus_cmd_valid                (fb_ibus_cmd_valid),
      .fb_ibus_cmd_addr                 (fb_ibus_cmd_addr[`NCPU_AW-1:0]),
      .fb_dbus_ready                    (fb_dbus_ready),
      .fb_dbus_din                      (fb_dbus_din[`NCPU_DW-1:0]),
      .fb_dbus_cmd_valid                (fb_dbus_cmd_valid),
      .fb_dbus_cmd_addr                 (fb_dbus_cmd_addr[`NCPU_AW-1:0]),
      .fb_dbus_cmd_we_msk               (fb_dbus_cmd_we_msk[`NCPU_DW/8-1:0]),
      .fb_mbus_valid                    (fb_mbus_valid),
      .fb_mbus_dout                     (fb_mbus_dout[`NCPU_IW-1:0]),
      .fb_mbus_cmd_ready                (fb_mbus_cmd_ready));
   
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
      .fb_mbus_valid                    (fb_mbus_valid),
      .fb_mbus_dout                     (fb_mbus_dout[`NCPU_DW-1:0]),
      .fb_mbus_cmd_ready                (fb_mbus_cmd_ready),
      .fb_bus_ready                     (fb_bus_ready[NBUS-1:0]),
      .fb_bus_din                       (fb_bus_din[NBUS*`NCPU_DW-1:0]),
      .fb_bus_cmd_valid                 (fb_bus_cmd_valid[NBUS-1:0]),
      .fb_bus_cmd_addr                  (fb_bus_cmd_addr[NBUS*`NCPU_AW-1:0]),
      .fb_bus_cmd_we_msk                (fb_bus_cmd_we_msk[NBUS*`NCPU_DW/8-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_mbus_ready                    (fb_mbus_ready),
      .fb_mbus_din                      (fb_mbus_din[`NCPU_DW-1:0]),
      .fb_mbus_cmd_valid                (fb_mbus_cmd_valid),
      .fb_mbus_cmd_addr                 (fb_mbus_cmd_addr[`NCPU_AW-1:0]),
      .fb_mbus_cmd_we_msk               (fb_mbus_cmd_we_msk[`NCPU_DW/8-1:0]),
      .fb_bus_sel                       (fb_bus_sel[NBUS-1:0]),
      .fb_bus_valid                     (fb_bus_valid[NBUS-1:0]),
      .fb_bus_dout                      (fb_bus_dout[NBUS*`NCPU_DW-1:0]),
      .fb_bus_cmd_ready                 (fb_bus_cmd_ready[NBUS-1:0]));
   
   // Bus address mapping
   wire bank_sys_mem = ~fb_mbus_cmd_addr[`NCPU_AW-1];
   wire bank_mmio = ~bank_sys_mem;
   // System memory
   assign fb_bus_sel[0] = bank_sys_mem;
   // Bootrom
   assign fb_bus_sel[1] = bank_mmio & fb_mbus_cmd_addr[`NCPU_AW-1:24]==8'h1;
   // SPI Master
   assign fb_bus_sel[2] = bank_mmio & fb_mbus_cmd_addr[`NCPU_AW-1:24]==8'h2;
   // UART
   assign fb_bus_sel[3] = bank_mmio & fb_mbus_cmd_addr[`NCPU_AW-1:24]==8'h3;
   
   assign
      {
         pb_uart_ready,
         pb_spi_ready,
         pb_bootm_ready,
         l2_ch_ready
      } = fb_bus_ready;
   
   assign
      {
         pb_uart_din[`NCPU_DW-1:0],
         pb_spi_din[`NCPU_DW-1:0],
         pb_bootm_din[`NCPU_DW-1:0],
         l2_ch_din[`NCPU_DW-1:0]
      } = fb_bus_din;
   
   assign
      {
         pb_uart_cmd_valid,
         pb_spi_cmd_valid,
         pb_bootm_cmd_valid,
         l2_ch_cmd_valid
      } = fb_bus_cmd_valid;
   
   assign
      {
         pb_uart_cmd_addr[`NCPU_AW-1:0],
         pb_spi_cmd_addr[`NCPU_AW-1:0],
         pb_bootm_cmd_addr[`NCPU_AW-1:0],
         l2_ch_cmd_addr[`NCPU_AW-1:0]
      } = fb_bus_cmd_addr;
     
   assign
      {
         pb_uart_cmd_we_msk[`NCPU_DW/8-1:0],
         pb_spi_cmd_we_msk[`NCPU_DW/8-1:0],
         pb_bootm_cmd_we_msk[`NCPU_DW/8-1:0],
         l2_ch_cmd_we_msk[`NCPU_DW/8-1:0]
      } = fb_bus_cmd_we_msk;
      
   assign fb_bus_valid =
      {
         1'b0, //pb_uart_valid
         pb_spi_valid,
         pb_bootm_valid,
         l2_ch_valid
      };
   
   assign fb_bus_dout =
      {
         32'b0, //pb_uart_dout
         pb_spi_dout[`NCPU_DW-1:0],
         pb_bootm_dout[`NCPU_DW-1:0],
         l2_ch_dout[`NCPU_DW-1:0]
      };
      
   assign fb_bus_cmd_ready =
      {
         1'b0, // uart_cmd_ready
         pb_spi_cmd_ready,
         pb_bootm_cmd_ready,
         l2_ch_cmd_ready
      };
   
   /************************************************************
    * Bootrom
    ************************************************************/
   pb_fb_bootrom
      #(
         .SIZE_BYTES    (BOOTM_SIZE_BYTES),
         .MEMH_FILE     (BOOTM_MEMH_FILE),
         .ENABLE_BYPASS (0)
      )
   fb_bootrom
      (
         .clk                          (clk),
         .rst_n                        (rst_n),
         .cmd_ready                    (pb_bootm_cmd_ready),
         .cmd_valid                    (pb_bootm_cmd_valid),
         .cmd_addr                     (pb_bootm_cmd_addr[`NCPU_AW-1:0]),
         .cmd_we_msk                   (pb_bootm_cmd_we_msk[`NCPU_DW/8-1:0]),
         .ready                        (pb_bootm_ready),
         .valid                        (pb_bootm_valid),
         .dout                         (pb_bootm_dout[`NCPU_DW-1:0]),
         .din                          (pb_bootm_din[`NCPU_DW-1:0])
      );

   /************************************************************
    * SPI Master Controller
    ************************************************************/
   soc_pb_spi_master pb_spi_master
     (/*AUTOINST*/
      // Outputs
      .pb_spi_cmd_ready                 (pb_spi_cmd_ready),
      .pb_spi_dout                      (pb_spi_dout[31:0]),
      .pb_spi_valid                     (pb_spi_valid),
      .SPI_SCK                          (SPI_SCK),
      .SPI_CS_L                         (SPI_CS_L),
      .SPI_MOSI                         (SPI_MOSI),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .pb_spi_cmd_valid                 (pb_spi_cmd_valid),
      .pb_spi_cmd_addr                  (pb_spi_cmd_addr[`NCPU_AW-1:0]),
      .pb_spi_cmd_we_msk                (pb_spi_cmd_we_msk[4:0]),
      .pb_spi_din                       (pb_spi_din[31:0]),
      .pb_spi_ready                     (pb_spi_ready),
      .SPI_MISO                         (SPI_MISO));
   
   /************************************************************
    * CPU Core (L1 Caches/MMUs/IRQC/TSC/...)
    ************************************************************/
   ncpu32k
     #(
      .CPU_RSET_VECTOR (CPU_RSET_VECTOR)
     )
   ncpu32k
     (/*AUTOINST*/
      // Outputs
      .fb_ibus_ready                    (fb_ibus_ready),
      .fb_ibus_cmd_valid                (fb_ibus_cmd_valid),
      .fb_ibus_cmd_addr                 (fb_ibus_cmd_addr[`NCPU_AW-1:0]),
      .fb_dbus_ready                    (fb_dbus_ready),
      .fb_dbus_din                      (fb_dbus_din[`NCPU_DW-1:0]),
      .fb_dbus_cmd_valid                (fb_dbus_cmd_valid),
      .fb_dbus_cmd_addr                 (fb_dbus_cmd_addr[`NCPU_AW-1:0]),
      .fb_dbus_cmd_we_msk               (fb_dbus_cmd_we_msk[`NCPU_DW/8-1:0]),
      // Inputs
      .clk                              (clk),
      .rst_n                            (rst_n),
      .fb_ibus_valid                    (fb_ibus_valid),
      .fb_ibus_dout                     (fb_ibus_dout[`NCPU_IW-1:0]),
      .fb_ibus_cmd_ready                (fb_ibus_cmd_ready),
      .fb_dbus_valid                    (fb_dbus_valid),
      .fb_dbus_dout                     (fb_dbus_dout[`NCPU_IW-1:0]),
      .fb_dbus_cmd_ready                (fb_dbus_cmd_ready),
      .fb_irqs                          (fb_irqs[`NCPU_NIRQ-1:0]));
   
   /************************************************************
    * Interrupt Requests
    ************************************************************/
   assign fb_irqs = {`NCPU_NIRQ{1'b0}};
   
   
   /************************************************************
    * Clock and Reset
    ************************************************************/
   assign clk = CPU_CLK;

   // Reset system flip flops
   reg [1:0] rst_r;
   always @(posedge CPU_CLK or RST_L) begin
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
   always @(posedge SDR_CLK or RST_L) begin
      if(~RST_L) begin
         sdr_rst_r <= 0;
      end else begin
         sdr_rst_r <= {sdr_rst_r[0],1'b1};
      end
   end
   assign sdr_rst_n = sdr_rst_r[1];
   
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
