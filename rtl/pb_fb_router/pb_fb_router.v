
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

module pb_fb_router
#(
   parameter NBUS
)
(
   input                      clk,
   input                      rst_n,
   // Frontend M-Bus
   output                     fb_mbus_valid,
   input                      fb_mbus_ready,
   output [`NCPU_DW-1:0]      fb_mbus_dout,
   input [`NCPU_DW-1:0]       fb_mbus_din,
   output                     fb_mbus_cmd_ready,
   input                      fb_mbus_cmd_valid,
   input [`NCPU_AW-1:0]       fb_mbus_cmd_addr,
   input [`NCPU_DW/8-1:0]     fb_mbus_cmd_we_msk,
   // Address Mapping input
   input [NBUS-1:0]           fb_bus_sel,
   // Buses
   input [NBUS-1:0]           fb_bus_valid,
   output [NBUS-1:0]          fb_bus_ready,
   input [NBUS*`NCPU_DW-1:0]  fb_bus_dout,
   output [NBUS*`NCPU_DW-1:0] fb_bus_din,
   input [NBUS-1:0]           fb_bus_cmd_ready,
   output [NBUS-1:0]          fb_bus_cmd_valid,
   output [NBUS*`NCPU_AW-1:0] fb_bus_cmd_addr,
   output [NBUS*`NCPU_DW/8-1:0] fb_bus_cmd_we_msk
);

   localparam AW = `NCPU_AW;
   localparam DW = `NCPU_DW;
   
   genvar i;

   // Cmd Routing
   wire [NBUS-1:0] cmd_ready;
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign cmd_ready[i] = fb_bus_sel[i] & fb_bus_cmd_ready[i];
      assign fb_bus_cmd_valid[i] = fb_bus_sel[i] & fb_mbus_cmd_valid;
   end
endgenerate
   assign fb_mbus_cmd_ready = |cmd_ready;
   
   // Direct route
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign fb_bus_cmd_addr[AW*(i+1)-1:AW*i]         = fb_mbus_cmd_addr;
      assign fb_bus_cmd_we_msk[DW/8*(i+1)-1:DW/8*i]   = fb_mbus_cmd_we_msk;
      assign fb_bus_din[DW*(i+1)-1:DW*i]              = fb_mbus_din;
   end
endgenerate

   wire [NBUS-1:0] bus_dout_sel;
   wire [NBUS-1:0] bus_dout_sel_nxt;
   wire [NBUS-1:0] hds_bus_cmd;
   wire [NBUS-1:0] hds_bus_dout;

   // Bus cycle FSM
   // Assert (03181514)
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign hds_bus_cmd[i] = fb_bus_cmd_ready[i] & fb_bus_cmd_valid[i];
      assign hds_bus_dout[i] = fb_bus_ready[i] & fb_bus_valid[i];
      
      assign bus_dout_sel_nxt[i] = hds_bus_cmd[i] | ~hds_bus_dout[i];

      ncpu32k_cell_dff_lr #(1) dff_bus_dout_sel
                      (clk,rst_n, (hds_bus_cmd[i] | hds_bus_dout[i]), bus_dout_sel_nxt[i], bus_dout_sel[i]);
   end
endgenerate

   // Data Routing
   wire [NBUS-1:0] dout_valid;
   wire [DW-1:0] dout[NBUS-1:0];
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign dout_valid = bus_dout_sel[i] & fb_bus_valid[i];
      if (i==0)
         assign dout[i] = {DW{bus_dout_sel[i]}} & fb_bus_dout[DW*(i+1)-1:DW*i];
      else
         assign dout[i] = dout[i-1] | ({DW{bus_dout_sel[i]}} & fb_bus_dout[DW*(i+1)-1:DW*i]);
   end
endgenerate
   assign fb_mbus_valid = |dout_valid;
   assign fb_mbus_dout = dout[NBUS-1];
   
   // Direct route
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign fb_bus_ready[i] = fb_mbus_ready;
   end
endgenerate

endmodule
