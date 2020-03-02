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

module ncpu32k_i_mmu(
   input                   clk,
   input                   rst_n,
   output                  ibus_dout_valid, /* Insn is presented at immu's output */
   input                   ibus_dout_ready, /* ifu is ready to accepted Insn */
   output [`NCPU_IW-1:0]   ibus_dout,
   output                  ibus_cmd_ready, /* ibus is ready to accept cmd */
   input                   ibus_cmd_valid, /* cmd is presented at ibus'input */
   input [`NCPU_AW-1:0]    ibus_cmd_addr,
   output [`NCPU_AW-1:0]   ibus_out_id,
   input                   icache_dout_valid, /* Insn is presented at ibus */
   output                  icache_dout_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    icache_dout,
   input                   icache_cmd_ready, /* icache is ready to accept cmd */
   output                  icache_cmd_valid, /* cmd is presented at icache's input */
   output [`NCPU_AW-1:0]   icache_cmd_addr
);

   // MMU FSM
   localparam MS_IDLE = 1'd0;
   localparam MS_TRANSLATE = 1'd1;
   
   wire status_nxt;
   wire status_r;
   
   wire ibus_dout_valid_w;

   // Handshaked with cmd
   wire hds_cmd = (ibus_cmd_ready & ibus_cmd_valid);
   // Handshaked with ICache Command
   wire hds_icache_cmd = (icache_cmd_valid & icache_cmd_ready);
   // Handshaked with ibus dout
   wire hds_ibus_dout = (ibus_dout_valid_w & ibus_dout_ready);
   
   assign status_nxt = hds_cmd | ~(hds_icache_cmd & hds_ibus_dout);

   ncpu32k_cell_dff_lr #(1) dff_status
                   (clk,rst_n, (hds_cmd | (hds_icache_cmd & hds_ibus_dout)), status_nxt, status_r);

   
   wire [`NCPU_AW-1:0] id;                   
   ncpu32k_cell_dff_lr #(`NCPU_AW, `NCPU_ERST_VECTOR-`NCPU_AW'd4) dff_id
                   (clk,rst_n, hds_cmd, ibus_cmd_addr[`NCPU_AW-1:0], id[`NCPU_AW-1:0]);

   // TLB
   wire [`NCPU_AW-1:0] tlb_addr;
   ncpu32k_cell_dff_lr #(`NCPU_AW) dff_tlb
                   (clk,rst_n, hds_cmd, ibus_cmd_addr[`NCPU_AW-1:0]/*+32'd4*/, tlb_addr[`NCPU_AW-1:0]);

   assign icache_cmd_valid = status_r;
   assign icache_dout_ready = status_r;
   assign icache_cmd_addr = tlb_addr;
   
   assign ibus_cmd_ready = ~status_r; // Idle
   assign ibus_dout_valid_w = icache_dout_valid;
   assign ibus_dout = icache_dout;
   assign ibus_out_id = id;
   
   // Validate output when the next cmd received
   assign ibus_dout_valid = ibus_dout_valid_w & hds_cmd;
   
endmodule
