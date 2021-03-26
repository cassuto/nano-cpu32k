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

module ncpu32k_issue_queue
#(
   parameter DEPTH = 2,
   parameter UOP_WIDTH = 8
)
(
   input                      clk,
   input                      rst_n,
   input                      i_issue_valid,
   output                     o_issue_ready,
   input [UOP_WIDTH-1:0]      i_uop,
   input                      i_rs1_rdy,
   input [`NCPU_DW-1:0]       i_rs1_dat,
   input [`NCPU_REG_AW-1:0]   i_rs1_addr,
   input                      i_rs2_rdy,
   input [`NCPU_DW-1:0]       i_rs2_dat,
   input [`NCPU_REG_AW-1:0]   i_rs2_addr,
   input                      cdb_BVALID,
   input [`NCPU_DW-1:0]       cdb_BDATA,
   input                      cdb_rd_we,
   input [`NCPU_REG_AW-1:0]   cdb_rd_addr,
   input                      i_fu_ready,
   output                     o_fu_valid,
   output [UOP_WIDTH-1:0]     o_fu_uop,
   output [`NCPU_DW-1:0]      o_fu_rs1_dat,
   output [`NCPU_DW-1:0]      o_fu_rs2_dat
);

   wire                       que_v_r [DEPTH-1:0];
   wire                       que_v_nxt [DEPTH-1:0];
   wire                       que_v_en [DEPTH-1:0];
   wire [UOP_WIDTH-1:0]       que_uop_r [DEPTH-1:0];
   wire                       que_uop_en [DEPTH-1:0];
   wire                       que_rs1_rdy_r [DEPTH-1:0];
   wire                       que_rs1_rdy_nxt [DEPTH-1:0];
   wire [`NCPU_DW-1:0]        que_rs1_r [DEPTH-1:0];
   wire [`NCPU_DW-1:0]        que_rs1_nxt [DEPTH-1:0];
   wire                       que_rs2_rdy_r [DEPTH-1:0];
   wire                       que_rs2_rdy_nxt [DEPTH-1:0];
   wire [`NCPU_DW-1:0]        que_rs2_r [DEPTH-1:0];
   wire [`NCPU_DW-1:0]        que_rs2_nxt [DEPTH-1:0];

   wire [DEPTH-1:0]           free;
   wire [DEPTH-1:0]           select;
   wire                       rs1_bypass_rdy, rs2_bypass_rdy;

   genvar i;

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_DFFs
            nDFF_lr #(1) dff_que_v_r
              (clk,rst_n, que_v_en[i], que_v_nxt[i], que_v_r[i]);
            nDFF_lr #(UOP_WIDTH) dff_que_uop_r
              (clk,rst_n, que_uop_en[i], i_uop, que_uop_r[i]);
            nDFF_r #(1) dff_que_rs1_rdy_r
              (clk,rst_n, que_rs1_rdy_nxt[i], que_rs1_rdy_r[i]);
            nDFF_r #(`NCPU_DW) dff_que_rs1_r
              (clk,rst_n, que_rs1_nxt[i], que_rs1_r[i]);
            nDFF_r #(1) dff_que_rs2_rdy_r
              (clk,rst_n, que_rs2_rdy_nxt[i], que_rs2_rdy_r[i]);
            nDFF_r #(`NCPU_DW) dff_que_rs2_r
              (clk,rst_n, que_rs2_nxt[i], que_rs2_r[i]);
         end
   endgenerate

   // Allocator
   // FIXME: a better algorithm than the simple serial priority arbiter
   generate
      wire [DEPTH-1:0] t_que_v_r;
      assign t_que_v_r[0] = 1'b1;
      for(i=1;i<DEPTH;i=i+1)
         begin : gen_t_que_v_r
            assign t_que_v_r[i] = t_que_v_r[i-1] & que_v_r[i-1];
         end
      for(i=0;i<DEPTH;i=i+1)
         begin : gen_free
            assign free[i] = t_que_v_r[i] & ~que_v_r[i];
         end
   endgenerate

   assign o_issue_ready = |free;

   assign rs1_i_bypass_rdy = ~i_rs1_rdy & cdb_BVALID & cdb_rd_we & (cdb_rd_addr==i_rs1_addr);
   assign rs2_i_bypass_rdy = ~i_rs2_rdy & cdb_BVALID & cdb_rd_we & (cdb_rd_addr==i_rs2_addr);

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_write
            wire this_push, this_pop;
            wire rs1_r_bypass_rdy;
            wire rs2_r_bypass_rdy;

            // Each entry of issuing queue is a 1-slot FIFO
            assign this_push = i_issue_valid & free[i];
            assign this_pop = select[i] & i_fu_ready;
            assign que_v_nxt[i] = (this_push|~this_pop);
            assign que_v_en[i] = (this_push|this_pop);
            assign que_uop_en[i] = this_push;

            // Wake up
            assign rs1_r_bypass_rdy = que_v_r[i] & ~que_rs1_rdy_r[i] & cdb_BVALID & cdb_rd_we & (cdb_rd_addr==que_rs1_r[i][`NCPU_REG_AW-1:0]);
            assign rs2_r_bypass_rdy = que_v_r[i] & ~que_rs2_rdy_r[i] & cdb_BVALID & cdb_rd_we & (cdb_rd_addr==que_rs2_r[i][`NCPU_REG_AW-1:0]);

            assign que_rs1_rdy_nxt[i] = this_push ? (i_rs1_rdy | rs1_i_bypass_rdy) : (que_rs1_rdy_r[i] | rs1_r_bypass_rdy);
            assign que_rs2_rdy_nxt[i] = this_push ? (i_rs2_rdy | rs2_i_bypass_rdy) : (que_rs2_rdy_r[i] | rs2_r_bypass_rdy);

            //
            // 1) Push insn
            //    If the operand of the pushed insn is ready, then store then value of operand.
            //    Otherwise, if the operand is not ready, firstly check the CDB, If value from CDB is ready, then apply the value.
            //    If CDB is not ready, then store the register address of the operand.
            // 2) Wake-up
            //    If the operand is not ready, then listening to the CDB. If CDB is ready, then wake up this entry.
            //
            assign que_rs1_nxt[i] = (this_push & i_rs1_rdy) ? i_rs1_dat
                                       : (this_push & rs1_i_bypass_rdy) ? cdb_BDATA
                                       : (this_push & ~i_rs1_rdy) ? {{`NCPU_DW-`NCPU_REG_AW{1'b0}}, i_rs1_addr[`NCPU_REG_AW-1:0]}
                                       : (rs1_r_bypass_rdy) ? cdb_BDATA
                                       : que_rs1_r[i];

            assign que_rs2_nxt[i] = (this_push & i_rs2_rdy) ? i_rs2_dat
                                       : (this_push & rs2_i_bypass_rdy) ? cdb_BDATA
                                       : (this_push & ~i_rs2_rdy) ? {{`NCPU_DW-`NCPU_REG_AW{1'b0}}, i_rs2_addr[`NCPU_REG_AW-1:0]}
                                       : (rs2_r_bypass_rdy) ? cdb_BDATA
                                       : que_rs2_r[i];

            // synthesis translate_off
`ifndef SYNTHESIS
            // Assertions
`ifdef NCPU_ENABLE_ASSERT
            always @(posedge clk)
               begin
                  // When rs1 or rs2 is not needed, the recommanded schema is to let `i_rsN_rdy` = 1 and `i_rsN_addr` = 'd0
                  // (the address of nil register).
                  // As nil register can be never written back, bypass from CDB will never be ready.
                  if ((que_rs1_rdy_r[i] & rs1_r_bypass_rdy) | (que_rs2_rdy_r[i] & rs2_r_bypass_rdy))
                     $fatal("\n Check the implement of issuing queue, CDB or others.\n");
                  if (this_push & ((i_rs1_rdy & rs1_i_bypass_rdy) | (i_rs2_rdy & rs2_i_bypass_rdy)))
                     $fatal("\n Check the implement of ISSUE unit, issuing queue, CDB or others.\n");
               end
`endif
`endif
            // synthesis translate_on

         end
   endgenerate


   // Selector
   // FIXME: a better algorithm than the simple serial priority arbiter
   generate
      wire [DEPTH-1:0] t_select;
      assign t_select[0] = 1'b0;
      for(i=1;i<DEPTH;i=i+1)
         begin : gen_t_select
            assign t_select[i] = t_select[i-1] | select[i-1];
         end
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_select
            assign select[i] = ~t_select[i] & (que_v_r[i] & que_rs1_rdy_r[i] & que_rs2_rdy_r[i]);
         end
   endgenerate

   assign o_fu_valid = |select;

   // Output MUX
   generate
      wire [UOP_WIDTH-1:0] t_uop [DEPTH-1:0];
      wire [`NCPU_DW-1:0] t_rs1_dat [DEPTH-1:0];
      wire [`NCPU_DW-1:0] t_rs2_dat [DEPTH-1:0];

      assign t_uop[0] = {UOP_WIDTH{select[0]}} & que_uop_r[0];
      assign t_rs1_dat[0] = {`NCPU_DW{select[0]}} & que_rs1_r[0];
      assign t_rs2_dat[0] = {`NCPU_DW{select[0]}} & que_rs2_r[0];

      for(i=1;i<DEPTH;i=i+1)
         begin : gen_output
            assign t_uop[i] = t_uop[i-1] | ({UOP_WIDTH{select[i]}} & que_uop_r[i]);
            assign t_rs1_dat[i] = t_rs1_dat[i-1] | ({`NCPU_DW{select[i]}} & que_rs1_r[i]);
            assign t_rs2_dat[i] = t_rs2_dat[i-1] | ({`NCPU_DW{select[i]}} & que_rs2_r[i]);
         end

      assign o_fu_uop = t_uop[DEPTH-1];
      assign o_fu_rs1_dat = t_rs1_dat[DEPTH-1];
      assign o_fu_rs2_dat = t_rs2_dat[DEPTH-1];
   endgenerate

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   initial
      begin
         if (`NCPU_REG_AW > `NCPU_DW)
            $fatal("\n Address width of regfile is larger than the `NCPU_DW\n");
      end
   always @(posedge clk)
      begin
         if (count_1({free}) > 1)
            $fatal("\n `free` must be mutex\n");
         if (count_1({select}) > 1)
            $fatal("\n `select` must be mutex\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
