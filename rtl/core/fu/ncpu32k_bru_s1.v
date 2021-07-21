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

module ncpu32k_bru_s1
(
   // From scheduler
   input                      bru_AVALID,
   input [`NCPU_AW-3:0]       bru_pc,
   input [`NCPU_BRU_IOPW-1:0] bru_opc_bus,
   input [`NCPU_DW-1:0]       bru_operand1,
   input [`NCPU_DW-1:0]       bru_operand2,
   input [14:0]               bru_rel15,
   input                      bru_in_slot_1,
   // To WB
   output                     wb_bru_AVALID,
   output [`NCPU_DW-1:0]      wb_bru_dout,
   output                     wb_bru_is_bcc,
   output                     wb_bru_is_breg,
   output                     wb_bru_in_slot_1,
   output [`NCPU_DW-1:0]      wb_bru_operand1,
   output [`NCPU_DW-1:0]      wb_bru_operand2,
   output [`NCPU_BRU_IOPW-1:0] wb_bru_opc_bus,
   output [`NCPU_AW-3:0]      wb_bru_pc,
   output [14:0]              wb_bru_rel15
   
); 
   assign wb_bru_is_bcc = (bru_opc_bus[`NCPU_BRU_BEQ] |
                           bru_opc_bus[`NCPU_BRU_BNE] |
                           bru_opc_bus[`NCPU_BRU_BGTU] |
                           bru_opc_bus[`NCPU_BRU_BGT] |
                           bru_opc_bus[`NCPU_BRU_BLEU] |
                           bru_opc_bus[`NCPU_BRU_BLE]);
   
   assign wb_bru_is_breg = bru_opc_bus[`NCPU_BRU_JMPREG];

   assign wb_bru_AVALID = bru_AVALID;

   assign wb_bru_dout = {(bru_pc + 1'b1), 2'b00}; // Link addr

   assign wb_bru_in_slot_1 = bru_in_slot_1;
   
   assign wb_bru_operand1 = bru_operand1;
   assign wb_bru_operand2 = bru_operand2;
   assign wb_bru_opc_bus = bru_opc_bus;
   assign wb_bru_pc = bru_pc;
   assign wb_bru_rel15 = bru_rel15;

endmodule
