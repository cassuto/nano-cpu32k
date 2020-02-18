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
   input                   clk_i,
   input                   rst_n_i,
   input [`NCPU_DW-1:0]    d_i,              // data
   input [`NCPU_IW-1:0]    insn_i,           // instruction
   input                   insn_ready_i,     // Insn bus is ready
   input                   dbus_rd_ready_i,  // Data bus Dout is ready
   input                   dbus_we_done_i,   // Data bus Writing is done
   output [`NCPU_DW-1:0]   d_o,	            // data
   output [`NCPU_AW-1:0]   addr_o,           // data address
   output                  dbus_rd_o,        // data bus ReadEnable
   output                  dbus_we_o,        // data bus WriteEnable
   output [`NCPU_AW-1:0]   iaddr_o,          // instruction address
   output                  ibus_rd_o         // instruction bus ReadEnable
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_DW-1:0]  rs1_o;                  // From regfile0 of ncpu32k_regfile.v
   wire                 rs1_valid_o;            // From regfile0 of ncpu32k_regfile.v
   wire [`NCPU_DW-1:0]  rs2_o;                  // From regfile0 of ncpu32k_regfile.v
   wire                 rs2_valid_o;            // From regfile0 of ncpu32k_regfile.v
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
   
   /* ncpu32k_regfile AUTO_TEMPLATE (
      ..*_i                             (regf_@"vl-name"[]),
      .clk_i                            (clk_i),
      .rst_n_i                          (rst_n_i),
   );*/
   
   ncpu32k_regfile regfile0
      (/*AUTOINST*/
       // Outputs
       .rs1_o                           (rs1_o[`NCPU_DW-1:0]),
       .rs2_o                           (rs2_o[`NCPU_DW-1:0]),
       .rs1_valid_o                     (rs1_valid_o),
       .rs2_valid_o                     (rs2_valid_o),
       // Inputs
       .clk_i                           (clk_i),                 // Templated
       .rst_n_i                         (rst_n_i),               // Templated
       .rs1_addr_i                      (regf_rs1_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rs2_addr_i                      (regf_rs2_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rs1_re_i                        (regf_rs1_re_i),         // Templated
       .rs2_re_i                        (regf_rs2_re_i),         // Templated
       .rd_addr_i                       (regf_rd_addr_i[`NCPU_REG_AW-1:0]), // Templated
       .rd_i                            (regf_rd_i[`NCPU_DW-1:0]), // Templated
       .rd_we_i                         (regf_rd_we_i));          // Templated
   
   // SMR.PSR.CC - Condition Control Register
   wire                 smr_psr_cc_i;
   wire                 smr_psr_cc;
   wire                 smr_psr_cc_w;
   wire                 smr_psr_cc_we;
   
   ncpu32k_cell_dff_lr #(1) dff_smr_psr_cc (clk_i, rst_n_i, smr_psr_cc_we, smr_psr_cc_i, smr_psr_cc_w);
   
   assign smr_psr_cc = (smr_psr_cc_we ? smr_psr_cc_i : smr_psr_cc_w);
   
   // Pipeline Dispatcher
   wire pipe1_flow;
   wire pipe2_flow;
   wire pipe3_flow;
   wire pipe1_ready;
   wire pipe2_ready;
   wire pipe3_ready;
   
   assign pipe3_flow = pipe3_ready;
   assign pipe2_flow = pipe3_flow & pipe2_ready;
   assign pipe1_flow = (pipe2_flow & pipe1_ready);
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 1: Fetch
   /////////////////////////////////////////////////////////////////////////////
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 2: Decode
   /////////////////////////////////////////////////////////////////////////////
   
   
   
   
   assign pipe2_ready = 1'b1;
   
   // Pipeline
   

   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 3: Execution && Load/Store
   /////////////////////////////////////////////////////////////////////////////
   
   ///////////////////////////
   // LU (Logic Unit)
   ///////////////////////////
   
   wire [`NCPU_DW-1:0] lu_and = (exc_operand_1_i & exc_operand_2_i);
   wire [`NCPU_DW-1:0] lu_or = (exc_operand_1_i | exc_operand_2_i);
   wire [`NCPU_DW-1:0] lu_xor = (exc_operand_1_i ^ exc_operand_2_i);
   
   function [`NCPU_DW-1:0] reverse_bits;
      input [`NCPU_DW-1:0] a;
	   integer 			      i;
	   begin
         for (i = 0; i < `NCPU_DW; i=i+1) begin
            reverse_bits[`NCPU_DW-1-i] = a[i];
         end
      end
   endfunction

   wire [`NCPU_DW-1:0] shift_right;
   wire [`NCPU_DW-1:0] shift_lsw;
   wire [`NCPU_DW-1:0] shift_msw;
   wire [`NCPU_DW*2-1:0] shift_wide;
   wire [`NCPU_DW-1:0] lu_shift;

   assign shift_lsw = exc_lu_opc_bus_i[`NCPU_LU_LSL] ? reverse_bits(exc_operand_1_i) : exc_operand_1_i;
`ifdef ENABLE_ASR
   assign shift_msw = exc_lu_opc_bus_i[`NCPU_LU_ASR] ? {`NCPU_DW{exc_operand_1_i[`NCPU_DW-1]}} : {`NCPU_DW{1'b0}};
   assign shift_wide = {shift_msw, shift_lsw} >> exc_operand_2_i[4:0];
   assign shift_right = shift_wide[`NCPU_DW-1:0];
`else
   assign shift_right = shift_lsw >> exc_operand_2_i[4:0];
`endif
   assign lu_shift = exc_lu_opc_bus_i[`NCPU_LU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign lu_op_shift = exc_lu_opc_bus_i[`NCPU_LU_LSL] | exc_lu_opc_bus_i[`NCPU_LU_LSR] | exc_lu_opc_bus_i[`NCPU_LU_ASR];

   
   ///////////////////////////
   // AU (Arithmetic Unit)
   ///////////////////////////
   

   ///////////////////////////
   // MU (Memory access Unit)
   ///////////////////////////
   wire load_ready;
   wire store_ready;
   wire [`NCPU_DW-1:0] mu_load;
   wire [`NCPU_DW-1:0] mu_store;
   
   assign addr_o = exc_operand_1_i + exc_operand_2_i;
   // Load from memory
   assign dbus_rd_o = exc_mu_load_i;
   assign mu_load = d_i;
   assign load_ready = dbus_rd_ready_i;
   // Store to memory
   assign dbus_we_o = exc_mu_store_i;
   assign mu_store = d_i;
   assign store_ready = dbus_we_done_i;
   
   // If Load/Store, then Wait for dbus.
   assign pipe3_ready = !(exc_mu_load_i|exc_mu_store_i) | (load_ready | store_ready);

   // Register-operand jmp
   assign fetch_jmpfar_addr = exc_operand_1_i[`NCPU_AW-1:2]; // TODO unalign check
   // Link address (offset(jmp)+1), which indicates the next insn of current jmp insn.
   wire [`NCPU_DW:0] linkaddr = {{(`NCPU_DW-`NCPU_AW+1){1'b0}}, {exc_insn_pc_i[`NCPU_AW-3:0]+1'b1, 2'b00}};
   
   assign regf_rd_i = ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_AND]}} & lu_and[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_OR]}} & lu_or[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_lu_opc_bus_i[`NCPU_LU_XOR]}} & lu_xor[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{lu_op_shift}} & lu_shift[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{au_op_adder}} & au_adder[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_mu_load_i}} & mu_load[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_mu_store_i}} & mu_store[`NCPU_DW-1:0]) |
                      ({`NCPU_DW{exc_jmp_link_i}} & linkaddr[`NCPU_DW-1:0]);
   
   
   /////////////////////////////////////////////////////////////////////////////
   // Pipeline Stage 4: Commit & WriteBack
   /////////////////////////////////////////////////////////////////////////////
   
   // WriteBack result to register file.
   assign regf_rd_we_i = pipe3_flow & exc_wb_regf_i;
   assign regf_rd_addr_i = exc_wb_reg_addr_i;
   
endmodule
