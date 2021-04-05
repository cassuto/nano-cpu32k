/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_pipeline_epu
#(
   parameter CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   // From DISPATCH
   output                     issue_epu_AREADY,
   input                      issue_epu_AVALID,
   input [`NCPU_EPU_UOPW-1:0] issue_epu_uop,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] issue_id,
   input                      issue_rs1_rdy,
   input [`NCPU_DW-1:0]       issue_rs1_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs1_addr,
   input                      issue_rs2_rdy,
   input [`NCPU_DW-1:0]       issue_rs2_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs2_addr,
   input [`NCPU_DW-1:0]       issue_imm32,
   // From ROB
   input [CONFIG_ROB_DEPTH_LOG2-1:0] rob_commit_ptr,
   input [`NCPU_AW-3:0]       rob_commit_pc,
   // From AGU
   input                      epu_commit_EDTM,
   input                      epu_commit_EDPF,
   input                      epu_commit_EALIGN,
   input [`NCPU_AW-1:0]       epu_commit_LSA,
   // From BYP
   input                      byp_BVALID,
   input [`NCPU_DW-1:0]       byp_BDATA,
   input                      byp_rd_we,
   input [`NCPU_REG_AW-1:0]   byp_rd_addr,
   // To WRITEBACK
   input                      wb_epu_BREADY,
   output                     wb_epu_BVALID,
   output [`NCPU_DW-1:0]      wb_epu_BDATA,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] wb_epu_BID,
   output                     wb_epu_BERET,
   output                     wb_epu_BESYSCALL,
   output                     wb_epu_BEINSN,
   output                     wb_epu_BEIPF,
   output                     wb_epu_BEITM,
   output                     wb_epu_BEIRQ,
   // PSR
   input [`NCPU_PSR_DW-1:0]   msr_psr,
   output                     msr_psr_rm_nxt,
   output                     msr_psr_rm_we,
   output                     msr_psr_imme_nxt,
   output                     msr_psr_imme_we,
   output                     msr_psr_dmme_nxt,
   output                     msr_psr_dmme_we,
   output                     msr_psr_ire_nxt,
   output                     msr_psr_ire_we,
   output                     msr_exc_ent,
   // CPUID
   input [`NCPU_DW-1:0]       msr_cpuid,
   // EPC
   input [`NCPU_DW-1:0]       msr_epc,
   output [`NCPU_DW-1:0]      msr_epc_nxt,
   output                     msr_epc_we,
   // EPSR
   input [`NCPU_PSR_DW-1:0]   msr_epsr,
   output [`NCPU_PSR_DW-1:0]  msr_epsr_nxt,
   output                     msr_epsr_we,
   // ELSA
   input [`NCPU_DW-1:0]       msr_elsa,
   output [`NCPU_DW-1:0]      msr_elsa_nxt,
   output                     msr_elsa_we,
   // COREID
   input [`NCPU_DW-1:0]       msr_coreid,
   // IMMID
   input [`NCPU_DW-1:0]       msr_immid,
   // ITLBL
   input [`NCPU_DW-1:0]       msr_imm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbl_nxt,
   output                     msr_imm_tlbl_we,
   // ITLBH
   input [`NCPU_DW-1:0]       msr_imm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbh_nxt,
   output                     msr_imm_tlbh_we,
   // DMMID
   input [`NCPU_DW-1:0]       msr_dmmid,
   // DTLBL
   input [`NCPU_DW-1:0]       msr_dmm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_dmm_tlbl_nxt,
   output                     msr_dmm_tlbl_we,
   // DTLBH
   input [`NCPU_DW-1:0]       msr_dmm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_dmm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_dmm_tlbh_nxt,
   output                     msr_dmm_tlbh_we,
   // IMR
   input [`NCPU_DW-1:0]       msr_irqc_imr,
   output [`NCPU_DW-1:0]      msr_irqc_imr_nxt,
   output                     msr_irqc_imr_we,
   // IRR
   input [`NCPU_DW-1:0]       msr_irqc_irr,
   // TSR
   input [`NCPU_DW-1:0]       msr_tsc_tsr,
   output [`NCPU_DW-1:0]      msr_tsc_tsr_nxt,
   output                     msr_tsc_tsr_we,
   // TCR
   input [`NCPU_DW-1:0]       msr_tsc_tcr,
   output [`NCPU_DW-1:0]      msr_tsc_tcr_nxt,
   output                     msr_tsc_tcr_we
);
   /*AUTOWIRE*/
   wire                       payload_re, payload_we;
   wire [CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2-1:0] payload_w_ptr;
   wire [CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2-1:0] payload_r_ptr;
   wire                       rs_AREADY;
   wire                       rs_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       rs_id;
   wire [`NCPU_DW-1:0]        rs_operand_1, rs_operand_2;
   wire [`NCPU_EPU_UOPW-1:0]  rs_uop;
   wire                       epu_AREADY;
   wire                       epu_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       epu_id;
   wire [`NCPU_DW-1:0]        epu_operand_1, epu_operand_2;
   wire [14:0]                epu_uimm15;
   wire [`NCPU_EPU_UOPW-1:0]  epu_uop;
   wire [`NCPU_EPU_IOPW-1:0]  epu_opc_bus;
   wire                       ESYSCALL_commit;
   wire                       ERET_commit;
   wire                       EITM_commit;
   wire                       EIPF_commit;
   wire                       EINSN_commit;
   wire                       EIRQ_commit;
   wire [`NCPU_DW-1:0]        msr_addr;
   wire [`NCPU_MSR_BANK_AW-1:0] bank_addr;
   wire [`NCPU_MSR_BANK_OFF_AW-1:0] bank_off;
   wire                       bank_ps;
   wire                       bank_imm;
   wire                       bank_dmm;
   wire                       bank_ica;
   wire                       bank_dca;
   wire                       bank_dbg;
   wire                       bank_irqc;
   wire                       bank_tsc;
   wire [`NCPU_DW-1:0]        dout_ps;
   wire                       msr_imm_tlbl_sel;
   wire                       msr_imm_tlbh_sel;
   wire [`NCPU_DW-1:0]        dout_imm;
   wire                       msr_dmm_tlbl_sel;
   wire                       msr_dmm_tlbh_sel;
   wire [`NCPU_DW-1:0]        dout_dmm;
   wire                       msr_irqc_imr_sel;
   wire                       msr_irqc_irr_sel;
   wire [`NCPU_DW-1:0]        dout_irqc;
   wire                       msr_tsc_tsr_sel;
   wire                       msr_tsc_tcr_sel;
   wire [`NCPU_DW-1:0]        dout_tsc;
   wire                       commit;
   wire                       exc_commit;
   wire [`NCPU_AW-3:0]        linkaddr;
   wire                       set_elsa_as_pc;
   wire                       set_elsa;
   wire [`NCPU_DW-1:0]        lsa_nxt;
   wire                       epu_hds_a;
   wire                       wmsr_we;
   wire [`NCPU_DW-1:0]        wmsr_operand;
   wire                       wmsr_psr_we;
   wire                       wmsr_epc_we;
   wire                       wmsr_epsr_we;
   wire                       wmsr_elsa_we;
   wire                       epsr_rm;
   wire                       epsr_ire;
   wire                       epsr_imme;
   wire                       epsr_dmme;
   wire [9:0]                 epsr_res;
   wire                       wmsr_psr_rm;
   wire                       wmsr_psr_ire;
   wire                       wmsr_psr_imme;
   wire                       wmsr_psr_dmme;
   wire [9:0]                 wmsr_psr_res;
   genvar i;
   
   ncpu32k_issue_queue
      #(
         .DEPTH            (1<<CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2),
         .DEPTH_WIDTH      (CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2),
         .UOP_WIDTH        (`NCPU_EPU_UOPW),
         .ALGORITHM        (1), // FIFO
         .CONFIG_ROB_DEPTH_LOG2 (CONFIG_ROB_DEPTH_LOG2)
      )
   RS_EPU
      (
         .clk              (clk),
         .rst_n            (rst_n),
         .i_issue_AVALID   (issue_epu_AVALID),
         .o_issue_AREADY   (issue_epu_AREADY),
         .i_flush          (flush),
         .i_uop            (issue_epu_uop),
         .i_id             (issue_id),
         .i_rs1_rdy        (issue_rs1_rdy),
         .i_rs1_dat        (issue_rs1_dat),
         .i_rs1_addr       (issue_rs1_addr),
         .i_rs2_rdy        (issue_rs2_rdy),
         .i_rs2_dat        (issue_rs2_dat),
         .i_rs2_addr       (issue_rs2_addr),
         .byp_BVALID       (byp_BVALID),
         .byp_BDATA        (byp_BDATA),
         .byp_rd_we        (byp_rd_we),
         .byp_rd_addr      (byp_rd_addr),
         .i_fu_AREADY      (rs_AREADY),
         .o_fu_AVALID      (rs_AVALID),
         .o_fu_id          (rs_id),
         .o_fu_uop         (rs_uop),
         .o_fu_rs1_dat     (rs_operand_1),
         .o_fu_rs2_dat     (rs_operand_2),
         .o_payload_w_ptr  (payload_w_ptr),
         .o_payload_r_ptr  (payload_r_ptr)
      );

   // Payload RAM to store immediate numbers.
   // This design improved the timing.
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (CONFIG_EPU_ISSUE_QUEUE_DEPTH_LOG2),
         .DW (15),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_RAM
      (
         // Outputs
         .dout    (epu_uimm15),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (payload_r_ptr),
         .re      (payload_re),
         .waddr   (payload_w_ptr),
         .we      (payload_we),
         .din     (issue_imm32[14:0])
      );

   assign payload_we = (issue_epu_AREADY & issue_epu_AVALID);

   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
      )
   PIPEBUF_PAYLOAD
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .flush   (flush),
         .A_en    (1'b1),
         .AVALID  (rs_AVALID),
         .AREADY  (rs_AREADY),
         .B_en    (1'b1),
         .BVALID  (epu_AVALID),
         .BREADY  (epu_AREADY),
         .cke     (payload_re),
         .pending ()
      );

   nDFF_l #(CONFIG_ROB_DEPTH_LOG2) dff_epu_id
     (clk, payload_re, rs_id, epu_id);
   nDFF_l #(`NCPU_EPU_UOPW) dff_epu_uop
     (clk, payload_re, rs_uop, epu_uop);
   nDFF_l #(`NCPU_DW) dff_epu_operand_1
     (clk, payload_re, rs_operand_1, epu_operand_1);
   nDFF_l #(`NCPU_DW) dff_epu_operand_2
     (clk, payload_re, rs_operand_2, epu_operand_2);

   // Unpack uOP for EPU
   generate
      for(i=1;i<=`NCPU_EPU_IOPW;i=i+1)
         begin : gen_opc_bus
            assign epu_opc_bus[i-1] = (epu_uop == i[`NCPU_EPU_UOPW-1:0]);
         end
   endgenerate

   assign msr_addr = epu_operand_1 | {{`NCPU_DW-15{1'b0}}, epu_uimm15[14:0]};
   assign bank_addr = msr_addr[`NCPU_MSR_BANK_AW+`NCPU_MSR_BANK_OFF_AW-1:`NCPU_MSR_BANK_OFF_AW];
   assign bank_off = msr_addr[`NCPU_MSR_BANK_OFF_AW-1:0];

   // Readout PS
   assign dout_ps =
      (
         ({`NCPU_DW{bank_off[`NCPU_MSR_PSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_psr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_CPUID]}} & msr_cpuid) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPSR]}} & {{`NCPU_DW-`NCPU_PSR_DW{1'b0}}, msr_epsr[`NCPU_PSR_DW-1:0]}) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_EPC]}} & msr_epc) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_ELSA]}} & msr_elsa) |
         ({`NCPU_DW{bank_off[`NCPU_MSR_COREID]}} & msr_coreid)
      );

   // Readout IMM
   assign msr_imm_tlbl_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & ~bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign msr_imm_tlbh_sel = bank_off[`NCPU_MSR_IMM_TLBSEL] & bank_off[`NCPU_MSR_IMM_TLBH_SEL];
   assign dout_imm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_IMM_TLBSEL]}} & msr_immid) |
         ({`NCPU_DW{msr_imm_tlbl_sel}} & msr_imm_tlbl) |
         ({`NCPU_DW{msr_imm_tlbh_sel}} & msr_imm_tlbh)
      );
   assign msr_imm_tlbl_idx = bank_off[`NCPU_TLB_AW-1:0];
   assign msr_imm_tlbh_idx = bank_off[`NCPU_TLB_AW-1:0];

   // Readout DMM
   assign msr_dmm_tlbl_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & ~bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign msr_dmm_tlbh_sel = bank_off[`NCPU_MSR_DMM_TLBSEL] & bank_off[`NCPU_MSR_DMM_TLBH_SEL];
   assign dout_dmm =
      (
         ({`NCPU_DW{~bank_off[`NCPU_MSR_DMM_TLBSEL]}} & msr_dmmid) |
         ({`NCPU_DW{msr_dmm_tlbl_sel}} & msr_dmm_tlbl) |
         ({`NCPU_DW{msr_dmm_tlbh_sel}} & msr_dmm_tlbh)
      );
   assign msr_dmm_tlbl_idx = bank_off[`NCPU_TLB_AW-1:0];
   assign msr_dmm_tlbh_idx = bank_off[`NCPU_TLB_AW-1:0];

   // Readout IRQC
   assign msr_irqc_imr_sel = bank_off[`NCPU_MSR_IRQC_IMR];
   assign msr_irqc_irr_sel = bank_off[`NCPU_MSR_IRQC_IRR];
   assign dout_irqc =
      (
         ({`NCPU_DW{msr_irqc_imr_sel}} & msr_irqc_imr) |
         ({`NCPU_DW{msr_irqc_irr_sel}} & msr_irqc_irr)
      );

   // Readout TSC
   assign msr_tsc_tsr_sel = bank_off[`NCPU_MSR_TSC_TSR];
   assign msr_tsc_tcr_sel = bank_off[`NCPU_MSR_TSC_TCR];
   assign dout_tsc =
      (
         ({`NCPU_DW{msr_tsc_tsr_sel}} & msr_tsc_tsr) |
         ({`NCPU_DW{msr_tsc_tcr_sel}} & msr_tsc_tcr)
      );

   // Decode MSR bank_addr
   assign bank_ps = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_PS);
   assign bank_imm = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_IMM);
   assign bank_dmm = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_DMM);
   assign bank_ica = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_ICA);
   assign bank_dca = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_DCA);
   assign bank_dbg = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_DBG);
   assign bank_irqc = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_IRQC);
   assign bank_tsc = epu_opc_bus[`NCPU_EPU_RMSR] & (bank_addr == `NCPU_MSR_BANK_TSC);

   // Result MUX
   assign wb_epu_BDATA =
      (
         ({`NCPU_DW{bank_ps}} & dout_ps) |
         ({`NCPU_DW{bank_imm}} & dout_imm) |
         ({`NCPU_DW{bank_dmm}} & dout_dmm) |
         ({`NCPU_DW{bank_irqc}} & dout_irqc) |
         ({`NCPU_DW{bank_tsc}} & dout_tsc) |
         ({`NCPU_DW{epu_opc_bus[`NCPU_EPU_ERET]}} & msr_epc)
      );

   assign wb_epu_BID = epu_id;
   assign wb_epu_BVALID = epu_AVALID & commit;
   assign epu_AREADY = wb_epu_BREADY & commit;

   assign wb_epu_BERET = epu_opc_bus[`NCPU_EPU_ERET];
   assign wb_epu_BESYSCALL = epu_opc_bus[`NCPU_EPU_ESYSCALL];
   assign wb_epu_BEINSN = epu_opc_bus[`NCPU_EPU_EINSN];
   assign wb_epu_BEITM = epu_opc_bus[`NCPU_EPU_EITM];
   assign wb_epu_BEIPF = epu_opc_bus[`NCPU_EPU_EIPF];
   assign wb_epu_BEIRQ = epu_opc_bus[`NCPU_EPU_EIRQ];

   assign commit = (rob_commit_ptr == epu_id) & ~flush;

   assign epu_hds_a = (wb_epu_BVALID & wb_epu_BREADY);

   //
   // Commit exceptions
   //
   assign ESYSCALL_commit = epu_hds_a & wb_epu_BESYSCALL;
   assign ERET_commit = epu_hds_a & wb_epu_BERET;
   assign EITM_commit = epu_hds_a & wb_epu_BEITM;
   assign EIPF_commit = epu_hds_a & wb_epu_BEIPF;
   assign EINSN_commit = epu_hds_a & wb_epu_BEINSN;
   assign EIRQ_commit = epu_hds_a & wb_epu_BEIRQ;

   ////////////////////////////////////////////////////////////////////////////////

   // Decode MSR address
   assign wmsr_operand = epu_operand_2;
   assign wmsr_we = epu_hds_a & epu_opc_bus[`NCPU_EPU_WMSR];
   assign wmsr_psr_we = epu_hds_a & epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_PSR];
   assign wmsr_epc_we = epu_hds_a & epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPC];
   assign wmsr_epsr_we = epu_hds_a & epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_EPSR];
   assign wmsr_elsa_we = epu_hds_a & epu_opc_bus[`NCPU_EPU_WMSR] & bank_ps & bank_off[`NCPU_MSR_ELSA];

   // Unpack EPSR. Be consistend with ncpu32k_psr
   assign {epsr_res[9],epsr_res[8],epsr_dmme,epsr_imme,epsr_ire,epsr_rm,epsr_res[3],epsr_res[2], epsr_res[1],epsr_res[0]} = msr_epsr;

   // Unpack WMSR PSR. Be consistend with ncpu32k_psr
   assign {wmsr_psr_res[9],wmsr_psr_res[8],wmsr_psr_dmme,wmsr_psr_imme,wmsr_psr_ire,wmsr_psr_rm,wmsr_psr_res[3],wmsr_psr_res[2], wmsr_psr_res[1],wmsr_psr_res[0]} = wmsr_operand[9:0];

   // For the convenience of maintaining EPC, SYSCALL and the other exceptions are treated differently from RET and WMSR.
   assign exc_commit = (ESYSCALL_commit | ERET_commit |
                              EITM_commit | EIPF_commit |
                              EINSN_commit |
                              epu_commit_EDTM | epu_commit_EDPF | epu_commit_EALIGN |
                              EIRQ_commit);

   assign msr_exc_ent = exc_commit & ~ERET_commit;
   // Commit PSR. Assert (03060934)
   assign msr_psr_rm_nxt = wmsr_psr_we ? wmsr_psr_rm : epsr_rm;
   assign msr_psr_rm_we = ERET_commit | wmsr_psr_we;
   assign msr_psr_imme_nxt = wmsr_psr_we ? wmsr_psr_imme : epsr_imme;
   assign msr_psr_imme_we = ERET_commit | wmsr_psr_we;
   assign msr_psr_dmme_nxt = wmsr_psr_we ? wmsr_psr_dmme : epsr_dmme;
   assign msr_psr_dmme_we = ERET_commit | wmsr_psr_we;
   assign msr_psr_ire_nxt = wmsr_psr_we ? wmsr_psr_ire : epsr_ire;
   assign msr_psr_ire_we = ERET_commit | wmsr_psr_we;
   // Commit EPSR
   assign msr_epsr_nxt = wmsr_epsr_we ? wmsr_operand[`NCPU_PSR_DW-1:0] : msr_psr;
   assign msr_epsr_we = msr_exc_ent | wmsr_epsr_we;
   // In syscall, EPC is a pointer to the next insn to syscall, while in general EPC points to the insn
   // that raised the exception.
   assign linkaddr = rob_commit_pc + 1'b1;
   assign msr_epc_nxt = wmsr_epc_we ? wmsr_operand :
                        ESYSCALL_commit ? {linkaddr[`NCPU_AW-3:0],2'b0} : {rob_commit_pc[`NCPU_AW-3:0],2'b0};
   assign msr_epc_we = msr_exc_ent | wmsr_epc_we;

   // Commit ELSA  Assert (03100705)
   assign set_elsa_as_pc = (EITM_commit | EIPF_commit | EINSN_commit);
   assign set_elsa = (set_elsa_as_pc | epu_commit_EDTM | epu_commit_EDPF | epu_commit_EALIGN);
   // Let ELSA be PC if it's IMMU or EINSN exception
   assign lsa_nxt = set_elsa_as_pc ? {rob_commit_pc[`NCPU_AW-3:0],2'b0} : epu_commit_LSA;
   // Assert (03060933)
   assign msr_elsa_nxt = set_elsa ? lsa_nxt : wmsr_operand;
   assign msr_elsa_we = set_elsa | wmsr_elsa_we;

   // Commit IMM
   assign msr_imm_tlbl_nxt = wmsr_operand;
   assign msr_imm_tlbl_we = wmsr_we & bank_imm & msr_imm_tlbl_sel;
   assign msr_imm_tlbh_nxt = wmsr_operand;
   assign msr_imm_tlbh_we = wmsr_we & bank_imm & msr_imm_tlbh_sel;

   // Commit DMM
   assign msr_dmm_tlbl_nxt = wmsr_operand;
   assign msr_dmm_tlbl_we = wmsr_we & bank_dmm & msr_dmm_tlbl_sel;
   assign msr_dmm_tlbh_nxt = wmsr_operand;
   assign msr_dmm_tlbh_we = wmsr_we & bank_dmm & msr_dmm_tlbh_sel;

   // Commit IRQC
   assign msr_irqc_imr_we = wmsr_we & bank_irqc & msr_irqc_imr_sel;
   assign msr_irqc_imr_nxt = wmsr_operand;

   // Commit TSC
   assign msr_tsc_tsr_we = wmsr_we & bank_tsc & msr_tsc_tsr_sel;
   assign msr_tsc_tsr_nxt = wmsr_operand;
   assign msr_tsc_tcr_we = wmsr_we & bank_tsc & msr_tsc_tcr_sel;
   assign msr_tsc_tcr_nxt = wmsr_operand;

	 // synthesis translate_off
`ifndef SYNTHESIS
   wire dbg_numport_sel = bank_off[0];
   wire dbg_msgport_sel = bank_off[1];
   always @(posedge clk) begin
      if (wmsr_we & bank_dbg & dbg_numport_sel)
         $display("Num port = %d", wmsr_operand);
      if (wmsr_we & bank_dbg & dbg_msgport_sel)
         $write("%c", wmsr_operand[7:0]);
   end
`endif
   // synthesis translate_on

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertions 03060934
         if (count_1({EITM_commit, EIPF_commit,
                        EINSN_commit,
                        ESYSCALL_commit, ERET_commit,
                        epu_commit_EDTM, epu_commit_EDPF, epu_commit_EALIGN,
                        EIRQ_commit,
                        wmsr_psr_we})>1)
            $fatal ("\n Bugs on exception sources (IMMU, IDU, AGU and DMMU)\n");
         // Assertions 03060933
         if (wmsr_elsa_we & set_elsa)
            $fatal ("\n Bugs on ELSA selection between wmsr and dbus\n");
         // Assertions 03100705
         if (set_elsa_as_pc & (epu_commit_EDTM | epu_commit_EDPF | epu_commit_EALIGN))
            $fatal ("\n Bugs on exception unit\n");
      end
`endif

`endif
   // synthesis translate_on


endmodule
