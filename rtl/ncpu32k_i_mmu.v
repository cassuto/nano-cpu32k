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
   output                  ibus_flush_ack,
   output [`NCPU_AW-1:0]   ibus_out_id,
   output [`NCPU_AW-1:0]   ibus_out_id_nxt,
   input                   icache_dout_valid, /* Insn is presented at ibus */
   output                  icache_dout_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    icache_dout,
   input                   icache_cmd_ready, /* icache is ready to accept cmd */
   output                  icache_cmd_valid, /* cmd is presented at icache's input */
   output [`NCPU_AW-1:0]   icache_cmd_addr
);

   // MMU FSM
   wire hds_ibus_cmd;
   wire hds_ibus_dout;
   wire hds_icache_cmd;
   wire icache_cmd_valid_w;
   
   // Cancel the current command request to icache
   // Occurs only if the icache accepts cmd while the output is valid.
   // There is no need to cacnel the dout of the cmd that has been handshaked before
   // this clk.
   ncpu32k_cell_dff_r #(1) dff_flush_ack
                   (clk,rst_n, ibus_cmd_flush & hds_icache_cmd, ibus_flush_ack);
   wire flush_strobe = (ibus_cmd_flush&~ibus_flush_ack);
   
   ncpu32k_cell_pipebuf #(`NCPU_IW) pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (),
         .dout       (),
         .in_valid   (ibus_cmd_valid),
         .in_ready   (ibus_cmd_ready),
         .out_valid  (icache_cmd_valid_w),
         .out_ready  (icache_cmd_ready | flush_strobe),
         .cas        (hds_ibus_cmd)
      );
      
   assign hds_ibus_dout = ibus_dout_valid & ibus_dout_ready;
      
   assign hds_icache_cmd = icache_cmd_valid & icache_cmd_ready;
   
   // Cacnel the cmd request to icache when flushing.
   assign icache_cmd_valid = ~flush_strobe & icache_cmd_valid_w;

   assign icache_dout_ready = ibus_dout_ready;
   
   assign ibus_dout_valid = icache_dout_valid;
   
   assign ibus_dout = icache_dout;
   
   // TLB is to be read
   // When flushing there is no need to handshake with command
   wire tlb_read = hds_ibus_cmd | ibus_cmd_flush;

   ////////////////////////////////////////////////////////////////////////////////
   // The following flip-flops are used to maintain the address of the (output-valid) insn
   // dff_id_nxt : Sync address with TLB
   //              (after the cur is sent to TLB, the NEXT insn addr should be is presented at ibus_cmd_addr )
   // dff_id     : Sync address with ibus dout
   //              (after handshaked with ibus dout, the NEXT insn addr is valid at ibus_out_id )
   ////////////////////////////////////////////////////////////////////////////////
   
   // Flush current-insn-PC indicator
   wire [`NCPU_AW-1:0] ibus_out_id_nxt_bypass = ibus_cmd_flush ? ibus_cmd_addr[`NCPU_AW-1:0] : ibus_out_id_nxt[`NCPU_AW-1:0];

   // Transfer when TLB is to be read
   ncpu32k_cell_dff_lr #(`NCPU_AW, `NCPU_ERST_VECTOR-`NCPU_AW'd4) dff_id_nxt
                   (clk,rst_n, tlb_read, ibus_cmd_addr[`NCPU_AW-1:0], ibus_out_id_nxt[`NCPU_AW-1:0]);
   // Transfer when handshaked with downstream module
   ncpu32k_cell_dff_lr #(`NCPU_AW, `NCPU_ERST_VECTOR) dff_id
                   (clk,rst_n, hds_ibus_dout, ibus_out_id_nxt_bypass, ibus_out_id[`NCPU_AW-1:0]);

   ////////////////////////////////////////////////////////////////////////////////
                   
   // TLB
   wire [`NCPU_AW-1:0] tlb_addr;

   ncpu32k_cell_dff_lr #(`NCPU_AW) dff_tlb
                   (clk,rst_n, tlb_read, ibus_cmd_addr[`NCPU_AW-1:0], tlb_addr[`NCPU_AW-1:0]);

   assign icache_cmd_addr = tlb_addr;
   
   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if(ibus_cmd_flush & ~hds_ibus_cmd)
         $fatal (0, "\n ibus cmd port should be handshaked when flushing.\n");
   end
`endif

endmodule
