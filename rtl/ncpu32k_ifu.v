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
   input                   msr_psr_cc,
   input [`NCPU_AW-3:0]    ifu_flush_jmp_tgt,
   input                   specul_flush,
   input                   idu_in_ready, /* idu is ready to accepted Insn */
   output                  idu_in_valid, /* Insn is prestented at idu's input */
   output [`NCPU_IW-1:0]   idu_insn,
   output [`NCPU_AW-3:0]   idu_insn_pc,
   output                  idu_jmprel_link,
   output                  idu_op_jmprel,
   output                  idu_op_jmpfar,
   output                  idu_specul_jmpfar,
   output [`NCPU_AW-3:0]   idu_specul_tgt,
   output                  idu_specul_jmprel,
   output                  idu_specul_bcc, /* = MSR.PSR.CC in prediction. not taken */
   output                  bpu_rd,
   output                  bpu_jmprel,
   output [`NCPU_AW-3:0]   bpu_insn_pc,
   input [`NCPU_AW-3:0]    bpu_jmp_tgt,
   input                   bpu_jmprel_taken
);

   wire [`NCPU_AW-3:0]     pc_addr_nxt;
   wire [`NCPU_IW-1:0]     insn;
   wire                    jmprel_taken;
   wire [`NCPU_AW-3:0]     jmprel_offset;
   wire                    jmprel_link_nxt;
   wire                    op_bcc;
   wire                    op_bt;
   wire                    op_jmprel_nxt;
   wire                    op_jmpfar_nxt;
   wire                    specul;
   
   // Predecoder
   ncpu32k_ipdu predecoder
      (
         .clk           (clk),
         .rst_n         (rst_n),
         .ipdu_insn     (insn),
         .bpu_taken     (bpu_jmprel_taken),
         .jmprel_taken  (jmprel_taken),
         .jmprel_offset (jmprel_offset),
         .jmprel_link   (jmprel_link_nxt),
         .op_bcc        (op_bcc),
         .op_bt         (op_bt),
         .op_jmpfar     (op_jmpfar_nxt),
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
   
   // Branching target
   wire [`NCPU_AW-3:0] jmpfar_tgt;
   wire [`NCPU_AW-3:0] jmprel_tgt_org;
   wire [`NCPU_AW-3:0] jmprel_tgt;
   wire [`NCPU_AW-3:0] fetch_next_tgt;
   
   // Speculative execution
   assign specul = bpu_jmprel | op_jmpfar_nxt;
   assign bpu_rd = specul;
   assign bpu_jmprel = op_bcc & jmprel_taken;
   assign bpu_insn_pc = ibus_out_id[`NCPU_AW-1:2];
   
   wire [`NCPU_AW-3:0] specul_tgt_nxt = 
      (
         bpu_jmprel ?
            // for jmprel, this is alternate target for failed SE
            // if prediction is _not taken_ , then use the contrary target
            (bpu_jmprel_taken ? fetch_next_tgt : jmprel_tgt_org)
            // for jmpfar, this is the predicated target,
            // which should be consistent with prediction result
            : jmpfar_tgt
      );
   // calc out predicted CC flag
   wire specul_bcc_nxt = bpu_jmprel_taken & (op_bt | ~(op_bcc & ~op_bt));
   
   // Pipeline
   wire pipebuf_cas;
   
   ncpu32k_cell_pipebuf #(`NCPU_IW) pipebuf_ifu
      (
         .clk        (clk),
         .rst_n      (rst_n),
         .din        (),
         .dout       (),
         .in_valid   (ibus_out_valid),
         .in_ready   (fetch_ready),
         .out_valid  (idu_in_valid),
         .out_ready  (idu_in_ready),
         .cas        (pipebuf_cas)
      );
   
   assign jmpfar_tgt = bpu_jmp_tgt;
   assign jmprel_tgt_org = ibus_out_id[`NCPU_AW-1:2] + jmprel_offset;
   assign jmprel_tgt = (bpu_jmprel_taken ? jmprel_tgt_org : fetch_next_tgt);
   assign fetch_next_tgt = (ibus_out_id[`NCPU_AW-1:2] + 1'b1);
   
   wire fetch_next = !op_jmpfar_nxt & !jmprel_taken & !specul_flush;
   
   // Program Counter Register
   assign pc_addr_nxt = ({`NCPU_AW-2{op_jmpfar_nxt}} & jmpfar_tgt) |
                        ({`NCPU_AW-2{jmprel_taken}} & jmprel_tgt) |
                        ({`NCPU_AW-2{specul_flush}} & ifu_flush_jmp_tgt) |
                        ({`NCPU_AW-2{fetch_next}} & fetch_next_tgt);

   assign ibus_addr_o = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
   assign insn = ibus_o;
   
   wire not_flushing = ~specul_flush;
   
   // Data path: no need to flush
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_idu_insn_pc
                   (clk,rst_n, pipebuf_cas, ibus_out_id[`NCPU_AW-1:2], idu_insn_pc[`NCPU_AW-3:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_idu_specul_tgt
                   (clk,rst_n, pipebuf_cas, specul_tgt_nxt, idu_specul_tgt[`NCPU_AW-3:0]);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_bcc
                   (clk,rst_n, pipebuf_cas, specul_bcc_nxt, idu_specul_bcc);
   // Control path
   ncpu32k_cell_dff_lr #(`NCPU_IW) dff_idu_insn
                   (clk,rst_n, pipebuf_cas, insn & {`NCPU_IW{not_flushing}}, idu_insn);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_jmprel
                   (clk,rst_n, pipebuf_cas, op_jmprel_nxt & not_flushing, idu_op_jmprel);
   ncpu32k_cell_dff_lr #(1) dff_idu_jmprel_link
                   (clk,rst_n, pipebuf_cas, jmprel_link_nxt & not_flushing, idu_jmprel_link);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_jmpfar
                   (clk,rst_n, pipebuf_cas, op_jmpfar_nxt & not_flushing, idu_op_jmpfar);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_jmpfar
                   (clk,rst_n, pipebuf_cas, specul & op_jmpfar_nxt & not_flushing, idu_specul_jmpfar);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_jmprel
                   (clk,rst_n, pipebuf_cas, specul & op_jmprel_nxt & not_flushing, idu_specul_jmprel);

endmodule
