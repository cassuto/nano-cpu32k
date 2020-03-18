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

module ncpu32k_ie_mu
#(
   parameter ENABLE_PIPEBUF_BYPASS = 1
)
(         
   input                      clk,
   input                      rst_n,
   input                      dbus_cmd_ready, /* dbus is ready to store */
   output                     dbus_cmd_valid, /* data is presented at dbus's input */
   output [`NCPU_AW-1:0]      dbus_cmd_addr,
   output [`NCPU_DW/8-1:0]    dbus_cmd_we_msk,
   output [`NCPU_DW-1:0]      dbus_din,
   output                     dbus_ready, /* MU is ready to load */
   input                      dbus_valid, /* data is presented at dbus's output */
   input [`NCPU_DW-1:0]       dbus_dout,
   input                      exp_dmm_tlb_miss,
   input                      exp_dmm_page_fault,
   output                     ieu_mu_in_ready, /* MU is ready to accept ops */
   input                      ieu_mu_in_valid, /* ops is presented at MU's input */
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_DW-1:0]       ieu_operand_3,
   input                      ieu_mu_load,
   input                      ieu_mu_store,
   input                      ieu_mu_sign_ext,
   input [2:0]                ieu_mu_store_size,
   input [2:0]                ieu_mu_load_size,
   input                      mu_exp_flush_ack,
   output [`NCPU_DW-1:0]      mu_load,
   output                     mu_exp_taken,
   output [`NCPU_AW-3:0]      mu_exp_tgt,
   output [`NCPU_DW-1:0]      mu_lsa,
   input                      wb_mu_in_ready, /* WB is ready to accept data */
   output                     wb_mu_in_valid /* data is presented at WB'input   */
);

   // ieu_in can handshake successfully if there is a valid operation
   wire hds_ieu_in = ieu_mu_in_valid & ieu_mu_in_ready;
   // dbus_cmd can handshake successfully only if it's a MU operation
   wire hds_dbus_cmd = dbus_cmd_valid & dbus_cmd_ready;
   // wb_in can handshake successfully if downstream module accepted dout.
   wire hds_wb_in = wb_mu_in_valid & wb_mu_in_ready;
   
   assign mu_lsa = ieu_operand_1 + ieu_operand_2;
   
   assign dbus_cmd_addr = mu_lsa;

   // B/HW align
   wire [`NCPU_DW/8-1:0] we_msk_8b = (dbus_cmd_addr[1:0]==2'b00 ? 4'b0001 :
                              dbus_cmd_addr[1:0]==2'b01 ? 4'b0010 :
                              dbus_cmd_addr[1:0]==2'b10 ? 4'b0100 :
                              dbus_cmd_addr[1:0]==2'b11 ? 4'b1000 : 4'b0000);
   wire [31:0] din_8b = {ieu_operand_3[7:0], ieu_operand_3[7:0], ieu_operand_3[7:0], ieu_operand_3[7:0]};
                         
   wire [`NCPU_DW/8-1:0] we_msk_16b = dbus_cmd_addr[0] ? 4'b0011 : 4'b1100;
   wire [31:0] din_16b = {ieu_operand_3[15:0], ieu_operand_3[15:0]};
   
   // Size
   assign dbus_cmd_we_msk = {`NCPU_DW/8{ieu_mu_store}} & (
                            ({`NCPU_DW/8{ieu_mu_store_size==3'd3}} & 4'b1111) |
                            ({`NCPU_DW/8{ieu_mu_store_size==3'd2}} & we_msk_16b) |
                            ({`NCPU_DW/8{ieu_mu_store_size==3'd1}} & we_msk_8b) );

   // Store to memory
   assign dbus_din = ({`NCPU_DW{ieu_mu_store_size==3'd3}} & ieu_operand_3) |
                     ({`NCPU_DW{ieu_mu_store_size==3'd2}} & din_16b) |
                     ({`NCPU_DW{ieu_mu_store_size==3'd1}} & din_8b);

   wire mu_op_nxt = ieu_mu_load | ieu_mu_store;
   
   // Internal, Don't deliver it out
   wire exp_raised_w = (exp_dmm_tlb_miss | exp_dmm_page_fault);
   // Handshaked with flush when exception raised
   wire hds_exp = (exp_raised_w & mu_exp_flush_ack);
   
   // MU FSM
   wire pending_r;
   // If handshaked with dbus_cmd, then MU is pending
   wire pending_push = hds_dbus_cmd;
   // If handshaked with downstream module (or exception), then MU is idle
   wire pending_pop = hds_wb_in | hds_exp;
   
   wire pending_nxt = (pending_push | ~pending_pop);

   ncpu32k_cell_dff_lr #(1) dff_pending_r
                   (clk,rst_n, (pending_push|pending_pop), pending_nxt, pending_r);
   
   wire pending = pending_r & ~hds_exp; // bypass flush_ack
   
   // MMU Exceptions
   // Just when pending exception can be delivered
   assign mu_exp_taken = pending & exp_raised_w;
   
   // Just when pending we can send cmd
   wire send_cmd = ~pending;

   // Send cmd to dbus if it's a valid MU operation
   assign dbus_cmd_valid = mu_op_nxt & ieu_mu_in_valid & send_cmd;

   // Assert (03092009)
   wire [`NCPU_VECT_DW-1:0] exp_vector =
      (
         ({`NCPU_VECT_DW{exp_dmm_tlb_miss}} & `NCPU_EDTM_VECTOR) |
         ({`NCPU_VECT_DW{exp_dmm_page_fault}} & `NCPU_EDPF_VECTOR)
      );
                     
   assign mu_exp_tgt = {{`NCPU_AW-2-`NCPU_VECT_DW{1'b0}}, exp_vector[`NCPU_VECT_DW-1:2]};
   
   // MU is ready when handshaked with dbus dout (or Exception raised) if it was a MU operation
   // This ensures that operations will not change before MU ready.
   assign ieu_mu_in_ready = ~(ieu_mu_load|ieu_mu_store) | (hds_wb_in | mu_exp_taken);
   
   // B/HW align
   wire [7:0] dout_8b = ({8{dbus_cmd_addr[1:0]==2'b00}} & dbus_dout[7:0]) |
                          ({8{dbus_cmd_addr[1:0]==2'b01}} & dbus_dout[15:8]) |
                          ({8{dbus_cmd_addr[1:0]==2'b10}} & dbus_dout[23:16]) |
                          ({8{dbus_cmd_addr[1:0]==2'b11}} & dbus_dout[31:24]);
   wire [15:0] dout_16b = dbus_cmd_addr[0] ? dbus_dout[15:0] : dbus_dout[31:16];
   
   // Data bits mask, sign extend
   assign mu_load =
         ({`NCPU_DW{ieu_mu_load_size==3'd3}} & dbus_dout) |
         ({`NCPU_DW{ieu_mu_load_size==3'd2}} & {{16{ieu_mu_sign_ext & dout_16b[15]}}, dout_16b[15:0]}) |
         ({`NCPU_DW{ieu_mu_load_size==3'd1}} & {{24{ieu_mu_sign_ext & dout_8b[7]}}, dout_8b[7:0]});

   assign dbus_ready = wb_mu_in_ready;
   assign wb_mu_in_valid = dbus_valid;


   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions 03092009
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if((exp_dmm_tlb_miss|exp_dmm_page_fault) &
            ~(exp_dmm_tlb_miss^exp_dmm_page_fault)) begin
         $fatal ("\n ctrls of 'exp_vector' MUX should be mutex\n");
      end
   end
`endif

`endif
   // synthesis translate_on
   
endmodule
