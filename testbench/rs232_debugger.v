/**@file
 * Virtual Console. Print chars of serial data
 * Limitations: 8-bit data, 1-bit stop, no parity
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

module rs232_debugger
#(
   parameter BAUD = 115200
)
(
   input DCE_TXD_L_I
);
   reg baud_clk = 0;

   initial forever #((1000000000/(BAUD*8))/2) baud_clk = ~baud_clk;
   
   reg [1:0] rx_status_r = 2'b0;
   reg [6:0] rx_smpl_cnt = 7'h00;
   reg uart_rx_r;
   reg [6:0] dout_r;

   localparam [1:0] RX_S_DETECT = 2'd0;
   localparam [1:0] RX_S_PENDING = 2'd1;
   localparam [1:0] RX_S_SHIFT = 2'd2;

   // RX FSM
   always @(posedge baud_clk) begin
      uart_rx_r <= DCE_TXD_L_I;

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
                     $write("%c", {uart_rx_r, dout_r[6:0]});
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
   end
   
endmodule
