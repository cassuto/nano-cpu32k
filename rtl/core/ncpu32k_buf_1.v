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

module ncpu32k_buf_1
#(
   parameter BPU_UPD_DW
   `PARAM_NOT_SPECIFIED
)
(
   input                               clk,
   input                               rst_n,
   input                               stall_bck,
   input                               flush,
   // From scheduler
   input [`NCPU_AW-3:0]                slot_1_pc,
   input [`NCPU_AW-3:0]                slot_1_pc_4,
   input                               slot_1_rd_we,
   input [`NCPU_REG_AW-1:0]            slot_1_rd_addr,
   input [`NCPU_AW-3:0]                slot_2_pc,
   input [`NCPU_AW-3:0]                slot_2_pc_4,
   input                               slot_2_rd_we,
   input [`NCPU_REG_AW-1:0]            slot_2_rd_addr,
   input [BPU_UPD_DW-1:0]              slot_1_bpu_upd,
   input [BPU_UPD_DW-1:0]              slot_2_bpu_upd,
   input [`NCPU_AW-3:0]                slot_bpu_pc_nxt,
   input                               slot_2_in_pred_path,
   input [`NCPU_BRU_IOPW-1:0]          bru_opc_bus,
   input                               lsu_AVALID,
   input                               lsu_in_slot_1,
   // From ALU #1
   input                               wb_alu_1_AVALID,
   input [`NCPU_DW-1:0]                wb_alu_1_dout,
   // From ALU #2
   input                               wb_alu_2_AVALID,
   input [`NCPU_DW-1:0]                wb_alu_2_dout,
   // From BRU
   input                               wb_bru_AVALID,
   input [`NCPU_DW-1:0]                wb_bru_dout,
   input                               wb_bru_is_bcc,
   input                               wb_bru_is_breg,
   input                               wb_bru_in_slot_1,
   input [`NCPU_DW-1:0]                wb_bru_operand1,
   input [`NCPU_DW-1:0]                wb_bru_operand2,
   input [`NCPU_BRU_IOPW-1:0]          wb_bru_opc_bus,
   input [`NCPU_AW-3:0]                wb_bru_pc,
   input [14:0]                        wb_bru_rel15,
   // From LPU
   input                               wb_lpu_AVALID,
   input [`NCPU_DW-1:0]                wb_lpu_dout,
   input                               wb_lpu_in_slot_1,
   // From EPU
   input                               wb_epu_AVALID,
   input [`NCPU_DW-1:0]                wb_epu_dout,
   input                               wb_epu_in_slot_1,
   input                               wb_epu_exc,
   input [`NCPU_AW-3:0]                wb_epu_exc_vec,
   input [`NCPU_DW-1:0]                wb_wmsr_dat,
   input [`NCPU_WMSR_WE_DW-1:0]        wb_wmsr_we,
   input                               wb_ERET,
   input                               wb_ESYSCALL,
   input                               wb_EINSN,
   input                               wb_EIPF,
   input                               wb_EITM,
   input                               wb_EIRQ,
   input                               wb_E_FLUSH_TLB,
   input [`NCPU_AW-3:0]                wb_epu_pc,

   // To bypass
   output                              s1i_slot_BVALID_1,
   output                              s1i_slot_rd_we_1,
   output [`NCPU_REG_AW-1:0]           s1i_slot_rd_addr_1,
   output [`NCPU_DW-1:0]               s1i_slot_dout_1,
   output                              s1i_slot_BVALID_2_bypass,
   output                              s1i_slot_rd_we_2,
   output [`NCPU_REG_AW-1:0]           s1i_slot_rd_addr_2,
   output [`NCPU_DW-1:0]               s1i_slot_dout_2,
   
   // To stage 2
   output [`NCPU_AW-3:0]               s1o_slot_1_pc_4,
   output [`NCPU_AW-3:0]               s1o_slot_2_pc_4,
   output [`NCPU_DW-1:0]               s1o_slot_dout_1,
   output [`NCPU_DW-1:0]               s1o_slot_dout_2,
   output                              s1o_slot_BVALID_1,
   output                              s1o_slot_BVALID_2,
   output                              s1o_wb_epu_AVALID,
   output [`NCPU_WMSR_WE_DW-1:0]       s1o_commit_wmsr_we,
   output                              s1o_commit_E_FLUSH_TLB_slot1,
   output                              s1o_commit_ERET_slot1,
   output                              s1o_commit_ESYSCALL_slot1,
   output                              s1o_commit_EINSN_slot1,
   output                              s1o_commit_EIPF_slot1,
   output                              s1o_commit_EITM_slot1,
   output                              s1o_commit_EIRQ_slot1,
   output                              s1o_commit_E_FLUSH_TLB_slot2,
   output                              s1o_commit_ERET_slot2,
   output                              s1o_commit_ESYSCALL_slot2,
   output                              s1o_commit_EINSN_slot2,
   output                              s1o_commit_EIPF_slot2,
   output                              s1o_commit_EITM_slot2,
   output                              s1o_commit_EIRQ_slot2,
   output                              s1o_slot_rd_we_1,
   output                              s1o_slot_rd_we_2,
   output [`NCPU_REG_AW-1:0]           s1o_slot_rd_addr_1,
   output [`NCPU_REG_AW-1:0]           s1o_slot_rd_addr_2,
   output                              wb_lsu_rd_we,
   output [`NCPU_REG_AW-1:0]           wb_lsu_rd_addr,
   output                              s1o_wb_epu_exc,
   output [`NCPU_AW-3:0]               s1o_wb_epu_exc_vec,
   output [`NCPU_DW-1:0]               s1o_commit_wmsr_dat,
   output                              s1o_wb_epu_in_slot_1,
   output [`NCPU_AW-3:0]               s1o_wb_epu_pc,
   output [`NCPU_AW-3:0]               s1o_wb_epu_pc_4,
   output                              bpu_wb_is_bcc,
   output                              bpu_wb_is_breg,
   output [`NCPU_AW-3:0]               bpu_wb_pc,
   output [BPU_UPD_DW-1:0]             bpu_wb_upd,
   output                              s1o_wb_bru_AVALID,
   output [`NCPU_DW-1:0]               s1o_wb_bru_operand1,
   output [`NCPU_DW-1:0]               s1o_wb_bru_operand2,
   output [`NCPU_BRU_IOPW-1:0]         s1o_wb_bru_opc_bus,
   output [`NCPU_AW-3:0]               s1o_wb_bru_pc,
   output [14:0]                       s1o_wb_bru_rel15,
   output                              s1o_bru_wb_bpu,
   output [`NCPU_AW-3:0]               s1o_slot_2_pc,
   output [`NCPU_AW-3:0]               s1o_slot_bpu_pc_nxt,
   output                              s1o_slot_2_in_pred_path,
   output                              s1o_wb_bru_in_slot_1,
   output                              s1_pipe_cke
);

   wire [`NCPU_DW-1:0]                 s1o_slot_dout[2:1];
   wire                                s1o_slot_BVALID[2:1];
   wire                                s1i_slot_AVALID [2:1];
   wire                                s1i_slot_BVALID [2:1];
   wire [`NCPU_DW-1:0]                 s1i_slot_dout [2:1];
   wire                                wb_lsu_rd_we_nxt;
   wire [`NCPU_REG_AW-1:0]             wb_lsu_rd_addr_nxt;
   wire                                s1o_noflush;
   wire                                bru_wb_bpu_nxt;
   genvar                              i;
  

   // Assert (2105041412)
   assign s1i_slot_AVALID[1] = wb_alu_1_AVALID |
                              (wb_bru_AVALID & wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & wb_epu_in_slot_1) |
                              (lsu_AVALID & lsu_in_slot_1);

   // Assert (2105041434)
   assign s1i_slot_AVALID[2] = wb_alu_2_AVALID |
                              (wb_bru_AVALID & ~wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & ~wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & ~wb_epu_in_slot_1) |
                              (lsu_AVALID & ~lsu_in_slot_1);

   // Describe which FUs could output the result in this stage here
   assign s1i_slot_BVALID[1] = wb_alu_1_AVALID |
                              (wb_bru_AVALID & wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & wb_epu_in_slot_1);
   assign s1i_slot_BVALID[2] = wb_alu_2_AVALID |
                              (wb_bru_AVALID & ~wb_bru_in_slot_1) |
                              (wb_lpu_AVALID & ~wb_lpu_in_slot_1) |
                              (wb_epu_AVALID & ~wb_epu_in_slot_1);

   // Result MUX for the 1st slot
   assign s1i_slot_dout[1] = 
      (wb_alu_1_dout & {`NCPU_DW{wb_alu_1_AVALID}}) |
      (wb_bru_dout & {`NCPU_DW{wb_bru_AVALID & wb_bru_in_slot_1}}) |
      (wb_lpu_dout & {`NCPU_DW{wb_lpu_AVALID & wb_lpu_in_slot_1}}) |
      (wb_epu_dout & {`NCPU_DW{wb_epu_AVALID & wb_epu_in_slot_1}});

   // Result MUX for the 2rd slot
   assign s1i_slot_dout[2] =
      (wb_alu_2_dout & {`NCPU_DW{wb_alu_2_AVALID}}) |
      (wb_bru_dout & {`NCPU_DW{wb_bru_AVALID & ~wb_bru_in_slot_1}}) |
      (wb_lpu_dout & {`NCPU_DW{wb_lpu_AVALID & ~wb_lpu_in_slot_1}}) |
      (wb_epu_dout & {`NCPU_DW{wb_epu_AVALID & ~wb_epu_in_slot_1}});

   // To bypass
   assign s1i_slot_BVALID_1 = s1i_slot_BVALID[1];
   assign s1i_slot_BVALID_2_bypass = (s1i_slot_BVALID[2] & slot_2_in_pred_path);
   assign s1i_slot_rd_we_1 = slot_1_rd_we;
   assign s1i_slot_rd_we_2 = slot_2_rd_we;
   assign s1i_slot_rd_addr_1 = slot_1_rd_addr;
   assign s1i_slot_rd_addr_2 = slot_2_rd_addr;
   assign s1i_slot_dout_1 = s1i_slot_dout[1];
   assign s1i_slot_dout_2 = s1i_slot_dout[2];


   assign wb_lsu_rd_we_nxt = lsu_in_slot_1 ? slot_1_rd_we : slot_2_rd_we;
   assign wb_lsu_rd_addr_nxt = lsu_in_slot_1 ? slot_1_rd_addr : slot_2_rd_addr;


   assign s1_pipe_cke = ~stall_bck;
   assign s1o_noflush = ~flush;

   generate
      for(i=1;i<=2;i=i+1)
         begin : gen_DFFs
            // Data path
            nDFF_l #(`NCPU_DW) dff_s1o_slot_dout
               (clk, s1_pipe_cke, s1i_slot_dout[i], s1o_slot_dout[i]);

            // Control path
            nDFF_lr #(1) dff_s1o_slot_BVALID
               (clk, rst_n, s1_pipe_cke, (s1o_noflush & s1i_slot_BVALID[i]), s1o_slot_BVALID[i]);
         end
   endgenerate

   assign s1o_slot_dout_1 = s1o_slot_dout[1];
   assign s1o_slot_dout_2 = s1o_slot_dout[2];
   assign s1o_slot_BVALID_1 = s1o_slot_BVALID[1];
   assign s1o_slot_BVALID_2 = s1o_slot_BVALID[2];
   
   
   // JMP REL is handled by pre decoder, do not affect BPU
   assign bru_wb_bpu_nxt = ~bru_opc_bus[`NCPU_BRU_JMPREL];

   // Control path
   nDFF_lr #(1) dff_s1o_wb_epu_AVALID
      (clk, rst_n, s1_pipe_cke, s1o_noflush & wb_epu_AVALID, s1o_wb_epu_AVALID);
   nDFF_lr #(`NCPU_WMSR_WE_DW) dff_commit_wmsr_we
      (clk, rst_n, s1_pipe_cke, {`NCPU_WMSR_WE_DW{s1o_noflush &  wb_epu_AVALID}} & wb_wmsr_we, s1o_commit_wmsr_we);
   nDFF_lr #(1) dff_commit_E_FLUSH_TLB_slot1
      (clk, rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_E_FLUSH_TLB & wb_epu_in_slot_1), s1o_commit_E_FLUSH_TLB_slot1);
   nDFF_lr #(1) dff_commit_ERET_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_ERET & wb_epu_in_slot_1), s1o_commit_ERET_slot1);
   nDFF_lr #(1) dff_commit_ESYSCALL_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_ESYSCALL & wb_epu_in_slot_1), s1o_commit_ESYSCALL_slot1);
   nDFF_lr #(1) dff_commit_EINSN_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EINSN & wb_epu_in_slot_1), s1o_commit_EINSN_slot1);
   nDFF_lr #(1) dff_commit_EIPF_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EIPF & wb_epu_in_slot_1), s1o_commit_EIPF_slot1);
   nDFF_lr #(1) dff_commit_EITM_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EITM & wb_epu_in_slot_1), s1o_commit_EITM_slot1);
   nDFF_lr #(1) dff_commit_EIRQ_slot1
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EIRQ & wb_epu_in_slot_1), s1o_commit_EIRQ_slot1);
   
   nDFF_lr #(1) dff_commit_E_FLUSH_TLB_slot2
      (clk, rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_E_FLUSH_TLB & ~wb_epu_in_slot_1), s1o_commit_E_FLUSH_TLB_slot2);
   nDFF_lr #(1) dff_commit_ERET_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_ERET & ~wb_epu_in_slot_1), s1o_commit_ERET_slot2);
   nDFF_lr #(1) dff_commit_ESYSCALL_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_ESYSCALL & ~wb_epu_in_slot_1), s1o_commit_ESYSCALL_slot2);
   nDFF_lr #(1) dff_commit_EINSN_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EINSN & ~wb_epu_in_slot_1), s1o_commit_EINSN_slot2);
   nDFF_lr #(1) dff_commit_EIPF_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EIPF & ~wb_epu_in_slot_1), s1o_commit_EIPF_slot2);
   nDFF_lr #(1) dff_commit_EITM_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EITM & ~wb_epu_in_slot_1), s1o_commit_EITM_slot2);
   nDFF_lr #(1) dff_commit_EIRQ_slot2
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_epu_AVALID & wb_EIRQ & ~wb_epu_in_slot_1), s1o_commit_EIRQ_slot2);
      
   nDFF_lr #(1) dff_s1o_wb_bru_AVALID
      (clk,rst_n, s1_pipe_cke, (s1o_noflush & wb_bru_AVALID), s1o_wb_bru_AVALID);
   
   // Data path
   nDFF_l #(`NCPU_AW-2) dff_s1o_slot_1_pc_4
      (clk, s1_pipe_cke, slot_1_pc_4, s1o_slot_1_pc_4);
   nDFF_l #(`NCPU_AW-2) dff_s1o_slot_2_pc_4
      (clk, s1_pipe_cke, slot_2_pc_4, s1o_slot_2_pc_4);
      
   nDFF_l #(1) dff_s1o_slot_rd_we_1
      (clk, s1_pipe_cke, slot_1_rd_we, s1o_slot_rd_we_1);
   nDFF_l #(1) dff_s1o_slot_rd_we_2
      (clk, s1_pipe_cke, slot_2_rd_we, s1o_slot_rd_we_2);

   nDFF_l #(`NCPU_REG_AW) dff_s1o_slot_rd_addr_1
      (clk, s1_pipe_cke, slot_1_rd_addr, s1o_slot_rd_addr_1);
   nDFF_l #(`NCPU_REG_AW) dff_s1o_slot_rd_addr_2
      (clk, s1_pipe_cke, slot_2_rd_addr, s1o_slot_rd_addr_2);

   nDFF_l #(1) dff_wb_lsu_rd_we
      (clk, s1_pipe_cke, wb_lsu_rd_we_nxt, wb_lsu_rd_we);
   nDFF_l #(`NCPU_REG_AW) dff_wb_lsu_rd_addr
      (clk, s1_pipe_cke, wb_lsu_rd_addr_nxt, wb_lsu_rd_addr);

   nDFF_l #(1) dff_s1o_wb_epu_exc
      (clk, s1_pipe_cke, wb_epu_exc, s1o_wb_epu_exc);
   nDFF_l #(`NCPU_AW-2) dff_s1o_wb_epu_exc_vec
      (clk, s1_pipe_cke, wb_epu_exc_vec, s1o_wb_epu_exc_vec);

   nDFF_l #(`NCPU_DW) dff_commit_wmsr_dat
      (clk, s1_pipe_cke, wb_wmsr_dat, s1o_commit_wmsr_dat);
      
   nDFF_l #(1) dff_wb_epu_in_slot_1
      (clk, s1_pipe_cke, wb_epu_in_slot_1, s1o_wb_epu_in_slot_1);

   nDFF_l #(`NCPU_AW-2) dff_commit_pc
      (clk, s1_pipe_cke, wb_epu_pc, s1o_wb_epu_pc);
   nDFF_l #(`NCPU_AW-2) dff_commit_pc_4
      (clk, s1_pipe_cke, wb_epu_pc + 'b1, s1o_wb_epu_pc_4);

   nDFF_l #(1) dff_bpu_wb_is_bcc
      (clk ,s1_pipe_cke, wb_bru_is_bcc, bpu_wb_is_bcc);
   nDFF_l #(1) dff_bpu_wb_is_breg
      (clk, s1_pipe_cke, wb_bru_is_breg, bpu_wb_is_breg);
   nDFF_l #(`NCPU_AW-2) dff_bpu_wb_pc
      (clk, s1_pipe_cke, (wb_bru_in_slot_1 ? slot_1_pc : slot_2_pc), bpu_wb_pc);
   nDFF_l #(BPU_UPD_DW) dff_bpu_wb_upd
      (clk, s1_pipe_cke, (wb_bru_in_slot_1 ? slot_1_bpu_upd : slot_2_bpu_upd), bpu_wb_upd);
      
   nDFF_l #(`NCPU_DW) dff_s1o_wb_bru_operand1
      (clk, s1_pipe_cke, wb_bru_operand1, s1o_wb_bru_operand1);
   nDFF_l #(`NCPU_DW) dff_s1o_wb_bru_operand2
      (clk, s1_pipe_cke, wb_bru_operand2, s1o_wb_bru_operand2);
   nDFF_l #(`NCPU_BRU_IOPW) dff_s1o_wb_bru_opc_bus
      (clk, s1_pipe_cke, wb_bru_opc_bus, s1o_wb_bru_opc_bus);
   nDFF_l #(`NCPU_AW-2) dff_s1o_wb_bru_pc
      (clk, s1_pipe_cke, wb_bru_pc, s1o_wb_bru_pc);
   nDFF_l #(15) dff_s1o_wb_bru_rel15
      (clk, s1_pipe_cke, wb_bru_rel15, s1o_wb_bru_rel15);
      
   nDFF_l #(1) dff_s1o_bru_wb_bpu
      (clk, s1_pipe_cke, bru_wb_bpu_nxt, s1o_bru_wb_bpu);
      
   nDFF_l #(`NCPU_AW-2) dff_s1o_s1o_slot_2_pc
      (clk, s1_pipe_cke, slot_2_pc, s1o_slot_2_pc);

   nDFF_l #(`NCPU_AW-2) dff_s1o_slot_bpu_pc_nxt
      (clk, s1_pipe_cke, slot_bpu_pc_nxt, s1o_slot_bpu_pc_nxt);
      
   nDFF_l #(1) dff_s1o_slot_2_in_pred_path
      (clk, s1_pipe_cke, slot_2_in_pred_path, s1o_slot_2_in_pred_path);
      
   nDFF_l #(1) dff_s1o_wb_bru_in_slot_1
      (clk, s1_pipe_cke, wb_bru_in_slot_1, s1o_wb_bru_in_slot_1);
      
endmodule
