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
#(
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED
)
(
   input                   clk,
   input                   rst_n,
   output                  icache_AREADY,
   input                   icache_AVALID,
   input [`NCPU_AW-1:0]    icache_AADDR,
   input [1:0]             icache_AEXC,
   output                  icache_BVALID,
   input                   icache_BREADY,
   output [`NCPU_IW-1:0]   icache_BDATA,
   output [1:0]            icache_BEXC,
   input                   fb_ibus_AREADY,
   output                  fb_ibus_AVALID,
   output [`NCPU_AW-1:0]   fb_ibus_AADDR,
   output [1:0]            fb_ibus_AEXC,
   input                   fb_ibus_BVALID,
   output                  fb_ibus_BREADY,
   input [`NCPU_IW-1:0]    fb_ibus_BDATA,
   input [1:0]             fb_ibus_BEXC
);

   // TODO

endmodule
