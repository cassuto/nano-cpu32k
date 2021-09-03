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

module axi4_arbiter
#(
   parameter AXI_P_DW_BYTES  = 0,
   parameter AXI_ADDR_WIDTH = 0,
   parameter AXI_ID_WIDTH = 0,
   parameter AXI_USER_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   // Slave interface 0
   output                              s0_ARREADY,
   input                               s0_ARVALID,
   input [AXI_ADDR_WIDTH-1:0]          s0_ARADDR,
   input [2:0]                         s0_ARPROT,
   input [AXI_ID_WIDTH-1:0]            s0_ARID,
   input [AXI_USER_WIDTH-1:0]          s0_ARUSER,
   input [7:0]                         s0_ARLEN,
   input [2:0]                         s0_ARSIZE,
   input [1:0]                         s0_ARBURST,
   input                               s0_ARLOCK,
   input [3:0]                         s0_ARCACHE,
   input [3:0]                         s0_ARQOS,
   input [3:0]                         s0_ARREGION,

   input                               s0_RREADY,
   output                              s0_RVALID,
   output  [(1<<AXI_P_DW_BYTES)*8-1:0] s0_RDATA,
   output  [1:0]                       s0_RRESP,
   output                              s0_RLAST,
   output  [AXI_ID_WIDTH-1:0]          s0_RID,
   output  [AXI_USER_WIDTH-1:0]        s0_RUSER,

   output                              s0_AWREADY,
   input                               s0_AWVALID,
   input [AXI_ADDR_WIDTH-1:0]          s0_AWADDR,
   input [2:0]                         s0_AWPROT,
   input [AXI_ID_WIDTH-1:0]            s0_AWID,
   input [AXI_USER_WIDTH-1:0]          s0_AWUSER,
   input [7:0]                         s0_AWLEN,
   input [2:0]                         s0_AWSIZE,
   input [1:0]                         s0_AWBURST,
   input                               s0_AWLOCK,
   input [3:0]                         s0_AWCACHE,
   input [3:0]                         s0_AWQOS,
   input [3:0]                         s0_AWREGION,

   output                              s0_WREADY,
   input                               s0_WVALID,
   input [(1<<AXI_P_DW_BYTES)*8-1:0]   s0_WDATA,
   input [(1<<AXI_P_DW_BYTES)-1:0]     s0_WSTRB,
   input                               s0_WLAST,
   input [AXI_USER_WIDTH-1:0]          s0_WUSER,

   input                               s0_BREADY,
   output                              s0_BVALID,
   output [1:0]                        s0_BRESP,
   output [AXI_ID_WIDTH-1:0]           s0_BID,
   output [AXI_USER_WIDTH-1:0]         s0_BUSER,

   // Slave interface 1
   output                              s1_ARREADY,
   input                               s1_ARVALID,
   input [AXI_ADDR_WIDTH-1:0]          s1_ARADDR,
   input [2:0]                         s1_ARPROT,
   input [AXI_ID_WIDTH-1:0]            s1_ARID,
   input [AXI_USER_WIDTH-1:0]          s1_ARUSER,
   input [7:0]                         s1_ARLEN,
   input [2:0]                         s1_ARSIZE,
   input [1:0]                         s1_ARBURST,
   input                               s1_ARLOCK,
   input [3:0]                         s1_ARCACHE,
   input [3:0]                         s1_ARQOS,
   input [3:0]                         s1_ARREGION,

   input                               s1_RREADY,
   output                              s1_RVALID,
   output  [(1<<AXI_P_DW_BYTES)*8-1:0] s1_RDATA,
   output  [1:0]                       s1_RRESP,
   output                              s1_RLAST,
   output  [AXI_ID_WIDTH-1:0]          s1_RID,
   output  [AXI_USER_WIDTH-1:0]        s1_RUSER,

   output                              s1_AWREADY,
   input                               s1_AWVALID,
   input [AXI_ADDR_WIDTH-1:0]          s1_AWADDR,
   input [2:0]                         s1_AWPROT,
   input [AXI_ID_WIDTH-1:0]            s1_AWID,
   input [AXI_USER_WIDTH-1:0]          s1_AWUSER,
   input [7:0]                         s1_AWLEN,
   input [2:0]                         s1_AWSIZE,
   input [1:0]                         s1_AWBURST,
   input                               s1_AWLOCK,
   input [3:0]                         s1_AWCACHE,
   input [3:0]                         s1_AWQOS,
   input [3:0]                         s1_AWREGION,

   output                              s1_WREADY,
   input                               s1_WVALID,
   input [(1<<AXI_P_DW_BYTES)*8-1:0]   s1_WDATA,
   input [(1<<AXI_P_DW_BYTES)-1:0]     s1_WSTRB,
   input                               s1_WLAST,
   input [AXI_USER_WIDTH-1:0]          s1_WUSER,

   input                               s1_BREADY,
   output                              s1_BVALID,
   output [1:0]                        s1_BRESP,
   output [AXI_ID_WIDTH-1:0]           s1_BID,
   output [AXI_USER_WIDTH-1:0]         s1_BUSER,

   // Master interface
   input                               m_ARREADY,
   output                              m_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         m_ARADDR,
   output [2:0]                        m_ARPROT,
   output [AXI_ID_WIDTH-1:0]           m_ARID,
   output [AXI_USER_WIDTH-1:0]         m_ARUSER,
   output [7:0]                        m_ARLEN,
   output [2:0]                        m_ARSIZE,
   output [1:0]                        m_ARBURST,
   output                              m_ARLOCK,
   output [3:0]                        m_ARCACHE,
   output [3:0]                        m_ARQOS,
   output [3:0]                        m_ARREGION,

   output                              m_RREADY,
   input                               m_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  m_RDATA,
   input  [1:0]                        m_RRESP,
   input                               m_RLAST,
   input  [AXI_ID_WIDTH-1:0]           m_RID,
   input  [AXI_USER_WIDTH-1:0]         m_RUSER,

   input                               m_AWREADY,
   output                              m_AWVALID,
   output [AXI_ADDR_WIDTH-1:0]         m_AWADDR,
   output [2:0]                        m_AWPROT,
   output [AXI_ID_WIDTH-1:0]           m_AWID,
   output [AXI_USER_WIDTH-1:0]         m_AWUSER,
   output [7:0]                        m_AWLEN,
   output [2:0]                        m_AWSIZE,
   output [1:0]                        m_AWBURST,
   output                              m_AWLOCK,
   output [3:0]                        m_AWCACHE,
   output [3:0]                        m_AWQOS,
   output [3:0]                        m_AWREGION,

   input                               m_WREADY,
   output                              m_WVALID,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  m_WDATA,
   output [(1<<AXI_P_DW_BYTES)-1:0]    m_WSTRB,
   output                              m_WLAST,
   output [AXI_USER_WIDTH-1:0]         m_WUSER,

   output                              m_BREADY,
   input                               m_BVALID,
   input [1:0]                         m_BRESP,
   input [AXI_ID_WIDTH-1:0]            m_BID,
   input [AXI_USER_WIDTH-1:0]          m_BUSER
);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [1:0]           m_RGRNT;                // From U_ARBITER_R of axi4_arbiter_r.v
   wire [1:0]           m_WGRNT;                // From U_ARBITER_W of axi4_arbiter_w.v
   // End of automatics

   axi4_arbiter_r U_ARBITER_R
      (/*AUTOINST*/
       // Outputs
       .m_RGRNT                         (m_RGRNT[1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .s0_ARVALID                      (s0_ARVALID),
       .s0_RREADY                       (s0_RREADY),
       .s1_ARVALID                      (s1_ARVALID),
       .s1_RREADY                       (s1_RREADY),
       .m_RVALID                        (m_RVALID),
       .m_RLAST                         (m_RLAST));

   axi4_arbiter_w U_ARBITER_W
      (/*AUTOINST*/
       // Outputs
       .m_WGRNT                         (m_WGRNT[1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .s0_AWVALID                      (s0_AWVALID),
       .s0_BREADY                       (s0_BREADY),
       .s1_AWVALID                      (s1_AWVALID),
       .s1_BREADY                       (s1_BREADY),
       .m_BVALID                        (m_BVALID));

   axi4_mux_r
      #(/*AUTOINSTPARAM*/
        // Parameters
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_MUX_R
      (/*AUTOINST*/
       // Outputs
       .s0_ARREADY                      (s0_ARREADY),
       .s0_RVALID                       (s0_RVALID),
       .s0_RDATA                        (s0_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .s0_RRESP                        (s0_RRESP[1:0]),
       .s0_RLAST                        (s0_RLAST),
       .s0_RID                          (s0_RID[AXI_ID_WIDTH-1:0]),
       .s0_RUSER                        (s0_RUSER[AXI_USER_WIDTH-1:0]),
       .s1_ARREADY                      (s1_ARREADY),
       .s1_RVALID                       (s1_RVALID),
       .s1_RDATA                        (s1_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .s1_RRESP                        (s1_RRESP[1:0]),
       .s1_RLAST                        (s1_RLAST),
       .s1_RID                          (s1_RID[AXI_ID_WIDTH-1:0]),
       .s1_RUSER                        (s1_RUSER[AXI_USER_WIDTH-1:0]),
       .m_ARVALID                       (m_ARVALID),
       .m_ARADDR                        (m_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .m_ARPROT                        (m_ARPROT[2:0]),
       .m_ARID                          (m_ARID[AXI_ID_WIDTH-1:0]),
       .m_ARUSER                        (m_ARUSER[AXI_USER_WIDTH-1:0]),
       .m_ARLEN                         (m_ARLEN[7:0]),
       .m_ARSIZE                        (m_ARSIZE[2:0]),
       .m_ARBURST                       (m_ARBURST[1:0]),
       .m_ARLOCK                        (m_ARLOCK),
       .m_ARCACHE                       (m_ARCACHE[3:0]),
       .m_ARQOS                         (m_ARQOS[3:0]),
       .m_ARREGION                      (m_ARREGION[3:0]),
       .m_RREADY                        (m_RREADY),
       // Inputs
       .m_RGRNT                         (m_RGRNT[1:0]),
       .s0_ARVALID                      (s0_ARVALID),
       .s0_ARADDR                       (s0_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .s0_ARPROT                       (s0_ARPROT[2:0]),
       .s0_ARID                         (s0_ARID[AXI_ID_WIDTH-1:0]),
       .s0_ARUSER                       (s0_ARUSER[AXI_USER_WIDTH-1:0]),
       .s0_ARLEN                        (s0_ARLEN[7:0]),
       .s0_ARSIZE                       (s0_ARSIZE[2:0]),
       .s0_ARBURST                      (s0_ARBURST[1:0]),
       .s0_ARLOCK                       (s0_ARLOCK),
       .s0_ARCACHE                      (s0_ARCACHE[3:0]),
       .s0_ARQOS                        (s0_ARQOS[3:0]),
       .s0_ARREGION                     (s0_ARREGION[3:0]),
       .s0_RREADY                       (s0_RREADY),
       .s1_ARVALID                      (s1_ARVALID),
       .s1_ARADDR                       (s1_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .s1_ARPROT                       (s1_ARPROT[2:0]),
       .s1_ARID                         (s1_ARID[AXI_ID_WIDTH-1:0]),
       .s1_ARUSER                       (s1_ARUSER[AXI_USER_WIDTH-1:0]),
       .s1_ARLEN                        (s1_ARLEN[7:0]),
       .s1_ARSIZE                       (s1_ARSIZE[2:0]),
       .s1_ARBURST                      (s1_ARBURST[1:0]),
       .s1_ARLOCK                       (s1_ARLOCK),
       .s1_ARCACHE                      (s1_ARCACHE[3:0]),
       .s1_ARQOS                        (s1_ARQOS[3:0]),
       .s1_ARREGION                     (s1_ARREGION[3:0]),
       .s1_RREADY                       (s1_RREADY),
       .m_ARREADY                       (m_ARREADY),
       .m_RVALID                        (m_RVALID),
       .m_RDATA                         (m_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .m_RRESP                         (m_RRESP[1:0]),
       .m_RLAST                         (m_RLAST),
       .m_RID                           (m_RID[AXI_ID_WIDTH-1:0]),
       .m_RUSER                         (m_RUSER[AXI_USER_WIDTH-1:0]));

   axi4_mux_w
      #(/*AUTOINSTPARAM*/
        // Parameters
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_MUX_W
      (/*AUTOINST*/
       // Outputs
       .s0_AWREADY                      (s0_AWREADY),
       .s0_WREADY                       (s0_WREADY),
       .s0_BVALID                       (s0_BVALID),
       .s0_BRESP                        (s0_BRESP[1:0]),
       .s0_BID                          (s0_BID[AXI_ID_WIDTH-1:0]),
       .s0_BUSER                        (s0_BUSER[AXI_USER_WIDTH-1:0]),
       .s1_AWREADY                      (s1_AWREADY),
       .s1_WREADY                       (s1_WREADY),
       .s1_BVALID                       (s1_BVALID),
       .s1_BRESP                        (s1_BRESP[1:0]),
       .s1_BID                          (s1_BID[AXI_ID_WIDTH-1:0]),
       .s1_BUSER                        (s1_BUSER[AXI_USER_WIDTH-1:0]),
       .m_AWVALID                       (m_AWVALID),
       .m_AWADDR                        (m_AWADDR[AXI_ADDR_WIDTH-1:0]),
       .m_AWPROT                        (m_AWPROT[2:0]),
       .m_AWID                          (m_AWID[AXI_ID_WIDTH-1:0]),
       .m_AWUSER                        (m_AWUSER[AXI_USER_WIDTH-1:0]),
       .m_AWLEN                         (m_AWLEN[7:0]),
       .m_AWSIZE                        (m_AWSIZE[2:0]),
       .m_AWBURST                       (m_AWBURST[1:0]),
       .m_AWLOCK                        (m_AWLOCK),
       .m_AWCACHE                       (m_AWCACHE[3:0]),
       .m_AWQOS                         (m_AWQOS[3:0]),
       .m_AWREGION                      (m_AWREGION[3:0]),
       .m_WVALID                        (m_WVALID),
       .m_WDATA                         (m_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .m_WSTRB                         (m_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
       .m_WLAST                         (m_WLAST),
       .m_WUSER                         (m_WUSER[AXI_USER_WIDTH-1:0]),
       .m_BREADY                        (m_BREADY),
       // Inputs
       .m_WGRNT                         (m_WGRNT[1:0]),
       .s0_AWVALID                      (s0_AWVALID),
       .s0_AWADDR                       (s0_AWADDR[AXI_ADDR_WIDTH-1:0]),
       .s0_AWPROT                       (s0_AWPROT[2:0]),
       .s0_AWID                         (s0_AWID[AXI_ID_WIDTH-1:0]),
       .s0_AWUSER                       (s0_AWUSER[AXI_USER_WIDTH-1:0]),
       .s0_AWLEN                        (s0_AWLEN[7:0]),
       .s0_AWSIZE                       (s0_AWSIZE[2:0]),
       .s0_AWBURST                      (s0_AWBURST[1:0]),
       .s0_AWLOCK                       (s0_AWLOCK),
       .s0_AWCACHE                      (s0_AWCACHE[3:0]),
       .s0_AWQOS                        (s0_AWQOS[3:0]),
       .s0_AWREGION                     (s0_AWREGION[3:0]),
       .s0_WVALID                       (s0_WVALID),
       .s0_WDATA                        (s0_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .s0_WSTRB                        (s0_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
       .s0_WLAST                        (s0_WLAST),
       .s0_WUSER                        (s0_WUSER[AXI_USER_WIDTH-1:0]),
       .s0_BREADY                       (s0_BREADY),
       .s1_AWVALID                      (s1_AWVALID),
       .s1_AWADDR                       (s1_AWADDR[AXI_ADDR_WIDTH-1:0]),
       .s1_AWPROT                       (s1_AWPROT[2:0]),
       .s1_AWID                         (s1_AWID[AXI_ID_WIDTH-1:0]),
       .s1_AWUSER                       (s1_AWUSER[AXI_USER_WIDTH-1:0]),
       .s1_AWLEN                        (s1_AWLEN[7:0]),
       .s1_AWSIZE                       (s1_AWSIZE[2:0]),
       .s1_AWBURST                      (s1_AWBURST[1:0]),
       .s1_AWLOCK                       (s1_AWLOCK),
       .s1_AWCACHE                      (s1_AWCACHE[3:0]),
       .s1_AWQOS                        (s1_AWQOS[3:0]),
       .s1_AWREGION                     (s1_AWREGION[3:0]),
       .s1_WVALID                       (s1_WVALID),
       .s1_WDATA                        (s1_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .s1_WSTRB                        (s1_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
       .s1_WLAST                        (s1_WLAST),
       .s1_WUSER                        (s1_WUSER[AXI_USER_WIDTH-1:0]),
       .s1_BREADY                       (s1_BREADY),
       .m_AWREADY                       (m_AWREADY),
       .m_WREADY                        (m_WREADY),
       .m_BVALID                        (m_BVALID),
       .m_BRESP                         (m_BRESP[1:0]),
       .m_BID                           (m_BID[AXI_ID_WIDTH-1:0]),
       .m_BUSER                         (m_BUSER[AXI_USER_WIDTH-1:0]));

endmodule
