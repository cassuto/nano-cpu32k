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
   output                  dcache_valid, /* Insn is presented at dcache's output */
   input                   dcache_ready, /* cpu is ready to accepted Insn */
   output [`NCPU_IW-1:0]   dcache_dout,
   input [`NCPU_DW-1:0]    dcache_din,
   output                  dcache_cmd_ready, /* dcache is ready to accept cmd */
   input                   dcache_cmd_valid, /* cmd is presented at dcache's input */
   input [`NCPU_AW-1:0]    dcache_cmd_addr,
   input [`NCPU_DW/8-1:0]  dcache_cmd_we_msk,
   input                   fb_dbus_valid, /* Insn is presented at dbus */
   output                  fb_dbus_ready, /* dcache is ready to accepted Insn */
   input [`NCPU_IW-1:0]    fb_dbus_dout,
   output [`NCPU_DW-1:0]   fb_dbus_din,
   input                   fb_dbus_cmd_ready, /* dbus is ready to accept cmd */
   output                  fb_dbus_cmd_valid, /* cmd is presented at dbus's input */
   output [`NCPU_AW-1:0]   fb_dbus_cmd_addr,
   output [`NCPU_DW/8-1:0] fb_dbus_cmd_we_msk,
   // PSR
   input                   msr_psr_dcae
);

`ifdef NCPU_ENABLE_DCACHE
   // TODO
`else
   assign dcache_valid = fb_dbus_valid;
   assign fb_dbus_ready = dcache_ready;
   assign dcache_dout = fb_dbus_dout;
   assign fb_dbus_din = dcache_din;
   assign dcache_cmd_ready = fb_dbus_cmd_ready;
   assign fb_dbus_cmd_valid = dcache_cmd_valid;
   assign fb_dbus_cmd_addr = dcache_cmd_addr;
   assign fb_dbus_cmd_we_msk = dcache_cmd_we_msk;
`endif

endmodule
