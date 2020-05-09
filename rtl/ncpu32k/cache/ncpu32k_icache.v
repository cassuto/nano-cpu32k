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

module ncpu32k_icache
(
   input                   clk,
   input                   rst_n,
   output                  icache_valid, /* Insn is presented at icache's output */
   input                   icache_ready, /* cpu is ready to accepted Insn */
   output [`NCPU_IW-1:0]   icache_dout,
   output                  icache_cmd_ready, /* icache is ready to accept cmd */
   input                   icache_cmd_valid, /* cmd is presented at icache's input */
   input [`NCPU_AW-1:0]    icache_cmd_addr,
   input                   fb_ibus_valid, /* Insn is presented at ibus */
   output                  fb_ibus_ready, /* icache is ready to accepted Insn */
   input [`NCPU_IW-1:0]    fb_ibus_dout,
   input                   fb_ibus_cmd_ready, /* ibus is ready to accept cmd */
   output                  fb_ibus_cmd_valid, /* cmd is presented at ibus's input */
   output [`NCPU_AW-1:0]   fb_ibus_cmd_addr,
   // PSR
   input                   msr_psr_icae
);

`ifdef NCPU_ENABLE_ICACHE
   // TODO
`else
   assign icache_valid = fb_ibus_valid;
   assign fb_ibus_ready = icache_ready;
   assign icache_dout = fb_ibus_dout;
   assign icache_cmd_ready = fb_ibus_cmd_ready;
   assign fb_ibus_cmd_valid = icache_cmd_valid;
   assign fb_ibus_cmd_addr = icache_cmd_addr;
`endif

endmodule
