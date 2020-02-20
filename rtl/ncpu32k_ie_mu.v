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
   output [`NCPU_AW-1:0]      dbus_addr_o,
   input                      dbus_in_ready, /* dbus is ready to store */
   output                     dbus_in_valid, /* data is presented at dbus's input */
   input [`NCPU_DW-1:0]       dbus_i,
   output                     dbus_out_ready, /* MU is ready to load */
   input                      dbus_out_valid, /* data is presented at dbus's output */
   output [`NCPU_DW-1:0]      dbus_o,
   output [2:0]               dbus_size_o,
   output                     ieu_mu_in_ready, /* MU is ready to accept ops */
   input                      ieu_mu_in_valid, /* ops is presented at MU's input */
   input [`NCPU_DW-1:0]       ieu_operand_1,
   input [`NCPU_DW-1:0]       ieu_operand_2,
   input [`NCPU_DW-1:0]       ieu_operand_3,
   input                      ieu_mu_load,
   input                      ieu_mu_store,
   input [2:0]                ieu_mu_store_size,
   input [2:0]                ieu_mu_load_size,
   output [`NCPU_DW-1:0]      mu_load,
   input                      wb_mu_in_ready, /* WB is ready to accept data */
   output                     wb_mu_in_valid /* data is presented at WB'input   */
);
  
   assign dbus_addr_o = ieu_operand_1 + ieu_operand_2;
   // Load from memory
   assign dbus_rd_o = ieu_mu_load;
   assign mu_load = dbus_i;

   // Store to memory
   assign dbus_we_o = ieu_mu_store;
   assign dbus_o = ieu_operand_3;

   // Size
   assign dbus_size_o = ({3{ieu_mu_load}} & ieu_mu_load_size) |
                        ({3{ieu_mu_store}} & ieu_mu_store_size);
   
   // Pipeline handshake
   wire store_in_ready;
   wire load_out_valid;
   
   wire busy_r;
   wire busy_nxt;
   wire push;
   wire pop_dbus;
   wire pop_wb;
   
   ncpu32k_cell_dff_lr #(1) dff_busy
                   (clk,rst_n, 1'b1, busy_nxt, busy_r);
   
   assign push = ieu_mu_in_ready & ieu_mu_in_valid;
   assign pop_dbus = ieu_mu_store ? (dbus_in_ready & dbus_in_valid) :
                     ieu_mu_load ? (dbus_out_ready & dbus_out_valid) : 1'b1;
   assign pop_wb = wb_mu_in_ready & wb_mu_in_valid;
   
   assign busy_nxt = push | ~(pop_dbus & pop_wb);
   
   generate
      if(ENABLE_PIPEBUF_BYPASS) begin :enable_pipebuf_bypass
         assign ieu_mu_in_ready = ~busy_r | (pop_dbus & pop_wb);
      end else begin
         assign ieu_mu_in_ready = ~busy_r;
      end
   endgenerate
   
   assign wb_mu_in_valid = pop_dbus;
   
   assign dbus_in_valid = ieu_mu_store & busy_r;
   assign dbus_out_ready = ieu_mu_load & busy_r;
   
endmodule
