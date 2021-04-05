/**@file
 * Out-of-order issue queue
 */

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
   parameter DEPTH `PARAM_NOT_SPECIFIED ,
   parameter DEPTH_WIDTH `PARAM_NOT_SPECIFIED ,
   parameter UOP_WIDTH `PARAM_NOT_SPECIFIED ,
   parameter ALGORITHM `PARAM_NOT_SPECIFIED , // 0 = Fully Out of Order, 1 = FIFO
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      i_issue_AVALID,
   output                     o_issue_AREADY,
   input                      i_flush,
   input [UOP_WIDTH-1:0]      i_uop,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] i_id,
   input                      i_rs1_rdy,
   input [`NCPU_DW-1:0]       i_rs1_dat,
   input [`NCPU_REG_AW-1:0]   i_rs1_addr,
   input                      i_rs2_rdy,
   input [`NCPU_DW-1:0]       i_rs2_dat,
   input [`NCPU_REG_AW-1:0]   i_rs2_addr,
   input                      byp_BVALID,
   input [`NCPU_DW-1:0]       byp_BDATA,
   input                      byp_rd_we,
   input [`NCPU_REG_AW-1:0]   byp_rd_addr,
   input                      i_fu_AREADY,
   output                     o_fu_AVALID,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] o_fu_id,
   output [UOP_WIDTH-1:0]     o_fu_uop,
   output [`NCPU_DW-1:0]      o_fu_rs1_dat,
   output [`NCPU_DW-1:0]      o_fu_rs2_dat,
   // For extended payload memory (currently only for FIFO mode)
   output [DEPTH_WIDTH-1:0]   o_payload_w_ptr,
   output [DEPTH_WIDTH-1:0]   o_payload_r_ptr
);
   localparam PTR_MAX = (DEPTH-1);
   wire                       que_v_r [DEPTH-1:0];
   wire                       que_v_nxt [DEPTH-1:0];
   wire                       que_v_en [DEPTH-1:0];
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       que_id_r [DEPTH-1:0];
   wire                       que_id_en [DEPTH-1:0];
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
   wire                       rs1_i_bypass_rdy, rs2_i_bypass_rdy;

   genvar i;
   integer x;

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_DFFs
            nDFF_lr #(1) dff_que_v_r
              (clk,rst_n, que_v_en[i] | i_flush, que_v_nxt[i] & ~i_flush, que_v_r[i]);
            nDFF_lr #(CONFIG_ROB_DEPTH_LOG2) dff_que_id_r
              (clk,rst_n, que_id_en[i], i_id, que_id_r[i]);
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

   assign o_issue_AREADY = |free;

   assign rs1_i_bypass_rdy = ~i_rs1_rdy & byp_BVALID & byp_rd_we & (byp_rd_addr==i_rs1_addr);
   assign rs2_i_bypass_rdy = ~i_rs2_rdy & byp_BVALID & byp_rd_we & (byp_rd_addr==i_rs2_addr);

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_write
            wire this_push, this_pop;
            wire rs1_r_bypass_rdy;
            wire rs2_r_bypass_rdy;

            // Each entry of issuing queue is a 1-slot FIFO
            assign this_push = i_issue_AVALID & free[i];
            assign this_pop = select[i] & i_fu_AREADY;
            assign que_v_nxt[i] = (this_push|~this_pop);
            assign que_v_en[i] = (this_push|this_pop);
            assign que_id_en[i] = this_push;
            assign que_uop_en[i] = this_push;

            // Wake up
            assign rs1_r_bypass_rdy = que_v_r[i] & ~que_rs1_rdy_r[i] & byp_BVALID & byp_rd_we & (byp_rd_addr==que_rs1_r[i][`NCPU_REG_AW-1:0]);
            assign rs2_r_bypass_rdy = que_v_r[i] & ~que_rs2_rdy_r[i] & byp_BVALID & byp_rd_we & (byp_rd_addr==que_rs2_r[i][`NCPU_REG_AW-1:0]);

            assign que_rs1_rdy_nxt[i] = this_push ? (i_rs1_rdy | rs1_i_bypass_rdy) : (que_rs1_rdy_r[i] | rs1_r_bypass_rdy);
            assign que_rs2_rdy_nxt[i] = this_push ? (i_rs2_rdy | rs2_i_bypass_rdy) : (que_rs2_rdy_r[i] | rs2_r_bypass_rdy);

            //
            // 1) Push insn
            //    If the operand of the pushed insn is ready, then store the value of operand.
            //    Otherwise, if the operand is not ready, firstly check the BYP, If value from BYP is ready, then apply the value.
            //    If BYP is not ready, then store the register address of the operand.
            // 2) Wake-up
            //    If the operand is not ready, then listening to the BYP. If BYP is ready, then wake up this entry.
            //
            assign que_rs1_nxt[i] = (this_push & i_rs1_rdy) ? i_rs1_dat
                                       : (this_push & rs1_i_bypass_rdy) ? byp_BDATA
                                       : (this_push & ~i_rs1_rdy) ? {{`NCPU_DW-`NCPU_REG_AW{1'b0}}, i_rs1_addr[`NCPU_REG_AW-1:0]}
                                       : (rs1_r_bypass_rdy) ? byp_BDATA
                                       : que_rs1_r[i];

            assign que_rs2_nxt[i] = (this_push & i_rs2_rdy) ? i_rs2_dat
                                       : (this_push & rs2_i_bypass_rdy) ? byp_BDATA
                                       : (this_push & ~i_rs2_rdy) ? {{`NCPU_DW-`NCPU_REG_AW{1'b0}}, i_rs2_addr[`NCPU_REG_AW-1:0]}
                                       : (rs2_r_bypass_rdy) ? byp_BDATA
                                       : que_rs2_r[i];

            // synthesis translate_off
`ifndef SYNTHESIS
            // Assertions
`ifdef NCPU_ENABLE_ASSERT
            always @(posedge clk)
               begin
                  // When rs1 or rs2 is not needed, the recommanded schema is to let `i_rsN_rdy` = 1 and `i_rsN_addr` = 'd0
                  // (the address of nil register).
                  // As nil register can be never written back, bypass from BYP will never be ready.
                  if ((que_rs1_rdy_r[i] & rs1_r_bypass_rdy) | (que_rs2_rdy_r[i] & rs2_r_bypass_rdy))
                     $fatal(1, "\n Check the implement of issuing queue, BYP or others.\n");
                  if (this_push & ((i_rs1_rdy & rs1_i_bypass_rdy) | (i_rs2_rdy & rs2_i_bypass_rdy)))
                     $fatal(1, "\n Check the implement of ISSUE unit, issuing queue, BYP or others.\n");
               end
`endif
`endif
            // synthesis translate_on

         end
   endgenerate

   generate
      wire [DEPTH_WIDTH-1:0] w_ptr_r, w_ptr_nxt;
      wire [DEPTH_WIDTH-1:0] r_ptr_r, r_ptr_nxt;
      //
      // Allocator
      //
      if (ALGORITHM == 0)
         begin : gen_alloc_out_of_order
            // FIXME: design a better algorithm
            reg t_que_v_r;
            reg [DEPTH-1:0] free_r;
            always @(*)
               begin
                  for(x=0; x<DEPTH; x=x+1)
                     begin
                        if (x==0)
                           t_que_v_r = 1'b1;
                        else
                           t_que_v_r = t_que_v_r & que_v_r[x-1];
                        free_r[x] = t_que_v_r & ~que_v_r[x];
                     end
               end
            for(i=0; i<DEPTH; i=i+1)
               assign free[i] = free_r[i];
            assign o_payload_w_ptr = {DEPTH_WIDTH{1'b0}}; // unimplemented
         end
      else
         begin : gen_alloc_FIFO
            // Note that DEPTH is not necessary being exactly 2^DEPTH_WIDTH
            assign w_ptr_nxt = (w_ptr_r + 1'b1) & {DEPTH_WIDTH{(w_ptr_r != PTR_MAX[DEPTH_WIDTH-1:0]) & ~i_flush}};
            // Write pointer register
            nDFF_lr #(DEPTH_WIDTH) dff_w_ptr_r
              (clk,rst_n, (i_issue_AVALID & o_issue_AREADY) | i_flush, w_ptr_nxt, w_ptr_r);

            // Address decoder
            for(i = 0; i < DEPTH; i = i + 1)
               assign free[i] = (w_ptr_r == i[DEPTH_WIDTH-1:0]) & ~que_v_r[i];
            assign o_payload_w_ptr = w_ptr_r;
         end

      //
      // Selector
      //
      if (ALGORITHM == 0)
         begin : gen_sel_out_of_order
            // FIXME: design a better algorithm
            reg t_select;
            reg [DEPTH-1:0] select_r;
            always @(*)
               for(x=0; x<DEPTH; x=x+1)
                  begin : gen_t_select
                     if (x==0)
                        t_select = 1'b0;
                     else
                        t_select = t_select | select_r[x-1];
                     select_r[x] = ~t_select & (que_v_r[x] & que_rs1_rdy_r[x] & que_rs2_rdy_r[x]);
                  end
            for (i=0; i<DEPTH; i=i+1)
               assign select[i] = select_r[i];
            assign o_payload_r_ptr = {DEPTH_WIDTH{1'b0}}; // unimplemented
         end
      else
         begin : gen_sel_FIFO
            // Note that DEPTH is not necessary being exactly 2^DEPTH_WIDTH
            assign r_ptr_nxt = (r_ptr_r + 1'b1) & {DEPTH_WIDTH{(r_ptr_r != PTR_MAX[DEPTH_WIDTH-1:0]) & ~i_flush}};
            // Read pointer register
            nDFF_lr #(DEPTH_WIDTH) dff_r_ptr_r
              (clk,rst_n, (o_fu_AVALID & i_fu_AREADY) | i_flush, r_ptr_nxt, r_ptr_r);
            
            // Address decoder
            for(i = 0; i < DEPTH; i = i + 1)
               begin
                  assign select[i] = (r_ptr_r == i[DEPTH_WIDTH-1:0]) &
                                       (que_v_r[i] & que_rs1_rdy_r[i] & que_rs2_rdy_r[i]);
               end
            assign o_payload_r_ptr = r_ptr_r;
         end
   endgenerate

   assign o_fu_AVALID = |select;

   // Output MUX
   generate
      reg [CONFIG_ROB_DEPTH_LOG2-1:0] t_id;
      reg [UOP_WIDTH-1:0] t_uop;
      reg [`NCPU_DW-1:0] t_rs1_dat;
      reg [`NCPU_DW-1:0] t_rs2_dat;
      always @(*)
         begin
            t_id = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
            t_uop = {UOP_WIDTH{1'b0}};
            t_rs1_dat = {`NCPU_DW{1'b0}};
            t_rs2_dat = {`NCPU_DW{1'b0}};
            for(x=0; x<DEPTH; x=x+1)
               begin : gen_output
                  t_id = t_id | ({CONFIG_ROB_DEPTH_LOG2{select[x]}} & que_id_r[x]);
                  t_uop = t_uop | ({UOP_WIDTH{select[x]}} & que_uop_r[x]);
                  t_rs1_dat = t_rs1_dat | ({`NCPU_DW{select[x]}} & que_rs1_r[x]);
                  t_rs2_dat = t_rs2_dat | ({`NCPU_DW{select[x]}} & que_rs2_r[x]);
               end
         end
      assign o_fu_id = t_id;
      assign o_fu_uop = t_uop;
      assign o_fu_rs1_dat = t_rs1_dat;
      assign o_fu_rs2_dat = t_rs2_dat;
   endgenerate

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   initial
      begin
         if (DEPTH > (1<<DEPTH_WIDTH))
            $fatal(1, "\n Check parameters. DEPTH and DEPTH_WIDTH mismatch.");
         if (`NCPU_REG_AW > `NCPU_DW)
            $fatal(1, "\n Check parameters. Address width of regfile is larger than the `NCPU_DW\n");
      end
   always @(posedge clk)
      begin
         if (count_1({free}) > 1)
            $fatal(1, "\n Bugs on allocator algoritgm\n");
         if (count_1({select}) > 1)
            $fatal(1, "\n Bugs on selector algorithm\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
