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
   output [`NCPU_DW-1:0]      dbus_i,
   output                     dbus_out_ready, /* MU is ready to load */
   input                      dbus_out_valid, /* data is presented at dbus's output */
   input [`NCPU_DW-1:0]       dbus_o,
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
   assign mu_load = dbus_o;

   // Store to memory
   assign dbus_we_o = ieu_mu_store;
   assign dbus_i = ieu_operand_3;

   // Size
   assign dbus_size_o = ({3{ieu_mu_load}} & ieu_mu_load_size) |
                        ({3{ieu_mu_store}} & ieu_mu_store_size);
   
   // handshake FSM
   localparam HS_IDLE = 2'd0;
   localparam HS_LOAD = 2'd1;
   localparam HS_STORE = 2'd2;
   localparam HS_PENDING = 2'd3;
   
   wire [1:0] hs_status_r;
   wire [1:0] hs_status_nxt;
   
   assign ieu_mu_in_ready = (hs_status_r==HS_IDLE);
   assign dbus_in_valid = (hs_status_r==HS_STORE);
   assign dbus_out_ready = (hs_status_r==HS_LOAD);
   assign wb_mu_in_valid = (hs_status_r==HS_PENDING);
   assign hs_status_nxt =
      (
         // If there is an incoming load/store request, then goto to the corresponding status.
         // otherwise, keep idle.
           (hs_status_r==HS_IDLE) ? (ieu_mu_load ? HS_LOAD : ieu_mu_store ? HS_STORE : HS_IDLE)
         // handshake with dbus output
         : (hs_status_r==HS_LOAD) ? (dbus_out_valid ? HS_PENDING : HS_LOAD)
         // handshake with dbus input
         : (hs_status_r==HS_STORE) ? (dbus_in_ready ? HS_PENDING : HS_STORE)
         // handshake with downstream
         : (hs_status_r==HS_PENDING) ? (wb_mu_in_ready ? HS_IDLE : HS_PENDING)
         : HS_IDLE
      );
   
   ncpu32k_cell_dff_lr #(2) dff_hs_status_r
                (clk,rst_n, 1'b1, hs_status_nxt[1:0], hs_status_r[1:0]);

endmodule
