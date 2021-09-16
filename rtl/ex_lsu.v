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

module ex_lsu
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_DW = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_DMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_DTLB_P_SETS = 0,
   parameter                           CONFIG_DC_P_LINE = 0,
   parameter                           CONFIG_DC_P_SETS = 0,
   parameter                           CONFIG_DC_P_WAYS = 0,
   parameter                           AXI_P_DW_BYTES    = 0,
   parameter                           AXI_ADDR_WIDTH    = 0,
   parameter                           AXI_ID_WIDTH      = 0,
   parameter                           AXI_USER_WIDTH    = 0
)
(
   input                               clk,
   input                               rst,
   input                               stall,
   input                               flush_s1,
   output                              lsu_stall_req,
   input                               ex_valid,
   input [`NCPU_LSU_IOPW-1:0]          ex_lsu_opc_bus,
   output                              agu_en,
   input [CONFIG_DW-1:0]               add_sum,
   input [CONFIG_DW-1:0]               ex_operand2,
   // AXI Master (Cached access)
   input                               dbus_ARREADY,
   output                              dbus_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_ARADDR,
   output [2:0]                        dbus_ARPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_ARID,
   output [AXI_USER_WIDTH-1:0]         dbus_ARUSER,
   output [7:0]                        dbus_ARLEN,
   output [2:0]                        dbus_ARSIZE,
   output [1:0]                        dbus_ARBURST,
   output                              dbus_ARLOCK,
   output [3:0]                        dbus_ARCACHE,
   output [3:0]                        dbus_ARQOS,
   output [3:0]                        dbus_ARREGION,

   output                              dbus_RREADY,
   input                               dbus_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_RDATA,
   input  [1:0]                        dbus_RRESP,
   input                               dbus_RLAST,
   input  [AXI_ID_WIDTH-1:0]           dbus_RID,
   input  [AXI_USER_WIDTH-1:0]         dbus_RUSER,

   input                               dbus_AWREADY,
   output                              dbus_AWVALID,
   output [AXI_ADDR_WIDTH-1:0]         dbus_AWADDR,
   output [2:0]                        dbus_AWPROT,
   output [AXI_ID_WIDTH-1:0]           dbus_AWID,
   output [AXI_USER_WIDTH-1:0]         dbus_AWUSER,
   output [7:0]                        dbus_AWLEN,
   output [2:0]                        dbus_AWSIZE,
   output [1:0]                        dbus_AWBURST,
   output                              dbus_AWLOCK,
   output [3:0]                        dbus_AWCACHE,
   output [3:0]                        dbus_AWQOS,
   output [3:0]                        dbus_AWREGION,

   input                               dbus_WREADY,
   output                              dbus_WVALID,
   output [(1<<AXI_P_DW_BYTES)*8-1:0]  dbus_WDATA,
   output [(1<<AXI_P_DW_BYTES)-1:0]    dbus_WSTRB,
   output                              dbus_WLAST,
   output [AXI_USER_WIDTH-1:0]         dbus_WUSER,

   output                              dbus_BREADY,
   input                               dbus_BVALID,
   input [1:0]                         dbus_BRESP,
   input [AXI_ID_WIDTH-1:0]            dbus_BID,
   input [AXI_USER_WIDTH-1:0]          dbus_BUSER,
   
   // To WB
   output                              lsu_EDTM,
   output                              lsu_EDPF,
   output                              lsu_EALIGN,
   output [CONFIG_AW-1:0]              lsu_vaddr,
   output [CONFIG_DW-1:0]              lsu_dout,
   // PSR
   input                               msr_psr_dmme,
   input                               msr_psr_rm,
   input                               msr_psr_dce,
   // DMMID
   output [CONFIG_DW-1:0]              msr_dmmid,
   // DTLBL
   input [CONFIG_DTLB_P_SETS-1:0]      msr_dmm_tlbl_idx,
   input [CONFIG_DW-1:0]               msr_dmm_tlbl_nxt,
   input                               msr_dmm_tlbl_we,
   // DTLBH
   input [CONFIG_DTLB_P_SETS-1:0]      msr_dmm_tlbh_idx,
   input [CONFIG_DW-1:0]               msr_dmm_tlbh_nxt,
   input                               msr_dmm_tlbh_we,
   // DCID
   output [CONFIG_DW-1:0]              msr_dcid,
   // DCINV
   input [CONFIG_DW-1:0]               msr_dcinv_nxt,
   input                               msr_dcinv_we,
   // DCFLS
   input [CONFIG_DW-1:0]               msr_dcfls_nxt,
   input                               msr_dcfls_we
);
   localparam CONFIG_P_DW_BYTES        = (CONFIG_P_DW-3);
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 dc_stall_req;           // From U_D_CACHE of dcache.v
   // End of automatics
   wire                                p_cke;
   // Stage 1 Input
   wire                                s1i_valid;
   wire                                s1i_load;
   wire                                s1i_store;
   wire                                s1i_sign_ext;
   wire                                s1i_barr;
   wire                                s1i_dcop;
   wire                                s1i_dc_req;
   wire                                s1i_tlb_req;
   wire [CONFIG_AW-1:0]                s1i_dc_vaddr;
   wire [CONFIG_P_PAGE_SIZE-1:0]       s1i_dc_vpo;
   wire [CONFIG_DW/8-1:0]              s1i_dc_wmsk;
   wire [CONFIG_DW-1:0]                s1i_dc_wdat;
   wire                                s1i_misalign;
   wire [CONFIG_DW-1:0]                s1i_din_8b;
   wire [CONFIG_DW-1:0]                s1i_din_16b;
   wire [3:0]                          s1i_we_msk_8b;
   wire [3:0]                          s1i_we_msk_16b;
   wire [2:0]                          s1i_size;
   // Stage 2 Input / Stage 1 Output
   wire                                s1o_valid;
   wire [2:0]                          s1o_size;
   wire                                s1o_sign_ext;
   wire                                s2i_tlb_uncached;
   wire                                s2i_tlb_exc;
   wire                                s2i_kill_req;
   wire                                s2i_uncached;
   wire [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] s2i_tlb_ppn;
   wire [CONFIG_AW-CONFIG_P_PAGE_SIZE-1:0] s2i_dc_ppn;
   wire                                s1o_EDTM;
   wire                                s1o_EDPF;
   wire                                s1o_EALIGN;
   wire [CONFIG_AW-1:0]                s1o_vaddr;
   wire                                s1o_dcop;
   wire                                s1o_msr_psr_dce;
   // Stage 3 Input / Stage 2 Output
   wire [CONFIG_DW-1:0]                s2o_dout_32b;
   wire [7:0]                          s2o_dout_8b;
   wire [15:0]                         s2o_dout_16b;
   wire [CONFIG_AW-1:0]                s2o_vaddr;
   wire [2:0]                          s2o_size;
   wire                                s2o_sign_ext;

   assign s1i_valid = ex_valid & (s1i_load|s1i_store|s1i_dcop);
   assign s1i_load = ex_lsu_opc_bus[`NCPU_LSU_LOAD];
   assign s1i_store = ex_lsu_opc_bus[`NCPU_LSU_STORE];
   assign s1i_sign_ext = ex_lsu_opc_bus[`NCPU_LSU_SIGN_EXT];
   assign s1i_barr = ex_lsu_opc_bus[`NCPU_LSU_BARR];
   assign s1i_size = ex_lsu_opc_bus[`NCPU_LSU_SIZE];

   assign s1i_dcop = (msr_dcinv_we | msr_dcfls_we);

   assign agu_en = (s1i_load|s1i_store);
   assign s1i_dc_vaddr = (msr_dcinv_we)
                           ? msr_dcinv_nxt
                           : (msr_dcfls_we)
                              ? msr_dcfls_nxt
                              : add_sum;

   // Address alignment check
   assign s1i_misalign = (s1i_size==3'd3 & |s1i_dc_vaddr[1:0]) |
                           (s1i_size==3'd2 & s1i_dc_vaddr[0]);

   assign s1i_din_8b = {ex_operand2[7:0], ex_operand2[7:0], ex_operand2[7:0], ex_operand2[7:0]};
   assign s1i_din_16b = {ex_operand2[15:0], ex_operand2[15:0]};

   assign s1i_dc_wdat = ({CONFIG_DW{s1i_size==3'd3}} & ex_operand2) |
                        ({CONFIG_DW{s1i_size==3'd2}} & s1i_din_16b) |
                        ({CONFIG_DW{s1i_size==3'd1}} & s1i_din_8b);

   // B/HW align
   assign s1i_we_msk_8b = (s1i_dc_vaddr[1:0]==2'b00 ? 4'b0001 :
                           s1i_dc_vaddr[1:0]==2'b01 ? 4'b0010 :
                           s1i_dc_vaddr[1:0]==2'b10 ? 4'b0100 :
                           s1i_dc_vaddr[1:0]==2'b11 ? 4'b1000 : 4'b0000);
   assign s1i_we_msk_16b = s1i_dc_vaddr[1] ? 4'b1100 : 4'b0011;

   // Write byte mask
   assign s1i_dc_wmsk = {CONFIG_DW/8{s1i_store}} & (
                        ({CONFIG_DW/8{s1i_size==3'd3}} & 4'b1111) |
                        ({CONFIG_DW/8{s1i_size==3'd2}} & s1i_we_msk_16b) |
                        ({CONFIG_DW/8{s1i_size==3'd1}} & s1i_we_msk_8b) );

   assign s1i_dc_vpo = s1i_dc_vaddr[CONFIG_P_PAGE_SIZE-1:0];

   assign s1i_dc_req = (p_cke & s1i_valid & ~flush_s1);

   assign s1i_tlb_req = (s1i_dc_req & ~s1i_dcop);

   assign p_cke = (~stall);

   dmmu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS))
   U_D_MMU
      (
         .clk                          (clk),
         .rst                          (rst),
         .re                           (s1i_tlb_req),
         .vpn                          (s1i_dc_vaddr[CONFIG_AW-1:CONFIG_P_PAGE_SIZE]),
         .we                           (s1i_store),
         .ppn                          (s2i_tlb_ppn),
         .EDTM                         (s1o_EDTM),
         .EDPF                         (s1o_EDPF),
         .uncached                     (s2i_tlb_uncached),
         .msr_psr_dmme                 (msr_psr_dmme),
         .msr_psr_rm                   (msr_psr_rm),
         .msr_dmmid                    (msr_dmmid),
         .msr_dmm_tlbl_idx             (msr_dmm_tlbl_idx),
         .msr_dmm_tlbl_nxt             (msr_dmm_tlbl_nxt),
         .msr_dmm_tlbl_we              (msr_dmm_tlbl_we),
         .msr_dmm_tlbh_idx             (msr_dmm_tlbh_idx),
         .msr_dmm_tlbh_nxt             (msr_dmm_tlbh_nxt),
         .msr_dmm_tlbh_we              (msr_dmm_tlbh_we)
      );

   assign s2i_tlb_exc = (s1o_EDTM | s1o_EDPF | s1o_EALIGN);

   // Kill the request to D$ if MMU raised exceptions or cache was inhibited
   assign s2i_kill_req = (s2i_tlb_exc);

   assign s2i_uncached = (s2i_tlb_uncached | ~s1o_msr_psr_dce);
   
   assign s2i_dc_ppn = (s1o_dcop)
                        ? s1o_vaddr[CONFIG_AW-1:CONFIG_P_PAGE_SIZE]
                        : s2i_tlb_ppn;

   /* dcache AUTO_TEMPLATE (
      .req                             (s1i_dc_req),
      .size                            (s1i_size),
      .wmsk                            (s1i_dc_wmsk),
      .wdat                            (s1i_dc_wdat),
      .vpo                             (s1i_dc_vpo),
      .ppn_s2                          (s2i_dc_ppn),
      .kill_req_s2                     (s2i_kill_req),
      .uncached_s2                     (s2i_uncached),
      .inv                             (msr_dcinv_we),
      .fls                             (msr_dcfls_we),
      .stall_req                       (dc_stall_req),
      .dout                            (s2o_dout_32b),
   )
   */
   dcache
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_D_CACHE
      (/*AUTOINST*/
       // Outputs
       .stall_req                       (dc_stall_req),          // Templated
       .dout                            (s2o_dout_32b),          // Templated
       .dbus_ARVALID                    (dbus_ARVALID),
       .dbus_ARADDR                     (dbus_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .dbus_ARPROT                     (dbus_ARPROT[2:0]),
       .dbus_ARID                       (dbus_ARID[AXI_ID_WIDTH-1:0]),
       .dbus_ARUSER                     (dbus_ARUSER[AXI_USER_WIDTH-1:0]),
       .dbus_ARLEN                      (dbus_ARLEN[7:0]),
       .dbus_ARSIZE                     (dbus_ARSIZE[2:0]),
       .dbus_ARBURST                    (dbus_ARBURST[1:0]),
       .dbus_ARLOCK                     (dbus_ARLOCK),
       .dbus_ARCACHE                    (dbus_ARCACHE[3:0]),
       .dbus_ARQOS                      (dbus_ARQOS[3:0]),
       .dbus_ARREGION                   (dbus_ARREGION[3:0]),
       .dbus_RREADY                     (dbus_RREADY),
       .dbus_AWVALID                    (dbus_AWVALID),
       .dbus_AWADDR                     (dbus_AWADDR[AXI_ADDR_WIDTH-1:0]),
       .dbus_AWPROT                     (dbus_AWPROT[2:0]),
       .dbus_AWID                       (dbus_AWID[AXI_ID_WIDTH-1:0]),
       .dbus_AWUSER                     (dbus_AWUSER[AXI_USER_WIDTH-1:0]),
       .dbus_AWLEN                      (dbus_AWLEN[7:0]),
       .dbus_AWSIZE                     (dbus_AWSIZE[2:0]),
       .dbus_AWBURST                    (dbus_AWBURST[1:0]),
       .dbus_AWLOCK                     (dbus_AWLOCK),
       .dbus_AWCACHE                    (dbus_AWCACHE[3:0]),
       .dbus_AWQOS                      (dbus_AWQOS[3:0]),
       .dbus_AWREGION                   (dbus_AWREGION[3:0]),
       .dbus_WVALID                     (dbus_WVALID),
       .dbus_WDATA                      (dbus_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .dbus_WSTRB                      (dbus_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
       .dbus_WLAST                      (dbus_WLAST),
       .dbus_WUSER                      (dbus_WUSER[AXI_USER_WIDTH-1:0]),
       .dbus_BREADY                     (dbus_BREADY),
       .msr_dcid                        (msr_dcid[CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .req                             (s1i_dc_req),            // Templated
       .size                            (s1i_size),              // Templated
       .wmsk                            (s1i_dc_wmsk),           // Templated
       .wdat                            (s1i_dc_wdat),           // Templated
       .vpo                             (s1i_dc_vpo),            // Templated
       .ppn_s2                          (s2i_dc_ppn),            // Templated
       .kill_req_s2                     (s2i_kill_req),          // Templated
       .uncached_s2                     (s2i_uncached),          // Templated
       .inv                             (msr_dcinv_we),          // Templated
       .fls                             (msr_dcfls_we),          // Templated
       .dbus_ARREADY                    (dbus_ARREADY),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .dbus_RLAST                      (dbus_RLAST),
       .dbus_AWREADY                    (dbus_AWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_RRESP                      (dbus_RRESP[1:0]),
       .dbus_RID                        (dbus_RID[AXI_ID_WIDTH-1:0]),
       .dbus_RUSER                      (dbus_RUSER[AXI_USER_WIDTH-1:0]),
       .dbus_BRESP                      (dbus_BRESP[1:0]),
       .dbus_BID                        (dbus_BID[AXI_ID_WIDTH-1:0]),
       .dbus_BUSER                      (dbus_BUSER[AXI_USER_WIDTH-1:0]));

   // Data path
   mDFF_l #(.DW(3)) ff_s1o_size (.CLK(clk), .LOAD(p_cke), .D(s1i_size), .Q(s1o_size) );
   mDFF_l #(.DW(CONFIG_AW)) ff_s1o_vaddr (.CLK(clk), .LOAD(p_cke), .D(s1i_dc_vaddr), .Q(s1o_vaddr) );
   mDFF_l #(.DW(1)) ff_s1o_sign_ext (.CLK(clk), .LOAD(p_cke), .D(s1i_sign_ext), .Q(s1o_sign_ext) );
   mDFF_l #(.DW(1)) ff_s1o_dcop (.CLK(clk), .LOAD(p_cke), .D(s1i_dcop), .Q(s1o_dcop) );
   mDFF_l #(.DW(CONFIG_AW)) ff_s2o_vaddr (.CLK(clk), .LOAD(p_cke), .D(s1o_vaddr), .Q(s2o_vaddr) );
   mDFF_l #(.DW(3)) ff_s2o_size (.CLK(clk), .LOAD(p_cke), .D(s1o_size), .Q(s2o_size) );
   mDFF_l #(.DW(1)) ff_s2o_sign_ext (.CLK(clk), .LOAD(p_cke), .D(s1o_sign_ext), .Q(s2o_sign_ext) );

   // Control path
   mDFF_lr #(.DW(1)) ff_s1o_valid (.CLK(clk), .RST(rst), .LOAD(p_cke|flush_s1), .D(s1i_valid & ~flush_s1), .Q(s1o_valid) );
   mDFF_lr #(.DW(1)) ff_s1o_misalign (.CLK(clk), .RST(rst), .LOAD(p_cke), .D(s1i_misalign), .Q(s1o_EALIGN) );
   mDFF_lr #(.DW(1)) ff_s1o_msr_psr_dce (.CLK(clk), .RST(rst), .LOAD(p_cke), .D(msr_psr_dce), .Q(s1o_msr_psr_dce) );
   

   assign lsu_stall_req = (dc_stall_req);

   // B/HW align
   assign s2o_dout_8b = ({8{s2o_vaddr[1:0]==2'b00}} & s2o_dout_32b[7:0]) |
                          ({8{s2o_vaddr[1:0]==2'b01}} & s2o_dout_32b[15:8]) |
                          ({8{s2o_vaddr[1:0]==2'b10}} & s2o_dout_32b[23:16]) |
                          ({8{s2o_vaddr[1:0]==2'b11}} & s2o_dout_32b[31:24]);
   assign s2o_dout_16b = s2o_vaddr[1] ? s2o_dout_32b[31:16] : s2o_dout_32b[15:0];

   assign lsu_dout =
      ({CONFIG_DW{s2o_size==3'd3}} & s2o_dout_32b) |
      ({CONFIG_DW{s2o_size==3'd2}} & {{16{s2o_sign_ext & s2o_dout_16b[15]}}, s2o_dout_16b[15:0]}) |
      ({CONFIG_DW{s2o_size==3'd1}} & {{24{s2o_sign_ext & s2o_dout_8b[7]}}, s2o_dout_8b[7:0]});

   assign lsu_EDTM = (s1o_valid & s1o_EDTM);
   assign lsu_EDPF = (s1o_valid & s1o_EDPF);
   assign lsu_EALIGN = (s1o_valid & s1o_EALIGN);
   
   assign lsu_vaddr = s1o_vaddr;

endmodule
