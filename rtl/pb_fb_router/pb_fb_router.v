
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
   parameter NBUS=-1
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
   
   genvar i,j,k,x,y;

   wire [NBUS-1:0] bus_pending;
   wire [NBUS-1:0] bus_pending_nxt;
   wire [NBUS-1:0] hds_bus_cmd;
   wire [NBUS-1:0] hds_bus_dout;

   // Bus cycle FSM
   // Assert (03181514)
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign hds_bus_cmd[i] = fb_bus_cmd_ready[i] & fb_bus_cmd_valid[i];
      assign hds_bus_dout[i] = fb_bus_ready[i] & fb_bus_valid[i];
      
      assign bus_pending_nxt[i] = hds_bus_cmd[i] | ~hds_bus_dout[i];

      nDFF_lr #(1) dff_bus_dout_sel
                      (clk,rst_n, (hds_bus_cmd[i] | hds_bus_dout[i]), bus_pending_nxt[i], bus_pending[i]);
   end
endgenerate
   
   // Cmd Routing
   wire [NBUS-1:0] cmd_ready;
generate
   for(j=0;j<NBUS;j=j+1) begin
      // Exclusive bus channel
      // If there is not any bus taking the time slice,
      // or this is the bus being occupied, we can accept new cmd.
      wire accept_cmd = ~|bus_pending | bus_pending[j];
      
      assign cmd_ready[j] = fb_bus_sel[j] & accept_cmd & fb_bus_cmd_ready[j];
      assign fb_bus_cmd_valid[j] = fb_bus_sel[j] & accept_cmd & fb_mbus_cmd_valid;
   end
endgenerate
   assign fb_mbus_cmd_ready = |cmd_ready;
   
   // Direct route
generate
   for(k=0;k<NBUS;k=k+1) begin
      assign fb_bus_cmd_addr[AW*(k+1)-1:AW*k]         = fb_mbus_cmd_addr;
      assign fb_bus_cmd_we_msk[DW/8*(k+1)-1:DW/8*k]   = fb_mbus_cmd_we_msk;
      assign fb_bus_din[DW*(k+1)-1:DW*k]              = fb_mbus_din;
   end
endgenerate

   // Data Routing
   wire [NBUS-1:0] dout_valid;
   wire [DW-1:0] dout[NBUS-1:0];
generate
   for(x=0;x<NBUS;x=x+1) begin
      assign dout_valid[x] = bus_pending[x] & fb_bus_valid[x];
      if (x==0)
         assign dout[x] = {DW{bus_pending[x]}} & fb_bus_dout[DW*(x+1)-1:DW*x];
      else
         assign dout[x] = dout[x-1] | ({DW{bus_pending[x]}} & fb_bus_dout[DW*(x+1)-1:DW*x]);
   end
endgenerate
   assign fb_mbus_valid = |dout_valid;
   assign fb_mbus_dout = dout[NBUS-1];
   
   // Direct route
generate
   for(i=0;i<NBUS;i=i+1) begin
      assign fb_bus_ready[i] = fb_mbus_ready & bus_pending[i];
   end
endgenerate

   // synthesis translate_off
`ifndef SYNTHESIS
   
   `include "ncpu32k_assert.h"
   
   // Assertions (03181514)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (count_1(bus_pending) > 1)
         $fatal ("\n conflicting bus cycle\n");
   end
`endif

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if (count_1(fb_bus_sel) > 1)
         $fatal ("\n conflicting cmd scheme\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
