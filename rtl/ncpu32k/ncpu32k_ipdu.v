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
   input                   bpu_taken,
   input                   valid,
   output                  jmprel_taken, /* do relative jmp now ? */
   output [`NCPU_AW-3:0]   jmprel_offset,
   output                  jmprel_link,
   output                  op_bcc,
   output                  op_bt,
   output                  op_jmprel,
   output                  op_jmpfar,
   output                  op_syscall,
   output                  op_ret
);
   wire [6:0] f_opcode = ipdu_insn[6:0] & {7{valid}};
   wire [24:0] f_rel25 = ipdu_insn[31:7];
   
   wire op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   wire op_jmp_lnk_i = (f_opcode == `NCPU_OP_JMP_LNK_I);
   assign op_bt = (f_opcode == `NCPU_OP_BT);
   wire op_bf = (f_opcode == `NCPU_OP_BF);
   assign op_jmpfar = (f_opcode == `NCPU_OP_JMP);
   
   assign op_syscall = (f_opcode == `NCPU_OP_SYSCALL);
   assign op_ret = (f_opcode == `NCPU_OP_RET);
   
   // PC-Relative address (sign-extended)
   wire [`NCPU_AW-3:0] rel25 = {{`NCPU_AW-2-25{f_rel25[24]}}, f_rel25[24:0]};
   // PC-Relative jump
   assign jmprel_taken = (op_jmp_i | op_jmp_lnk_i) | (op_bcc & bpu_taken);
   assign jmprel_offset = rel25;
   assign jmprel_link = op_jmp_lnk_i;
   assign op_bcc = (op_bt | op_bf);
   assign op_jmprel = op_jmp_i | op_jmp_lnk_i | op_bcc;
   
endmodule
