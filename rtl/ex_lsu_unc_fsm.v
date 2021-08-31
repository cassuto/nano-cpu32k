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

module ex_lsu_unc_fsm
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_DW = 0,
   parameter                           AXI_P_DW_BYTES    = 0,
   parameter                           AXI_ADDR_WIDTH    = 0,
   parameter                           AXI_ID_WIDTH      = 0,
   parameter                           AXI_USER_WIDTH    = 0
)
(
   input                               clk,
   input                               rst,
   input                               stall,
   input                               boot,
   input                               store,
   input [CONFIG_AW-1:0]               paddr,
   input [2:0]                         size,
   input [CONFIG_DW-1:0]               wdat,
   input [CONFIG_DW/8-1:0]             wmsk,
   output                              stall_req,
   output                              valid,
   output [CONFIG_DW-1:0]              dout,
   // AXI Master (Uncached access)
   input                               uncached_ARREADY,
   output                              uncached_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         uncached_ARADDR,
   output [2:0]                        uncached_ARPROT,
   output [AXI_ID_WIDTH-1:0]           uncached_ARID,
   output [AXI_USER_WIDTH-1:0]         uncached_ARUSER,
   output [7:0]                        uncached_ARLEN,
   output [2:0]                        uncached_ARSIZE,
   output [1:0]                        uncached_ARBURST,
   output                              uncached_ARLOCK,
   output [3:0]                        uncached_ARCACHE,
   output [3:0]                        uncached_ARQOS,
   output [3:0]                        uncached_ARREGION,

   output                              uncached_RREADY,
   input                               uncached_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  uncached_RDATA,
   input  [1:0]                        uncached_RRESP,
   input                               uncached_RLAST,
   input  [AXI_ID_WIDTH-1:0]           uncached_RID,
   input  [AXI_USER_WIDTH-1:0]         uncached_RUSER,

   input                               uncached_AWREADY,
   output                              uncached_AWVALID,
   output [AXI_ADDR_WIDTH-1:0]         uncached_AWADDR,
   output [2:0]                        uncached_AWPROT,
   output [AXI_ID_WIDTH-1:0]           uncached_AWID,
   output [AXI_USER_WIDTH-1:0]         uncached_AWUSER,
   output [7:0]                        uncached_AWLEN,
   output [2:0]                        uncached_AWSIZE,
   output [1:0]                        uncached_AWBURST,
   output                              uncached_AWLOCK,
   output [3:0]                        uncached_AWCACHE,
   output [3:0]                        uncached_AWQOS,
   output [3:0]                        uncached_AWREGION,

   input                               uncached_WREADY,
   output                              uncached_WVALID,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  uncached_WDATA,
   output [(1<<AXI_P_DW_BYTES)-1:0]    uncached_WSTRB,
   output                              uncached_WLAST,
   output [AXI_USER_WIDTH-1:0]         uncached_WUSER,

   output                              uncached_BREADY,
   input                               uncached_BVALID,
   input [1:0]                         uncached_BRESP,
   input [AXI_ID_WIDTH-1:0]            uncached_BID,
   input [AXI_USER_WIDTH-1:0]          uncached_BUSER
);
   localparam CONFIG_P_DW_BYTES        = (CONFIG_P_DW-3);
   /*AUTOWIRE*/
   // FSM of uncached access
   wire [1:0]                          fsm_state_ff;
   reg [1:0]                           fsm_state_nxt;
   reg                                 ar_set, aw_set;
   wire                                ar_clr, aw_clr;
   wire                                w_set, w_clr;
   wire [AXI_ADDR_WIDTH-1:0]           axi_arw_addr_nxt;
   wire [2:0]                          axi_arw_size_ff;
   wire [(1<<AXI_P_DW_BYTES)-1:0]      axi_uncached_WSTRB_nxt;
   wire [(1<<AXI_P_DW_BYTES)*8-1:0]    axi_uncached_WDATA_nxt;
   wire [CONFIG_DW-1:0]                axi_uncached_din;
   wire                                hds_axi_R;
   wire                                hds_axi_B;

   localparam [1:0] S_UNCACHED_IDLE = 2'd0;
   localparam [1:0] S_UNCACHED_WAIT_B = 2'd1;
   localparam [1:0] S_UNCACHED_WAIT_R = 2'd2;
   localparam [1:0] S_UNCACHED_OUT = 2'd3;

   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         ar_set = 'b0;
         aw_set = 'b0;
         case (fsm_state_ff)
            S_UNCACHED_IDLE:
               if (boot)
                  begin
                     fsm_state_nxt = (store) ? S_UNCACHED_WAIT_B : S_UNCACHED_WAIT_R;
                     ar_set = ~store;
                     aw_set = store;
                  end

            // W
            S_UNCACHED_WAIT_B:
               if (hds_axi_B)
                  fsm_state_nxt = S_UNCACHED_OUT;

            // R
            S_UNCACHED_WAIT_R:
               if (hds_axi_R)
                  fsm_state_nxt = S_UNCACHED_OUT;

            S_UNCACHED_OUT:
               if (~stall)
                  fsm_state_nxt = S_UNCACHED_IDLE;

            default: ;
            endcase
      end

   mDFF_r #(.DW(2), .RST_VECTOR(S_UNCACHED_IDLE)) ff_uncached_state_ff (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff) );


   // Address width adapter (truncate or fill zero)
   generate
      if (AXI_ADDR_WIDTH > CONFIG_AW)
         assign axi_arw_addr_nxt = {{AXI_ADDR_WIDTH-CONFIG_AW{1'b0}}, paddr};
      else if (AXI_ADDR_WIDTH < CONFIG_AW)
         assign axi_arw_addr_nxt = paddr[AXI_ADDR_WIDTH-1:0];
      else
         assign axi_arw_addr_nxt = paddr;
   endgenerate
   
   // AR
   assign uncached_ARID = 'b0;
   assign uncached_ARLEN = 'd0;
   assign uncached_ARBURST = `AXI_BURST_TYPE_INCR;
   assign uncached_ARLOCK = 'b0;
   assign uncached_ARCACHE = `AXI_AWCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign uncached_ARPROT = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign uncached_ARQOS = 'b0;
   assign uncached_ARREGION = 'b0;
   assign uncached_ARUSER = 'b0;
   assign ar_clr = (uncached_ARVALID & uncached_ARREADY);
   mDFF_lr # (.DW(1)) ff_uncached_ARVALID (.CLK(clk), .RST(rst), .LOAD(ar_set|ar_clr), .D(ar_set|~ar_clr), .Q(uncached_ARVALID) );
   mDFF_l # (.DW(AXI_ADDR_WIDTH)) ff_uncached_ARADDR (.CLK(clk), .LOAD(ar_set), .D(axi_arw_addr_nxt), .Q(uncached_ARADDR) );
   mDFF_l #(.DW(3)) ff_uncached_ARSIZE (.CLK(clk), .LOAD(ar_set), .D(size), .Q(uncached_ARSIZE) );

   // AW
   assign uncached_AWID = 'b0;
   assign uncached_AWLEN = 'd0;
   assign uncached_AWBURST = `AXI_BURST_TYPE_INCR;
   assign uncached_AWLOCK ='b0;
   assign uncached_AWCACHE = `AXI_AWCACHE_NORMAL_NON_CACHEABLE_NON_BUFFERABLE;
   assign uncached_AWPROT = `AXI_PROT_UNPRIVILEGED_ACCESS | `AXI_PROT_SECURE_ACCESS | `AXI_PROT_DATA_ACCESS;
   assign uncached_AWQOS = 'b0;
   assign uncached_AWREGION = 'b0;
   assign aw_clr = (uncached_AWVALID & uncached_AWREADY);
   mDFF_lr # (.DW(1)) ff_uncached_AWVALID (.CLK(clk), .RST(rst), .LOAD(aw_set|aw_clr), .D(aw_set|~aw_clr), .Q(uncached_AWVALID) );
   mDFF_l # (.DW(AXI_ADDR_WIDTH)) ff_uncached_AWADDR (.CLK(clk), .LOAD(aw_set), .D(axi_arw_addr_nxt), .Q(uncached_AWADDR) );
   mDFF_l #(.DW(3)) ff_uncached_AWSIZE (.CLK(clk), .LOAD(aw_set), .D(size), .Q(uncached_AWSIZE) );

   // R
   assign uncached_RREADY = (fsm_state_ff == S_UNCACHED_WAIT_R);
   assign hds_axi_R = (uncached_RREADY & uncached_RVALID);
   mDFF_l #(.DW(CONFIG_DW)) ff_uncached_dout (.CLK(clk), .LOAD(hds_axi_R), .D(axi_uncached_din), .Q(dout) );

   // Aligner for AXI R
   generate
      if (CONFIG_P_DW_BYTES <= AXI_P_DW_BYTES)
         begin
            assign axi_uncached_din = uncached_RDATA[CONFIG_DW-1:0];
         end
      else
         initial $fatal(1, "Unsupported bitwidth");
   endgenerate
   
   // W
   assign uncached_WUSER = 'b0;
   assign uncached_WLAST = 'b1;
   assign uncached_AWUSER = 'b0;
   assign w_set = (aw_set);
   assign w_clr = (uncached_WVALID & uncached_WREADY);
   mDFF_lr # (.DW(1)) ff_uncached_WVALID (.CLK(clk), .RST(rst), .LOAD(w_set|w_clr), .D(w_set|~w_clr), .Q(uncached_WVALID) );
   mDFF_l #(.DW(1<<AXI_P_DW_BYTES)) ff_axi_wstrb_ff (.CLK(clk), .LOAD(w_set), .D(axi_uncached_WSTRB_nxt), .Q(uncached_WSTRB) );
   mDFF_l #(.DW((1<<AXI_P_DW_BYTES)*8)) ff_uncached_WDATA (.CLK(clk), .LOAD(w_set), .D(axi_uncached_WDATA_nxt), .Q(uncached_WDATA) );

   // Aligner for AXI W
   generate
      if (CONFIG_P_DW_BYTES <= AXI_P_DW_BYTES)
         begin
            assign axi_uncached_WSTRB_nxt = {{(1<<AXI_P_DW_BYTES)-CONFIG_DW/8{1'b0}}, wmsk}; // FIXME?
            assign axi_uncached_WDATA_nxt = {{(1<<AXI_P_DW_BYTES)-(1<<CONFIG_P_DW_BYTES){8'b0}}, wdat}; // FIXME?
         end
      else
         initial $fatal(1, "Unsupported bitwidth");
   endgenerate
   
   // B
   assign uncached_BREADY = (fsm_state_ff == S_UNCACHED_WAIT_B);
   assign hds_axi_B = (uncached_BREADY & uncached_BVALID);

   assign stall_req = (fsm_state_ff != S_UNCACHED_OUT) &
                        ((fsm_state_ff != S_UNCACHED_IDLE) | boot);

   assign valid = (fsm_state_ff==S_UNCACHED_OUT);

endmodule
