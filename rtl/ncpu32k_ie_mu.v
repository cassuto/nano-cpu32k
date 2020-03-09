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
   output [2:0]               dbus_cmd_size,
   output                     dbus_cmd_we,
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
   output [`NCPU_DW-1:0]      mu_load,
   output                     mu_exp_taken,
   output [`NCPU_AW-3:0]      mu_exp_tgt,
   input                      wb_mu_in_ready, /* WB is ready to accept data */
   output                     wb_mu_in_valid /* data is presented at WB'input   */
);

   // ieu_in can handshake successfully if there is a valid operation
   wire hds_ieu_in = ieu_mu_in_valid & ieu_mu_in_ready;
   // dbus_cmd can handshake successfully only if it's a MU operation
   wire hds_dbus_cmd = dbus_cmd_valid & dbus_cmd_ready;
   // wb_in can handshake successfully if downstream module accepted dout.
   wire hds_wb_in = wb_mu_in_valid & wb_mu_in_ready;
   
   assign dbus_cmd_addr = ieu_operand_1 + ieu_operand_2;

   // Store to memory
   assign dbus_cmd_we = ieu_mu_store;
   assign dbus_din = ieu_operand_3;

   // Size
   assign dbus_cmd_size = ({3{ieu_mu_load}} & ieu_mu_load_size) |
                        ({3{ieu_mu_store}} & ieu_mu_store_size);
   
   wire mu_op_nxt = ieu_mu_load | ieu_mu_store;
   
   // Send cmd to dbus if it's a valid MU operation
   assign dbus_cmd_valid = mu_op_nxt & ieu_mu_in_valid;

   // MMU Exceptions
   assign mu_exp_taken = exp_dmm_tlb_miss | exp_dmm_page_fault;

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
   
   // Load from memory
   assign mu_load =
         ({`NCPU_DW{ieu_mu_load_size==3'd3}} & dbus_dout) |
         ({`NCPU_DW{ieu_mu_load_size==3'd2}} & {{16{ieu_mu_sign_ext & dbus_dout[15]}}, dbus_dout[15:0]}) |
         ({`NCPU_DW{ieu_mu_load_size==3'd1}} & {{24{ieu_mu_sign_ext & dbus_dout[7]}}, dbus_dout[7:0]});

   assign dbus_ready = wb_mu_in_ready;
   assign wb_mu_in_valid = dbus_valid;
   

   // Assertions 03092009
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if((exp_dmm_tlb_miss|exp_dmm_page_fault) &
            ~(exp_dmm_tlb_miss^exp_dmm_page_fault)) begin
         $fatal ("\n ctrls of 'exp_vector' MUX should be mutex\n");
      end
   end
`endif
   
endmodule
