
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
   parameter NBUS `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   // Frontend M-Bus
   output reg                 fb_mbus_BVALID,
   input                      fb_mbus_BREADY,
   output reg [`NCPU_DW-1:0]  fb_mbus_BDATA,
   output reg [1:0]           fb_mbus_BEXC,
   input [`NCPU_DW-1:0]       fb_mbus_ADATA,
   output                     fb_mbus_AREADY,
   input                      fb_mbus_AVALID,
   input [`NCPU_AW-1:0]       fb_mbus_AADDR,
   input [`NCPU_DW/8-1:0]     fb_mbus_AWMSK,
   input [1:0]                fb_mbus_AEXC,
   // Address Mapping input
   input [NBUS-1:0]           fb_bus_sel,
   // Buses
   input [NBUS-1:0]           fb_bus_BVALID,
   output [NBUS-1:0]          fb_bus_BREADY,
   input [NBUS*`NCPU_DW-1:0]  fb_bus_BDATA,
   input [NBUS*2-1:0]         fb_bus_BEXC,
   output [NBUS*`NCPU_DW-1:0] fb_bus_ADATA,
   input [NBUS-1:0]           fb_bus_AREADY,
   output [NBUS-1:0]          fb_bus_AVALID,
   output [NBUS*`NCPU_AW-1:0] fb_bus_AADDR,
   output [NBUS*`NCPU_DW/8-1:0] fb_bus_AWMSK,
   output [NBUS*2-1:0]        fb_bus_AEXC
);
   genvar i;
   integer x;

   wire [NBUS-1:0] bus_pending;
   wire [NBUS-1:0] bus_pending_nxt;
   wire [NBUS-1:0] hds_bus_cmd;
   wire [NBUS-1:0] hds_bus_dout;

   // Bus cycle FSM
   // Assert (03181514)
   generate
      for(i=0;i<NBUS;i=i+1)
         begin
            assign hds_bus_cmd[i] = fb_bus_AREADY[i] & fb_bus_AVALID[i];
            assign hds_bus_dout[i] = fb_bus_BREADY[i] & fb_bus_BVALID[i];

            assign bus_pending_nxt[i] = hds_bus_cmd[i] | ~hds_bus_dout[i];

            nDFF_lr #(1) dff_bus_dout_sel
                            (clk,rst_n, (hds_bus_cmd[i] | hds_bus_dout[i]), bus_pending_nxt[i], bus_pending[i]);
         end
   endgenerate

   // Cmd Routing
   wire [NBUS-1:0] AREADY;
   generate
      for(i=0;i<NBUS;i=i+1)
         begin
            // Exclusive bus channel
            // If there is not any bus taking the time slice,
            // or this is the bus being occupied, we can accept new cmd.
            wire accept_cmd = ~|bus_pending | bus_pending[i];

            assign AREADY[i] = fb_bus_sel[i] & accept_cmd & fb_bus_AREADY[i];
            assign fb_bus_AVALID[i] = fb_bus_sel[i] & accept_cmd & fb_mbus_AVALID;
         end
   endgenerate
   assign fb_mbus_AREADY = |AREADY;

   // Direct route
   generate
      for(i=0;i<NBUS;i=i+1) begin
         assign fb_bus_AADDR[`NCPU_AW*(i+1)-1:`NCPU_AW*i]      = fb_mbus_AADDR;
         assign fb_bus_AWMSK[`NCPU_DW/8*(i+1)-1:`NCPU_DW/8*i]  = fb_mbus_AWMSK;
         assign fb_bus_AEXC[2*(i+1)-1:2*i]                     = fb_mbus_AEXC;
         assign fb_bus_ADATA[`NCPU_DW*(i+1)-1:`NCPU_DW*i]      = fb_mbus_ADATA;
      end
   endgenerate

   // Data Routing
   wire [`NCPU_DW-1:0]  e_fb_bus_BDATA [NBUS-1:0];
   wire [1:0]           e_fb_bus_BEXC [NBUS-1:0];
   generate
      for(i=0;i<NBUS;i=i+1)
         begin
            assign e_fb_bus_BDATA[i] = fb_bus_BDATA[`NCPU_DW*(i+1)-1:`NCPU_DW*i];
            assign e_fb_bus_BEXC[i] = fb_bus_BEXC[2*(i+1)-1:2*i];
         end
      always @(*)
         begin
            fb_mbus_BVALID = 1'b0;
            fb_mbus_BDATA = {`NCPU_DW{1'b0}};
            fb_mbus_BEXC = 2'b0;
            for(x=0;x<NBUS;x=x+1)
               begin
                  fb_mbus_BVALID = fb_mbus_BVALID | (bus_pending[x] & fb_bus_BVALID[x]);
                  fb_mbus_BDATA = fb_mbus_BDATA | ({`NCPU_DW{bus_pending[x]}} & e_fb_bus_BDATA[x]);
                  fb_mbus_BEXC = fb_mbus_BEXC | ({2{bus_pending[x]}} & e_fb_bus_BEXC[x]);
               end
         end
   endgenerate

   // Direct route
   generate
      for(i=0;i<NBUS;i=i+1)
         begin
            assign fb_bus_BREADY[i] = fb_mbus_BREADY & bus_pending[i];
         end
   endgenerate

   // synthesis translate_off
`ifndef SYNTHESIS

   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   // Assertions (03181514)
   always @(posedge clk) begin
      if (count_1(bus_pending) > 1)
         $fatal ("\n conflicting bus cycle\n");
   end

   // Assertion
   always @(posedge clk) begin
      if (count_1(fb_bus_sel) > 1)
         $fatal ("\n conflicting cmd scheme\n");
   end
`endif

`endif
   // synthesis translate_on

endmodule
