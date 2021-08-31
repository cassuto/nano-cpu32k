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

module align_r
#(
   parameter                           AXI_P_DW_BYTES = 0,
   
)
(
   
);

   generate
      if (PAYLOAD_P_DW_BYTES <= AXI_P_DW_BYTES)
         begin
            assign s1i_payload_we = {PAYLOAD_DW/8{fsm_state_ff == S_REFILL}};
            assign s1i_payload_din = ibus_RDATA[(1<<PAYLOAD_P_DW_BYTES)*8-1:0];
         end
      else
         for(i=0;i<PAYLOAD_DW/8;i=i+1)
            begin : gen_aligner
               assign s1i_payload_we[i] = (fsm_state_ff == S_REFILL) &
                                          (fsm_refill_cnt[AXI_FETCH_SIZE +: PAYLOAD_P_DW_BYTES-AXI_FETCH_SIZE] == i[AXI_FETCH_SIZE +: PAYLOAD_P_DW_BYTES-AXI_FETCH_SIZE]);
               assign s1i_payload_din[i*8 +: 8] = ibus_RDATA[(i%(1<<AXI_FETCH_SIZE))*8 +: 8];
            end
   endgenerate

endmodule
