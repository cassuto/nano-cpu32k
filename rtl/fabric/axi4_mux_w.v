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

module axi4_mux_w
#(
   parameter AXI_P_DW_BYTES  = 0,
   parameter AXI_ADDR_WIDTH = 0,
   parameter AXI_ID_WIDTH = 0,
   parameter AXI_USER_WIDTH = 0
)
(
   input [1:0]                         m_WGRNT,

   // Slave interface 0
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
   input                               m_AWREADY,
   output reg                          m_AWVALID,
   output reg  [AXI_ADDR_WIDTH-1:0]    m_AWADDR,
   output reg  [2:0]                   m_AWPROT,
   output reg  [AXI_ID_WIDTH-1:0]      m_AWID,
   output reg  [AXI_USER_WIDTH-1:0]    m_AWUSER,
   output reg  [7:0]                   m_AWLEN,
   output reg  [2:0]                   m_AWSIZE,
   output reg  [1:0]                   m_AWBURST,
   output reg                          m_AWLOCK,
   output reg  [3:0]                   m_AWCACHE,
   output reg  [3:0]                   m_AWQOS,
   output reg  [3:0]                   m_AWREGION,

   input                               m_WREADY,
   output reg                          m_WVALID,
   output reg  [(1<<AXI_P_DW_BYTES)*8-1:0] m_WDATA,
   output reg  [(1<<AXI_P_DW_BYTES)-1:0]  m_WSTRB,
   output reg                          m_WLAST,
   output reg  [AXI_USER_WIDTH-1:0]    m_WUSER,

   output reg                          m_BREADY,
   input                               m_BVALID,
   input [1:0]                         m_BRESP,
   input [AXI_ID_WIDTH-1:0]            m_BID,
   input [AXI_USER_WIDTH-1:0]          m_BUSER
);

   always @(*)
      case (m_WGRNT)
         2'b01:
            begin
               m_AWVALID = s0_AWVALID;
               m_AWADDR = s0_AWADDR;
               m_AWPROT = s0_AWPROT;
               m_AWID = s0_AWID;
               m_AWUSER = s0_AWUSER;
               m_AWLEN = s0_AWLEN;
               m_AWSIZE = s0_AWSIZE;
               m_AWBURST = s0_AWBURST;
               m_AWLOCK = s0_AWLOCK;
               m_AWCACHE = s0_AWCACHE;
               m_AWQOS = s0_AWQOS;
               m_AWREGION = s0_AWREGION;
               m_WVALID = s0_WVALID;
               m_WDATA = s0_WDATA;
               m_WSTRB = s0_WSTRB;
               m_WLAST = s0_WLAST;
               m_WUSER = s0_WUSER;
               m_BREADY = s0_BREADY;
            end
         default:
            begin
               m_AWVALID = s1_AWVALID;
               m_AWADDR = s1_AWADDR;
               m_AWPROT = s1_AWPROT;
               m_AWID = s1_AWID;
               m_AWUSER = s1_AWUSER;
               m_AWLEN = s1_AWLEN;
               m_AWSIZE = s1_AWSIZE;
               m_AWBURST = s1_AWBURST;
               m_AWLOCK = s1_AWLOCK;
               m_AWCACHE = s1_AWCACHE;
               m_AWQOS = s1_AWQOS;
               m_AWREGION = s1_AWREGION;
               m_WVALID = s1_WVALID;
               m_WDATA = s1_WDATA;
               m_WSTRB = s1_WSTRB;
               m_WLAST = s1_WLAST;
               m_WUSER = s1_WUSER;
               m_BREADY = s1_BREADY;
            end
      endcase

   assign s0_AWREADY = (m_WGRNT[0] & m_AWREADY);
   assign s0_WREADY = (m_WGRNT[0] & m_WREADY);
   assign s0_BVALID = (m_WGRNT[0] & m_BVALID);
   assign s0_BRESP = m_BRESP;
   assign s0_BID = m_BID;
   assign s0_BUSER = m_BUSER;
   assign s1_AWREADY = (m_WGRNT[0] & m_AWREADY);
   assign s1_WREADY = (m_WGRNT[0] & m_WREADY);
   assign s1_BVALID = (m_WGRNT[0] & m_BVALID);
   assign s1_BRESP = m_BRESP;
   assign s1_BID = m_BID;
   assign s1_BUSER = m_BUSER;

endmodule
