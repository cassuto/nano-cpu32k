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

module ncpu32k_ipdu(
   input                   clk,
   input                   rst_n,
   input [`NCPU_IW-1:0]    ipdu_insn,
   input                   msr_psr_cc,
   output                  jmprel,
   output [`NCPU_AW-3:0]   jmprel_offset,
   output                  jmprel_link
);
   wire [5:0] f_opcode = ipdu_insn[5:0];
   wire [25:0] f_rel26 = ipdu_insn[31:6];
   
   wire op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   wire op_jmp_lnk_i = (f_opcode == `NCPU_OP_JMP_LNK_I);
   wire op_bt = (f_opcode == `NCPU_OP_BT);
   wire op_bf = (f_opcode == `NCPU_OP_BF);
   
   // PC-Relative address (sign-extended)
   wire [`NCPU_AW-3:0] rel26 = {{`NCPU_AW-28{f_rel26[25]}}, f_rel26[25:0]};
   // PC-Relative jump
   wire bcc = (op_bt | op_bf) & (msr_psr_cc);
   assign jmprel = (op_jmp_i | op_jmp_lnk_i) | bcc;
   assign jmprel_offset = rel26;
   assign jmprel_link = op_jmp_lnk_i;
   
endmodule
