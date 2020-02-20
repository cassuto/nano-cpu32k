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

module ncpu32k_ie_lu(         
   input                      clk,
   input                      rst_n,
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_LU_IOPW-1:0]  ieu_lu_opc_bus,
   output                     lu_op_shift,
   output [`NCPU_DW-1:0]      lu_shift,
   output [`NCPU_DW-1:0]      lu_and,
   output [`NCPU_DW-1:0]      lu_or,
   output [`NCPU_DW-1:0]      lu_xor
);
   
   assign lu_and = (ieu_operand_1 & ieu_operand_2);
   assign lu_or = (ieu_operand_1 | ieu_operand_2);
   assign lu_xor = (ieu_operand_1 ^ ieu_operand_2);
   
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

   assign shift_lsw = ieu_lu_opc_bus[`NCPU_LU_LSL] ? reverse_bits(ieu_operand_1) : ieu_operand_1;
`ifdef ENABLE_ASR
   assign shift_msw = ieu_lu_opc_bus[`NCPU_LU_ASR] ? {`NCPU_DW{ieu_operand_1[`NCPU_DW-1]}} : {`NCPU_DW{1'b0}};
   assign shift_wide = {shift_msw, shift_lsw} >> ieu_operand_2[4:0];
   assign shift_right = shift_wide[`NCPU_DW-1:0];
`else
   assign shift_right = shift_lsw >> ieu_operand_2[4:0];
`endif
   assign lu_shift = ieu_lu_opc_bus[`NCPU_LU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign lu_op_shift = ieu_lu_opc_bus[`NCPU_LU_LSL] | ieu_lu_opc_bus[`NCPU_LU_LSR] | ieu_lu_opc_bus[`NCPU_LU_ASR];

   /*
   assign lu_valid_in = ieu_lu_valid_in & (ieu_lu_opc_bus[`NCPU_LU_AND] |
                      ieu_lu_opc_bus[`NCPU_LU_OR] |
                      ieu_lu_opc_bus[`NCPU_LU_XOR] |
                      lu_op_shift);
                      
   assign ieu_lu_ready_in = lu_ready_in;
   */
   
endmodule
