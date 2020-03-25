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
   input                   ibus_valid, /* Insn is presented at immu's output */
   output                  ibus_ready, /* ifu is ready to accepted Insn */
   input [`NCPU_IW-1:0]    ibus_dout,
   input                   ibus_cmd_ready, /* ibus is ready to accept cmd */
   output                  ibus_cmd_valid, /* cmd is presented at ibus'input */
   output [`NCPU_AW-1:0]   ibus_cmd_addr,
   input [`NCPU_AW-1:0]    ibus_out_id, /* address of data preseted at ibus_dout */
   input [`NCPU_AW-1:0]    ibus_out_id_nxt,
   output                  ibus_flush_req,
   input                   ibus_flush_ack,
   input                   exp_imm_tlb_miss,
   input                   exp_imm_page_fault,
   input                   irqc_intr_sync,
   input [`NCPU_DW-1:0]    bpu_msr_epc,
   input [`NCPU_AW-3:0]    ifu_flush_jmp_tgt,
   input                   specul_flush,
   output                  specul_flush_ack,
   input                   idu_in_ready, /* idu is ready to accepted Insn */
   output                  idu_in_valid, /* Insn is prestented at idu's input */
   output [`NCPU_IW-1:0]   idu_insn,
   output [`NCPU_AW-3:0]   idu_insn_pc,
   output                  idu_jmprel_link,
   output                  idu_op_jmprel,
   output                  idu_op_jmpfar,
   output                  idu_op_syscall,
   output                  idu_op_ret,
   output                  idu_specul_jmpfar,
   output [`NCPU_AW-3:0]   idu_specul_tgt,
   output                  idu_specul_jmprel,
   output                  idu_specul_bcc, /* = MSR.PSR.CC in prediction. not taken */
   output                  idu_specul_extexp,
   output                  idu_let_lsa_pc,
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
   wire                    op_syscall;
   wire                    op_ret;
   wire                    specul_jmp;
   
   wire extexp_taken;
   wire hds_ibus_dout = ibus_valid & ibus_ready;
   wire hds_idu = (idu_in_valid & idu_in_ready);
   
   // Predecoder
   ncpu32k_ipdu predecoder
      (
         .clk           (clk),
         .rst_n         (rst_n),
         .ipdu_insn     (insn),
         .bpu_taken     (bpu_jmprel_taken),
         .valid         (hds_ibus_dout & ~extexp_taken),
         .jmprel_taken  (jmprel_taken),
         .jmprel_offset (jmprel_offset),
         .jmprel_link   (jmprel_link_nxt),
         .op_bcc        (op_bcc),
         .op_bt         (op_bt),
         .op_jmpfar     (op_jmpfar_nxt),
         .op_jmprel     (op_jmprel_nxt),
         .op_syscall    (op_syscall),
         .op_ret        (op_ret)
       );
   
   // Reset control
   wire[2:0] reset_cnt;
   wire[2:0] reset_cnt_nxt;
   wire reset_cnt_ld;
   ncpu32k_cell_dff_lr #(3) dff_reset_cnt
                   (clk,rst_n, reset_cnt_ld, reset_cnt_nxt[2:0], reset_cnt[2:0]);
   
   assign reset_cnt_ld = ~reset_cnt[1];
   assign reset_cnt_nxt = reset_cnt + 1'b1;
   
   
   // The folowing signals are for flush only
   wire [`NCPU_AW-3:0] flush_insn_pc = ibus_out_id[`NCPU_AW-1:2];
   wire [`NCPU_AW-3:0] flush_next_tgt = ibus_out_id[`NCPU_AW-1:2] + 1'b1;
   
   // Branching target
   wire [`NCPU_AW-3:0] flush_jmpfar_tgt;
   wire [`NCPU_AW-3:0] flush_jmprel_tgt_org;
   wire [`NCPU_AW-3:0] flush_jmprel_tgt;
   
   // Extrnal Exceptions
   assign extexp_taken = (exp_imm_tlb_miss | exp_imm_page_fault | irqc_intr_sync) & hds_ibus_dout;
   // Internal and Extrnal Exceptions. Assert (03071429)
   wire exp_taken = op_syscall | extexp_taken;
   // Let ELSA = PC(Virtual Address)
   wire let_lsa_pc_nxt = (exp_imm_tlb_miss | exp_imm_page_fault);
   // MUX (03060653)
   wire [`NCPU_VECT_DW-1:0] exp_vector =
      (
         ({`NCPU_VECT_DW{op_syscall}} & `NCPU_ESYSCALL_VECTOR) |
         (
            // IRQ takes precedence over TLB
            irqc_intr_sync ? `NCPU_EIRQ_VECTOR :
            (
               ({`NCPU_VECT_DW{exp_imm_tlb_miss}} & `NCPU_EITM_VECTOR) |
               ({`NCPU_VECT_DW{exp_imm_page_fault}} & `NCPU_EIPF_VECTOR)
            )
         )
      );
   wire [`NCPU_AW-3:0] flush_exp_vect_tgt = {{`NCPU_AW-2-`NCPU_VECT_DW{1'b0}}, exp_vector[`NCPU_VECT_DW-1:2]};
   
   // Speculative execution
   assign specul_jmp = bpu_jmprel | op_jmpfar_nxt;
   assign bpu_rd = specul_jmp;
   assign bpu_jmprel = op_bcc;
   assign bpu_insn_pc = flush_insn_pc;
   
   wire [`NCPU_AW-3:0] specul_tgt_nxt =
      (
           bpu_jmprel ?
            // for jmprel, this is alternate target for failed SE
            // if prediction is _not taken_ , then use the contrary target
            (bpu_jmprel_taken ? flush_next_tgt : flush_jmprel_tgt_org)
         : op_jmpfar_nxt ?
            // for jmpfar, this is the predicated target,
            // consistent with BPU result
            flush_jmpfar_tgt
         : exp_taken ?
            // for exception call, this is vector address
            flush_exp_vect_tgt
         : op_ret ?
            // for ret, this is the predicated target,
            // consistent with BPU result
            bpu_msr_epc[`NCPU_AW-1:2]
         : {`NCPU_AW-2{1'b0}}
      );
   // calc out predicted CC flag
   wire specul_bcc_nxt = (bpu_jmprel_taken & op_bt | (~bpu_jmprel_taken & op_bcc & ~op_bt));
   
   // Pipeline
   localparam ENABLE_BYPASS = `NCPU_PIPEBUF_BYPASS;
   wire fetch_ready;
   
   //
   // Equivalent to 1-slot FIFO
   //
   wire valid_nxt = (hds_ibus_dout | ~hds_idu);
   
   ncpu32k_cell_dff_lr #(1) dff_out_valid
                   (clk,rst_n, (hds_ibus_dout | hds_idu), valid_nxt, idu_in_valid);
   
   generate
      if (ENABLE_BYPASS) begin :enable_bypass
         assign fetch_ready = ~idu_in_valid | hds_idu;
      end else begin
         assign fetch_ready = ~idu_in_valid;
      end
   endgenerate
   
   wire pipebuf_cas = hds_ibus_dout;
   
   assign flush_jmpfar_tgt = bpu_jmp_tgt;
   assign flush_jmprel_tgt_org = flush_insn_pc + jmprel_offset;
   assign flush_jmprel_tgt = (jmprel_taken ? flush_jmprel_tgt_org : flush_next_tgt);
   
   // Program Counter Register
   // priority MUX
   // Note that _nxt and flush_ are reusing the same port 
   assign pc_addr_nxt = specul_flush ? ifu_flush_jmp_tgt
                           : op_syscall ? flush_exp_vect_tgt
                           : op_ret ? bpu_msr_epc[`NCPU_AW-1:2]
                           : op_jmpfar_nxt ? flush_jmpfar_tgt
                           : op_jmprel_nxt ? flush_jmprel_tgt
                           : ibus_out_id_nxt[`NCPU_AW-1:2] + 1'b1; /* Non flush */

   assign ibus_flush_req = specul_flush | op_syscall | op_ret | op_jmpfar_nxt | op_jmprel_nxt;
   
   assign specul_flush_ack = ibus_flush_ack;
   
`ifdef NCPU_HANDSHAKE_NOT_ALWAYS_SUCCEED_WHEN_FLUSHING
   // FMS to maintain ibus_cmd_addr
   wire fls_status_r;
   wire fls_status_nxt;
   ncpu32k_cell_dff_r #(1) dff_fls_status
                   (clk,rst_n, fls_status_nxt, fls_status_r);

   assign fls_status_nxt = (
         // in specul_flush there is no need to hold addr
         (~fls_status_r & ibus_flush_req & ~specul_flush) ? 1'b1
         : (fls_status_r & ibus_flush_ack) ? 1'b0
         : fls_status_r
      );
   // Indicate whether to hold the ibus_cmd_addr
   wire fls_hld_addr = fls_status_r & ~ibus_flush_ack; // bypass ack
   
   wire [`NCPU_AW-1:0] fls_addr_r;
   wire [`NCPU_AW-1:0] fls_addr_nxt;
   ncpu32k_cell_dff_lr #(`NCPU_AW) dff_fls_addr_r
                   (clk,rst_n, ~fls_hld_addr, fls_addr_nxt[`NCPU_AW-1:0], fls_addr_r[`NCPU_AW-1:0]);

   assign fls_addr_nxt = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
                           
   assign ibus_cmd_addr = fls_hld_addr ? fls_addr_r : fls_addr_nxt;
`else
   wire fls_hld_addr = 1'b0;
   assign ibus_cmd_addr = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
`endif
   
   assign ibus_cmd_valid = reset_cnt[1];
   assign ibus_ready = (~fls_hld_addr) & fetch_ready & reset_cnt[1];
   
   assign insn = ibus_dout;
   
   // If extrnal exception raised, then ignore any instruction.
   // Because if we issued the insn that not only _writes MSR_ but also _raises exception_
   // even the insn was in speculative exception, both of these aspects would set
   // WriteEnable signal of MSR at _IEU stage_ and make conflict.
   // Note that 'ret' is a special exception.
   wire not_flushing = ~(specul_flush | extexp_taken);
   wire not_flushing_extexp = ~(specul_flush);

   // Data path: no need to flush
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_idu_insn_pc
                   (clk,rst_n, pipebuf_cas, flush_insn_pc[`NCPU_AW-3:0], idu_insn_pc[`NCPU_AW-3:0]);
   ncpu32k_cell_dff_lr #(`NCPU_AW-2) dff_idu_specul_tgt
                   (clk,rst_n, pipebuf_cas, specul_tgt_nxt, idu_specul_tgt[`NCPU_AW-3:0]);
  
   // Control path
   ncpu32k_cell_dff_lr #(`NCPU_IW) dff_idu_insn
                   (clk,rst_n, pipebuf_cas, insn & {`NCPU_IW{not_flushing}}, idu_insn);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_jmprel
                   (clk,rst_n, pipebuf_cas, op_jmprel_nxt & not_flushing, idu_op_jmprel);
   ncpu32k_cell_dff_lr #(1) dff_idu_jmprel_link
                   (clk,rst_n, pipebuf_cas, jmprel_link_nxt & not_flushing, idu_jmprel_link);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_jmpfar
                   (clk,rst_n, pipebuf_cas, op_jmpfar_nxt & not_flushing, idu_op_jmpfar);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_ret
                   (clk,rst_n, pipebuf_cas, op_ret & not_flushing, idu_op_ret);
   ncpu32k_cell_dff_lr #(1) dff_idu_op_syscall
                   (clk,rst_n, pipebuf_cas, op_syscall & not_flushing, idu_op_syscall);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_jmpfar
                   (clk,rst_n, pipebuf_cas, specul_jmp & op_jmpfar_nxt & not_flushing, idu_specul_jmpfar);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_jmprel
                   (clk,rst_n, pipebuf_cas, specul_jmp & op_jmprel_nxt & not_flushing, idu_specul_jmprel);
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_bcc
                   (clk,rst_n, pipebuf_cas, specul_bcc_nxt & not_flushing, idu_specul_bcc);
      // Yes, even external exceptions could be flushed
   ncpu32k_cell_dff_lr #(1) dff_idu_specul_extexp
                   (clk,rst_n, pipebuf_cas, extexp_taken & not_flushing_extexp, idu_specul_extexp);
   ncpu32k_cell_dff_lr #(1) dff_idu_set_lsa_pc
                   (clk,rst_n, pipebuf_cas, let_lsa_pc_nxt & not_flushing_extexp, idu_let_lsa_pc);

   // synthesis translate_off
`ifndef SYNTHESIS                   
   `include "ncpu32k_assert.h"
   
   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if(ibus_ready & op_jmpfar_nxt & op_jmprel_nxt)
         $fatal ("\n 'op_jmpfar_nxt' and 'jmprel_taken' should be mutex\n");
   end
`endif

   // Assertions 03060653
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if(exp_taken & count_1({op_syscall,exp_imm_tlb_miss,exp_imm_page_fault})>1)
         $fatal ("\n ctrls of 'exp_vector' should be mutex\n");
   end
`endif

   // Assertions 03071429
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if ((op_syscall|extexp_taken) &
          ~(op_syscall^extexp_taken))
         $fatal ("\n ctrls of 'exp_taken' should be mutex\n");
   end
`endif

   // For Debugging only
   wire [`NCPU_AW-1:0] idu_insn_pc_w = {idu_insn_pc[`NCPU_AW-3:0],2'b0};

`endif
   // synthesis translate_on
   
endmodule
