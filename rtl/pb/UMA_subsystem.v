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

module UMA_subsystem
#(
   parameter CONFIG_SDR_ROW_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_BA_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_COL_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_DATA_BYTES_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_DATA_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ICACHE_P_LINE
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DCACHE_P_LINE
   `PARAM_NOT_SPECIFIED
)
(
   input                               sdr_clk,
   input                               sdr_rst_n,
   input                               cpu_clk,
   input                               cpu_rst_n,
   // I-Bus Slave
   output                              ibus_ARREADY,
   input                               ibus_ARVALID,
   input [CONFIG_IBUS_AW-1:0]          ibus_ARADDR,
   input                               ibus_ASEL_BOOTROM,
   input                               ibus_RREADY,
   output                              ibus_RVALID,
   output [CONFIG_IBUS_DW-1:0]         ibus_RDATA,
   // D-Bus Slave
   output                              dbus_ARWREADY,
   input                               dbus_ARWVALID,
   input [CONFIG_DBUS_AW-1:0]          dbus_ARWADDR,
   input                               dbus_AWE,
   output                              dbus_WREADY,
   input                               dbus_WVALID,
   input [CONFIG_DBUS_DW-1:0]          dbus_WDATA,
   output                              dbus_BVALID,
   input                               dbus_BREADY,
   output                              dbus_RVALID,
   input                               dbus_RREADY,
   output [CONFIG_DBUS_DW-1:0]         dbus_RDATA,
   // SDR
   output                              sdr_cmd_bst_we_req,
   input                               sdr_cmd_bst_we_ack,
   output                              sdr_cmd_bst_rd_req,
   input                               sdr_cmd_bst_rd_ack,
   output reg [CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-1:0] sdr_cmd_addr,
   output [CONFIG_SDR_DATA_BITS-1:0]   sdr_din,
   input  [CONFIG_SDR_DATA_BITS-1:0]   sdr_dout,
   input                               sdr_r_vld,   // sdr_dout valid
   input                               sdr_w_rdy,   // write ready
   // BootROM
   output reg                          bootrom_en,
   output reg [CONFIG_IBUS_AW-1:0]     bootrom_addr,
   input [CONFIG_IBUS_DW-1:0]          bootrom_dout
);

   // TODO: Allow different size of I$ and D$ line
   parameter BURST_WORDS_AW = CONFIG_DCACHE_P_LINE - CONFIG_SDR_DATA_BYTES_LOG2;
   parameter BURST_WORDS = (1<<BURST_WORDS_AW);

/////////////////////////////////////////////////////////////////////////////
// Begin of CPU clock domain
/////////////////////////////////////////////////////////////////////////////

   reg [3:0]                           state_r;
   reg [BURST_WORDS_AW-1:0]            bootrom_burst_cnt;
   reg                                 cdc_sdr_cmd_bst_we_req;
   reg                                 cdc_sdr_cmd_bst_rd_req;
   reg                                 sdr_ibus_r, sdr_dbus_r;
   wire                                rx_empty;
   wire [CONFIG_SDR_DATA_BITS-1:0]     rx_dout;
   wire                                rx_pop;
   wire                                rx_BVALID_r;
   wire                                tx_full;
   wire                                dbus_hds_W;
   wire                                dbus_hds_B;
   wire                                cdc_sdr_burst_cnt_msb;

   localparam [3:0]                    S_IDLE                     = 4'd0;
   localparam [3:0]                    S_DBUS_BURST_W_BUF         = 4'd1;
   localparam [3:0]                    S_DBUS_BURST_WRITE_1       = 4'd2;
   localparam [3:0]                    S_DBUS_BURST_WRITE_2       = 4'd3;
   localparam [3:0]                    S_DBUS_BURST_READ_1        = 4'd4;
   localparam [3:0]                    S_DBUS_BURST_READ_2        = 4'd5;
   localparam [3:0]                    S_IBUS_BURST_READ_1        = 4'd6;
   localparam [3:0]                    S_IBUS_BURST_READ_2        = 4'd7;
   localparam [3:0]                    S_IBUS_BURST_START_BOOTROM = 4'd8;
   localparam [3:0]                    S_IBUS_BURST_BOOTROM_PENDING = 4'd9;

   // D-BUS is prior to I-BUS
   assign dbus_ARWREADY = (state_r == S_IDLE);
   assign ibus_ARREADY = (state_r == S_IDLE) & ~dbus_ARWVALID;

/////////////////////////////////////////////////////////////////////////////
// End of CPU clock domain
/////////////////////////////////////////////////////////////////////////////

/////////////////////////////////////////////////////////////////////////////
// Begin of SDR clock domain
/////////////////////////////////////////////////////////////////////////////

   wire                                tx_empty;
   wire                                rx_full;
   wire                                sdr_burst_cnt_ld;
   wire [BURST_WORDS_AW-1:0]           sdr_burst_cnt;
   wire [BURST_WORDS_AW-1:0]           sdr_burst_cnt_nxt;

   assign sdr_burst_cnt_ld = (sdr_w_rdy | sdr_r_vld);

   assign sdr_burst_cnt_nxt = (sdr_burst_cnt + 'b1);

   nDFF_lr #(BURST_WORDS_AW) dff_sdr_burst_cnt
      (sdr_clk, sdr_rst_n, sdr_burst_cnt_ld, sdr_burst_cnt_nxt, sdr_burst_cnt);

   ncpu32k_cdc_sync #(
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_SDR_CMD_BST_RD_REQ
      (
         .A       (cdc_sdr_cmd_bst_rd_req),
         .CLK_B   (sdr_clk),
         .RST_N_B (sdr_rst_n),
         .B       (sdr_cmd_bst_rd_req)
      );

   ncpu32k_cdc_sync #(
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_SDR_CMD_BST_WE_REQ
      (
         .A       (cdc_sdr_cmd_bst_we_req),
         .CLK_B   (sdr_clk),
         .RST_N_B (sdr_rst_n),
         .B       (sdr_cmd_bst_we_req)
      );

   ncpu32k_cdc_sync #(
         .CONFIG_CDC_STAGES (`NCPU_CDC_STAGES)
      )
   CDC_SDR_BURST_CNT_MSB
      (
         .A       (sdr_burst_cnt[BURST_WORDS_AW-1]),
         .CLK_B   (cpu_clk),
         .RST_N_B (cpu_rst_n),
         .B       (cdc_sdr_burst_cnt_msb)
      );

/////////////////////////////////////////////////////////////////////////////
// End of SDR clock domain
/////////////////////////////////////////////////////////////////////////////


   ncpu32k_fifo_aclk
      #(
         .DW (CONFIG_SDR_DATA_BITS),
         .AW (BURST_WORDS_AW)
      )
   FIFO_RX
      (
         .wclk    (sdr_clk),
         .wrst_n  (sdr_rst_n),
         .din     (sdr_dout),
         .push    (sdr_r_vld),
         .full    (rx_full),

         .rclk    (cpu_clk),
         .rrst_n  (cpu_rst_n),
         .pop     (rx_pop),
         .dout    (rx_dout),
         .empty   (rx_empty)
      );

   ncpu32k_fifo_aclk
      #(
         .DW (CONFIG_SDR_DATA_BITS),
         .AW (BURST_WORDS_AW)
      )
   FIFO_TX
      (
         .wclk    (cpu_clk),
         .wrst_n  (cpu_rst_n),
         .din     (dbus_WDATA),
         .push    (dbus_hds_W),
         .full    (tx_full),

         .rclk    (sdr_clk),
         .rrst_n  (sdr_rst_n),
         .pop     (sdr_w_rdy),
         .dout    (sdr_din),
         .empty   (tx_empty)
      );

/////////////////////////////////////////////////////////////////////////////
// Begin of CPU clock domain
/////////////////////////////////////////////////////////////////////////////

   assign rx_pop = (~rx_BVALID_r & ~rx_empty)
                     ? 1'b1
                     : (rx_BVALID_r & rx_empty)
                        ? 1'b0
                        : rx_BVALID_r;
   
   nDFF_r #(1) dff_rx_BVALID
      (cpu_clk, cpu_rst_n, rx_pop, rx_BVALID_r);

   // Read response
   assign dbus_RVALID = (sdr_dbus_r & rx_BVALID_r);
   assign dbus_RDATA = rx_dout;

   assign ibus_RVALID = (sdr_ibus_r & rx_BVALID_r) | (state_r==S_IBUS_BURST_BOOTROM_PENDING);
   assign ibus_RDATA = (sdr_ibus_r & rx_BVALID_r) ? rx_dout : bootrom_dout;

   // Write ready
   assign dbus_WREADY = (state_r==S_DBUS_BURST_W_BUF) & ~tx_full;
   assign dbus_hds_W = (dbus_WREADY & dbus_WVALID);

   // Write response
   assign dbus_BVALID = ((state_r==S_DBUS_BURST_WRITE_2) & ~cdc_sdr_burst_cnt_msb);
   assign dbus_hds_B = (dbus_BREADY & dbus_BVALID);

   
   always @(posedge cpu_clk or negedge cpu_rst_n)
      if (~cpu_rst_n)
         begin
            state_r <= S_IDLE;
            sdr_ibus_r <= 1'b0;
            sdr_dbus_r <= 1'b0;
            cdc_sdr_cmd_bst_we_req <= 1'b0;
            cdc_sdr_cmd_bst_rd_req <= 1'b0;
         end
      else
         begin
            case (state_r)
            S_IDLE:
               if (dbus_ARWVALID)
                  begin
                     sdr_dbus_r <= 1'b1;
                     sdr_cmd_addr <= dbus_ARWADDR[CONFIG_SDR_DATA_BYTES_LOG2 +: CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS];
                     if (dbus_AWE)
                        begin
                           // Buffer the data into FIFO.
                           state_r <= S_DBUS_BURST_W_BUF;
                        end
                     else
                        begin
                           cdc_sdr_cmd_bst_rd_req <= 1'b1;
                           state_r <= S_DBUS_BURST_READ_1;
                        end
                  end

               else if (ibus_ARVALID & ibus_ASEL_BOOTROM) // Bootrom is selected
                  begin
                     bootrom_en <= 1'b1;
                     bootrom_addr <= ibus_ARADDR;
                     bootrom_burst_cnt <= {BURST_WORDS_AW{1'b0}};
                     state_r <= S_IBUS_BURST_START_BOOTROM;
                  end

               else if (ibus_ARVALID)
                  begin
                     sdr_cmd_addr <= ibus_ARADDR[CONFIG_SDR_DATA_BYTES_LOG2 +: CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS];
                     cdc_sdr_cmd_bst_rd_req <= 1'b1;
                     sdr_ibus_r <= 1'b1;
                     state_r <= S_IBUS_BURST_READ_1;
                  end


            S_DBUS_BURST_W_BUF:
               if (tx_full)
                  begin
                     cdc_sdr_cmd_bst_we_req <= 1'b1;
                     state_r <= S_DBUS_BURST_WRITE_1;
                  end

            S_DBUS_BURST_WRITE_1:
               if (cdc_sdr_burst_cnt_msb)
                  begin
                     cdc_sdr_cmd_bst_we_req <= 1'b0;
                     state_r <= S_DBUS_BURST_WRITE_2;
                  end
            S_DBUS_BURST_WRITE_2:
               // Need to wait handshake
               if (~cdc_sdr_burst_cnt_msb & dbus_hds_B)
                  begin
                     sdr_dbus_r <= 1'b0;
                     state_r <= S_IDLE;
                  end

            S_IBUS_BURST_READ_1,
            S_DBUS_BURST_READ_1:
               if (cdc_sdr_burst_cnt_msb)
                  begin
                     cdc_sdr_cmd_bst_rd_req <= 1'b0;
                     state_r <= S_DBUS_BURST_READ_2;
                  end
            S_IBUS_BURST_READ_2,
            S_DBUS_BURST_READ_2:
               // Need to wait FIFO being empty
               if (~cdc_sdr_burst_cnt_msb & rx_empty)
                  begin
                     sdr_ibus_r <= 1'b0;
                     sdr_dbus_r <= 1'b0;
                     state_r <= S_IDLE;
                  end


            S_IBUS_BURST_START_BOOTROM:
               begin
                  // Bootrom takes 1 clk to output the result
                  state_r <= S_IBUS_BURST_BOOTROM_PENDING;
                  bootrom_addr <= bootrom_addr + (CONFIG_IBUS_DW/8);
               end

            S_IBUS_BURST_BOOTROM_PENDING:
               begin
                  if (|bootrom_burst_cnt)
                     begin
                        bootrom_burst_cnt <= bootrom_burst_cnt - 'b1;
                        bootrom_addr <= bootrom_addr + (CONFIG_IBUS_DW/8);
                     end
                  else
                     begin
                        state_r <= S_IDLE;
                     end
               end

            default: begin
            end

            endcase
         end

/////////////////////////////////////////////////////////////////////////////
// End of CPU clock domain
/////////////////////////////////////////////////////////////////////////////


   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge sdr_clk)
      begin
         if ( (sdr_cmd_bst_we_req & sdr_cmd_bst_rd_ack) |
               (sdr_cmd_bst_rd_req & sdr_cmd_bst_we_ack) )
            $fatal (1, "BUG ON: DRAM_ctrl");

         if ((dbus_RVALID & ~dbus_RREADY) |
               (ibus_RVALID & ~ibus_RREADY))
            $fatal(1, "TODO: Bus waiting while RVALID is asserted high is currently unsupported!");
      end

   always @(posedge sdr_clk)
      begin
         if (sdr_w_rdy & tx_empty)
            $fatal(1, "TODO: FIFO empty when burst writing is currently unsupported!");

         if (sdr_r_vld & rx_full)
            $fatal(1, "BUG ON: RX FIFO is too small!");
      end

   initial
      begin
         if (CONFIG_DCACHE_P_LINE != CONFIG_ICACHE_P_LINE)
            $fatal(1, "TODO: Different size of D$ and I$ line");
      end
`endif

`endif
   // synthesis translate_on


endmodule
