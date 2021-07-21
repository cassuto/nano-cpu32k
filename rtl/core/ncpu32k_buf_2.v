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

module ncpu32k_buf_2
#(
   parameter [`NCPU_AW-1:0] CONFIG_EDTM_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EDPF_VECTOR
   `PARAM_NOT_SPECIFIED ,
   parameter [`NCPU_AW-1:0] CONFIG_EALIGN_VECTOR
   `PARAM_NOT_SPECIFIED
)
(
   input                               clk,
   input                               stall_bck,
   input                               s1o_wb_bru_AVALID,
   input                               s1o_bru_wb_bpu,
   input                               s1o_wb_epu_in_slot_1,
   input [`NCPU_AW-3:0]                s1o_wb_epu_pc,
   input [`NCPU_AW-3:0]                s1o_wb_epu_pc_4,
   input                               s1o_wb_epu_exc,
   input [`NCPU_AW-3:0]                s1o_wb_epu_exc_vec,
   input [`NCPU_AW-3:0]                s1o_slot_1_pc_4,
   input [`NCPU_AW-3:0]                s1o_slot_2_pc_4,
   input [`NCPU_DW-1:0]                s1o_slot_dout_1,
   input [`NCPU_DW-1:0]                s1o_slot_dout_2,
   input                               s1o_slot_BVALID_1,
   input                               s1o_slot_BVALID_2,
   input                               s1o_wb_epu_AVALID,
   input [`NCPU_AW-3:0]                s1o_slot_2_pc,
   input [`NCPU_AW-3:0]                s1o_slot_bpu_pc_nxt,
   input                               s1o_slot_2_in_pred_path,
   input                               s1o_wb_bru_in_slot_1,
   input [`NCPU_DW-1:0]                s1o_commit_wmsr_dat,
   input [`NCPU_WMSR_WE_DW-1:0]        s1o_commit_wmsr_we,
   input                               s1o_commit_E_FLUSH_TLB_slot1,
   input                               s1o_commit_ERET_slot1,
   input                               s1o_commit_ESYSCALL_slot1,
   input                               s1o_commit_EINSN_slot1,
   input                               s1o_commit_EIPF_slot1,
   input                               s1o_commit_EITM_slot1,
   input                               s1o_commit_EIRQ_slot1,
   input                               s1o_commit_E_FLUSH_TLB_slot2,
   input                               s1o_commit_ERET_slot2,
   input                               s1o_commit_ESYSCALL_slot2,
   input                               s1o_commit_EINSN_slot2,
   input                               s1o_commit_EIPF_slot2,
   input                               s1o_commit_EITM_slot2,
   input                               s1o_commit_EIRQ_slot2,
   input                               s1o_slot_rd_we_1,
   input                               s1o_slot_rd_we_2,
   input [`NCPU_REG_AW-1:0]            s1o_slot_rd_addr_1,
   input [`NCPU_REG_AW-1:0]            s1o_slot_rd_addr_2,
   // BRU
   input                               s2i_bru_branch_taken,
   input [`NCPU_AW-3:0]                s2i_bru_branch_tgt,
   // LSU
   input                               wb_lsu_AVALID,
   input                               wb_lsu_in_slot_1,
   input                               wb_lsu_EDTM,
   input                               wb_lsu_EDPF,
   input                               wb_lsu_EALIGN,
   input [`NCPU_AW-3:0]                wb_lsu_pc,
   input [`NCPU_AW-1:0]                wb_lsu_LSA,
   input [`NCPU_DW-1:0]                wb_lsu_dout,
   // To BPU
   output                              bpu_wb_taken,
   output [`NCPU_AW-3:0]               bpu_wb_pc_nxt_act,
   // To WB
   output                              bpu_wb,
   output [`NCPU_DW-1:0]               commit_wmsr_dat,
   output [`NCPU_WMSR_WE_DW-1:0]       commit_wmsr_we,
   output                              commit_EALIGN,          // To EPU of ncpu32k_epu.v
   output                              commit_EDPF,            // To EPU of ncpu32k_epu.v
   output                              commit_EDTM,            // To EPU of ncpu32k_epu.v
   output                              commit_EINSN,           // To EPU of ncpu32k_epu.v
   output                              commit_EIPF,            // To EPU of ncpu32k_epu.v
   output                              commit_EIRQ,            // To EPU of ncpu32k_epu.v
   output                              commit_EITM,            // To EPU of ncpu32k_epu.v
   output                              commit_ERET,            // To EPU of ncpu32k_epu.v
   output                              commit_ESYSCALL,        // To EPU of ncpu32k_epu.v
   output                              commit_E_FLUSH_TLB, // To EPU of ncpu32k_epu.v
   output [`NCPU_AW-1:0]               commit_LSA,             // To EPU of ncpu32k_epu.v
   output [`NCPU_AW-3:0]               commit_pc,              // To EPU of ncpu32k_epu.v
   output                              s2i_slot_BVALID_1,
   output                              s2i_slot_BVALID_2,
   output [`NCPU_DW-1:0]               s2i_slot_dout_1,
   output [`NCPU_DW-1:0]               s2i_slot_dout_2,
   output                              s2i_slot_rd_we_1,
   output                              s2i_slot_rd_we_2,
   output [`NCPU_REG_AW-1:0]           s2i_slot_rd_addr_1,
   output [`NCPU_REG_AW-1:0]           s2i_slot_rd_addr_2,
   output                              lsu_kill_req,
   output                              flush,
   output [`NCPU_AW-3:0]               flush_tgt,
   output                              fu_flush,
   output                              s1i_inv_slot_2
);

   reg                                 s2i_se_inv_slot [2:1];
   reg                                 s2i_se_flush;
   reg [`NCPU_AW-3:0]                  s2i_se_flush_tgt;
   wire                                s2i_exc_flush;
   wire [`NCPU_AW-3:0]                 s2i_exc_flush_tgt;
   wire                                s2i_slot_1_exc_inv;
   wire                                s2i_inv_slot_1;
   wire                                s2i_inv_slot_2;
   wire                                s2i_slot_BVALID_before_inv_1;
   wire                                s2i_slot_BVALID_before_inv_2;
   wire                                commit_EALIGN_slot1, commit_EALIGN_slot2;
   wire                                commit_EDPF_slot1, commit_EDPF_slot2;
   wire                                commit_EDTM_slot1, commit_EDTM_slot2;
   wire                                commit_EINSN_slot1, commit_EINSN_slot2;
   wire                                commit_EIPF_slot1, commit_EIPF_slot2;
   wire                                commit_EIRQ_slot1, commit_EIRQ_slot2;
   wire                                commit_EITM_slot1, commit_EITM_slot2;
   wire                                commit_ERET_slot1, commit_ERET_slot2;
   wire                                commit_ESYSCALL_slot1, commit_ESYSCALL_slot2;
   wire                                commit_E_FLUSH_TLB_slot1, commit_E_FLUSH_TLB_slot2;
   wire                                commit_exc_slot1;
   wire [`NCPU_AW-3:0]                 s2i_slot_pc_nxt_act[2:1];

   //
   // Speculative execution check point
   //
   always @(*)
      begin
         s2i_se_inv_slot[1] = 1'b0;
         s2i_se_inv_slot[2] = 1'b0;
         s2i_se_flush = 1'b0;
         s2i_se_flush_tgt = 'b0;

         if (s2i_slot_BVALID_before_inv_1)
            begin
               if ((s2i_slot_pc_nxt_act[1] == s1o_slot_2_pc) & s1o_slot_2_in_pred_path)
                  begin
                     if (s2i_slot_BVALID_before_inv_2 & (s2i_slot_pc_nxt_act[2] != s1o_slot_bpu_pc_nxt))
                        begin
                           s2i_se_inv_slot[1] = 1'b0;
                           s2i_se_inv_slot[2] = 1'b0;
                           s2i_se_flush = 1'b1; // The predication is wrong
                           s2i_se_flush_tgt = s2i_slot_pc_nxt_act[2];
                        end
                  end
               else
                  begin
                     if ((s2i_slot_pc_nxt_act[1] == s1o_slot_bpu_pc_nxt) & ~s1o_slot_2_in_pred_path)
                        begin
                           s2i_se_inv_slot[1] = 1'b0;
                           s2i_se_inv_slot[2] = 1'b1; // slot #2 is in wrong path
                           s2i_se_flush = 1'b0; // The predication is right, do not flush.
                        end
                     else
                        begin
                           s2i_se_inv_slot[1] = 1'b0;
                           s2i_se_inv_slot[2] = 1'b1;
                           s2i_se_flush = 1'b1; // The predication is wrong
                           s2i_se_flush_tgt = s2i_slot_pc_nxt_act[1];
                        end
                  end
            end

         // Slot 1 is prior to the slot 2
         if (s2i_slot_BVALID_before_inv_2 & ~s2i_se_inv_slot[2] & ~s2i_se_flush)
            begin
               s2i_se_inv_slot[2] = 1'b0;
               s2i_se_flush = (s2i_slot_pc_nxt_act[2] != s1o_slot_bpu_pc_nxt);
               s2i_se_flush_tgt = s2i_slot_pc_nxt_act[2];
            end
      end

   // Write back BPU
   assign bpu_wb = (s1o_wb_bru_AVALID & s1o_bru_wb_bpu &
                     // Check if this branch insn is not invalidated
                     (~s1o_wb_bru_in_slot_1|~s2i_se_inv_slot[1]) & (s1o_wb_bru_in_slot_1|~s2i_se_inv_slot[2]) );

   
   assign commit_EDTM_slot1 = (wb_lsu_AVALID & wb_lsu_EDTM & wb_lsu_in_slot_1);
   assign commit_EDPF_slot1 = (wb_lsu_AVALID & wb_lsu_EDPF & wb_lsu_in_slot_1);
   assign commit_EALIGN_slot1 = (wb_lsu_AVALID & wb_lsu_EALIGN & wb_lsu_in_slot_1);

   assign commit_EDTM_slot2 = (wb_lsu_AVALID & wb_lsu_EDTM & ~wb_lsu_in_slot_1);
   assign commit_EDPF_slot2 = (wb_lsu_AVALID & wb_lsu_EDPF & ~wb_lsu_in_slot_1);
   assign commit_EALIGN_slot2 = (wb_lsu_AVALID & wb_lsu_EALIGN & ~wb_lsu_in_slot_1);

   assign commit_exc_slot1 = (commit_EALIGN_slot1|commit_EDPF_slot1|commit_EDTM_slot1|
                              s1o_commit_EINSN_slot1|
                              s1o_commit_EIPF_slot1|
                              s1o_commit_EIRQ_slot1|
                              s1o_commit_EITM_slot1|
                              s1o_commit_ERET_slot1|
                              s1o_commit_ESYSCALL_slot1|
                              s1o_commit_E_FLUSH_TLB_slot1);

   // Exception are generated both by EPU or LSU
   // If slot 1 occurs an exception, then any exception in slot 2 is ignored,
   // because insn in slot 2 will be flushed out.
   assign commit_EALIGN = commit_EALIGN_slot1 | (~commit_exc_slot1 & commit_EALIGN_slot2);
   assign commit_EDPF = commit_EDPF_slot1 | (~commit_exc_slot1 & commit_EDPF_slot2);
   assign commit_EDTM = commit_EDTM_slot1 | (~commit_exc_slot1 & commit_EDTM_slot2);
   assign commit_EINSN = s1o_commit_EINSN_slot1 | (~commit_exc_slot1 & s1o_commit_EINSN_slot2);
   assign commit_EIPF = s1o_commit_EIPF_slot1 | (~commit_exc_slot1 & s1o_commit_EIPF_slot2);
   assign commit_EIRQ = s1o_commit_EIRQ_slot1 | (~commit_exc_slot1 & s1o_commit_EIRQ_slot2);
   assign commit_EITM = s1o_commit_EITM_slot1 | (~commit_exc_slot1 & s1o_commit_EITM_slot2);
   assign commit_ERET = s1o_commit_ERET_slot1 | (~commit_exc_slot1 & s1o_commit_ERET_slot2);
   assign commit_ESYSCALL = s1o_commit_ESYSCALL_slot1 | (~commit_exc_slot1 & s1o_commit_ESYSCALL_slot2);
   assign commit_E_FLUSH_TLB = s1o_commit_E_FLUSH_TLB_slot1 | (~commit_exc_slot1 & s1o_commit_E_FLUSH_TLB_slot2);

   // If it is an LSU exception, set EPC as the address of LS insn.
   assign commit_pc = (commit_EDTM | commit_EDPF | commit_EALIGN) ? wb_lsu_pc : s1o_wb_epu_pc;
   assign commit_LSA = wb_lsu_LSA;
   
   assign commit_wmsr_dat = s1o_commit_wmsr_dat;
   assign commit_wmsr_we = s1o_commit_wmsr_we;

   // 1. Don't writeback LSU insns if exception raised.
   // 2. Writeback EPU insn although exception raised.
   assign s2i_slot_1_exc_inv = (commit_EDTM_slot1 | commit_EDPF_slot1 | commit_EALIGN_slot1);
   assign s2i_inv_slot_1 = (s2i_se_inv_slot[1] | s2i_slot_1_exc_inv);
   assign s2i_inv_slot_2 = s2i_se_inv_slot[2] |
                           s2i_slot_1_exc_inv |
                           (s1o_wb_epu_AVALID & s1o_wb_epu_exc & s1o_wb_epu_in_slot_1) |
                           (s1o_commit_E_FLUSH_TLB_slot1) |
                           (commit_EDTM_slot2 | commit_EDPF_slot2 | commit_EALIGN_slot2);
       
   // Kill request to stage 2 of LSU if the insn is invalidated
   assign lsu_kill_req = ((s2i_se_inv_slot[1] & wb_lsu_AVALID & wb_lsu_in_slot_1) |
                           (s2i_se_inv_slot[2] & wb_lsu_AVALID & ~wb_lsu_in_slot_1));

   // Flush caused by exceptions
   assign s2i_exc_flush = (commit_EDTM | commit_EDPF | commit_EALIGN | commit_E_FLUSH_TLB |
                        (s1o_wb_epu_AVALID & s1o_wb_epu_exc));

   // Exceptions of D-MMU are prior to others
   assign s2i_exc_flush_tgt = (commit_EDTM)
                           ? CONFIG_EDTM_VECTOR[2 +: `NCPU_AW-2]
                           : (commit_EDPF)
                              ? CONFIG_EDPF_VECTOR[2 +: `NCPU_AW-2]
                              : (commit_EALIGN)
                                 ? CONFIG_EALIGN_VECTOR[2 +: `NCPU_AW-2]
                                 : (commit_E_FLUSH_TLB)
                                    ? s1o_wb_epu_pc_4
                                    : s1o_wb_epu_exc_vec;

   // Arbiter of flush
   assign flush = (s2i_se_flush | s2i_exc_flush);
   // SE is prior to exceptions, because exceptions may be raised by the insn that is in wrong path
   assign flush_tgt = (s2i_se_flush)
                        ? s2i_se_flush_tgt
                        : s2i_exc_flush_tgt;

   assign fu_flush = flush;

   // Both LSU and other FUs in path
   assign s2i_slot_BVALID_before_inv_1 = (s1o_slot_BVALID_1 |
                                          (wb_lsu_AVALID & wb_lsu_in_slot_1));

   assign s2i_slot_BVALID_before_inv_2 = (s1o_slot_BVALID_2 |
                                          (wb_lsu_AVALID & ~wb_lsu_in_slot_1));

   // Assert (2105042339)
   assign s2i_slot_BVALID_1 = ~s2i_inv_slot_1 & s2i_slot_BVALID_before_inv_1;

   // Assert (2105042347)
   assign s2i_slot_BVALID_2 = ~s2i_inv_slot_2 & s2i_slot_BVALID_before_inv_2;

   assign s2i_slot_dout_1 = s1o_slot_BVALID_1 ? s1o_slot_dout_1 : wb_lsu_dout;

   assign s2i_slot_dout_2 = ({`NCPU_DW{s1o_slot_BVALID_2}} & s1o_slot_dout_2) |
                              ({`NCPU_DW{wb_lsu_AVALID & ~wb_lsu_in_slot_1}} & wb_lsu_dout);

   // If single issue, the insn of slot #1 is in backend stage #2
   // while the insn of slot #2 is in the backend stage #1. We need to flush stage #1.
   assign s1i_inv_slot_2 = s2i_inv_slot_2;
                              
   assign s2i_slot_rd_we_1 = s1o_slot_rd_we_1;
   assign s2i_slot_rd_we_2 = s1o_slot_rd_we_2;
   assign s2i_slot_rd_addr_1 = s1o_slot_rd_addr_1;
   assign s2i_slot_rd_addr_2 = s1o_slot_rd_addr_2;
   
   assign s2i_slot_pc_nxt_act[1] =
      (s1o_wb_bru_AVALID & s1o_wb_bru_in_slot_1 & s2i_bru_branch_taken)
         ? s2i_bru_branch_tgt
         : s1o_slot_1_pc_4;

   assign s2i_slot_pc_nxt_act[2] =
      (s1o_wb_bru_AVALID & ~s1o_wb_bru_in_slot_1 & s2i_bru_branch_taken)
         ? s2i_bru_branch_tgt
         : s1o_slot_2_pc_4;

   assign bpu_wb_taken = s2i_bru_branch_taken;
   
   assign bpu_wb_pc_nxt_act = s2i_bru_branch_tgt;
   

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (count_1({commit_EALIGN_slot1,
                     commit_EDPF_slot1,
                     commit_EDTM_slot1,
                     commit_EINSN_slot1,
                     commit_EIPF_slot1,
                     commit_EIRQ_slot1,
                     commit_EITM_slot1,
                     commit_ERET_slot1,
                     commit_ESYSCALL_slot1,
                     commit_E_FLUSH_TLB_slot1}) > 1 )
         $fatal (1, "BUG ON: Exception sel of slot1");
      if (count_1({commit_EALIGN_slot2,
                     commit_EDPF_slot2,
                     commit_EDTM_slot2,
                     commit_EINSN_slot2,
                     commit_EIPF_slot2,
                     commit_EIRQ_slot2,
                     commit_EITM_slot2,
                     commit_ERET_slot2,
                     commit_ESYSCALL_slot2,
                     commit_E_FLUSH_TLB_slot2}) > 1 )
         $fatal (1, "BUG ON: Exception sel of slot2");
   end
`endif

`endif
   // synthesis translate_on
   
endmodule
