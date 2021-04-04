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
   output                  fb_ibus_BVALID,
   input                   fb_ibus_BREADY,
   output [`NCPU_IW-1:0]   fb_ibus_BDATA,
   output [1:0]            fb_ibus_BEXC,
   output                  fb_ibus_AREADY,
   input                   fb_ibus_AVALID,
   input [`NCPU_AW-1:0]    fb_ibus_AADDR,
   input [1:0]             fb_ibus_AEXC,
   // Frontend D-Bus
   output                  fb_dbus_BVALID,
   input                   fb_dbus_BREADY,
   output [`NCPU_IW-1:0]   fb_dbus_BDATA,
   output [1:0]            fb_dbus_BEXC,
   input [`NCPU_DW-1:0]    fb_dbus_ADATA,
   output                  fb_dbus_AREADY,
   input                   fb_dbus_AVALID,
   input [`NCPU_AW-1:0]    fb_dbus_AADDR,
   input [`NCPU_DW/8-1:0]  fb_dbus_AWMSK,
   input [1:0]             fb_dbus_AEXC,
   // Frontend M-Bus
   input                   fb_mbus_BVALID,
   output                  fb_mbus_BREADY,
   input [`NCPU_IW-1:0]    fb_mbus_BDATA,
   input [1:0]             fb_mbus_BEXC,
   output [`NCPU_DW-1:0]   fb_mbus_ADATA,
   input                   fb_mbus_AREADY,
   output                  fb_mbus_AVALID,
   output [`NCPU_AW-1:0]   fb_mbus_AADDR,
   output [`NCPU_DW/8-1:0] fb_mbus_AWMSK,
   output [1:0]            fb_mbus_AEXC
);
   wire tlb_cke = fb_dbus_AREADY & fb_dbus_AVALID;
   wire hds_dbus_b = fb_dbus_BREADY & fb_dbus_BVALID;
   wire hds_ibus_a = fb_ibus_AREADY & fb_ibus_AVALID;
   wire hds_ibus_b = fb_ibus_BREADY & fb_ibus_BVALID;

   wire [1:0] status_r;
   reg [1:0] status_nxt;

   localparam [1:0] STATUS_IDLE = 2'b00;
   localparam [1:0] STATUS_IBUS_CYC = 2'b01;
   localparam [1:0] STATUS_DBUS_CYC = 2'b11;

   // Priority scheme (dbus > ibus)
   always @(*)
      case (status_r)
         STATUS_IDLE:
            if (fb_dbus_AVALID)
               status_nxt = STATUS_DBUS_CYC;
            else if (fb_ibus_AVALID)
               status_nxt = STATUS_IBUS_CYC;
            else
               status_nxt = status_r;

         STATUS_DBUS_CYC:
            status_nxt = hds_dbus_b ?
                           (fb_dbus_AVALID ? STATUS_DBUS_CYC :
                            fb_ibus_AVALID ? STATUS_IBUS_CYC : STATUS_IDLE) : status_r;
         STATUS_IBUS_CYC:
            status_nxt = hds_ibus_b ?
                           (fb_dbus_AVALID ? STATUS_DBUS_CYC :
                            fb_ibus_AVALID ? STATUS_IBUS_CYC : STATUS_IDLE) : status_r;
      endcase

   nDFF_r #(2, STATUS_IDLE) dff_status_r
                   (clk,rst_n, status_nxt, status_r);

   // Assert (03112048)
   wire dbus_sel_a = (status_r == STATUS_DBUS_CYC);
   wire ibus_sel_a = (status_r == STATUS_IBUS_CYC);
   wire dbus_sel_b = dbus_sel_a;
   wire ibus_sel_b = ibus_sel_a;

   // A-channel switch
   assign fb_dbus_AREADY = dbus_sel_a & fb_mbus_AREADY;
   assign fb_ibus_AREADY = ibus_sel_a & fb_mbus_AREADY;
   assign fb_mbus_AVALID = (dbus_sel_a & fb_dbus_AVALID) |
                              (ibus_sel_a & fb_ibus_AVALID);
   assign fb_mbus_AADDR = dbus_sel_a ? fb_dbus_AADDR : fb_ibus_AADDR;
   assign fb_mbus_AWMSK = dbus_sel_a ? fb_dbus_AWMSK : {`NCPU_DW/8{1'b0}};
   assign fb_mbus_AEXC = dbus_sel_a ? fb_dbus_AEXC : fb_ibus_AEXC;
   assign fb_mbus_ADATA = fb_dbus_ADATA;

   // B-channel switch
   assign fb_dbus_BVALID = dbus_sel_b & fb_mbus_BVALID;
   assign fb_ibus_BVALID = ibus_sel_b & fb_mbus_BVALID;

   assign fb_mbus_BREADY = (dbus_sel_b & fb_dbus_BREADY) |
                          (ibus_sel_b & fb_ibus_BREADY);
   assign fb_dbus_BDATA = fb_mbus_BDATA;
   assign fb_ibus_BDATA = fb_mbus_BDATA;
   assign fb_dbus_BEXC = fb_mbus_BEXC;
   assign fb_ibus_BEXC = fb_mbus_BEXC;

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions (03112048)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if (dbus_sel_a & ibus_sel_a)
            $fatal ("\n conflicting cmd scheme\n");
         if (dbus_sel_b & ibus_sel_b)
            $fatal ("\n conflicting dout scheme\n");
      end
`endif

`endif
   // synthesis translate_on


endmodule
