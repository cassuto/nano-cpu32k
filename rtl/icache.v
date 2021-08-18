/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module icache
#(
   parameter CONFIG_AW = 0,
   parameter CONFIG_DW = 0,
   parameter CONFIG_ISSUE_WIDTH = 0,
   parameter CONFIG_P_PAGE_SIZE = 0,
   parameter CONFIG_IC_P_LINE = 0,
   parameter CONFIG_IC_P_SETS = 0,
   parameter CONFIG_IC_P_WAYS = 0
)
(
   input                                           clk,
   input                                           rst,
   input                                           req,
   input [CONFIG_P_PAGE_SIZE-1:0]                  vpo,
   input [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0]        ppn_s2,
   output [`NCPU_INSN_LEN-1:0]                     dout [CONFIG_ISSUE_WIDTH-1:0],
   output                                          stall_req
);

   localparam TAG_WIDTH = (CONFIG_AW-CONFIG_IC_P_SETS-CONFIG_IC_P_LINE);
   localparam TAG_RAM_WIDTH = (TAG_WIDTH + 1); // V + TAG
   
   // Stage #1
   wire [CONFIG_IC_P_SETS-1:0]                     s1i_line_addr;
   
   assign s1i_line_addr = vpo[CONFIG_IC_P_SETS-1:0];

   

   // synthesis translate_off
`ifndef SYNTHESIS
   initial
      begin
         if (CONFIG_P_PAGE_SIZE < CONFIG_IC_P_LINE + CONFIG_IC_P_SETS)
            $fatal(1, "Invalid size of icache (Must <= page size of I-MMU)");
         if ((1<<CONFIG_IBUS_BYTES_LOG2) != (CONFIG_IBUS_DW/8))
            $fatal(1, "Error value of CONFIG_IBUS_BYTES_LOG2");
         if ((1<<CONFIG_IC_DW_BYTES_LOG2) != (CONFIG_IC_DW/8))
            $fatal(1, "Error value of CONFIG_IC_DW_BYTES_LOG2");
         if (CONFIG_IC_DW_BYTES_LOG2 < CONFIG_IBUS_BYTES_LOG2)
            $fatal(1, "Invalid configuration of IBW or IBUS");
      end
`endif
   // synthesis translate_on

endmodule
