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
   input                   ibus_cmd_flush,
   output [`NCPU_AW-1:0]   ibus_out_id,
   output [`NCPU_AW-1:0]   ibus_out_id_nxt,
   input                   ibus_hld_id,
   input                   icache_dout_valid, /* Insn is presented at ibus */
   output                  icache_dout_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    icache_dout,
   input                   icache_cmd_ready, /* icache is ready to accept cmd */
   output                  icache_cmd_valid, /* cmd is presented at icache's input */
   output [`NCPU_AW-1:0]   icache_cmd_addr
);

   // MMU FSM
   wire hds_cmd;
   wire hds_icache;
   wire icache_cmd_valid_w;

   ncpu32k_cell_pipebuf #(`NCPU_IW) pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (),
         .dout       (),
         .in_valid   (ibus_cmd_valid),
         .in_ready   (ibus_cmd_ready),
         .out_valid  (icache_cmd_valid_w),
         .out_ready  (icache_cmd_ready),
         .cas        (hds_cmd)
      );
      
   assign icache_cmd_valid = /*~ibus_cmd_flush &*/ icache_cmd_valid_w;

   assign hds_icache = icache_dout_valid & icache_dout_ready;
      
   localparam RST_FETCH_ADDR = `NCPU_ERST_VECTOR-`NCPU_AW'd4;
   
   // Transfer when handshaked with ibus cmd
   ncpu32k_cell_dff_lr #(`NCPU_AW, RST_FETCH_ADDR) dff_id_nxt
                   (clk,rst_n, hds_cmd, ibus_cmd_addr[`NCPU_AW-1:0], ibus_out_id_nxt[`NCPU_AW-1:0]);
   // Transfer when handshaked with ibus dout and did not hold on GENPC
   ncpu32k_cell_dff_lr #(`NCPU_AW, RST_FETCH_ADDR) dff_id
                   (clk,rst_n, hds_icache & ~ibus_hld_id, ibus_cmd_flush ? ibus_cmd_addr[`NCPU_AW-1:0] : ibus_out_id_nxt[`NCPU_AW-1:0], ibus_out_id[`NCPU_AW-1:0]);

   // TLB
   wire [`NCPU_AW-1:0] tlb_addr;
   ncpu32k_cell_dff_lr #(`NCPU_AW) dff_tlb
                   (clk,rst_n, hds_cmd, ibus_cmd_addr[`NCPU_AW-1:0], tlb_addr[`NCPU_AW-1:0]);

   assign icache_cmd_addr = tlb_addr;
   
   assign icache_dout_ready = ibus_dout_ready;
   assign ibus_dout_valid = icache_dout_valid;
   assign ibus_dout = icache_dout;
   
endmodule
