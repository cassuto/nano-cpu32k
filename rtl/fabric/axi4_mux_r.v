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

module axi4_mux_r
#(
   parameter AXI_P_DW_BYTES  = 0,
   parameter AXI_ADDR_WIDTH = 0,
   parameter AXI_ID_WIDTH = 0,
   parameter AXI_USER_WIDTH = 0
)
(
   input [1:0]                         m_RGRNT,

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


   // Master interface
   input                               m_ARREADY,
   output reg                          m_ARVALID,
   output reg  [AXI_ADDR_WIDTH-1:0]    m_ARADDR,
   output reg  [2:0]                   m_ARPROT,
   output reg  [AXI_ID_WIDTH-1:0]      m_ARID,
   output reg  [AXI_USER_WIDTH-1:0]    m_ARUSER,
   output reg  [7:0]                   m_ARLEN,
   output reg  [2:0]                   m_ARSIZE,
   output reg  [1:0]                   m_ARBURST,
   output reg                          m_ARLOCK,
   output reg  [3:0]                   m_ARCACHE,
   output reg  [3:0]                   m_ARQOS,
   output reg  [3:0]                   m_ARREGION,

   output reg                          m_RREADY,
   input                               m_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  m_RDATA,
   input  [1:0]                        m_RRESP,
   input                               m_RLAST,
   input  [AXI_ID_WIDTH-1:0]           m_RID,
   input  [AXI_USER_WIDTH-1:0]         m_RUSER
);

   always @(*)
      case (m_RGRNT)
         2'b01:
            begin
               m_ARVALID = s0_ARVALID;
               m_ARADDR = s0_ARADDR;
               m_ARPROT = s0_ARPROT;
               m_ARID = s0_ARID;
               m_ARUSER = s0_ARUSER;
               m_ARLEN = s0_ARLEN;
               m_ARSIZE = s0_ARSIZE;
               m_ARBURST = s0_ARBURST;
               m_ARLOCK = s0_ARLOCK;
               m_ARCACHE = s0_ARCACHE;
               m_ARQOS = s0_ARQOS;
               m_ARREGION = s0_ARREGION;
               m_RREADY = s0_RREADY;
            end
         default:
            begin
               m_ARVALID = s1_ARVALID;
               m_ARADDR = s1_ARADDR;
               m_ARPROT = s1_ARPROT;
               m_ARID = s1_ARID;
               m_ARUSER = s1_ARUSER;
               m_ARLEN = s1_ARLEN;
               m_ARSIZE = s1_ARSIZE;
               m_ARBURST = s1_ARBURST;
               m_ARLOCK = s1_ARLOCK;
               m_ARCACHE = s1_ARCACHE;
               m_ARQOS = s1_ARQOS;
               m_ARREGION = s1_ARREGION;
               m_RREADY = s1_RREADY;
            end
      endcase

   assign s0_ARREADY = (m_RGRNT[0] & m_ARREADY);
   assign s0_RVALID = (m_RGRNT[0] & m_RVALID);
   assign s0_RDATA = m_RDATA;
   assign s0_RRESP = m_RRESP;
   assign s0_RLAST = m_RLAST;
   assign s0_RID = m_RID;
   assign s0_RUSER = m_RUSER;

   assign s1_ARREADY = (m_RGRNT[1] & m_ARREADY);
   assign s1_RVALID = (m_RGRNT[1] & m_RVALID);
   assign s1_RDATA = m_RDATA;
   assign s1_RRESP = m_RRESP;
   assign s1_RLAST = m_RLAST;
   assign s1_RID = m_RID;
   assign s1_RUSER = m_RUSER;

endmodule
