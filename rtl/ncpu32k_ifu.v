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

module ncpu32k_ifu(         
   input                   clk,
   input                   rst_n,
   input                   ibus_out_valid, /* Insn is presented at ibus */
   output                  ibus_out_ready, /* ifu is ready to accepted Insn */
   output [`NCPU_AW-1:0]   ibus_addr_o,
   input [`NCPU_IW-1:0]    ibus_o,
   input [`NCPU_AW-1:0]    ibus_out_id, /* address of data preseted at ibus_o */
   input                   ifu_jmpfar,
   input [`NCPU_AW-3:0]    ifu_jmpfar_addr,
   input                   ifu_jmp_ready,
   input                   msr_psr_cc,
   input                   idu_in_ready, /* idu is ready to accepted Insn */
   output                  idu_in_valid, /* Insn is prestented at idu's input */
   output [`NCPU_IW-1:0]   idu_insn,
   output [`NCPU_AW-3:0]   idu_insn_pc,
   output                  idu_jmprel_link,
   output                  idu_op_jmprel
);

   wire [`NCPU_AW-3:0]  pc_addr_nxt;
   wire [`NCPU_IW-1:0]  insn;
   wire                 jmprel_taken;
   wire [`NCPU_AW-3:0]  jmprel_offset;
   wire                 jmprel_link_nxt;
   wire                 op_jmprel_nxt;
   
   // Predecoder
   ncpu32k_ipdu predecoder
      (
         .clk           (clk),
         .rst_n         (rst_n),
         .ipdu_insn     (insn),
         .msr_psr_cc    (msr_psr_cc),
         .jmprel_taken  (jmprel_taken),
         .jmprel_offset (jmprel_offset),
         .jmprel_link   (jmprel_link_nxt),
         .op_jmprel     (op_jmprel_nxt)
       );
   
   wire fetch_ready;
   
   // Reset control
   wire[2:0] reset_cnt;
   wire[2:0] reset_cnt_nxt;
   wire reset_cnt_ld;
   ncpu32k_cell_dff_lr #(3) dff_reset_cnt
                   (clk,rst_n, reset_cnt_ld, reset_cnt_nxt[2:0], reset_cnt[2:0]);
   
   assign reset_cnt_ld = ~reset_cnt[1];
   assign reset_cnt_nxt = reset_cnt + 1'b1;
   
   assign ibus_out_ready = fetch_ready & reset_cnt[1];
   
   // Pipeline
   wire pipebuf_cas;
   wire [`NCPU_IW-1:0]  idu_insn_w;
   wire [`NCPU_AW-3:0]  idu_insn_pc_w;
   wire                 idu_op_jmprel_w;
   wire                 idu_jmprel_link_w;
   
   ncpu32k_cell_pipebuf #(`NCPU_IW) pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (insn),
         .dout       (idu_insn_w),
         .in_valid   (ibus_out_valid),
         .in_ready   (fetch_ready),
         .out_valid  (idu_in_valid),
         .out_ready  (idu_in_ready),
         .cas        (pipebuf_cas)
      );
   
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_idu_insn_pc
                   (clk,rst_n, pipebuf_cas, ibus_out_id[`NCPU_AW-1:2], idu_insn_pc_w[`NCPU_AW-3:0]);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_jmprel
                   (clk,rst_n, pipebuf_cas, op_jmprel_nxt, idu_op_jmprel_w);
   ncpu32k_cell_dff_lr #(1) dff_idu_jmprel_link
                   (clk,rst_n, pipebuf_cas, jmprel_link_nxt, idu_jmprel_link_w);

   assign idu_insn = /*{`NCPU_IW{idu_in_valid}} &*/ idu_insn_w;
   assign idu_insn_pc = idu_insn_pc_w;
   assign idu_op_jmprel = idu_in_valid & idu_op_jmprel_w;
   assign idu_jmprel_link = idu_in_valid & idu_jmprel_link_w;
   
   // Program Counter Register
   assign pc_addr_nxt = ifu_jmpfar
                  ? ifu_jmpfar_addr
                  : jmprel_taken
                     ? ibus_out_id[`NCPU_AW-1:2] + jmprel_offset
                     : ibus_out_id[`NCPU_AW-1:2] + 1'b1;

   assign ibus_addr_o = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
   assign insn = ibus_o;

endmodule
