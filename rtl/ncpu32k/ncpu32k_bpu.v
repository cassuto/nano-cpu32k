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

module ncpu32k_bpu
#(
   parameter BPU_JMPREL_STRATEGY = "always_taken"
)
(
   input                   clk,
   input                   rst_n,
   input [`NCPU_AW-3:0]    bpu_insn_pc,
   input                   bpu_rd,
   input                   bpu_jmprel,
   output [`NCPU_AW-3:0]   bpu_jmp_tgt,
   output                  bpu_jmprel_taken,
   output [`NCPU_DW-1:0]   bpu_msr_epc,
   input                   bpu_wb,
   input                   bpu_wb_jmprel,
   input [`NCPU_AW-3:0]    bpu_wb_insn_pc,
   input                   bpu_wb_hit
);
   
   generate
      if(BPU_JMPREL_STRATEGY=="always_taken") begin : class_always_taken
         assign bpu_jmprel_taken = 1'b0;
      end
   endgenerate
   
   assign bpu_jmp_tgt = {`NCPU_AW-2{1'b0}};
   
   assign bpu_msr_epc = {`NCPU_DW{1'b0}};
   
endmodule
