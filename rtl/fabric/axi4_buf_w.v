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

module axi4_buf_w
#(
   parameter AXI_P_DW_BYTES  = 0,
   parameter AXI_ADDR_WIDTH = 0,
   parameter AXI_ID_WIDTH = 0,
   parameter AXI_USER_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   
   // Slave interface
   output                              s_AWREADY,
   input                               s_AWVALID,
   input [AXI_ADDR_WIDTH-1:0]          s_AWADDR,
   input [2:0]                         s_AWPROT,
   input [AXI_ID_WIDTH-1:0]            s_AWID,
   input [AXI_USER_WIDTH-1:0]          s_AWUSER,
   input [7:0]                         s_AWLEN,
   input [2:0]                         s_AWSIZE,
   input [1:0]                         s_AWBURST,
   input                               s_AWLOCK,
   input [3:0]                         s_AWCACHE,
   input [3:0]                         s_AWQOS,
   input [3:0]                         s_AWREGION,

   output                              s_WREADY,
   input                               s_WVALID,
   input [(1<<AXI_P_DW_BYTES)*8-1:0]   s_WDATA,
   input [(1<<AXI_P_DW_BYTES)-1:0]     s_WSTRB,
   input                               s_WLAST,
   input [AXI_USER_WIDTH-1:0]          s_WUSER,

   input                               s_BREADY,
   output                              s_BVALID,
   output [1:0]                        s_BRESP,
   output [AXI_ID_WIDTH-1:0]           s_BID,
   output [AXI_USER_WIDTH-1:0]         s_BUSER,

   // Master interface
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
   wire                                cke_aw;
   wire                                cke_w;
   wire                                cke_b;
   
   hds_buf
      #(.BYPASS(0) )
   U_HDS_AW
      (
         .clk     (clk),
         .rst     (rst),
         .flush   (1'b0),
         .A_en    (1'b1),
         .AVALID  (s_AWVALID),
         .AREADY  (s_AWREADY),
         .B_en    (1'b1),
         .BVALID  (m_AWVALID),
         .BREADY  (m_AWREADY),
         .p_ce    (cke_aw)
      );
   
   // Pipeline stage for AW
   `mDFF_l #(.DW(AXI_ADDR_WIDTH)) dff_m_AWADDR (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWADDR), .Q(m_AWADDR) );
   `mDFF_l #(.DW(3)) dff_m_AWPROT (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWPROT), .Q(m_AWPROT) );
   `mDFF_l #(.DW(AXI_ID_WIDTH)) dff_m_AWID (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWID), .Q(m_AWID) );
   `mDFF_l #(.DW(AXI_USER_WIDTH)) dff_m_AWUSER (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWUSER), .Q(m_AWUSER) );
   `mDFF_l #(.DW(8)) dff_m_AWLEN (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWLEN), .Q(m_AWLEN) );
   `mDFF_l #(.DW(3)) dff_m_AWSIZE (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWSIZE), .Q(m_AWSIZE) );
   `mDFF_l #(.DW(2)) dff_m_AWBURST (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWBURST), .Q(m_AWBURST) );
   `mDFF_l #(.DW(1)) dff_m_AWLOCK (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWLOCK), .Q(m_AWLOCK) );
   `mDFF_l #(.DW(4)) dff_m_AWCACHE (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWCACHE), .Q(m_AWCACHE) );
   `mDFF_l #(.DW(4)) dff_m_AWQOS (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWQOS), .Q(m_AWQOS) );
   `mDFF_l #(.DW(4)) dff_m_AWREGION (.CLK(clk), `rst .LOAD(cke_aw), .D(s_AWREGION), .Q(m_AWREGION) );
   
      
   hds_buf
      #(.BYPASS(0) )
   U_HDS_W
      (
         .clk     (clk),
         .rst     (rst),
         .flush   (1'b0),
         .A_en    (1'b1),
         .AVALID  (s_WVALID),
         .AREADY  (s_WREADY),
         .B_en    (1'b1),
         .BVALID  (m_WVALID),
         .BREADY  (m_WREADY),
         .p_ce    (cke_w)
      );
      
   // Pipeline stage for W
   `mDFF_l #(.DW((1<<AXI_P_DW_BYTES)*8)) dff_m_WDATA (.CLK(clk), `rst .LOAD(cke_w), .D(s_WDATA), .Q(m_WDATA) );
   `mDFF_l #(.DW((1<<AXI_P_DW_BYTES))) dff_m_WSTRB (.CLK(clk), `rst .LOAD(cke_w), .D(s_WSTRB), .Q(m_WSTRB) );
   `mDFF_l #(.DW(1)) dff_m_WLAST (.CLK(clk), `rst .LOAD(cke_w), .D(s_WLAST), .Q(m_WLAST) );
   `mDFF_l #(.DW(AXI_USER_WIDTH)) dff_m_WUSER (.CLK(clk), `rst .LOAD(cke_w), .D(s_WUSER), .Q(m_WUSER) );
   
   hds_buf
      #(.BYPASS(0) )
   U_HDS_B
      (
         .clk     (clk),
         .rst     (rst),
         .flush   (1'b0),
         .A_en    (1'b1),
         .AVALID  (m_BVALID),
         .AREADY  (m_BREADY),
         .B_en    (1'b1),
         .BVALID  (s_BVALID),
         .BREADY  (s_BREADY),
         .p_ce    (cke_b)
      );

   // Pipeline stage for B
   `mDFF_l #(.DW(2)) dff_s_BRESP (.CLK(clk), `rst .LOAD(cke_b), .D(m_BRESP), .Q(s_BRESP) );
   `mDFF_l #(.DW(AXI_ID_WIDTH)) dff_s_BID (.CLK(clk), `rst .LOAD(cke_b), .D(m_BID), .Q(s_BID) );
   `mDFF_l #(.DW(AXI_USER_WIDTH)) dff_s_BUSER (.CLK(clk), `rst .LOAD(cke_b), .D(m_BUSER), .Q(s_BUSER) );

endmodule
