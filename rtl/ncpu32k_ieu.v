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

module ncpu32k_ieu(         
   input                      clk,
   input                      rst_n,
   input                      dbus_cmd_ready, /* dbus is ready to store */
   output                     dbus_cmd_valid, /* data is presented at dbus's input */
   output [`NCPU_AW-1:0]      dbus_cmd_addr,
   output [2:0]               dbus_cmd_size,
   output                     dbus_cmd_we,
   output [`NCPU_DW-1:0]      dbus_din,
   output                     dbus_ready, /* MU is ready to load */
   input                      dbus_valid, /* data is presented at dbus's output */
   input [`NCPU_DW-1:0]       dbus_dout,
   output                     ieu_in_ready, /* ops is accepted by ieu */
   input                      ieu_in_valid, /* ops is presented at ieu's input */
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_DW-1:0]       ieu_operand_3,
   input [`NCPU_AU_IOPW-1:0]  ieu_au_opc_bus,
   input                      ieu_au_cmp_eq,
   input                      ieu_au_cmp_signed,
   input [`NCPU_LU_IOPW-1:0]  ieu_lu_opc_bus,
   input [`NCPU_EU_IOPW-1:0]  ieu_eu_opc_bus,
   input                      ieu_emu_insn,
   input                      ieu_mu_load,
   input                      ieu_mu_store,
   input                      ieu_mu_sign_ext,
   input                      ieu_mu_barr,
   input [2:0]                ieu_mu_store_size,
   input [2:0]                ieu_mu_load_size,
   input                      ieu_wb_regf,
   input [`NCPU_REG_AW-1:0]   ieu_wb_reg_addr,
   input                      ieu_jmpreg,
   input [`NCPU_AW-3:0]       ieu_insn_pc,
   input                      ieu_jmplink,
   input                      ieu_syscall,
   input                      ieu_ret,
   input                      ieu_specul_jmpfar,
   input [`NCPU_AW-3:0]       ieu_specul_tgt,
   input                      ieu_specul_jmprel,
   input                      ieu_specul_bcc,
   input                      ieu_specul_extexp,
   input                      ieu_let_lsa_pc,
   output [`NCPU_REG_AW-1:0]  regf_din_addr,
   output [`NCPU_DW-1:0]      regf_din,
   output                     regf_we,
   output                     msr_exp_ent,
   input [`NCPU_PSR_DW-1:0]   msr_psr,
   input [`NCPU_PSR_DW-1:0]   msr_psr_nold,
   input                      msr_psr_cc,
   output                     msr_psr_cc_nxt,
   output                     msr_psr_cc_we,
   output                     msr_psr_rm_nxt,
   output                     msr_psr_rm_we,
   output                     msr_psr_imme_nxt,
   output                     msr_psr_imme_we,
   output                     msr_psr_dmme_nxt,
   output                     msr_psr_dmme_we,
   output                     msr_psr_ire_nxt,
   output                     msr_psr_ire_we,
   input [`NCPU_DW-1:0]       msr_epc,
   output [`NCPU_DW-1:0]      msr_epc_nxt,
   output                     msr_epc_we,
   input [`NCPU_PSR_DW-1:0]   msr_epsr,
   output [`NCPU_PSR_DW-1:0]  msr_epsr_nxt,
   output                     msr_epsr_we,
   input [`NCPU_DW-1:0]       msr_elsa,
   output [`NCPU_DW-1:0]      msr_elsa_nxt,
   output                     msr_elsa_we,
   input [`NCPU_DW-1:0]       msr_cpuid,
   input [`NCPU_DW-1:0]       msr_coreid,
   input [`NCPU_DW-1:0]       msr_immid,
   input [`NCPU_DW-1:0]       msr_imm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbl_nxt,
   output                     msr_imm_tlbl_we,
   input [`NCPU_DW-1:0]       msr_imm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbh_nxt,
   output                     msr_imm_tlbh_we,
   output                     specul_flush,
   input                      specul_flush_ack,
   output [`NCPU_AW-3:0]      ifu_flush_jmp_tgt,
   output                     bpu_wb,
   output                     bpu_wb_jmprel,
   output [`NCPU_AW-3:0]      bpu_wb_insn_pc,
   output                     bpu_wb_hit
);

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  au_adder;               // From au of ncpu32k_ie_au.v
   wire                 au_cc_nxt;              // From au of ncpu32k_ie_au.v
   wire                 au_cc_we;               // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  au_div;                 // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  au_mhi;                 // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  au_mul;                 // From au of ncpu32k_ie_au.v
   wire                 au_op_adder;            // From au of ncpu32k_ie_au.v
   wire                 au_op_mhi;              // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  ieu_eu_dout;            // From eu of ncpu32k_ie_eu.v
   wire                 ieu_eu_dout_op;         // From eu of ncpu32k_ie_eu.v
   wire                 ieu_mu_in_ready;        // From mu of ncpu32k_ie_mu.v
   wire [`NCPU_DW-1:0]  lu_and;                 // From lu of ncpu32k_ie_lu.v
   wire                 lu_op_shift;            // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_or;                  // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_shift;               // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_xor;                 // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  mu_load;                // From mu of ncpu32k_ie_mu.v
   wire                 mu_op_load;             // From mu of ncpu32k_ie_mu.v
   wire [`NCPU_REG_AW-1:0] mu_wb_reg_addr;      // From mu of ncpu32k_ie_mu.v
   wire                 mu_wb_regf;             // From mu of ncpu32k_ie_mu.v
   wire                 wb_mu_in_valid;         // From mu of ncpu32k_ie_mu.v
   // End of automatics
   wire                 ieu_mu_in_valid;
   wire                 mu_op;
   wire [`NCPU_DW:0]    linkaddr;
   wire                 ieu_set_lsa;
   wire [`NCPU_DW:0]    ieu_lsa;
   
   ncpu32k_ie_au au
      (/*AUTOINST*/
       // Outputs
       .au_op_adder                     (au_op_adder),
       .au_adder                        (au_adder[`NCPU_DW-1:0]),
       .au_op_mhi                       (au_op_mhi),
       .au_mhi                          (au_mhi[`NCPU_DW-1:0]),
       .au_cc_we                        (au_cc_we),
       .au_cc_nxt                       (au_cc_nxt),
       .au_mul                          (au_mul[`NCPU_DW-1:0]),
       .au_div                          (au_div[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_au_opc_bus                  (ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]),
       .ieu_au_cmp_eq                   (ieu_au_cmp_eq),
       .ieu_au_cmp_signed               (ieu_au_cmp_signed));

   ncpu32k_ie_lu lu
      (/*AUTOINST*/
       // Outputs
       .lu_op_shift                     (lu_op_shift),
       .lu_shift                        (lu_shift[`NCPU_DW-1:0]),
       .lu_and                          (lu_and[`NCPU_DW-1:0]),
       .lu_or                           (lu_or[`NCPU_DW-1:0]),
       .lu_xor                          (lu_xor[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_lu_opc_bus                  (ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]));

   ncpu32k_ie_mu mu
      (/*AUTOINST*/
       // Outputs
       .dbus_cmd_valid                  (dbus_cmd_valid),
       .dbus_cmd_addr                   (dbus_cmd_addr[`NCPU_AW-1:0]),
       .dbus_cmd_size                   (dbus_cmd_size[2:0]),
       .dbus_cmd_we                     (dbus_cmd_we),
       .dbus_din                        (dbus_din[`NCPU_DW-1:0]),
       .dbus_ready                      (dbus_ready),
       .ieu_mu_in_ready                 (ieu_mu_in_ready),
       .mu_op                           (mu_op),
       .mu_op_load                      (mu_op_load),
       .mu_wb_regf                      (mu_wb_regf),
       .mu_wb_reg_addr                  (mu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .mu_load                         (mu_load[`NCPU_DW-1:0]),
       .wb_mu_in_valid                  (wb_mu_in_valid),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dbus_cmd_ready                  (dbus_cmd_ready),
       .dbus_valid                      (dbus_valid),
       .dbus_dout                       (dbus_dout[`NCPU_DW-1:0]),
       .ieu_mu_in_valid                 (ieu_mu_in_valid),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_operand_3                   (ieu_operand_3[`NCPU_DW-1:0]),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_sign_ext                 (ieu_mu_sign_ext),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .ieu_wb_regf                     (ieu_wb_regf),
       .ieu_wb_reg_addr                 (ieu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .wb_mu_in_ready                  (wb_mu_in_ready));
        
   ncpu32k_ie_eu eu
      (/*AUTOINST*/
       // Outputs
       .ieu_eu_dout_op                  (ieu_eu_dout_op),
       .ieu_eu_dout                     (ieu_eu_dout[`NCPU_DW-1:0]),
       .msr_psr_cc_nxt                  (msr_psr_cc_nxt),
       .msr_psr_cc_we                   (msr_psr_cc_we),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_exp_ent                     (msr_exp_ent),
       .msr_epc_nxt                     (msr_epc_nxt[`NCPU_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[`NCPU_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[`NCPU_TLB_AW-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[`NCPU_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ieu_eu_opc_bus                  (ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_operand_3                   (ieu_operand_3[`NCPU_DW-1:0]),
       .commit                          (commit),
       .au_cc_we                        (au_cc_we),
       .au_cc_nxt                       (au_cc_nxt),
       .ieu_ret                         (ieu_ret),
       .ieu_syscall                     (ieu_syscall),
       .ieu_lsa                         (ieu_lsa[`NCPU_DW-1:0]),
       .ieu_insn_pc                     (ieu_insn_pc[`NCPU_AW-3:0]),
       .ieu_specul_extexp               (ieu_specul_extexp),
       .ieu_let_lsa_pc                  (ieu_let_lsa_pc),
       .linkaddr                        (linkaddr[`NCPU_DW:0]),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_imm_tlbl                    (msr_imm_tlbl[`NCPU_DW-1:0]),
       .msr_imm_tlbh                    (msr_imm_tlbh[`NCPU_DW-1:0]));
        
   wire hds_ieu_in = ieu_in_ready & ieu_in_valid;
   wire hds_wb_mu_in = wb_mu_in_ready & wb_mu_in_valid;
   
   // Link address (offset(jmp)+1), which indicates the next insn of current jmp insn.
   assign linkaddr = {{(`NCPU_DW-`NCPU_AW+1){1'b0}}, {ieu_insn_pc[`NCPU_AW-3:0]+1'b1, 2'b00}};
   
   // WriteBack (commit)
   // Before commit, modules must check this bit.
   // valid signal from upstream makes sense here, as an insn with invalid info
   // should be never committed.
   assign commit = hds_ieu_in;
   assign mu_commit = hds_wb_mu_in;
   
   // Flush FSM
   wire fls_status_r;
   wire fls_status_nxt;
   wire specul_flush_r;
   wire specul_flush_nxt;
   
   assign fls_status_nxt =
      (
         // If speculative execution taken, then request flushing.
         (~fls_status_r & hds_ieu_in & specul_flush_nxt) ? 1'b1 :
         // If request is acked, then exit flushing.
         (fls_status_r & specul_flush_ack) ? 1'b0 : fls_status_r
      );
   
   ncpu32k_cell_dff_r #(1) dff_fls_status_r
                   (clk,rst_n, fls_status_nxt, fls_status_r);

   ncpu32k_cell_dff_lr #(1) dff_specul_flush_r
                   (clk,rst_n, ~fls_status_r, specul_flush_nxt, specul_flush_r);
   
   wire hld_fls = fls_status_r & ~specul_flush_ack; // bypass flush_ack
   
   assign specul_flush = hld_fls ? specul_flush_r : specul_flush_nxt;
   
   //
   // Speculative execution checking point. Flush:
   //    case 1: jmprel: specul_bcc mismatched
   //    case 2: jmpfar: specul_tgt mismatched
   //    case 3: syscall : unconditional flush. (For pipeline refreshing of IMMU)
   //    case 4: ret: unconditional flush. (Mainly for pipeline refreshing of IMMU)
   //    case 5: exception: unconditional flush.
   // This should not be controlled by commit, instead flush_ack
   assign specul_flush_nxt = commit &
      (
         (ieu_specul_jmprel & (ieu_specul_bcc != msr_psr_cc))
         | (ieu_specul_jmpfar & (ieu_specul_tgt != ieu_operand_1))
         | ieu_syscall
         | ieu_ret
         | ieu_specul_extexp
      );
   
   // Speculative exec is failed, then flush all pre-insns and fetch the right target
   // Assert (03060725)
   assign ifu_flush_jmp_tgt =
         ({`NCPU_AW-2{ieu_specul_jmprel}} & ieu_specul_tgt) |
         ({`NCPU_AW-2{ieu_specul_jmpfar}} & ieu_operand_1) |
         ({`NCPU_AW-2{ieu_syscall}} & ieu_specul_tgt) |
         ({`NCPU_AW-2{ieu_ret}} & msr_epc[`NCPU_AW-1:2]) |
         ({`NCPU_AW-2{ieu_specul_extexp}} & ieu_specul_tgt);
   
   assign bpu_wb = commit & (ieu_specul_jmprel | ieu_specul_jmpfar);
   assign bpu_wb_jmprel = ieu_specul_jmprel;
   assign bpu_wb_hit = ~specul_flush;
   assign bpu_wb_insn_pc = ieu_insn_pc;
   
   // Write back regfile
   assign regf_din = 
      ({`NCPU_DW{mu_op_load}} & mu_load[`NCPU_DW-1:0]) |
      ({`NCPU_DW{~mu_op_load}} & (
            // Assert (03060935)
            ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_AND]}} & lu_and[`NCPU_DW-1:0]) |
            ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_OR]}} & lu_or[`NCPU_DW-1:0]) |
            ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_XOR]}} & lu_xor[`NCPU_DW-1:0]) |
            ({`NCPU_DW{lu_op_shift}} & lu_shift[`NCPU_DW-1:0]) |
            ({`NCPU_DW{au_op_adder}} & au_adder[`NCPU_DW-1:0]) |
            ({`NCPU_DW{au_op_mhi}} & au_mhi[`NCPU_DW-1:0]) |
            ({`NCPU_DW{ieu_jmplink}} & linkaddr[`NCPU_DW-1:0]) |
            ({`NCPU_DW{ieu_eu_dout_op}} & ieu_eu_dout[`NCPU_DW-1:0])
         ));
   
   assign regf_din_addr = ({`NCPU_REG_AW{~mu_op}} & ieu_wb_reg_addr) |
                          ({`NCPU_REG_AW{mu_op}} & mu_wb_reg_addr);

   assign regf_we = (~mu_op & commit & ieu_wb_regf) |
                     (mu_op & mu_commit & mu_wb_regf);

   assign wb_mu_in_ready = /* data is accepted by regfile */ 1'b1;
   
   assign ieu_mu_in_valid = ieu_in_valid;
   
   // IEU is ready when there is no flushing and MU is ready
   assign ieu_in_ready = (~hld_fls) & ieu_mu_in_ready;
   
   // Assertions 03060935
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if(regf_we & (ieu_lu_opc_bus[`NCPU_LU_AND] |
                     ieu_lu_opc_bus[`NCPU_LU_OR] |
                     ieu_lu_opc_bus[`NCPU_LU_XOR] |
                     lu_op_shift |
                     au_op_adder |
                     au_op_mhi |
                     ieu_jmplink |
                     ieu_eu_dout_op)
                  & ~(ieu_lu_opc_bus[`NCPU_LU_AND] ^
                        ieu_lu_opc_bus[`NCPU_LU_OR] ^
                        ieu_lu_opc_bus[`NCPU_LU_XOR] ^
                        lu_op_shift ^
                        au_op_adder ^
                        au_op_mhi ^
                        ieu_jmplink ^
                        ieu_eu_dout_op)
                  )
         $fatal ("\n ctrls of 'regf_din' MUX should be mutex\n");
   end
`endif

   // Assertions 03060725
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if((ieu_specul_jmprel|ieu_specul_jmpfar|ieu_syscall|ieu_ret|ieu_specul_extexp) &
            ~(ieu_specul_jmprel^ieu_specul_jmpfar^ieu_syscall^ieu_ret^ieu_specul_extexp)) begin
         $fatal ("\n ctrls of 'ifu_flush_jmp_tgt' MUX should be mutex\n");
      end
   end
`endif

endmodule
