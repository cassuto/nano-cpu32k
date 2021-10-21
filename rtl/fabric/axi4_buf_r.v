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

module axi4_buf_r
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
   output                              s_ARREADY,
   input                               s_ARVALID,
   input [AXI_ADDR_WIDTH-1:0]          s_ARADDR,
   input [2:0]                         s_ARPROT,
   input [AXI_ID_WIDTH-1:0]            s_ARID,
   input [AXI_USER_WIDTH-1:0]          s_ARUSER,
   input [7:0]                         s_ARLEN,
   input [2:0]                         s_ARSIZE,
   input [1:0]                         s_ARBURST,
   input                               s_ARLOCK,
   input [3:0]                         s_ARCACHE,
   input [3:0]                         s_ARQOS,
   input [3:0]                         s_ARREGION,

   input                               s_RREADY,
   output                              s_RVALID,
   output  [(1<<AXI_P_DW_BYTES)*8-1:0] s_RDATA,
   output  [1:0]                       s_RRESP,
   output                              s_RLAST,
   output  [AXI_ID_WIDTH-1:0]          s_RID,
   output  [AXI_USER_WIDTH-1:0]        s_RUSER,


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
   input  [AXI_USER_WIDTH-1:0]         m_RUSER
);
   wire                                cke_ar;
   wire                                cke_r;
   
   hds_buf
      #(.BYPASS(0) )
   U_HDS_AR
      (
         .clk     (clk),
         .rst     (rst),
         .flush   (1'b0),
         .A_en    (1'b1),
         .AVALID  (s_ARVALID),
         .AREADY  (s_ARREADY),
         .B_en    (1'b1),
         .BVALID  (m_ARVALID),
         .BREADY  (m_ARREADY),
         .p_ce    (cke_ar)
      );
   
   // Pipeline stage for AR
   `mDFF_l #(.DW(AXI_ADDR_WIDTH)) dff_m_ARADDR (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARADDR), .Q(m_ARADDR) );
   `mDFF_l #(.DW(3)) dff_m_ARPROT (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARPROT), .Q(m_ARPROT) );
   `mDFF_l #(.DW(AXI_ID_WIDTH)) dff_m_ARID (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARID), .Q(m_ARID) );
   `mDFF_l #(.DW(AXI_USER_WIDTH)) dff_m_ARUSER (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARUSER), .Q(m_ARUSER) );
   `mDFF_l #(.DW(8)) dff_m_ARLEN (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARLEN), .Q(m_ARLEN) );
   `mDFF_l #(.DW(3)) dff_m_ARSIZE (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARSIZE), .Q(m_ARSIZE) );
   `mDFF_l #(.DW(2)) dff_m_ARBURST (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARBURST), .Q(m_ARBURST) );
   `mDFF_l #(.DW(1)) dff_m_ARLOCK (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARLOCK), .Q(m_ARLOCK) );
   `mDFF_l #(.DW(4)) dff_m_ARCACHE (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARCACHE), .Q(m_ARCACHE) );
   `mDFF_l #(.DW(4)) dff_m_ARQOS (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARQOS), .Q(m_ARQOS) );
   `mDFF_l #(.DW(4)) dff_m_ARREGION (.CLK(clk), `rst .LOAD(cke_ar), .D(s_ARREGION), .Q(m_ARREGION) );
   
   hds_buf
      #(.BYPASS(0) )
   U_HDS_R
      (
         .clk     (clk),
         .rst     (rst),
         .flush   (1'b0),
         .A_en    (1'b1),
         .AVALID  (m_RVALID),
         .AREADY  (m_RREADY),
         .B_en    (1'b1),
         .BVALID  (s_RVALID),
         .BREADY  (s_RREADY),
         .p_ce    (cke_r)
      );
      
   // Pipeline stage for R
   `mDFF_l #(.DW((1<<AXI_P_DW_BYTES)*8)) dff_s_RDATA (.CLK(clk), `rst .LOAD(cke_r), .D(m_RDATA), .Q(s_RDATA) );
   `mDFF_l #(.DW(2)) dff_s_RRESP (.CLK(clk), `rst .LOAD(cke_r), .D(m_RRESP), .Q(s_RRESP) );
   `mDFF_l #(.DW(1)) dff_s_RLAST (.CLK(clk), `rst .LOAD(cke_r), .D(m_RLAST), .Q(s_RLAST) );
   `mDFF_l #(.DW(AXI_ID_WIDTH)) dff_s_RID (.CLK(clk), `rst .LOAD(cke_r), .D(m_RID), .Q(s_RID) );
   `mDFF_l #(.DW(AXI_USER_WIDTH)) dff_s_RUSER (.CLK(clk), `rst .LOAD(cke_r), .D(m_RUSER), .Q(s_RUSER) );
   
endmodule
