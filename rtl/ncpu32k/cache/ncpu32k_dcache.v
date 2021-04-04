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

module ncpu32k_dcache
(
   input                   clk,
   input                   rst_n,
   output                  dcache_BVALID,
   input                   dcache_BREADY,
   output [`NCPU_DW-1:0]   dcache_BDATA,
   output [1:0]            dcache_BEXC,
   input [`NCPU_DW-1:0]    dcache_ADATA,
   output                  dcache_AREADY,
   input                   dcache_AVALID,
   input [`NCPU_AW-1:0]    dcache_AADDR,
   input [`NCPU_DW/8-1:0]  dcache_AWMSK,
   input [1:0]             dcache_AEXC,
   input                   fb_dbus_BVALID,
   output                  fb_dbus_BREADY,
   input [`NCPU_DW-1:0]    fb_dbus_BDATA,
   input [1:0]             fb_dbus_BEXC,
   output [`NCPU_DW-1:0]   fb_dbus_ADATA,
   input                   fb_dbus_AREADY,
   output                  fb_dbus_AVALID,
   output [`NCPU_AW-1:0]   fb_dbus_AADDR,
   output [`NCPU_DW/8-1:0] fb_dbus_AWMSK,
   output [1:0]            fb_dbus_AEXC
);

   // TODO

endmodule
