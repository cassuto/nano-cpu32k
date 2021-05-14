/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module ncpu32k_pidu
(
   input                      pidu_insn_vld,
   input [`NCPU_IW-1:0]       pidu_insn,
   input [`NCPU_AW-3:0]       pidu_pc,
   input                      pidu_EITM,
   input                      pidu_EIPF,
   output                     jmprel,
   output [`NCPU_AW-3:0]      jmprel_tgt
);
   wire [6:0]                 f_opcode;
   wire [24:0]                f_rel25;
   wire                       op_jmp_i;
   wire                       op_jmp_lnk_i;
   wire                       fnt_exc;
   
   assign fnt_exc = (pidu_EITM | pidu_EIPF);

   // If the frontend raised exceptions, displace the insn with NOP.
   assign f_opcode = pidu_insn[6:0] & {7{~fnt_exc}};
   assign f_rel25 = pidu_insn[31:7];

   assign op_jmp_i = (f_opcode == `NCPU_OP_JMP_I);
   assign op_jmp_lnk_i = (f_opcode == `NCPU_OP_JMP_LNK_I);
   assign jmprel = pidu_insn_vld & (op_jmp_lnk_i | op_jmp_i);
   
   // Address generator
   // PC-Relative address (sign-extended)
   assign jmprel_tgt = (pidu_pc + {{`NCPU_AW-2-25{f_rel25[24]}}, f_rel25[24:0]});
   
endmodule
