/**@file
 * Simple 16550 compatible UART
 * Spec:
 * Limitations:
 * 1. Register and features of 16550 are partially implemented:
 * --------+-----------------+------------------------------------------------
 * Address |  Desc           | Unimplemented field(s)
 * --------+-----------------+------------------------------------------------
 * 0x0     |  RBR (DLAB = 0) |
 *         |  DLL (DLAB = 1) |
 * --------+-----------------+------------------------------------------------
 * 0x1     |  IER (DLAB = 0) | EM EL
 *         |  DLM (DLAB = 1) |
 * --------+-----------------+------------------------------------------------
 * 0x2     |  FCR            | DMA RCVRL RCVRH
 * 0x3     |  LCR            | WLS[0..1] STB PEN EPS SP SB
 * 0x4     |  MCR            | (all)
 * 0x5     |  LSR            | PE FE BI ERR
 * 0x6     |  MSR            | (all)
 * 0x7     |  SCR            | (all)
 * --------+-----------------+-------------------------------------------------
 * 2. Transmission protocol (Non programmable)
 *      8-bit data, 1-bit stop, no parity
 * 3. Unsupport modem and hardware flow control.
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

module soc_pb_uart
(
   input                      clk,
   input                      clk_baud,
   input                      rst_n,
   input                      rst_baud_n,
   input                      pb_uart_cmd_valid,
   output                     pb_uart_cmd_ready,
   input [`NCPU_AW-1:0]       pb_uart_cmd_addr,
   input [3:0]                pb_uart_cmd_we_msk,
   input [31:0]               pb_uart_din,
   output reg [31:0]          pb_uart_dout,
   output reg                 pb_uart_valid,
   input                      pb_uart_ready,
   output                     pb_uart_irq,
   // TTL UART Interface
   output                     UART_TX_L,
   input                      UART_RX_L
);

   wire hds_cmd = pb_uart_cmd_valid & pb_uart_cmd_ready;
   wire hds_dout = pb_uart_valid & pb_uart_ready;

   always @(posedge clk or negedge rst_n)
      if(~rst_n)
         pb_uart_valid <= 1'b0;
      else if (hds_cmd | hds_dout)
         pb_uart_valid <= (hds_cmd | ~hds_dout);

   assign pb_uart_cmd_ready = ~pb_uart_valid | hds_cmd;
   
   // PHY transceiver interface
   wire phy_cmd_rd_vld;
   wire phy_cmd_we_vld;
   // ASSERT (03202136)
   reg phy_cmd_rd_rdy = 1'b0;
   // ASSERT (03202138)
   reg phy_cmd_we_rdy = 1'b0;
   // RX overrun
   reg phy_dout_overun = 1'b0;
   // Division factor
   wire [15:0] baud_div;
   // Data write to serial
   wire [7:0] phy_din;
   // Data read from serial
   reg [7:0] phy_dout;

   reg [15:0] div_cnt;
   wire [15:0] div_cnt_nxt = div_cnt + 1'b1;
   wire phy_cke = div_cnt_nxt == baud_div; // RX/TX clk enable

   // Baud CLK divisior
   always @(posedge clk_baud or negedge rst_n) begin
      if(~rst_n)
         div_cnt <= 16'h0000;
      else
         div_cnt <= phy_cke ? 16'h0000 : div_cnt_nxt;
   end

   reg [6:0] tx_shift_cnt = 6'b000000;
   reg tx_pending = 1'b0;
   reg we_vld_r = 1'b0;
   reg uart_tx_r;

   // TX Frame
   //   0   | xxxx xxxx |  1
   // ------+-----------+------> t
   // Start |  Data     | Stop
   wire [9:0] tx_frame = {1'b1, phy_din, 1'b0};

   // TX FSM
   always @(posedge clk_baud) begin
      uart_tx_r <= tx_frame[tx_shift_cnt[6:3]] | ~tx_pending;
      we_vld_r <= phy_cmd_we_vld;

      if(phy_cke) begin
         if(tx_shift_cnt == 7'b1001111)
            tx_shift_cnt <= 7'b000000;
         else
            tx_shift_cnt <= tx_shift_cnt + tx_pending;
      end
   end

   assign UART_TX_L = uart_tx_r;

   // TX cmd
   always @(posedge clk_baud) begin
      if(phy_cke) begin
         if(tx_shift_cnt == 7'b1001111 | ~tx_pending) begin
            // Accept new cmd
            tx_pending <= we_vld_r;
            phy_cmd_we_rdy <= ~we_vld_r;
         end else if(~we_vld_r)
            phy_cmd_we_rdy <= 1'b1;
      end
   end

   reg [1:0] rx_status_r = 2'b0;
   reg [6:0] rx_smpl_cnt = 7'h00;
   reg uart_rx_r;
   reg [6:0] dout_r;

   localparam [1:0] RX_S_DETECT = 2'd0;
   localparam [1:0] RX_S_PENDING = 2'd1;
   localparam [1:0] RX_S_SHIFT = 2'd2;

   // RX FSM
   always @(posedge clk_baud) begin
      uart_rx_r <= UART_RX_L;

      if(phy_cke) begin
         case(rx_status_r)
            RX_S_DETECT:
               if(uart_rx_r) begin
                  // Waiting for START bit
                  rx_smpl_cnt <= 7'h00;
               end else begin
                  // START bit detected
                  // FIXME: add 8 cycles anti-jitter filter
                  // Delay 16 cycles (8 + PENDING 8)
                  rx_smpl_cnt <= rx_smpl_cnt + 1'b1;
                  if(rx_smpl_cnt[2]) begin
                     rx_status_r <= RX_S_PENDING;
                  end
               end
            RX_S_PENDING: begin
               // Pending for 8 cycles
               rx_smpl_cnt <= rx_smpl_cnt + 1'b1;
               if(~rx_smpl_cnt[2]) begin
                  rx_status_r <= RX_S_SHIFT;
               end
            end
            RX_S_SHIFT: begin
               // Pending for 8 cycles
               rx_smpl_cnt <= rx_smpl_cnt + 1'b1;
               if(rx_smpl_cnt[2])
                  case({rx_smpl_cnt[6], rx_smpl_cnt[3]})
                     2'b11: begin
                        // STOP bit ignored
                        // Start to receive new frame
                        rx_smpl_cnt <= 7'h00;
                        rx_status_r <= RX_S_DETECT;
                     end
                     2'b10: begin
                        // Receive last bit of all 8bits
                        if(~phy_cmd_rd_rdy) begin
                           phy_dout <= {uart_rx_r, dout_r[6:0]};
                        end else begin
                           phy_dout_overun <= 1'b1;
                        end
                        phy_cmd_rd_rdy <= 1'b1;
                        // Waiting for STOP bit
                        rx_status_r <= RX_S_PENDING;
                     end
                     default: begin
                        // Shift in DATA bit
                        dout_r <= {uart_rx_r, dout_r[6:1]};
                        rx_status_r <= RX_S_PENDING;
                     end
                  endcase
            end
         endcase
         
         // RX cmd
         if(phy_cmd_rd_vld & phy_cmd_rd_rdy) begin
            // cmd handshaked
            phy_cmd_rd_rdy <= 1'b0;
            phy_dout_overun <= 1'b0;
         end
      end
   end

   reg [15:0] DLR = 8'ha0;
   reg [3:0] IER = 8'h00;
   reg [7:0] LCR = 8'h00;
   reg [2:0] IIR = 3'b001;
   wire [7:0] RBR;
   wire DLAB = LCR[7];

   reg [1:0] tx_status = 2'b00;
   reg rx_status = 1'b0;
   wire tx_full;
   wire tx_empty;
   wire rx_full;
   wire rx_empty;
   reg dat_ready = 1'b0;

   assign baud_div = {DLR[14:0], 1'b0};
   assign pb_uart_irq = ~IIR[0];

   assign phy_cmd_rd_vld = rx_status;
   assign phy_cmd_we_vld = tx_status == 2'b01;

   wire cmd_we = |pb_uart_cmd_we_msk;
   wire rd_RBR = hds_cmd & ~cmd_we & (pb_uart_cmd_addr[2:0] == 3'b000) & ~DLAB; // Read RBR
   wire we_RBR = hds_cmd & cmd_we & (pb_uart_cmd_addr[2:0] == 3'b000) & ~DLAB; // Write RBR
   
   sco_fifo_asclk
   #(
      .DW (8),
      .AW (4) // 16 entries
   )
   tx_fifo
   (
      .wclk (clk),
      .wrst_n (rst_n),
      .rclk (clk_baud),
      .rrst_n (rst_baud_n),
      .din (pb_uart_din[7:0]),
      .push (we_RBR),
      .pop (&tx_status),
      .dout (phy_din[7:0]),
      .full (tx_full),
      .empty (tx_empty)
   );

   sco_fifo_asclk
   #(
      .DW (8),
      .AW (4) // 16 entries
   )
   rx_fifo
   (
      .wclk (clk_baud),
      .wrst_n (rst_baud_n),
      .rclk (clk),
      .rrst_n (rst_n),
      .din (phy_dout[7:0]),
      .push (~rx_status & phy_cmd_rd_rdy),
      .pop (~dat_ready & ~rx_empty),
      .dout (RBR[7:0]),
      .full (rx_full),
      .empty (rx_empty)
   );

   // TX FIFO FSM
   always @(posedge clk_baud) begin
      case(tx_status)
         2'b00:
            if(~tx_empty & phy_cmd_we_rdy)
               tx_status <= 2'b01;
         2'b01:
            if(~phy_cmd_we_rdy)
               tx_status <= 2'b11;
         default:
            tx_status <= 2'b00;
      endcase
   end

   // RX FIFO FSM
   always @(posedge clk_baud) begin
      if(~rx_full | rx_status)
         rx_status <= phy_cmd_rd_rdy;
   end
   
   // Is data ready in RBR ?
   always @(posedge clk) begin
      if(~dat_ready)
         dat_ready <= ~rx_empty;
      else if(rd_RBR)
         dat_ready <= 1'b0;
   end

   reg [2:0] cmd_addr_r = 2'b0;
   always @(posedge clk)
      if (hds_cmd)
         cmd_addr_r <= pb_uart_cmd_addr[2:0];
   
   // Readout registers
   always @(*) begin
      case(cmd_addr_r)
         // RBR (DLAB = 0)
         // DLL (DLAB = 1)
         3'b000: pb_uart_dout = {24'b0, DLAB ? DLR[7:0] : RBR};
         // IER (DLAB = 0) TODO: EM EL
         // DLM (DLAB = 1)
         3'b001: pb_uart_dout = {16'b0, DLAB ? DLR[15:8] : {4'b0000, IER}, 8'b0};
         // FCR TODO
         3'b010: pb_uart_dout = {8'b0, {5'b0000, IIR}, 16'b0};
         // LCR TODO: Data bits / Stop bit/ parity / set break
         3'b011: pb_uart_dout = {{LCR[7], 7'b0000011}, 24'b0};
         // MCR TODO: DTR RTS OUT1 OUT2 LOOP
         3'b100: pb_uart_dout = 32'h0;
         // LSR TODO: Parity and errors
         3'b101: pb_uart_dout = {{16'b0, phy_cmd_we_rdy, ~tx_full, 3'b000, phy_dout_overun, dat_ready}, 8'b0};
         // MSR TODO
         3'b110: pb_uart_dout = {8'b0, 8'b10000000, 16'b0};
         // SCR TODO
         3'b111: pb_uart_dout = 32'h0;
      endcase
   end

   reg RBR_written = 1'b0;
   
   always @(posedge clk) begin
      // Writeback registers
      if(hds_cmd & cmd_we) begin
         case(pb_uart_cmd_addr[2:0])
            3'b000:
               if(DLAB)
                  DLR[7:0] <= pb_uart_din[7:0];
               else
                  RBR_written <= 1'b1;
            3'b001:
               if(DLAB)
                  DLR[15:8] <= pb_uart_din[15:8];
               else
                  IER <= pb_uart_din[3+8:0+8];
            3'b011:
               LCR[7] <= pb_uart_din[7+24];
         endcase
      end
      
      // IRQ FSM
      if(IIR[0]) begin
         if(dat_ready & IER[0]) begin
            // Raise RX buffer full IRQ
            IIR <= 3'b100;
         end else if(~tx_full & RBR_written & IER[1]) begin
            // Raise TX buffer empty IRQ
            {RBR_written, IIR} <= {1'b0, 3'b010};
         end
      end else if(hds_cmd)
         // Accept/clear IRQ
         if((IIR[2:1] == 2'b10) & ~cmd_we & (pb_uart_cmd_addr[2:0] == 3'b000) & ~DLAB | // read RBR
            (IIR[2:1] == 2'b01) & (~cmd_we & (pb_uart_cmd_addr[2:0] == 3'b010) | // read IIR or write RBR
                                   cmd_we & (pb_uart_cmd_addr[2:0] == 3'b000) & ~DLAB))
         begin
            IIR[0] <= 1'b1; // no IRQ pending
         end
   end

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions 03202136
`ifdef NCPU_ENABLE_ASSERT
   reg hds_phy_cmd_rd=0;
   always @(posedge clk_baud) begin
      if(phy_cke) begin
         if(phy_cmd_rd_rdy & phy_cmd_rd_vld)
            hds_phy_cmd_rd <= 1;
         else if (~phy_cmd_rd_rdy)
            hds_phy_cmd_rd <= 0;
         if(hds_phy_cmd_rd&phy_cmd_rd_rdy & ~phy_cmd_rd_vld) begin
            $fatal ("\n invalid phy_cmd_rd_vld until phy_cmd_rd_rdy=1 \n");
         end
      end
   end
`endif

   // Assertions 03202138
`ifdef NCPU_ENABLE_ASSERT
   reg hds_phy_cmd_we=0;
   always @(posedge clk_baud) begin
      if(phy_cke) begin
         if(phy_cmd_we_rdy & phy_cmd_we_vld)
            hds_phy_cmd_we <= 1;
         else if (~phy_cmd_we_rdy)
            hds_phy_cmd_we <= 0;
         if(hds_phy_cmd_we&phy_cmd_we_rdy & ~phy_cmd_we_vld) begin
            $fatal ("\n invalid phy_cmd_we_vld until phy_cmd_we_rdy=1 \n");
         end
      end
   end
`endif

`endif
   // synthesis translate_on

endmodule
