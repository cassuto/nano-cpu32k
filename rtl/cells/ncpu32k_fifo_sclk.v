/**@file
 * Cell - Sync clock FIFO
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

module ncpu32k_fifo_sclk # (
   parameter DW = 8, // Data Width in bits
   parameter DEPTH_WIDTH = 4, // Width of depth
   parameter FWFT = 1, // FWFT (First Word Fall Through) mode
   parameter N_PROG_EMPTY = 1 // The number of remaining elements when the PROG_EMPTY is issued
)
(
   input CLK,
   input RST_N,
   input FLUSH,
   // Push port
   input PUSH,
   input [DW-1:0] DIN,
   output FULL,
   // Pop port
   input POP,
   output [DW-1:0] DOUT,
   output EMPTY,
   output PROG_EMPTY
);
   wire [DEPTH_WIDTH:0] w_ptr_r;
   wire [DEPTH_WIDTH:0] w_ptr_nxt;
   wire [DEPTH_WIDTH:0] r_ptr_r;
   wire [DEPTH_WIDTH:0] r_ptr_nxt;
   wire [DEPTH_WIDTH-1:0] ram_raddr;
   wire [DEPTH_WIDTH-1:0] ram_waddr;
   wire [DW-1:0] ram_dout;

   assign w_ptr_nxt = (w_ptr_r + 1'd1) & {DEPTH_WIDTH+1{~FLUSH}};
   assign r_ptr_nxt = (r_ptr_r + 1'd1) & {DEPTH_WIDTH+1{~FLUSH}};

   nDFF_lr #(DEPTH_WIDTH + 1) dff_w_ptr_r
                   (CLK,RST_N, PUSH|FLUSH, w_ptr_nxt, w_ptr_r);
   nDFF_lr #(DEPTH_WIDTH + 1) dff_r_ptr_r
                   (CLK,RST_N, POP|FLUSH, r_ptr_nxt, r_ptr_r);

   assign FULL = (w_ptr_r[DEPTH_WIDTH] != r_ptr_r[DEPTH_WIDTH]) &&
                (w_ptr_r[DEPTH_WIDTH-1:0] == r_ptr_r[DEPTH_WIDTH-1:0]);
   assign EMPTY = (w_ptr_r == r_ptr_r);
   assign PROG_EMPTY = (w_ptr_r == (r_ptr_r + N_PROG_EMPTY));

   ncpu32k_cell_sdpram_sclk
      #(
         .AW (DEPTH_WIDTH),
         .DW (DW),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_RAM
      (
         // Outputs
         .dout    (ram_dout[DW-1:0]),
         // Inputs
         .clk     (CLK),
         .rst_n   (RST_N),
         .raddr   (ram_raddr[DEPTH_WIDTH-1:0]),
         .re      (POP),
         .waddr   (ram_waddr[DEPTH_WIDTH-1:0]),
         .we      (PUSH),
         .din     (DIN[DW-1:0])
      );

   generate
      if (FWFT)
         begin : gen_fwft
            //
            // Basic idea of FWFT:
            // Look ahead and output the next position of the head pointer when PUSH is issuing.
            // If the next position of queue is invalid (i.e. the queue is empty), then store the current input,
            // Output the stored value in the next beat. This state will remain unchanged until the next position
            // is valid (i.e. there is a POP after some PUSHs).
            //
            wire state_r;
            wire fwft_nxt;
            wire clr_state;
            wire [DW-1:0] dat_r;

            // FWFT FSM
            nDFF_lr #(DW) dff_dat_r
              (CLK,RST_N, fwft_nxt, DIN, dat_r);
            nDFF_lr #(1) dff_state_r
              (CLK,RST_N, (fwft_nxt|clr_state|FLUSH), (fwft_nxt|~clr_state) & ~FLUSH, state_r);

            assign fwft_nxt = ~state_r & EMPTY & PUSH;
            assign clr_state = state_r & POP;

            assign ram_raddr = r_ptr_nxt[DEPTH_WIDTH-1:0];
            assign ram_waddr = w_ptr_r[DEPTH_WIDTH-1:0];
            assign DOUT = state_r ? dat_r : ram_dout;
         end
      else
         begin : gen_standard
            assign ram_raddr = r_ptr_r[DEPTH_WIDTH-1:0];
            assign ram_waddr = w_ptr_r[DEPTH_WIDTH-1:0];
            assign DOUT = ram_dout;
         end
   endgenerate

endmodule
