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
   output [`NCPU_AW-1:0]   ibus_addr_o,
   input                   ibus_out_valid,
   output                  ibus_out_ready,
   input [`NCPU_IW-1:0]    ibus_o
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 idu_in_ready;           // From idu of ncpu32k_idu.v
   wire                 idu_in_valid;           // From ifu of ncpu32k_ifu.v
   wire [`NCPU_IW-1:0]  idu_insn;               // From ifu of ncpu32k_ifu.v
   wire [`NCPU_AW-3:0]  idu_insn_pc;            // From ifu of ncpu32k_ifu.v, ...
   wire                 idu_jmprel_link;        // From ifu of ncpu32k_ifu.v
   wire                 idu_op_jmprel;          // From ifu of ncpu32k_ifu.v
   wire [`NCPU_AU_IOPW-1:0] ieu_au_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_emu_insn;           // From idu of ncpu32k_idu.v
   wire [`NCPU_EU_IOPW-1:0] ieu_eu_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_in_ready;           // From ieu of ncpu32k_ieu.v
   wire                 ieu_in_valid;           // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ieu_insn_pc;            // From idu of ncpu32k_idu.v
   wire                 ieu_jmplink;            // From idu of ncpu32k_idu.v
   wire [`NCPU_LU_IOPW-1:0] ieu_lu_opc_bus;     // From idu of ncpu32k_idu.v
   wire                 ieu_mu_barr;            // From idu of ncpu32k_idu.v
   wire                 ieu_mu_load;            // From idu of ncpu32k_idu.v
   wire [2:0]           ieu_mu_load_size;       // From idu of ncpu32k_idu.v
   wire                 ieu_mu_store;           // From idu of ncpu32k_idu.v
   wire [2:0]           ieu_mu_store_size;      // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_1;          // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_2;          // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  ieu_operand_3;          // From idu of ncpu32k_idu.v
   wire [`NCPU_REG_AW-1:0] ieu_wb_reg_addr;     // From idu of ncpu32k_idu.v
   wire                 ieu_wb_regf;            // From idu of ncpu32k_idu.v
   wire                 ifu_jmpfar;             // From idu of ncpu32k_idu.v
   wire [`NCPU_AW-3:0]  ifu_jmpfar_addr;        // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  regf_din;               // From ieu of ncpu32k_ieu.v
   wire [`NCPU_REG_AW-1:0] regf_din_addr;       // From ieu of ncpu32k_ieu.v
   wire [`NCPU_REG_AW-1:0] regf_rs1_addr;       // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  regf_rs1_dout;          // From regfile0 of ncpu32k_regfile.v
   wire                 regf_rs1_re;            // From idu of ncpu32k_idu.v
   wire                 regf_rs1_valid;         // From regfile0 of ncpu32k_regfile.v
   wire [`NCPU_REG_AW-1:0] regf_rs2_addr;       // From idu of ncpu32k_idu.v
   wire [`NCPU_DW-1:0]  regf_rs2_dout;          // From regfile0 of ncpu32k_regfile.v
   wire                 regf_rs2_re;            // From idu of ncpu32k_idu.v
   wire                 regf_rs2_valid;         // From regfile0 of ncpu32k_regfile.v
   wire                 regf_we;                // From ieu of ncpu32k_ieu.v
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
       .regf_rs1_valid                  (regf_rs1_valid),
       .regf_rs2_valid                  (regf_rs2_valid),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .regf_rs1_addr                   (regf_rs1_addr[`NCPU_REG_AW-1:0]),
       .regf_rs2_addr                   (regf_rs2_addr[`NCPU_REG_AW-1:0]),
       .regf_rs1_re                     (regf_rs1_re),
       .regf_rs2_re                     (regf_rs2_re),
       .regf_din_addr                   (regf_din_addr[`NCPU_REG_AW-1:0]),
       .regf_din                        (regf_din[`NCPU_DW-1:0]),
       .regf_rd_we                      (regf_rd_we));
   
   // MSR.PSR.CC - Condition Control Register
   wire                 msr_psr_cc_i;
   wire                 msr_psr_cc;
   wire                 msr_psr_cc_r;
   wire                 msr_psr_cc_we;
   
   ncpu32k_cell_dff_lr #(1) dff_msr_psr_cc (clk_i, rst_n_i, msr_psr_cc_we, msr_psr_cc_i, msr_psr_cc_r);
   
   // MSR Bypass
   assign msr_psr_cc = (msr_psr_cc_we ? msr_psr_cc_i : msr_psr_cc_r);
   
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1: Fetch
   /////////////////////////////////////////////////////////////////////////////
   
   ncpu32k_ifu ifu
      (/*AUTOINST*/
       // Outputs
       .ibus_out_ready                  (ibus_out_ready),
       .ibus_addr_o                     (ibus_addr_o[`NCPU_AW-1:0]),
       .idu_in_valid                    (idu_in_valid),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_insn_pc                     (idu_insn_pc[`NCPU_AW-3:0]),
       .idu_jmprel_link                 (idu_jmprel_link),
       .idu_op_jmprel                   (idu_op_jmprel),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ibus_out_valid                  (ibus_out_valid),
       .ibus_o                          (ibus_o[`NCPU_IW-1:0]),
       .ifu_jmpfar                      (ifu_jmpfar),
       .ifu_jmpfar_addr                 (ifu_jmpfar_addr[`NCPU_AW-3:0]),
       .ifu_jmp_ready                   (ifu_jmp_ready),
       .msr_psr_cc                      (msr_psr_cc),
       .idu_in_ready                    (idu_in_ready));
   
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
       .ieu_eu_opc_bus                  (ieu_eu_opc_bus[`NCPU_EU_IOPW-1:0]),
       .ieu_emu_insn                    (ieu_emu_insn),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_barr                     (ieu_mu_barr),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .ieu_wb_regf                     (ieu_wb_regf),
       .ieu_wb_reg_addr                 (ieu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .ieu_insn_pc                     (ieu_insn_pc[`NCPU_AW-3:0]),
       .ieu_jmplink                     (ieu_jmplink),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .idu_in_valid                    (idu_in_valid),
       .idu_insn                        (idu_insn[`NCPU_IW-1:0]),
       .idu_op_jmprel                   (idu_op_jmprel),
       .idu_jmprel_link                 (idu_jmprel_link),
       .regf_rs1_dout                   (regf_rs1_dout[`NCPU_DW-1:0]),
       .regf_rs1_dout_valid             (regf_rs1_dout_valid),
       .regf_rs2_dout                   (regf_rs2_dout[`NCPU_DW-1:0]),
       .regf_rs2_dout_valid             (regf_rs2_dout_valid),
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
       .ieu_lu_opc_bus                  (ieu_lu_opc_bus[`NCPU_LU_IOPW-1:0]),
       .ieu_emu_insn                    (ieu_emu_insn),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_barr                     (ieu_mu_barr),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .ieu_wb_regf                     (ieu_wb_regf),
       .ieu_wb_reg_addr                 (ieu_wb_reg_addr[`NCPU_REG_AW-1:0]),
       .ieu_jmpreg                      (ieu_jmpreg),
       .ieu_insn_pc                     (ieu_insn_pc[`NCPU_AW-3:0]),
       .ieu_jmplink                     (ieu_jmplink));
   
   
endmodule
