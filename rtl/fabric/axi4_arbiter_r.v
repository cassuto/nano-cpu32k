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

module axi4_arbiter_r
(
   input                               clk,
   input                               rst,
   input                               s0_ARVALID,
   input                               s0_RREADY,
   input                               s1_ARVALID,
   input                               s1_RREADY,
   input                               m_RVALID,
   input                               m_RLAST,
   // Bus grant
   output [1:0]                        m_RGRNT
);

   localparam [1:0] S_S0               = 2'b01;
   localparam [1:0] S_S1               = 2'b10;

   wire [1:0]                          fsm_state_ff;
   reg [1:0]                           fsm_state_nxt;
   wire                                s0_sel;
   wire                                s1_sel;
   wire                                s0_pending, s0_pending_clr;
   wire                                s1_pending, s1_pending_clr;
   reg                                 s0_pending_set, s1_pending_set;

   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         s0_pending_set = 1'b0;
         s1_pending_set = 1'b0;
         case (fsm_state_ff)
            S_S0:
               begin
                  if (s0_ARVALID)
                     begin
                        fsm_state_nxt = S_S0;
                        s0_pending_set = 1'b1;
                     end
                  else if (s0_pending & ~s0_pending_clr)
                    fsm_state_nxt = S_S0; // Lock the bus for slave0
                  else if (s0_pending & s0_pending_clr)
                    fsm_state_nxt = S_S1;  // Round-robin
                  else if (s1_ARVALID)
                     begin
                        fsm_state_nxt = S_S1;
                        s1_pending_set = 1'b1;
                     end
                  else
                    fsm_state_nxt = S_S0;
               end

            S_S1:
               begin
                  if (s1_ARVALID)
                     begin
                        fsm_state_nxt = S_S1;
                        s1_pending_set = 1'b1;
                     end
                  else if (s1_pending & ~s1_pending_clr)
                    fsm_state_nxt = S_S1; // Lock the bus for slave1
                  else if (s1_pending & s1_pending_clr)
                    fsm_state_nxt = S_S0;  // Round-robin
                  else if (s0_ARVALID)
                     begin
                        fsm_state_nxt = S_S0;
                        s0_pending_set = 1'b1;
                     end
                  else
                    fsm_state_nxt = S_S1;
               end
            
            default:
               fsm_state_nxt = fsm_state_ff;
         endcase
      end

   mDFF_r #(.DW(2), .RST_VECTOR(S_S0)) ff_fsm_state (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff));
      
   assign s0_sel = (fsm_state_ff == S_S0);
   assign s1_sel = (fsm_state_ff == S_S1);

   assign s0_pending_clr = (s0_sel & m_RLAST & m_RVALID & s0_RREADY);
   assign s1_pending_clr = (s1_sel & m_RLAST & m_RVALID & s1_RREADY);

   mDFF_lr #(.DW(1)) s0_pending_ff (.CLK(clk), .RST(rst), .LOAD(s0_pending_set|s0_pending_clr), .D(s0_pending_set|~s0_pending_clr), .Q(s0_pending) );
   mDFF_lr #(.DW(1)) s1_pending_ff (.CLK(clk), .RST(rst), .LOAD(s1_pending_set|s1_pending_clr), .D(s1_pending_set|~s1_pending_clr), .Q(s1_pending) );

   assign m_RGRNT = {s1_sel, s0_sel};

endmodule
