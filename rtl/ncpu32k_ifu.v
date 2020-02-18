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

module ncpu32k_ifu(         
   input                   clk,
   input                   rst_n,
   input                   ibus_valid_out, /* Insn is presented at ibus */
   output                  ibus_ready_out, /* Insn is accepted by ifu */
   output                  ibus_rd_o,
   output [`NCPU_AW-1:0]   ibus_addr_o,
   input [`NCPU_IW-1:0]    ibus_i,
   input                   ifu_jmprel,
   input                   ifu_jmpfar,
   input                   ifu_jmp_ready,
   input [`NCPU_AW-3:0]    ifu_jmprel_offset,
   input [`NCPU_AW-3:0]    ifu_jmpfar_addr,
   input                   idu_ready_in, /* Insn is accepted by idu */
   output                  idu_valid_in, /* Insn is prestented at idu's input */
   output [`NCPU_IW-1:0]   idu_insn,
   output [`NCPU_AW-3:0]   idu_insn_pc
);

   wire [`NCPU_AW-3:0] pc_addr_r;
   wire [`NCPU_AW-3:0] pc_addr_nxt;
   wire [`NCPU_IW-1:0] insn;
   
   // Program Counter Register
   ncpu32k_cell_dff_lr #(`NCPU_AW-2, (`NCPU_ERST_VECTOR>>2)-1'b1) dff_pc_addr
                   (clk, rst_n, ibus_ready_out, pc_addr_nxt[`NCPU_AW-3:0], pc_addr_r[`NCPU_AW-3:0]);
   assign pc_addr_nxt = ifu_jmpfar ? ifu_jmpfar_addr :
                    pc_addr_r + (ifu_jmprel ? ifu_jmprel_offset : 1'b1);

   // Insn Bus addressing
   assign ibus_addr_o = {pc_addr_nxt[`NCPU_AW-3:0], 2'b00};
   // Insn Bus reading
   assign ibus_rd_o = 1'b1;
   assign idu_insn = ibus_i;
   assign idu_insn_pc = pc_addr_nxt;
   
   assign ibus_ready_out = idu_ready_in;
   assign idu_valid_in = ibus_valid_out;
   
endmodule