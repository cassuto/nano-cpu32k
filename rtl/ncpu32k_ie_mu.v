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
   input                      ieu_wb_regf,
   input [`NCPU_REG_AW-1:0]   ieu_wb_reg_addr,
   output                     mu_op,
   output                     mu_op_load,
   output                     mu_wb_regf,
   output [`NCPU_REG_AW-1:0]  mu_wb_reg_addr,
   output [`NCPU_DW-1:0]      mu_load,
   input                      wb_mu_in_ready, /* WB is ready to accept data */
   output                     wb_mu_in_valid /* data is presented at WB'input   */
);

   wire hds_ieu_in = ieu_mu_in_valid & ieu_mu_in_ready;
   wire hds_dbus_cmd = dbus_cmd_valid & dbus_cmd_ready;
   wire hds_wb_in = wb_mu_in_valid & wb_mu_in_ready;
   
   assign dbus_cmd_addr = ieu_operand_1 + ieu_operand_2;

   // Store to memory
   assign dbus_cmd_we = ieu_mu_store;
   assign dbus_din = ieu_operand_3;

   // Size
   assign dbus_cmd_size = ({3{ieu_mu_load}} & ieu_mu_load_size) |
                        ({3{ieu_mu_store}} & ieu_mu_store_size);
   
   wire mu_op_nxt = ieu_mu_load | ieu_mu_store;
   
   // Send cmd to dbus if it's a MU operation
   assign dbus_cmd_valid = mu_op_nxt & ieu_mu_in_valid;
   
   wire [2:0] load_size_r;
   wire sign_ext_r;
   
   ncpu32k_cell_dff_lr #(3) dff_load_size_r
                   (clk,rst_n, hds_dbus_cmd, ieu_mu_load_size[2:0], load_size_r[2:0]);
   ncpu32k_cell_dff_lr #(1) dff_sign_ext_r
                   (clk,rst_n, hds_dbus_cmd, ieu_mu_sign_ext, sign_ext_r);

   // MU FSM
   wire pending_r;
   wire pending_nxt;
   
   assign pending_nxt =
      (
         // If handshaked with dbus_cmd, then MU is pending
         (~pending_r & hds_dbus_cmd) ? 1'b1 :
         // If handshaked with downstream module, then MU is idle
         (pending_r & hds_wb_in) ? 1'b0 : pending_r
      );
      
   ncpu32k_cell_dff_r #(1) dff_pending_r
                   (clk,rst_n, pending_nxt, pending_r);
   
   wire mu_op_r;
   wire mu_load_op_r;
   wire mu_wb_regf_r;
   wire [`NCPU_REG_AW-1:0] mu_wb_reg_addr_r;
   
   // MU is ready when both dbus and MU is idle
   assign ieu_mu_in_ready = dbus_cmd_ready & ~pending_r;
   
   ncpu32k_cell_dff_lr #(1) dff_mu_op_r
                   (clk,rst_n, hds_ieu_in, mu_op_nxt, mu_op_r);
   ncpu32k_cell_dff_lr #(1) dff_mu_load_op_r
                   (clk,rst_n, hds_ieu_in, ieu_mu_load, mu_load_op_r);
   ncpu32k_cell_dff_lr #(1) dff_wb_mu_regf_r
                   (clk,rst_n, hds_ieu_in, ieu_wb_regf, mu_wb_regf_r); 
   ncpu32k_cell_dff_lr #(`NCPU_REG_AW) dff_wb_mu_reg_addr_r
                   (clk,rst_n, hds_ieu_in, ieu_wb_reg_addr[`NCPU_REG_AW-1:0], mu_wb_reg_addr_r[`NCPU_REG_AW-1:0]); 

   assign mu_op = pending_r ? mu_op_r : mu_op_nxt;
   assign mu_op_load = pending_r ? mu_load_op_r : ieu_mu_load;
   assign mu_wb_regf = pending_r ? mu_wb_regf_r : ieu_wb_regf;
   assign mu_wb_reg_addr = pending_r ? mu_wb_reg_addr_r : ieu_wb_reg_addr;

   // Load from memory
   assign mu_load =
         ({`NCPU_DW{load_size_r==3'd3}} & dbus_dout) |
         ({`NCPU_DW{load_size_r==3'd2}} & {{16{sign_ext_r & dbus_dout[15]}}, dbus_dout[15:0]}) |
         ({`NCPU_DW{load_size_r==3'd1}} & {{24{sign_ext_r & dbus_dout[7]}}, dbus_dout[7:0]});

   assign dbus_ready = wb_mu_in_ready;
   assign wb_mu_in_valid = dbus_valid;
   
endmodule
