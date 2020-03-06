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

module ncpu32k_core(
   input                   clk,
   input                   rst_n,
   output [`NCPU_AW-1:0]   dbus_addr_o,
   output                  dbus_in_valid,
   input                   dbus_in_ready,
   output [`NCPU_DW-1:0]   dbus_o,
   input                   dbus_out_valid,
   output                  dbus_out_ready,
   input [`NCPU_DW-1:0]    dbus_i,
   output [2:0]            dbus_size_o,
   input                   ibus_cmd_ready, /* ibus is ready to accept cmd */
   output                  ibus_cmd_valid, /* cmd is presented at ibus'input */
   output [`NCPU_AW-1:0]   ibus_cmd_addr, /* IMPORTANT! changing after cmd handshaked */
   input                   ibus_dout_valid,
   output                  ibus_dout_ready,
   input [`NCPU_IW-1:0]    ibus_dout,
   input [`NCPU_AW-1:0]    ibus_out_id,
   input [`NCPU_AW-1:0]    ibus_out_id_nxt,
   output                  ibus_cmd_flush,
   input                   ibus_flush_ack,
   input                   exp_imm_tlb_miss,
   input                   exp_imm_page_fault,
   output                  msr_psr_imme,
   output                  msr_psr_rm,
   input [`NCPU_DW-1:0]       msr_immid,
   input [`NCPU_DW-1:0]       msr_imm_tlbl,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbl_nxt,
   output                     msr_imm_tlbl_we,
   input [`NCPU_DW-1:0]       msr_imm_tlbh,
   output [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx,
   output [`NCPU_DW-1:0]      msr_imm_tlbh_nxt,
   output                     msr_imm_tlbh_we
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_AW-3:0]  bpu_insn_pc;            // From ifu of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  bpu_jmp_tgt;            // From bpu of ncpu32k_bpu.v
   wire                 bpu_jmprel;             // From ifu of ncpu32k_ifu.v, ...
   wire                 bpu_jmprel_taken;       // From bpu of ncpu32k_bpu.v
   wire [`NCPU_DW-1:0]  bpu_msr_epc;            // From bpu of ncpu32k_bpu.v
   wire                 bpu_rd;                 // From ifu of ncpu32k_ifu.v
   wire                 bpu_wb;                 // From ieu of ncpu32k_ieu.v
   wire                 bpu_wb_hit;             // From ieu of ncpu32k_ieu.v
   wire [`NCPU_AW-3:0]  bpu_wb_insn_pc;         // From ieu of ncpu32k_ieu.v
   wire                 bpu_wb_jmprel;          // From ieu of ncpu32k_ieu.v
   wire                 idu_in_ready;           // From idu of ncpu32k_idu.v
   wire                 idu_in_valid;           // From ifu of ncpu32k_ifu.v
   wire [`NCPU_IW-1:0]  idu_insn;               // From ifu of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  idu_insn_pc;            // From ifu of ncpu32k_ifu.v, ...
   wire                 idu_jmprel_link;        // From ifu of ncpu32k_ifu.v
   wire                 idu_let_lsa_pc;         // From ifu of ncpu32k_ifu.v
   wire                 idu_op_jmpfar;          // From ifu of ncpu32k_ifu.v
   wire                 idu_op_jmprel;          // From ifu of ncpu32k_ifu.v
   wire                 idu_op_ret;             // From ifu of ncpu32k_ifu.v
   wire                 idu_op_syscall;         // From ifu of ncpu32k_ifu.v
   wire                 idu_specul_bcc;         // From ifu of ncpu32k_ifu.v
   wire                 idu_specul_extexp;      // From ifu of ncpu32k_ifu.v
   wire                 idu_specul_jmpfar;      // From ifu of ncpu32k_ifu.v
   wire                 idu_specul_jmprel;      // From ifu of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  idu_specul_tgt;         // From ifu of ncpu32k_ifu.v
   wire                 ieu_au_cmp_eq;          // From idu of ncpu32k_idu.v
   wire                 ieu_au_cmp_signed;      // From idu of ncpu32k_idu.v
   wire [`NCPU_AU_IOPW-1:0] ieu_au_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_emu_insn;           // From idu of ncpu32k_idu.v
   wire [`NCPU_EU_IOPW-1:0] ieu_eu_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_in_ready;           // From ieu of ncpu32k_ieu.v
   wire                 ieu_in_valid;           // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ieu_insn_pc;            // From idu of ncpu32k_idu.v
   wire                 ieu_jmplink;            // From idu of ncpu32k_idu.v
   wire                 ieu_let_lsa_pc;         // From idu of ncpu32k_idu.v
   wire [`NCPU_LU_IOPW-1:0] ieu_lu_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_mu_barr;            // From idu of ncpu32k_idu.v
   wire                 ieu_mu_load;            // From idu of ncpu32k_idu.v
   wire [2:0]           ieu_mu_load_size;       // From idu of ncpu32k_idu.v
   wire                 ieu_mu_sign_ext;        // From idu of ncpu32k_idu.v
   wire                 ieu_mu_store;           // From idu of ncpu32k_idu.v
   wire [2:0]           ieu_mu_store_size;      // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_1;          // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_2;          // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_3;          // From idu of ncpu32k_idu.v
   wire                 ieu_ret;                // From idu of ncpu32k_idu.v
   wire                 ieu_specul_bcc;         // From idu of ncpu32k_idu.v
   wire                 ieu_specul_extexp;      // From idu of ncpu32k_idu.v
   wire                 ieu_specul_jmpfar;      // From idu of ncpu32k_idu.v
   wire                 ieu_specul_jmprel;      // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ieu_specul_tgt;         // From idu of ncpu32k_idu.v
   wire                 ieu_syscall;            // From idu of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] ieu_wb_reg_addr;     // From idu of ncpu32k_idu.v
   wire                 ieu_wb_regf;            // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ifu_flush_jmp_tgt;      // From ieu of ncpu32k_ieu.v
   wire                 ifu_jmpfar;             // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ifu_jmpfar_addr;        // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  msr_coreid;             // From psr of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_cpuid;              // From psr of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_elsa;               // From psr of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_elsa_nxt;           // From ieu of ncpu32k_ieu.v
   wire                 msr_elsa_we;            // From ieu of ncpu32k_ieu.v
   wire [`NCPU_DW-1:0]  msr_epc;                // From psr of ncpu32k_psr.v
   wire [`NCPU_DW-1:0]  msr_epc_nxt;            // From ieu of ncpu32k_ieu.v
   wire                 msr_epc_we;             // From ieu of ncpu32k_ieu.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr;            // From psr of ncpu32k_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nxt;        // From ieu of ncpu32k_ieu.v
   wire                 msr_epsr_we;            // From ieu of ncpu32k_ieu.v
   wire                 msr_exp_ent;            // From ieu of ncpu32k_ieu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr;             // From psr of ncpu32k_psr.v
   wire                 msr_psr_cc;             // From psr of ncpu32k_psr.v
   wire                 msr_psr_cc_nxt;         // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_cc_we;          // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_dmme;           // From psr of ncpu32k_psr.v
   wire                 msr_psr_dmme_nxt;       // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_dmme_we;        // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_imme_nxt;       // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_imme_we;        // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_ire;            // From psr of ncpu32k_psr.v
   wire                 msr_psr_ire_nxt;        // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_ire_we;         // From ieu of ncpu32k_ieu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr_nold;        // From psr of ncpu32k_psr.v
   wire                 msr_psr_rm_nxt;         // From ieu of ncpu32k_ieu.v
   wire                 msr_psr_rm_we;          // From ieu of ncpu32k_ieu.v
   wire [`NCPU_DW-1:0]  regf_din;               // From ieu of ncpu32k_ieu.v
   wire [`NCPU_REG_AW-1:0] regf_din_addr;       // From ieu of ncpu32k_ieu.v
   wire [`NCPU_REG_AW-1:0] regf_rs1_addr;       // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  regf_rs1_dout;          // From regfile0 of ncpu32k_regfile.v
   wire                 regf_rs1_re;            // From idu of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] regf_rs2_addr;       // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  regf_rs2_dout;          // From regfile0 of ncpu32k_regfile.v
   wire                 regf_rs2_re;            // From idu of ncpu32k_idu.v
   wire                 regf_we;                // From ieu of ncpu32k_ieu.v
   wire                 specul_flush;           // From ieu of ncpu32k_ieu.v
   // End of automatics
   
   /////////////////////////////////////////////////////////////////////////////
   // Regfile
   /////////////////////////////////////////////////////////////////////////////
   
   wire [`NCPU_REG_AW-1:0] regf_rs1_addr_i;
   wire [`NCPU_REG_AW-1:0] regf_rs2_addr_i;
   wire                    regf_rs1_re_i;
   wire                    regf_rs2_re_i;
   wire [`NCPU_REG_AW-1:0] regf_rd_addr_i;
   wire [`NCPU_DW-1:0]     regf_rd_i;
   wire                    regf_rd_we_i;
   
   ncpu32k_regfile regfile0
      (/*AUTOINST*/
       // Outputs
       .regf_rs1_dout                   (regf_rs1_dout[`NCPU_DW-1:0]),
       .regf_rs2_dout                   (regf_rs2_dout[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .regf_rs1_addr                   (regf_rs1_addr[`NCPU_REG_AW-1:0]),
       .regf_rs2_addr                   (regf_rs2_addr[`NCPU_REG_AW-1:0]),
       .regf_rs1_re                     (regf_rs1_re),
       .regf_rs2_re                     (regf_rs2_re),
       .regf_din_addr                   (regf_din_addr[`NCPU_REG_AW-1:0]),
       .regf_din                        (regf_din[`NCPU_DW-1:0]),
       .regf_we                         (regf_we));
   
   ncpu32k_psr psr
      (/*AUTOINST*/
       // Outputs
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_psr_cc                      (msr_psr_cc),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .msr_exp_ent                     (msr_exp_ent),
       .msr_psr_cc_nxt                  (msr_psr_cc_nxt),
       .msr_psr_cc_we                   (msr_psr_cc_we),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_epc_nxt                     (msr_epc_nxt[`NCPU_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[`NCPU_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we));
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1: Fetch
   /////////////////////////////////////////////////////////////////////////////
   
   ncpu32k_ifu ifu
      (/*AUTOINST*/
       // Outputs
       .ibus_dout_ready                 (ibus_dout_ready),
       .ibus_cmd_valid                  (ibus_cmd_valid),
       .ibus_cmd_addr                   (ibus_cmd_addr[`NCPU_AW-1:0]),
       .ibus_cmd_flush                  (ibus_cmd_flush),
       .idu_in_valid                    (idu_in_valid),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_insn_pc                     (idu_insn_pc[`NCPU_AW-3:0]),
       .idu_jmprel_link                 (idu_jmprel_link),
       .idu_op_jmprel                   (idu_op_jmprel),
       .idu_op_jmpfar                   (idu_op_jmpfar),
       .idu_op_syscall                  (idu_op_syscall),
       .idu_op_ret                      (idu_op_ret),
       .idu_specul_jmpfar               (idu_specul_jmpfar),
       .idu_specul_tgt                  (idu_specul_tgt[`NCPU_AW-3:0]),
       .idu_specul_jmprel               (idu_specul_jmprel),
       .idu_specul_bcc                  (idu_specul_bcc),
       .idu_specul_extexp               (idu_specul_extexp),
       .idu_let_lsa_pc                  (idu_let_lsa_pc),
       .bpu_rd                          (bpu_rd),
       .bpu_jmprel                      (bpu_jmprel),
       .bpu_insn_pc                     (bpu_insn_pc[`NCPU_AW-3:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ibus_dout_valid                 (ibus_dout_valid),
       .ibus_dout                       (ibus_dout[`NCPU_IW-1:0]),
       .ibus_cmd_ready                  (ibus_cmd_ready),
       .ibus_out_id                     (ibus_out_id[`NCPU_AW-1:0]),
       .ibus_out_id_nxt                 (ibus_out_id_nxt[`NCPU_AW-1:0]),
       .ibus_flush_ack                  (ibus_flush_ack),
       .exp_imm_tlb_miss                (exp_imm_tlb_miss),
       .exp_imm_page_fault              (exp_imm_page_fault),
       .bpu_msr_epc                     (bpu_msr_epc[`NCPU_DW-1:0]),
       .ifu_flush_jmp_tgt               (ifu_flush_jmp_tgt[`NCPU_AW-3:0]),
       .specul_flush                    (specul_flush),
       .idu_in_ready                    (idu_in_ready),
       .bpu_jmp_tgt                     (bpu_jmp_tgt[`NCPU_AW-3:0]),
       .bpu_jmprel_taken                (bpu_jmprel_taken));
   
   ncpu32k_bpu bpu
      (/*AUTOINST*/
       // Outputs
       .bpu_jmprel                      (bpu_jmprel),
       .bpu_jmp_tgt                     (bpu_jmp_tgt[`NCPU_AW-3:0]),
       .bpu_jmprel_taken                (bpu_jmprel_taken),
       .bpu_msr_epc                     (bpu_msr_epc[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .bpu_insn_pc                     (bpu_insn_pc[`NCPU_AW-3:0]),
       .bpu_rd                          (bpu_rd),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_jmprel                   (bpu_wb_jmprel),
       .bpu_wb_insn_pc                  (bpu_wb_insn_pc[`NCPU_AW-3:0]),
       .bpu_wb_hit                      (bpu_wb_hit));
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 2: Decode
   /////////////////////////////////////////////////////////////////////////////
   
   ncpu32k_idu idu
      (/*AUTOINST*/
       // Outputs
       .idu_in_ready                    (idu_in_ready),
       .idu_insn_pc                     (idu_insn_pc[`NCPU_AW-3:0]),
       .regf_rs1_re                     (regf_rs1_re),
       .regf_rs1_addr                   (regf_rs1_addr[`NCPU_REG_AW-1:0]),
       .regf_rs2_re                     (regf_rs2_re),
       .regf_rs2_addr                   (regf_rs2_addr[`NCPU_REG_AW-1:0]),
       .ifu_jmpfar                      (ifu_jmpfar),
       .ifu_jmpfar_addr                 (ifu_jmpfar_addr[`NCPU_AW-3:0]),
       .ieu_in_valid                    (ieu_in_valid),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_operand_3                   (ieu_operand_3[`NCPU_DW-1:0]),
       .ieu_lu_opc_bus                  (ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]),
       .ieu_au_opc_bus                  (ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]),
       .ieu_au_cmp_eq                   (ieu_au_cmp_eq),
       .ieu_au_cmp_signed               (ieu_au_cmp_signed),
       .ieu_eu_opc_bus                  (ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]),
       .ieu_emu_insn                    (ieu_emu_insn),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_sign_ext                 (ieu_mu_sign_ext),
       .ieu_mu_barr                     (ieu_mu_barr),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .ieu_wb_regf                     (ieu_wb_regf),
       .ieu_wb_reg_addr                 (ieu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .ieu_insn_pc                     (ieu_insn_pc[`NCPU_AW-3:0]),
       .ieu_jmplink                     (ieu_jmplink),
       .ieu_syscall                     (ieu_syscall),
       .ieu_ret                         (ieu_ret),
       .ieu_specul_jmpfar               (ieu_specul_jmpfar),
       .ieu_specul_tgt                  (ieu_specul_tgt[`NCPU_AW-3:0]),
       .ieu_specul_jmprel               (ieu_specul_jmprel),
       .ieu_specul_bcc                  (ieu_specul_bcc),
       .ieu_specul_extexp               (ieu_specul_extexp),
       .ieu_let_lsa_pc                  (ieu_let_lsa_pc),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .idu_in_valid                    (idu_in_valid),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_op_jmprel                   (idu_op_jmprel),
       .idu_op_jmpfar                   (idu_op_jmpfar),
       .idu_op_syscall                  (idu_op_syscall),
       .idu_op_ret                      (idu_op_ret),
       .idu_jmprel_link                 (idu_jmprel_link),
       .idu_specul_jmpfar               (idu_specul_jmpfar),
       .idu_specul_tgt                  (idu_specul_tgt[`NCPU_AW-3:0]),
       .idu_specul_jmprel               (idu_specul_jmprel),
       .idu_specul_bcc                  (idu_specul_bcc),
       .idu_specul_extexp               (idu_specul_extexp),
       .idu_let_lsa_pc                  (idu_let_lsa_pc),
       .specul_flush                    (specul_flush),
       .regf_rs1_dout                   (regf_rs1_dout[`NCPU_DW-1:0]),
       .regf_rs2_dout                   (regf_rs2_dout[`NCPU_DW-1:0]),
       .ieu_in_ready                    (ieu_in_ready));
   

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3: Execution && Load/Store
   /////////////////////////////////////////////////////////////////////////////
   
   ncpu32k_ieu ieu
      (/*AUTOINST*/
       // Outputs
       .dbus_addr_o                     (dbus_addr_o[`NCPU_AW-1:0]),
       .dbus_in_valid                   (dbus_in_valid),
       .dbus_out_ready                  (dbus_out_ready),
       .dbus_o                          (dbus_o[`NCPU_DW-1:0]),
       .dbus_size_o                     (dbus_size_o[2:0]),
       .ieu_in_ready                    (ieu_in_ready),
       .regf_din_addr                   (regf_din_addr[`NCPU_REG_AW-1:0]),
       .regf_din                        (regf_din[`NCPU_DW-1:0]),
       .regf_we                         (regf_we),
       .msr_exp_ent                     (msr_exp_ent),
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
       .specul_flush                    (specul_flush),
       .ifu_flush_jmp_tgt               (ifu_flush_jmp_tgt[`NCPU_AW-3:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_jmprel                   (bpu_wb_jmprel),
       .bpu_wb_insn_pc                  (bpu_wb_insn_pc[`NCPU_AW-3:0]),
       .bpu_wb_hit                      (bpu_wb_hit),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dbus_in_ready                   (dbus_in_ready),
       .dbus_i                          (dbus_i[`NCPU_DW-1:0]),
       .dbus_out_valid                  (dbus_out_valid),
       .ieu_in_valid                    (ieu_in_valid),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_operand_3                   (ieu_operand_3[`NCPU_DW-1:0]),
       .ieu_au_opc_bus                  (ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]),
       .ieu_au_cmp_eq                   (ieu_au_cmp_eq),
       .ieu_au_cmp_signed               (ieu_au_cmp_signed),
       .ieu_lu_opc_bus                  (ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]),
       .ieu_eu_opc_bus                  (ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]),
       .ieu_emu_insn                    (ieu_emu_insn),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_sign_ext                 (ieu_mu_sign_ext),
       .ieu_mu_barr                     (ieu_mu_barr),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .ieu_wb_regf                     (ieu_wb_regf),
       .ieu_wb_reg_addr                 (ieu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .ieu_jmpreg                      (ieu_jmpreg),
       .ieu_insn_pc                     (ieu_insn_pc[`NCPU_AW-3:0]),
       .ieu_jmplink                     (ieu_jmplink),
       .ieu_syscall                     (ieu_syscall),
       .ieu_ret                         (ieu_ret),
       .ieu_specul_jmpfar               (ieu_specul_jmpfar),
       .ieu_specul_tgt                  (ieu_specul_tgt[`NCPU_AW-3:0]),
       .ieu_specul_jmprel               (ieu_specul_jmprel),
       .ieu_specul_bcc                  (ieu_specul_bcc),
       .ieu_specul_extexp               (ieu_specul_extexp),
       .ieu_let_lsa_pc                  (ieu_let_lsa_pc),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_nold                    (msr_psr_nold[`NCPU_PSR_DW-1:0]),
       .msr_psr_cc                      (msr_psr_cc),
       .msr_epc                         (msr_epc[`NCPU_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[`NCPU_DW-1:0]),
       .msr_cpuid                       (msr_cpuid[`NCPU_DW-1:0]),
       .msr_coreid                      (msr_coreid[`NCPU_DW-1:0]),
       .msr_immid                       (msr_immid[`NCPU_DW-1:0]),
       .msr_imm_tlbl                    (msr_imm_tlbl[`NCPU_DW-1:0]),
       .msr_imm_tlbh                    (msr_imm_tlbh[`NCPU_DW-1:0]));
   
   
endmodule
