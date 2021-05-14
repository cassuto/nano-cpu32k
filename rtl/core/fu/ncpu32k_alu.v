/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_alu
(
`ifdef NCPU_ENABLE_ASSERT
   input                      clk,
`endif
   // From scheduler
   input                      alu_AVALID,
   input [`NCPU_ALU_IOPW-1:0] alu_opc_bus,
   input [`NCPU_DW-1:0]       alu_operand1,
   input [`NCPU_DW-1:0]       alu_operand2,
   // To WB
   output                     wb_alu_AVALID,
   output [`NCPU_DW-1:0]      wb_alu_dout
);
   wire                       adder_sub;
   wire [`NCPU_DW-1:0]        adder_op2;
   wire [`NCPU_DW-1:0]        dat_adder;
   wire [`NCPU_DW-1:0]        dat_and;
   wire [`NCPU_DW-1:0]        dat_or;
   wire [`NCPU_DW-1:0]        dat_xor;
   wire [`NCPU_DW-1:0]        dat_shifter;
   wire [`NCPU_DW-1:0]        dat_move;
   wire [`NCPU_DW-1:0]        dat_branch;
   wire                       sel_adder;
   wire                       sel_and;
   wire                       sel_or;
   wire                       sel_xor;
   wire                       sel_shifter;
   wire                       sel_move;

   //
   // Adder
   //
   assign adder_sub = alu_opc_bus[`NCPU_ALU_SUB];
   assign adder_op2 = adder_sub ? ~alu_operand2 : alu_operand2;
   assign dat_adder = alu_operand1 + adder_op2 + {{`NCPU_DW-1{1'b0}}, adder_sub};
   assign sel_adder = (alu_opc_bus[`NCPU_ALU_ADD] | alu_opc_bus[`NCPU_ALU_SUB]);

   //
   // Logic Arithmetic
   //
   assign dat_and = (alu_operand1 & alu_operand2);
   assign dat_or = (alu_operand1 | alu_operand2);
   assign dat_xor = (alu_operand1 ^ alu_operand2);
   assign sel_and = alu_opc_bus[`NCPU_ALU_AND];
   assign sel_or = alu_opc_bus[`NCPU_ALU_OR];
   assign sel_xor = alu_opc_bus[`NCPU_ALU_XOR];

   //
   // Shifter
   //

   wire [`NCPU_DW-1:0] shift_right;
   wire [`NCPU_DW-1:0] shift_lsw;

   function [`NCPU_DW-1:0] reverse_bits;
      input [`NCPU_DW-1:0] a;
	   integer 			      i;
	   begin
         for (i = 0; i < `NCPU_DW; i=i+1) begin
            reverse_bits[`NCPU_DW-1-i] = a[i];
         end
      end
   endfunction

   assign shift_lsw = alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(alu_operand1) : alu_operand1;
`ifdef ENABLE_ASR
   wire [`NCPU_DW-1:0] shift_msw;
   wire [`NCPU_DW*2-1:0] shift_wide;
   assign shift_msw = alu_opc_bus[`NCPU_ALU_ASR] ? {`NCPU_DW{alu_operand1[`NCPU_DW-1]}} : {`NCPU_DW{1'b0}};
   assign shift_wide = {shift_msw, shift_lsw} >> alu_operand2[4:0];
   assign shift_right = shift_wide[`NCPU_DW-1:0];
`else
   assign shift_right = shift_lsw >> alu_operand2[4:0];
`endif
   assign dat_shifter = alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign sel_shifter = alu_opc_bus[`NCPU_ALU_LSL] | alu_opc_bus[`NCPU_ALU_LSR] | alu_opc_bus[`NCPU_ALU_ASR];

   //
   // Move
   //
   assign sel_move = alu_opc_bus[`NCPU_ALU_MHI];
   assign dat_move = {alu_operand2[16:0], 15'b0};
   
   //
   // MUX. Assert (2103281518)
   //
   assign wb_alu_dout =
      ({`NCPU_DW{sel_adder}} & dat_adder) |
      ({`NCPU_DW{sel_and}} & dat_and) |
      ({`NCPU_DW{sel_or}} & dat_or) |
      ({`NCPU_DW{sel_xor}} & dat_xor) |
      ({`NCPU_DW{sel_shifter}} & dat_shifter) |
      ({`NCPU_DW{sel_move}} & dat_move);

   assign wb_alu_AVALID = alu_AVALID;
   
   // synthesis translate_off
`ifndef SYNTHESIS
 `include "ncpu32k_assert.h"

   // Assertions
 `ifdef NCPU_ENABLE_ASSERT

   always @(posedge clk)
      begin
         if (count_1({sel_adder,sel_and,sel_or,sel_xor,sel_shifter,sel_move})>1)
            $fatal(1, "\n Bugs on ALU output MUX\n");
      end

 `endif
`endif
// synthesis translate_on

endmodule
