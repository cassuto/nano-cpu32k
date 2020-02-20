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
   output [`NCPU_AW-1:0]      dbus_addr_o,
   input                      dbus_in_ready, /* dbus is ready to store */
   output                     dbus_in_valid, /* data is presented at dbus's input */
   input [`NCPU_DW-1:0]       dbus_i,
   output                     dbus_out_ready, /* MU is ready to load */
   input                      dbus_out_valid, /* data is presented at dbus's output */
   output [`NCPU_DW-1:0]      dbus_o,
   output [2:0]               dbus_size_o,
   output                     ieu_in_ready, /* ops is accepted by ieu */
   input                      ieu_in_valid, /* ops is presented at ieu's input */
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_DW-1:0]       ieu_operand_3,
   input [`NCPU_AU_IOPW-1:0]  ieu_au_opc_bus,
   input [`NCPU_LU_IOPW-1:0]  ieu_lu_opc_bus,
   input                      ieu_emu_insn,
   input                      ieu_mu_load,
   input                      ieu_mu_store,
   input                      ieu_mu_barr,
   input [2:0]                ieu_mu_store_size,
   input [2:0]                ieu_mu_load_size,
   input                      ieu_wb_regf,
   input [`NCPU_REG_AW-1:0]   ieu_wb_reg_addr,
   input                      ieu_jmpreg,
   input [`NCPU_AW-3:0]       ieu_insn_pc,
   input                      ieu_jmplink,
   output [`NCPU_REG_AW-1:0]  regf_din_addr,
   output [`NCPU_DW-1:0]      regf_din,
   output                     regf_we
);

   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  au_adder;               // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  au_div;                 // From au of ncpu32k_ie_au.v
   wire [`NCPU_DW-1:0]  au_mul;                 // From au of ncpu32k_ie_au.v
   wire                 au_op_adder;            // From au of ncpu32k_ie_au.v
   wire                 ieu_mu_in_ready;        // From mu of ncpu32k_ie_mu.v
   wire [`NCPU_DW-1:0]  lu_and;                 // From lu of ncpu32k_ie_lu.v
   wire                 lu_op_shift;            // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_or;                  // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_shift;               // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  lu_xor;                 // From lu of ncpu32k_ie_lu.v
   wire [`NCPU_DW-1:0]  mu_load;                // From mu of ncpu32k_ie_mu.v
   wire                 wb_mu_in_valid;         // From mu of ncpu32k_ie_mu.v
   // End of automatics

   ncpu32k_ie_au au
      (/*AUTOINST*/
       // Outputs
       .au_op_adder                     (au_op_adder),
       .au_adder                        (au_adder[`NCPU_DW-1:0]),
       .au_mul                          (au_mul[`NCPU_DW-1:0]),
       .au_div                          (au_div[`NCPU_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_au_opc_bus                  (ieu_au_opc_bus[`NCPU_AU_IOPW-1:0]));

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
       .dbus_addr_o                     (dbus_addr_o[`NCPU_AW-1:0]),
       .dbus_in_valid                   (dbus_in_valid),
       .dbus_out_ready                  (dbus_out_ready),
       .dbus_o                          (dbus_o[`NCPU_DW-1:0]),
       .dbus_size_o                     (dbus_size_o[2:0]),
       .ieu_mu_in_ready                 (ieu_mu_in_ready),
       .mu_load                         (mu_load[`NCPU_DW-1:0]),
       .wb_mu_in_valid                  (wb_mu_in_valid),
       // Inputs
       .clk                             (clk),
       .rst_n                           (rst_n),
       .dbus_in_ready                   (dbus_in_ready),
       .dbus_i                          (dbus_i[`NCPU_DW-1:0]),
       .dbus_out_valid                  (dbus_out_valid),
       .ieu_mu_in_valid                 (ieu_mu_in_valid),
       .ieu_operand_1                   (ieu_operand_1[`NCPU_DW-1:0]),
       .ieu_operand_2                   (ieu_operand_2[`NCPU_DW-1:0]),
       .ieu_operand_3                   (ieu_operand_3[`NCPU_DW-1:0]),
       .ieu_mu_load                     (ieu_mu_load),
       .ieu_mu_store                    (ieu_mu_store),
       .ieu_mu_store_size               (ieu_mu_store_size[2:0]),
       .ieu_mu_load_size                (ieu_mu_load_size[2:0]),
       .wb_mu_in_ready                  (wb_mu_in_ready));
        
   // Link address (offset(jmp)+1), which indicates the next insn of current jmp insn.
   wire [`NCPU_DW:0] linkaddr = {{(`NCPU_DW-`NCPU_AW+1){1'b0}}, {ieu_insn_pc[`NCPU_AW-3:0]+1'b1, 2'b00}};
   
   assign regf_din = ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_AND]}} & lu_and[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_OR]}} & lu_or[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{ieu_lu_opc_bus[`NCPU_LU_XOR]}} & lu_xor[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{lu_op_shift}} & lu_shift[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{au_op_adder}} & au_adder[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{ieu_mu_load}} & mu_load[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{ieu_jmplink}} & linkaddr[`NCPU_DW-1:0]);
   
   assign regf_din_addr = ieu_wb_reg_addr;

   assign regf_we = ieu_wb_regf & (~(ieu_mu_load|ieu_mu_store) | wb_mu_in_valid); /* data is presented at regfile's input */
   
   assign wb_mu_in_ready = 1'b1; /* data is accepted by regfile */
   
   assign ieu_in_ready = (~(ieu_mu_load|ieu_mu_store) | wb_mu_in_valid);
   
endmodule
