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

module ncpu32k_frontend
   #(
      parameter [`NCPU_AW-1:0] CONFIG_ERST_VECTOR
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_IBUS_DW
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_IBUS_BYTES_LOG2
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_IBUS_AW
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_ICACHE_P_LINE
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_ICACHE_P_SETS
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_ICACHE_P_WAYS
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_ITLB_NSETS_LOG2
      `PARAM_NOT_SPECIFIED , // (2^CONFIG_ITLB_NSETS_LOG2) entries
      parameter CONFIG_IMMU_PAGE_SIZE_LOG2
      `PARAM_NOT_SPECIFIED , // = log2(Size of page in bytes)
      parameter CONFIG_GSHARE_PHT_NUM_LOG2
      `PARAM_NOT_SPECIFIED ,
      parameter CONFIG_BTB_NUM_LOG2
      `PARAM_NOT_SPECIFIED ,
      parameter BPU_UPD_DW
      `PARAM_NOT_SPECIFIED
   )
   (
      input                      clk,
      input                      rst_n,
      // I-Bus Master
      input                      ibus_ARREADY,
      output                     ibus_ARVALID,
      output [CONFIG_IBUS_AW-1:0] ibus_ARADDR,
      output                     ibus_RREADY,
      input                      ibus_RVALID,
      input [CONFIG_IBUS_DW-1:0] ibus_RDATA,
      // Flush
      input                      flush,
      input [`NCPU_AW-3:0]       flush_tgt,
      input                      stall_fnt,
      output                     icinv_stall,
      // to IDU
      output                     idu_1_insn_vld,
      output [`NCPU_IW-1:0]      idu_1_insn,
      output [`NCPU_AW-3:0]      idu_1_pc,
      output [`NCPU_AW-3:0]      idu_1_pc_4,
      output [BPU_UPD_DW-1:0]    idu_1_bpu_upd,
      output                     idu_1_EITM,
      output                     idu_1_EIPF,
      output                     idu_2_insn_vld,
      output [`NCPU_IW-1:0]      idu_2_insn,
      output [`NCPU_AW-3:0]      idu_2_pc,
      output [`NCPU_AW-3:0]      idu_2_pc_4,
      output [BPU_UPD_DW-1:0]    idu_2_bpu_upd,
      output                     idu_2_EITM,
      output                     idu_2_EIPF,
      output [`NCPU_AW-3:0]      idu_bpu_pc_nxt,
      // WB
      input                      bpu_wb,
      input                      bpu_wb_is_bcc,
      input                      bpu_wb_is_breg,
      input                      bpu_wb_taken,
      input [`NCPU_AW-3:0]       bpu_wb_pc,
      input [`NCPU_AW-3:0]       bpu_wb_pc_nxt_act,
      input [BPU_UPD_DW-1:0]     bpu_wb_upd,

      // PSR
      input                      msr_psr_imme,
      input                      msr_psr_rm,
      // IMMID
      output [`NCPU_DW-1:0]      msr_immid,
      // TLBL
      input [`NCPU_TLB_AW-1:0]   msr_imm_tlbl_idx,
      input [`NCPU_DW-1:0]       msr_imm_tlbl_nxt,
      input                      msr_imm_tlbl_we,
      // TLBH
      input [`NCPU_TLB_AW-1:0]   msr_imm_tlbh_idx,
      input [`NCPU_DW-1:0]       msr_imm_tlbh_nxt,
      input                      msr_imm_tlbh_we,
      // ICID
      output [`NCPU_DW-1:0]      msr_icid,
      // ICINV
      input [`NCPU_DW-1:0]       msr_icinv_nxt,
      input                      msr_icinv_we
   );

   wire                          ic_re;
   wire [`NCPU_AW-3:0]           fls_tgt_r, fls_tgt_byp;
   wire                          fls_state_r, fls_byp;
   reg                           fls_state_nxt;
   wire [`NCPU_AW-3:0]           pc_r, pc_nxt;
   wire [`NCPU_AW-3:0]           fetch_pc;
   wire [`NCPU_AW-3:0]           fetch_pc_4;
   wire [`NCPU_AW-3:0]           fetch_pc_8;
   wire [`NCPU_AW-1:0]           fetch_vaddr;
   wire                          fetch_insn_1_vld;
   wire                          fetch_insn_2_vld;
   wire                          fetch_insn_1_vld_r;
   wire                          fetch_insn_2_vld_r;
   wire [`NCPU_AW-3:0]           insn_1_pc;
   wire [`NCPU_AW-3:0]           insn_2_pc, insn_2_pc_4;
   wire [`NCPU_IBW-1:0]          insn_pkt;
   wire                          insn_pkt_vld;
   wire                          insn_pkt_rdy;
   wire                          idu_1_insn_rdy;
   wire                          idu_2_insn_rdy;
   wire                          stall_pc;
   wire [`NCPU_AW-CONFIG_IMMU_PAGE_SIZE_LOG2-1:0] tlb_ppn;
   wire [`NCPU_AW-3:0]           bpu_pred_pc_nxt [1:0];
   wire                          mmu_EITM;
   wire                          mmu_EIPF;
   wire                          idu_1_jmprel;
   wire                          idu_2_jmprel;
   wire [`NCPU_AW-3:0]           idu_1_jmprel_tgt;
   wire [`NCPU_AW-3:0]           idu_2_jmprel_tgt;

   ncpu32k_immu
      #(
         .CONFIG_ITLB_NSETS_LOG2       (CONFIG_ITLB_NSETS_LOG2),
         .CONFIG_IMMU_PAGE_SIZE_LOG2   (CONFIG_IMMU_PAGE_SIZE_LOG2)
      )
   I_MMU
      (
         .clk                    (clk),
         .rst_n                  (rst_n),
         .re                     (ic_re),
         .vpn                    (fetch_vaddr[`NCPU_AW-1:CONFIG_IMMU_PAGE_SIZE_LOG2]),
         .ppn                    (tlb_ppn),
         .EITM                   (mmu_EITM),
         .EIPF                   (mmu_EIPF),
         .msr_psr_imme           (msr_psr_imme),
         .msr_psr_rm             (msr_psr_rm),
         .msr_immid              (msr_immid),
         .msr_imm_tlbl_idx       (msr_imm_tlbl_idx),
         .msr_imm_tlbl_nxt       (msr_imm_tlbl_nxt),
         .msr_imm_tlbl_we        (msr_imm_tlbl_we),
         .msr_imm_tlbh_idx       (msr_imm_tlbh_idx),
         .msr_imm_tlbh_nxt       (msr_imm_tlbh_nxt),
         .msr_imm_tlbh_we        (msr_imm_tlbh_we)
      );

   ncpu32k_icache
      #(
         .CONFIG_IBUS_DW         (CONFIG_IBUS_DW),
         .CONFIG_IBUS_BYTES_LOG2 (CONFIG_IBUS_BYTES_LOG2),
         .CONFIG_IBUS_AW         (CONFIG_IBUS_AW),
         .CONFIG_IMMU_PAGE_SIZE_LOG2 (CONFIG_IMMU_PAGE_SIZE_LOG2),
         .CONFIG_IC_AW           (`NCPU_AW),
         .CONFIG_IC_DW           (`NCPU_IBW),
         .CONFIG_IC_DW_BYTES_LOG2 (`NCPU_IBW_BYTES_LOG2),
         .CONFIG_IC_P_LINE       (CONFIG_ICACHE_P_LINE),
         .CONFIG_IC_P_SETS       (CONFIG_ICACHE_P_SETS),
         .CONFIG_IC_P_WAYS       (CONFIG_ICACHE_P_WAYS)
      )
   I_CACHE
      (
         .clk                    (clk),
         .rst_n                  (rst_n),
         .re                     (ic_re),
         .page_off               (fetch_vaddr[CONFIG_IMMU_PAGE_SIZE_LOG2-1:0]),
         .tlb_ppn                (tlb_ppn),
         .dout                   (insn_pkt),
         .dout_vld               (insn_pkt_vld),
         .dout_rdy               (insn_pkt_rdy),
         .stall_pc               (stall_pc),
         .icinv_stall            (icinv_stall),
         .msr_icid               (msr_icid),
         .msr_icinv_nxt          (msr_icinv_nxt),
         .msr_icinv_we           (msr_icinv_we),
         .ibus_ARREADY           (ibus_ARREADY),
         .ibus_ARVALID           (ibus_ARVALID),
         .ibus_ARADDR            (ibus_ARADDR),
         .ibus_RVALID            (ibus_RVALID),
         .ibus_RREADY            (ibus_RREADY),
         .ibus_RDATA             (ibus_RDATA)
      );

   assign ic_re = (~stall_pc & ~stall_fnt);

   // Flush FSM
   always @(*)
      begin
         fls_state_nxt = fls_state_r;
         if (flush)
            fls_state_nxt = ~ic_re;
         // Detect the edge where the cache is recovered from stall
         if (fls_state_r & ic_re)
            fls_state_nxt = 1'b0;
      end

   nDFF_l #(`NCPU_AW-2) dff_fls_tgt_r
      (clk, flush, flush_tgt, fls_tgt_r);

   nDFF_r #(1) dff_fls_state_r
      (clk, rst_n, fls_state_nxt, fls_state_r);

   //
   // Timing info about flush FSM while icache do not need wait
   //                  __    __    __    __ 
   // clk          ___|  |__|  |__|  |__|  |___
   //              ____________________________
   // ic_re
   //                  _____
   // flush        ___|     |__________________
   //
   // fls_state_nxt____________________________
   //
   // fls_state_r  ____________________________
   //                    ^
   //                    |
   //          Read the new insn here
   //   Current insn output remains no changed, which is
   //      flushed at the next pipeline stage.
   //
   // Note: The backend pipeline could keep flow while frontend stalling.
   // At this point, the backend will receive consecutive invalid NOP insns,
   // thus, signal `flush` will be reset after one cycle,
   // which causes incorrect behavior in flush.
   // This problem is solved by following schemes:
   //
   // Timing info about flush FSM while icache inserted stall cycles:
   //                  __    __    __    __ 
   // clk          ___|  |__|  |__|  |__|  |___
   //              ___             ____________
   // ic_re           |___________|
   //                  _____
   // flush        ___|     |__________________
   //                  ___________
   // fls_state_nxt___|           |____________
   //                        ___________
   // fls_state_r  _________|     |     |______
   //                          ^     ^
   //                          |     |
   //                          |   Read the new insn here.
   //                          |
   //               Invalidate the previous output
   //    (The previous output is invalid while icache is stalling,
   //   however, it goes valid again after the last low state of `ic_re`
   //   while `flush` has been reseted and no pipeline stage
   //   can flush it, so we invalidate it here)
   //
   //
   assign fls_byp = (fls_state_r|flush);
   assign fls_tgt_byp = fls_state_r ? fls_tgt_r : flush_tgt;

   assign idu_bpu_pc_nxt = (idu_1_jmprel)
                              ? idu_1_jmprel_tgt
                              : (idu_1_insn_rdy & (bpu_pred_pc_nxt[0] != idu_2_pc))
                                 ? bpu_pred_pc_nxt[0]
                                 : (idu_2_jmprel)
                                    ? idu_2_jmprel_tgt
                                    : (idu_2_insn_rdy & (bpu_pred_pc_nxt[1] != idu_2_pc_4))
                                       ? bpu_pred_pc_nxt[1]
                                       : pc_r;

   assign fetch_pc = (fls_byp) ? fls_tgt_byp : idu_bpu_pc_nxt;
   assign fetch_pc_4 = fetch_pc + 'd1;
   assign fetch_pc_8 = fetch_pc + 'd2;

   assign fetch_vaddr = {fetch_pc[`NCPU_AW-3:`NCPU_IBW_BYTES_LOG2-2], {`NCPU_IBW_BYTES_LOG2{1'b0}}};

   // The insn in 1st slot is valid if its PC is aligned at the boundary of insn packet,
   // Otherwise we could issue only one insn, which is in 2rd slot.
   assign fetch_insn_1_vld = (fetch_pc[`NCPU_IBW_BYTES_LOG2-2-1:0] == {`NCPU_IBW_BYTES_LOG2-2{1'b0}});
   assign fetch_insn_2_vld = 1'b1;

   assign insn_1_pc = fetch_pc;
   assign insn_2_pc = (fetch_insn_1_vld) ? fetch_pc_4 : fetch_pc;
   assign insn_2_pc_4 = (fetch_insn_1_vld) ? fetch_pc_8 : fetch_pc_4;

   assign pc_nxt = fetch_pc + {{`NCPU_AW-3{1'b0}}, fetch_insn_1_vld}
                            + {{`NCPU_AW-3{1'b0}}, fetch_insn_2_vld};

   // D Flip flops

   // Control path
   nDFF_lr #(`NCPU_AW-2, CONFIG_ERST_VECTOR[`NCPU_AW-1:2]) dff_fnt_PC_r
      (clk,rst_n, ic_re, pc_nxt, pc_r);

   nDFF_lr #(1) dff_idu_1_insn_vld
      (clk, rst_n, (ic_re|fls_state_nxt), ~fls_state_nxt & fetch_insn_1_vld, fetch_insn_1_vld_r);
   nDFF_lr #(1) dff_idu_2_insn_vld
      (clk, rst_n, (ic_re|fls_state_nxt), ~fls_state_nxt & fetch_insn_2_vld, fetch_insn_2_vld_r);

   assign idu_1_insn_vld = (insn_pkt_vld & fetch_insn_1_vld_r);
   assign idu_2_insn_vld = (insn_pkt_vld & fetch_insn_2_vld_r);

   //
   // Compared to `idu_*_insn_vld`, `idu_*_insn_rdy` keeps high
   // while icache is blocking, as long as dout is valid.
   // Use `_rdy` to determine whether flush PC.
   // Consider the following case:
   //              __    __    __    __
   // clk      ___|  |__|  |__|  |__|  |___
   //          ___             ____________
   // ic_re       |___________|
   //          ___             ____________
   // _vld        |___________|
   //          ____________________________
   // _rdy
   //           ______________ _____ _____
   // fetch_pc |__BPU_PC_nxt__|NPC_2|NPC_3|
   //
   // In which NPC 2 is the next address of BPU PC nxt.
   //
   // If `fetch_pc` is depended on `idu_*_insn_vld` (that's wrong),
   // the case will be:
   //               __    __    __    __
   // clk      ____|  |__|  |__|  |__|  |___
   //          ____             ____________
   // ic_re        |___________|
   //          ____             ____________
   // _vld         |___________|
   //          _____________________________
   // _rdy
   //           ___ ___________ ______ _____
   // fetch_pc |BPU|___NPC_1___|NPC_2 |NPC_3|
   //
   // In which BPU doesn't change the PC, beacse `pc_r` is latched
   // only if `ic_re` is high.
   //
   assign idu_1_insn_rdy = (insn_pkt_rdy & fetch_insn_1_vld_r);
   assign idu_2_insn_rdy = (insn_pkt_rdy & fetch_insn_2_vld_r);

   // Data path
   nDFF_l #(`NCPU_AW-2) dff_idu_1_pc
      (clk, ic_re, insn_1_pc, idu_1_pc);
   nDFF_l #(`NCPU_AW-2) dff_idu_2_pc
      (clk, ic_re, insn_2_pc, idu_2_pc);
   nDFF_l #(`NCPU_AW-2) dff_idu_2_pc_4
      (clk, ic_re, insn_2_pc_4, idu_2_pc_4);

   assign idu_1_pc_4 = idu_2_pc;

   // How to resolve PC in I-MMU exception:
   // 1. As the size of virtual page is the multiple of insn packet (Assert 2105021845),
   //    two insns of the packet must be on the same page.
   // 2. The code is executed sequentially, which means that the first executed insn
   //    in the packet is the cause of the exception.
   assign idu_1_EITM = (idu_1_insn_vld & mmu_EITM);
   assign idu_1_EIPF = (idu_1_insn_vld & mmu_EIPF);
   assign idu_2_EITM = (~idu_1_insn_vld & idu_2_insn_vld & mmu_EITM);
   assign idu_2_EIPF = (~idu_1_insn_vld & idu_2_insn_vld & mmu_EIPF);

   assign idu_1_insn = insn_pkt[`NCPU_IW-1:0];
   assign idu_2_insn = insn_pkt[`NCPU_IBW-1:`NCPU_IW];

   ncpu32k_bpu_gshare
      #(
         .CONFIG_PHT_NUM_LOG2 (CONFIG_GSHARE_PHT_NUM_LOG2),
         .CONFIG_BTB_NUM_LOG2 (CONFIG_BTB_NUM_LOG2)
      )
   BPU
      (
         .clk                    (clk),
         .rst_n                  (rst_n),
         .bpu_re                 (ic_re),
         .bpu_insn_pc_1          (insn_1_pc),
         .bpu_pred_pc_nxt_1      (bpu_pred_pc_nxt[0]),
         .bpu_pred_upd_1         (idu_1_bpu_upd),
         .bpu_insn_pc_2          (insn_2_pc),
         .bpu_pred_pc_nxt_2      (bpu_pred_pc_nxt[1]),
         .bpu_pred_upd_2         (idu_2_bpu_upd),
         .bpu_wb                 (bpu_wb),
         .bpu_wb_is_bcc          (bpu_wb_is_bcc),
         .bpu_wb_is_breg         (bpu_wb_is_breg),
         .bpu_wb_taken           (bpu_wb_taken),
         .bpu_wb_pc              (bpu_wb_pc),
         .bpu_wb_pc_nxt_act      (bpu_wb_pc_nxt_act),
         .bpu_wb_upd             (bpu_wb_upd)
      );

   ncpu32k_pidu PRE_DEC_1
      (
         .pidu_insn_vld          (idu_1_insn_rdy),
         .pidu_insn              (idu_1_insn),
         .pidu_pc                (idu_1_pc),
         .pidu_EITM              (idu_1_EITM),
         .pidu_EIPF              (idu_1_EIPF),
         .jmprel                 (idu_1_jmprel),
         .jmprel_tgt             (idu_1_jmprel_tgt)
      );

   ncpu32k_pidu PRE_DEC_2
      (
         .pidu_insn_vld          (idu_2_insn_rdy),
         .pidu_insn              (idu_2_insn),
         .pidu_pc                (idu_2_pc),
         .pidu_EITM              (idu_2_EITM),
         .pidu_EIPF              (idu_2_EIPF),
         .jmprel                 (idu_2_jmprel),
         .jmprel_tgt             (idu_2_jmprel_tgt)
      );

   // synthesis translate_off
`ifndef SYNTHESIS
 `include "ncpu32k_assert.h"

   // Assertions
 `ifdef NCPU_ENABLE_ASSERT

   initial
      begin
         // Assertion 2105021845
         if ((1<<CONFIG_IMMU_PAGE_SIZE_LOG2) % (`NCPU_IBW/8) != 0)
            $fatal(1, "Size of virtual page must be the multiple of an insn packet.");
         
         if (`NCPU_IBW_BYTES_LOG2 < 2)
            $fatal(1, "Size of an insn packet should be greater than the size of an insn.");
      end

 `endif

`endif
// synthesis translate_on

endmodule
