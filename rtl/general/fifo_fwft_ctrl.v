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

module fifo_fwft_ctrl
#(
   parameter DW = 8, // Data Width in bits
   parameter DEPTH_WIDTH = 4 // Width of depth
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input                               push,
   input [DW-1:0]                      din,
   output                              ready,
   input                               pop,
   output [DW-1:0]                     dout,
   output                              valid,
   output                              payload_re,
   output [DEPTH_WIDTH-1:0]            payload_raddr,
   input [DW-1:0]                      payload_rdata,
   output                              payload_we,
   output [DEPTH_WIDTH-1:0]            payload_waddr,
   output [DW-1:0]                     payload_wdata
);
   wire [DEPTH_WIDTH:0]                ff_w_ptr;
   wire [DEPTH_WIDTH:0]                w_ptr_nxt;
   wire [DEPTH_WIDTH:0]                ff_r_ptr;
   wire [DEPTH_WIDTH:0]                r_ptr_nxt;
   wire [DW-1:0]                       rf_dout, rf_dout_byp;
   wire                                state_r;
   wire                                fwft_nxt;
   wire                                clr_state;
   wire [DW-1:0]                       dat_r, din_r;
   wire                                rf_conflict;
   wire                                rf_bypass;

   assign w_ptr_nxt = (ff_w_ptr + 1'd1) & {DEPTH_WIDTH+1{~flush}};
   assign r_ptr_nxt = (ff_r_ptr + 1'd1) & {DEPTH_WIDTH+1{~flush}};

   mDFF_lr #(.DW(DEPTH_WIDTH + 1)) ff_w_ptr_r (.CLK(clk), .RST(rst), .LOAD(push|flush), .D(w_ptr_nxt), .Q(ff_w_ptr) );
   mDFF_lr #(.DW(DEPTH_WIDTH + 1)) ff_r_ptr_r (.CLK(clk), .RST(rst), .LOAD(pop|flush), .D(r_ptr_nxt), .Q(ff_r_ptr) );

   assign ready = (ff_w_ptr[DEPTH_WIDTH] == ff_r_ptr[DEPTH_WIDTH]) |
                  (ff_w_ptr[DEPTH_WIDTH-1:0] != ff_r_ptr[DEPTH_WIDTH-1:0]); // Not full
   assign valid = (ff_w_ptr != ff_r_ptr); // Not empty

   assign fwft_nxt = (~state_r & ~valid & push);
   assign clr_state = (state_r & pop);

   // FWFT FSM
   mDFF_lr #(.DW(DW)) ff_dat (.CLK(clk), .RST(rst), .LOAD(fwft_nxt), .D(din), .Q(dat_r) );
   mDFF_l #(.DW(DW)) ff_din (.CLK(clk), .LOAD(pop), .D(din), .Q(din_r) );
   mDFF_lr #(.DW(1)) ff_state (.CLK(clk),.RST(rst), .LOAD(fwft_nxt|clr_state|flush), .D((fwft_nxt|~clr_state) & ~flush), .Q(state_r) );

   assign dout = state_r ? dat_r : rf_dout_byp;
   
   assign payload_re = pop;
   assign payload_raddr = r_ptr_nxt[DEPTH_WIDTH-1:0];
   assign rf_dout = payload_rdata;
   assign payload_we = push;
   assign payload_waddr = ff_w_ptr[DEPTH_WIDTH-1:0];
   assign payload_wdata = din;
   
   assign rf_conflict = ((ff_w_ptr[DEPTH_WIDTH-1:0] == r_ptr_nxt[DEPTH_WIDTH-1:0]) & push & pop);

   // Bypass FSM
   mDFF_lr #(.DW(1)) ff_bypass (.CLK(clk), .RST(rst), .LOAD(rf_conflict | pop), .D(rf_conflict | ~pop), .Q(rf_bypass) );

   assign rf_dout_byp = rf_bypass ? din_r : rf_dout;

endmodule
