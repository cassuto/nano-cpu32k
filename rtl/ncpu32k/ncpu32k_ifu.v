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

module ncpu32k_ifu
   #(
      parameter [`NCPU_AW-1:0] CONFIG_ERST_VECTOR,
      parameter CONFIG_IBUS_OUTSTANTING_LOG2
   )
   (
      input                      clk,
      input                      rst_n,
      // I-Bus Master
      input                      ibus_AREADY,
      output                     ibus_AVALID,
      output [`NCPU_AW-1:0]      ibus_AADDR,
      output                     ibus_BREADY,
      input                      ibus_BVALID,
      input [`NCPU_IW-1:0]       ibus_BDATA,
      input [1:0]                ibus_BEXC,
      // IRQ
      input                      irqc_intr_sync,
      // Flush
      input                      flush,
      input [`NCPU_AW-3:0]       flush_tgt,
      // to DISPATCH
      input                      idu_AREADY,
      output                     idu_AVALID,
      output [`NCPU_IW-1:0]      idu_insn,
      output [`NCPU_AW-3:0]      idu_pc,
      output [2:0]               idu_exc, // 0: D-TLB Miss; 1: Data Page Fault; 2: IRQ
      output [`NCPU_AW-3:0]      idu_pred_tgt,
      // BPU
      output [`NCPU_AW-3:0]      bpu_insn_pc,
      input                      bpu_pred_taken,
      input [`NCPU_AW-3:0]       bpu_pred_tgt
   );

   localparam OUTST_DW = `NCPU_AW-2 + `NCPU_AW-2;
   localparam FLS_IDLE = 2'b00;
   localparam FLS_PENDING = 2'b01;
   localparam FLS_BLOCKING = 2'b11;

   wire                          outst_push;
   wire                          outst_pop;
   wire                          outst_full;
   wire [OUTST_DW-1:0]           outst_din;
   wire [OUTST_DW-1:0]           outst_dout;
   wire                          outst_empty;
   wire                          outst_almost_empty;
   wire [`NCPU_AW-3:0]           fnt_PC_r;
   wire [`NCPU_AW-3:0]           fnt_PC_nxt;
   wire [`NCPU_AW-3:0]           fnt_fetch_PC;
   wire [`NCPU_AW-3:0]           fnt_pred_tgt;
   wire [`NCPU_AW-3:0]           bck_pc;
   wire [`NCPU_AW-3:0]           bck_pred_tgt;
   wire [1:0]                    flush_state_r;
   wire [1:0]                    flush_state_nxt;
   wire                          flush_tgt_en;
   wire [`NCPU_AW-3:0]           flush_tgt_r;
   wire                          discard_B;

   // Outstanding buffer
   ncpu32k_fifo_sclk
      #(
         .DW           (OUTST_DW),
         .DEPTH_WIDTH  (CONFIG_IBUS_OUTSTANTING_LOG2),
         .FWFT         (1),
         .N_PROG_EMPTY (2)
      )
   FIFO_OUTSTANDING
      (
         .CLK           (clk),
         .RST_N         (rst_n),
         // Push port
         .PUSH          (outst_push),
         .DIN           (outst_din),
         .FULL          (outst_full),
         // Pop port
         .POP           (outst_pop),
         .DOUT          (outst_dout),
         .EMPTY         (outst_empty),
         .PROG_EMPTY    (outst_almost_empty)
      );

   assign outst_push = ibus_AREADY & ibus_AVALID;
   assign outst_din = {ibus_AADDR[`NCPU_AW-1:2], fnt_pred_tgt};

   assign ibus_AVALID = ~outst_full & (flush_state_r != FLS_BLOCKING);
   assign ibus_AADDR = {fnt_fetch_PC[`NCPU_AW-3:0], 2'b00};
   assign bpu_insn_pc = fnt_fetch_PC;

   assign outst_pop = ibus_BVALID & ibus_BREADY;
   assign {bck_pc[`NCPU_AW-3:0], bck_pred_tgt} = outst_dout;

   // Discard incoming B-packets when flushing
   assign discard_B = flush | (flush_state_r != FLS_IDLE);

   // Forward the handshake signals to the upstream module.
   assign ibus_BREADY = idu_AREADY | discard_B;
   assign idu_AVALID = ibus_BVALID & ~discard_B;

   assign idu_insn = ibus_BDATA;
   assign idu_pc = bck_pc;
   assign idu_exc = {irqc_intr_sync, ibus_BEXC[1:0]};
   assign idu_pred_tgt = bck_pred_tgt;

   // FSM for flushing
   assign flush_state_nxt = (flush_state_r == FLS_IDLE) ?
                              // A flush strobe is issued. The slave module has accepted the A-packet,
                              // but there are previous transactions staying in outstanding FIFO,
                              // So we need to discard them one by one (Drain Out)
                              (flush & outst_push & ~outst_empty) ? FLS_BLOCKING
                              // A flush strobe is issued. No response from the slave module, waiting for it.
                              : (flush & ~outst_push) ? FLS_PENDING
                              : flush_state_r

                           : (flush_state_r == FLS_PENDING) ?
                              // The slave module has accepted the A-packet, and there are no any previous transactions.
                              (outst_push & outst_empty) ? FLS_IDLE
                              // The slave module has accepted the A-packet but there are previous transactions to discard.
                              : outst_push & ~outst_empty ? FLS_BLOCKING
                              // No response from the slave module, waiting for it.
                              : flush_state_r

                           : (flush_state_r == FLS_BLOCKING) ?
                              // Merely 2 elements remained in the FIFO. In the next beat, there will be only one left,
                              // which is corresponding to our expected B-packet response.
                              outst_almost_empty & outst_pop ? FLS_IDLE
                              : flush_state_r
                           : flush_state_r
                           ;

   assign flush_tgt_en = (flush_state_r==FLS_IDLE) & (flush_state_nxt==FLS_PENDING);

   assign fnt_fetch_PC = (flush_state_r == FLS_PENDING) ? flush_tgt_r
                  : flush ? flush_tgt
                  // Speculative execution
                  : bpu_pred_taken ? bpu_pred_tgt
                  // Normally fetch the next insn
                  : fnt_PC_r;

   assign fnt_PC_nxt = fnt_fetch_PC + 1'b1;

   // Maintain the next value of PC for speculative execution
   assign fnt_pred_tgt = ((flush_state_r == FLS_PENDING) | flush | ~bpu_pred_taken) ? fnt_PC_nxt
                           : bpu_pred_tgt;

   // D Flip flops
   nDFF_r #(2, FLS_IDLE) dff_bck_flush_state_r
     (clk,rst_n, flush_state_nxt, flush_state_r);
   nDFF_lr #(`NCPU_AW-2) dff_bck_flush_tgt_r
     (clk,rst_n, flush_tgt_en, flush_tgt, flush_tgt_r);
   nDFF_lr #(`NCPU_AW-2, CONFIG_ERST_VECTOR[`NCPU_AW-1:2]) dff_fnt_PC_r
     (clk,rst_n, outst_push, fnt_PC_nxt, fnt_PC_r);

   // synthesis translate_off
`ifndef SYNTHESIS
 `include "ncpu32k_assert.h"

   // Assertions
 `ifdef NCPU_ENABLE_ASSERT

   always @(posedge clk)
      begin
         // This assertion will fail if another exception raised while we're in flushing.
         if(flush & (flush_state_r != FLS_IDLE))
            $fatal("\n While IFU is in the state of unfinished flushing, it received a new flushing request. The request will not be accepted\n");
      end

 `endif

`endif
// synthesis translate_on

endmodule
