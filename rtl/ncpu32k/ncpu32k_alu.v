/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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
#(
   parameter CONFIG_ALU_INSERT_REG,
   parameter CONFIG_PIPEBUF_BYPASS,
   parameter CONFIG_ROB_DEPTH_LOG2
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   output                     alu_AREADY,
   input                      alu_AVALID,
   input [`NCPU_DW-1:0]       alu_operand_1,
   input [`NCPU_DW-1:0]       alu_operand_2,
   input [14:0]               alu_rel15,
   input [CONFIG_ROB_DEPTH_LOG2-1:0]      alu_AID,
   input [`NCPU_ALU_IOPW-1:0] alu_opc_bus,
   input                      alu_BREADY,
   output                     alu_BVALID,
   output [CONFIG_ROB_DEPTH_LOG2-1:0]     alu_BID,
   output [`NCPU_DW-1:0]      alu_BDATA,
   output                     alu_BBRANCH_REG_TAKEN,
   output                     alu_BBRANCH_REL_TAKEN,
   output                     alu_BBRANCH_OP
);
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
   wire                       sel_branch;
   wire [`NCPU_DW-1:0]        alu_dat_nxt;
   wire                       branch_reg_taken_nxt;
   wire                       branch_rel_taken_nxt;
   wire                       branch_op_nxt;

   //
   // Full Adder
   //

   wire adder_sub;
   wire adder_carry_in;
   wire adder_carry_out;
   wire adder_overflow;
   wire [`NCPU_DW-1:0] adder_op2;
   wire bcc_op;

   assign bcc_op = (alu_opc_bus[`NCPU_ALU_BEQ] |
                     alu_opc_bus[`NCPU_ALU_BNE] |
                     alu_opc_bus[`NCPU_ALU_BLTU] |
                     alu_opc_bus[`NCPU_ALU_BLT] |
                     alu_opc_bus[`NCPU_ALU_BGEU] |
                     alu_opc_bus[`NCPU_ALU_BGE]);

   assign adder_sub = alu_opc_bus[`NCPU_ALU_SUB] | bcc_op;
   assign adder_carry_in = adder_sub;
   assign adder_op2 = adder_sub ? ~alu_operand_2 : alu_operand_2;

   assign {adder_carry_out, dat_adder} = alu_operand_1 + adder_op2 + {{`NCPU_DW-1{1'b0}}, adder_carry_in};

   assign adder_overflow = (alu_operand_1[`NCPU_DW-1] == adder_op2[`NCPU_DW-1]) &
                          (alu_operand_1[`NCPU_DW-1] ^ dat_adder[`NCPU_DW-1]);

   assign sel_adder = (alu_opc_bus[`NCPU_ALU_ADD] | alu_opc_bus[`NCPU_ALU_SUB]);

   //
   // Comparator
   //

   wire cmp_eq;
   wire cmp_lt_s, cmp_lt_u;
   wire bcc_taken;

   // equal
   assign cmp_eq = (alu_operand_1 == alu_operand_2);
   // greater
   assign cmp_lt_s = (dat_adder[`NCPU_DW-1] != adder_overflow);
   assign cmp_lt_u = ~adder_carry_out;

   assign bcc_taken = (alu_opc_bus[`NCPU_ALU_BEQ] & cmp_eq) |
                           (alu_opc_bus[`NCPU_ALU_BNE] & ~cmp_eq) |
                           (alu_opc_bus[`NCPU_ALU_BLTU] & cmp_lt_u) |
                           (alu_opc_bus[`NCPU_ALU_BLT] & cmp_lt_s) |
                           (alu_opc_bus[`NCPU_ALU_BGEU] & ~cmp_lt_u) |
                           (alu_opc_bus[`NCPU_ALU_BGE] & ~cmp_lt_s);

   assign branch_reg_taken_nxt = alu_opc_bus[`NCPU_ALU_JMPREG];
  
   assign branch_rel_taken_nxt = (bcc_taken | alu_opc_bus[`NCPU_ALU_JMPREL]);

   assign branch_op_nxt = (bcc_op |
                           alu_opc_bus[`NCPU_ALU_JMPREG] |
                           alu_opc_bus[`NCPU_ALU_JMPREL]);

   assign dat_branch = (// For PC-relative addressing, the output is sign-extended offset
                        branch_rel_taken_nxt ? {{`NCPU_DW-17{alu_rel15[14]}}, alu_rel15[14:0], 2'b0} :
                        // Operand #1 holds the absolute address
                        alu_operand_1);

   assign sel_branch = (branch_reg_taken_nxt | branch_rel_taken_nxt);


   //
   // Logic Arithmetic
   //

   assign dat_and = (alu_operand_1 & alu_operand_2);
   assign dat_or = (alu_operand_1 | alu_operand_2);
   assign dat_xor = (alu_operand_1 ^ alu_operand_2);

   assign sel_and = alu_opc_bus[`NCPU_ALU_AND];
   assign sel_or = alu_opc_bus[`NCPU_ALU_OR];
   assign sel_xor = alu_opc_bus[`NCPU_ALU_XOR];

   //
   // Shifter
   //

   wire [`NCPU_DW-1:0] shift_right;
   wire [`NCPU_DW-1:0] shift_lsw;
   wire [`NCPU_DW-1:0] shift_msw;
   wire [`NCPU_DW*2-1:0] shift_wide;

   function [`NCPU_DW-1:0] reverse_bits;
      input [`NCPU_DW-1:0] a;
	   integer 			      i;
	   begin
         for (i = 0; i < `NCPU_DW; i=i+1) begin
            reverse_bits[`NCPU_DW-1-i] = a[i];
         end
      end
   endfunction

   assign shift_lsw = alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(alu_operand_1) : alu_operand_1;
`ifdef ENABLE_ASR
   assign shift_msw = alu_opc_bus[`NCPU_ALU_ASR] ? {`NCPU_DW{alu_operand_1[`NCPU_DW-1]}} : {`NCPU_DW{1'b0}};
   assign shift_wide = {shift_msw, shift_lsw} >> alu_operand_2[4:0];
   assign shift_right = shift_wide[`NCPU_DW-1:0];
`else
   assign shift_right = shift_lsw >> alu_operand_2[4:0];
`endif
   assign lu_shifter = alu_opc_bus[`NCPU_ALU_LSL] ? reverse_bits(shift_right) : shift_right;
   assign sel_shifter = alu_opc_bus[`NCPU_ALU_LSL] | alu_opc_bus[`NCPU_ALU_LSR] | alu_opc_bus[`NCPU_ALU_ASR];

   //
   // Move
   //
   assign sel_move = alu_opc_bus[`NCPU_ALU_MHI];
   assign dat_move = {alu_operand_2[16:0], 15'b0};
   
   //
   // MUX. Assert (2103281518)
   //
   assign alu_dat_nxt =
      ({`NCPU_DW{sel_adder}} & dat_adder) |
      ({`NCPU_DW{sel_and}} & dat_and) |
      ({`NCPU_DW{sel_or}} & dat_or) |
      ({`NCPU_DW{sel_xor}} & dat_xor) |
      ({`NCPU_DW{sel_shifter}} & dat_shifter) |
      ({`NCPU_DW{sel_move}} & dat_move) |
      ({`NCPU_DW{sel_branch}} & dat_branch);
   
   generate
      if (CONFIG_ALU_INSERT_REG)
         begin
            wire pipe_cke;
            ncpu32k_cell_pipebuf
               #(
                  .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
               )
            pipebuf_alu
               (
                  .clk        (clk),
                  .rst_n      (rst_n),
                  .flush      (flush),
                  .A_en       (1'b1),
                  .AVALID     (alu_AVALID),
                  .AREADY     (alu_AREADY),
                  .B_en       (1'b1),
                  .BVALID     (alu_BVALID),
                  .BREADY     (alu_BREADY),
                  .cke        (pipe_cke),
                  .pending    ()
               );
            
            // Data path: not need to reset
            nDFF_l #(CONFIG_ROB_DEPTH_LOG2) dff_alu_BID
              (clk, pipe_cke, alu_AID, alu_BID);
            nDFF_l #(`NCPU_DW) dff_alu_BDATA
              (clk, pipe_cke, alu_dat_nxt, alu_BDATA);
            nDFF_l #(1) dff_alu_BBRANCH_REG_TAKEN
              (clk, pipe_cke, branch_reg_taken_nxt, alu_BBRANCH_REG_TAKEN);
            nDFF_l #(1) dff_alu_BBRANCH_REL_TAKEN
              (clk, pipe_cke, branch_rel_taken_nxt, alu_BBRANCH_REL_TAKEN);
            nDFF_l #(1) dff_alu_BBRANCH_OP
              (clk, pipe_cke, branch_op_nxt, alu_BBRANCH_OP);
         end
      else
         begin
            assign alu_AREADY = alu_BREADY;
            assign alu_BVALID = alu_AVALID;
            assign alu_BID = alu_AID;
            assign alu_BDATA = alu_dat_nxt;
            assign alu_BBRANCH_REG_TAKEN = branch_reg_taken_nxt;
            assign alu_BBRANCH_REL_TAKEN = branch_rel_taken_nxt;
            assign alu_BBRANCH_OP = branch_op_nxt;
         end
   endgenerate
   
   // synthesis translate_off
`ifndef SYNTHESIS
 `include "ncpu32k_assert.h"

   // Assertions
 `ifdef NCPU_ENABLE_ASSERT

   always @(posedge clk)
      begin
         if (count_1({sel_adder,sel_and,sel_or,sel_xor,sel_shifter,sel_move})>1)
            $fatal("\n Bugs on ALU output MUX\n");
      end

 `endif
`endif
// synthesis translate_on

endmodule
