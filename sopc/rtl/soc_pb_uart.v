/**@file
 * Simple 16550 UART
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
   input                      pb_uart_cmd_valid,
   output                     pb_uart_cmd_ready,
   input [`NCPU_AW-1:0]       pb_uart_cmd_addr,
   input [3:0]                pb_uart_cmd_we_msk,
   input [31:0]               pb_uart_din,
   output [31:0]              pb_uart_dout,
   output reg                 pb_uart_valid,
   input                      pb_uart_ready,
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

   assign pb_uart_cmd_ready = ~pb_uart_valid;

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
   reg [7:0] din_r;
	reg we_vld_r = 1'b0;
   reg uart_tx_r;
   
   // TX Frame
   //   0   | xxxx xxxx |  1
   // ------+-----------+------> t
   // Start |  Data     | Stop
	wire [9:0] tx_frame = {1'b1, din_r, 1'b0};

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
				if(we_vld_r) begin
               din_r <= phy_din;
            end
				phy_cmd_we_rdy <= ~we_vld_r;
			end else if(~we_vld_r)
            phy_cmd_we_rdy <= 1'b1;
		end
	end

   reg [1:0] rx_status_r = 2'b0;
	reg [6:0] rx_smpl_cnt = 7'h00;
   reg uart_rx_r = 1'b0;
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
                  // Waiting for start bit
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
                        // Waiting for stop bit
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
      end
   end
   
   // RX cmd
   always @(posedge clk_baud) begin
		if(phy_cke) begin
         if(phy_cmd_rd_vld & phy_cmd_rd_rdy) begin
            // cmd handshaked
            phy_cmd_rd_rdy <= 1'b0;
            phy_dout_overun <= 1'b0;
         end
      end
   end


   // synthesis translate_off
`ifndef SYNTHESIS
   
   // Assertions 03202136
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk_baud) begin
      if(phy_cmd_rd_rdy & ~phy_cmd_rd_vld) begin
         $fatal ("\n invalid phy_cmd_rd_vld until phy_cmd_rd_rdy=1 \n");
      end
   end
`endif

   // Assertions 03202138
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk_baud) begin
      if(phy_cmd_we_rdy & ~phy_cmd_we_vld) begin
         $fatal ("\n invalid phy_cmd_we_vld until phy_cmd_we_rdy=1 \n");
      end
   end
`endif

`endif
   // synthesis translate_on
   
endmodule
