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

module pb_fb_arbiter
(
   input                   clk,
   input                   rst_n,
   // Frontend I-Bus
   output                  fb_ibus_valid,
   input                   fb_ibus_ready,
   output [`NCPU_IW-1:0]   fb_ibus_dout,
   output                  fb_ibus_cmd_ready,
   input                   fb_ibus_cmd_valid,
   input [`NCPU_AW-1:0]    fb_ibus_cmd_addr,
   // Frontend D-Bus
   output                  fb_dbus_valid,
   input                   fb_dbus_ready,
   output [`NCPU_IW-1:0]   fb_dbus_dout,
   input [`NCPU_DW-1:0]    fb_dbus_din,
   output                  fb_dbus_cmd_ready,
   input                   fb_dbus_cmd_valid,
   input [`NCPU_AW-1:0]    fb_dbus_cmd_addr,
   input [2:0]             fb_dbus_cmd_size,
   input                   fb_dbus_cmd_we,
   // Frontend M-Bus
   input                   fb_mbus_valid,
   output                  fb_mbus_ready,
   input [`NCPU_IW-1:0]    fb_mbus_dout,
   output [`NCPU_DW-1:0]   fb_mbus_din,
   input                   fb_mbus_cmd_ready,
   output                  fb_mbus_cmd_valid,
   output [`NCPU_AW-1:0]   fb_mbus_cmd_addr,
   output [2:0]            fb_mbus_cmd_size,
   output                  fb_mbus_cmd_we
);
  
   // Priority scheme
   // Assert (03112048)
   wire dbus_cmd_sel = fb_dbus_cmd_valid;
   wire ibus_cmd_sel = ~fb_dbus_cmd_valid;
   
   // Bus cycle FSM
   // Assert (03112057)
   wire dbus_dout_sel;
   wire dbus_dout_sel_nxt;
   wire ibus_dout_sel;
   wire ibus_dout_sel_nxt;
   
   wire hds_dbus_cmd = fb_dbus_cmd_ready & fb_dbus_cmd_valid;
   wire hds_dbus_dout = fb_dbus_ready & fb_dbus_valid;
   wire hds_ibus_cmd = fb_ibus_cmd_ready & fb_ibus_cmd_valid;
   wire hds_ibus_dout = fb_ibus_ready & fb_ibus_valid;
   
   assign dbus_dout_sel_nxt = ~dbus_dout_sel & hds_dbus_cmd ? 1'b1 :
                              dbus_dout_sel & hds_dbus_dout ? 1'b1 : dbus_dout_sel;
   assign ibus_dout_sel_nxt = ~ibus_dout_sel & hds_ibus_cmd ? 1'b1 :
                              ibus_dout_sel & hds_ibus_dout ? 1'b1 : ibus_dout_sel;
   
   ncpu32k_cell_dff_r #(1) dff_dbus_dout_sel
                   (clk,rst_n, dbus_dout_sel_nxt, dbus_dout_sel);
   ncpu32k_cell_dff_r #(1) dff_ibus_dout_sel
                   (clk,rst_n, ibus_dout_sel_nxt, ibus_dout_sel);
   
   // Send cmd
   assign fb_dbus_cmd_ready = dbus_cmd_sel & fb_mbus_cmd_ready;
   assign fb_ibus_cmd_ready = ibus_cmd_sel & fb_mbus_cmd_ready;
   assign fb_mbus_cmd_valid = dbus_cmd_sel ? fb_dbus_cmd_valid : fb_ibus_cmd_valid;
   assign fb_mbus_cmd_addr = dbus_cmd_sel ? fb_dbus_cmd_addr : fb_ibus_cmd_addr;
   assign fb_mbus_cmd_size = dbus_cmd_sel ? fb_dbus_cmd_size : 3'd3 /* insn len */;
   assign fb_mbus_cmd_we = dbus_cmd_sel ? fb_dbus_cmd_we : 1'b0;
   assign fb_mbus_din = fb_dbus_din;
   
   // Transmit dout
   assign fb_dbus_valid = dbus_dout_sel & fb_mbus_valid;
   assign fb_ibus_valid = ibus_dout_sel & fb_mbus_valid;
   
   assign fb_mbus_ready = dbus_dout_sel ? fb_dbus_ready : fb_ibus_ready;
   assign fb_dbus_dout = {`NCPU_DW{dbus_dout_sel}} & fb_mbus_dout;
   assign fb_ibus_dout = {`NCPU_IW{ibus_dout_sel}} & fb_mbus_dout;
   
   // synthesis translate_off
`ifndef SYNTHESIS
   
   // Assertions (03112048)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if ((dbus_cmd_sel|ibus_cmd_sel) & ~(dbus_cmd_sel^ibus_cmd_sel))
         $fatal ("\n conflicting cmd scheme\n");
      if ((dbus_dout_sel|ibus_dout_sel) & ~(dbus_dout_sel^ibus_dout_sel))
         $fatal ("\n conflicting dout scheme\n");
   end
`endif

   // Assertions (03112057)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if ((dbus_dout_sel|ibus_dout_sel) & ~(dbus_dout_sel^ibus_dout_sel))
         $fatal ("\n conflicting bus cycle\n");
   end
`endif

`endif
   // synthesis translate_on

   
endmodule
