
/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
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

module pb_fb_bootrom
#(
   parameter CONFIG_IBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_BOOTROM_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_BOOTROM_MEMH_FILE
   `PARAM_NOT_SPECIFIED
)
(
   input                         clk,
   input                         en,
   input [CONFIG_IBUS_AW-1:0]    addr,
   output [CONFIG_IBUS_DW-1:0]   dout
);
   localparam WORD_BYTES = CONFIG_IBUS_DW/8;
   localparam SIZE_WORDS = (1<<CONFIG_BOOTROM_AW)/WORD_BYTES;
   localparam ADDR_BITS = CONFIG_BOOTROM_AW-CONFIG_IBUS_BYTES_LOG2;

   wire [ADDR_BITS-1:0] mem_addr = addr[CONFIG_IBUS_BYTES_LOG2 +: ADDR_BITS];

`ifdef PLATFORM_XILINX_XC6
   ip_bootrom ROM
      (
         .clka    (clk),
         .addra   (mem_addr[ADDR_BITS-1:0]),
         .ena     (en),
         .douta   (dout[CONFIG_IBUS_DW-1:0])
      );
`else
   reg[CONFIG_IBUS_DW-1:0] ROM[0:SIZE_WORDS-1];

   initial
      begin : initial_blk
         integer i;
         for(i=0;i<SIZE_WORDS;i=i+1)
            begin : for_size_bytes
               ROM[i] = 'b0;
            end
            $readmemh (CONFIG_BOOTROM_MEMH_FILE, ROM);
      end

   reg [CONFIG_IBUS_DW-1:0] dout_r;
   always @(posedge clk)
      begin
         if(en)
            dout_r <= ROM[mem_addr];
      end
   assign dout = dout_r;
`endif

endmodule
