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

module id_ro
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0
)
(
   input                               clk,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_dout,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_dout,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_dout,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_wdat,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_we,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_waddr,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_waddr,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_waddr,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_cmt_rf_waddr,
   input ro_ex_s1_load0,
   input ro_ex_s2_load0,
   input ro_ex_s3_load0,
   input [`NCPU_REG_AW*2*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] raddr,
   input [2*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] re,
   input [CONFIG_DW*2*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rf_din,
   output [CONFIG_DW*2*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] byp_dout,
   output [2*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] raw_dep_load0
);

   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CHS                      = (IW*2);
   wire                                p_ce;
   wire [CONFIG_DW*IW-1:0]             s1o_ex_s1_rf_dout_ff, s1o_ex_s1_rf_dout_ff_rev;
   wire [CONFIG_DW*IW-1:0]             s1o_ex_s2_rf_dout_ff, s1o_ex_s2_rf_dout_ff_rev;
   wire [CONFIG_DW*IW-1:0]             s1o_ex_s3_rf_dout_ff, s1o_ex_s3_rf_dout_ff_rev;
   wire [CONFIG_DW*IW-1:0]             s1o_cmt_rf_wdat_ff, s1o_cmt_rf_wdat_ff_rev;
   wire [CHS-1:0]                      rop_raw_load0;
   genvar i, k;
   integer j;
   
   generate
      for(i=0;i<CHS;i=i+1)
         begin
            wire [IW-1:0]        cf_ex_s1, cf_ex_s2, cf_ex_s3, cf_cmt;
            wire [IW-1:0]        cf_ex_s1_rev, cf_ex_s2_rev, cf_ex_s3_rev, cf_cmt_rev;
            wire [IW-1:0]        s1o_cf_ex_s1_rev, s1o_cf_ex_s2_rev, s1o_cf_ex_s3_rev, s1o_cf_cmt_rev;
            wire                 s1o_use_ex_s1, s1o_use_ex_s2, s1o_use_ex_s3, s1o_use_cmt;
            wire [CONFIG_DW-1:0] s1o_ex_s1_rf_dout_sel;
            wire [CONFIG_DW-1:0] s1o_ex_s2_rf_dout_sel;
            wire [CONFIG_DW-1:0] s1o_ex_s3_rf_dout_sel;
            wire [CONFIG_DW-1:0] s1o_cmt_rf_wdat_sel;
            
            for(k=0;k<IW;k=k+1)
               begin
                  assign cf_ex_s1[k] = ((raddr[i*`NCPU_REG_AW +: `NCPU_REG_AW] == ro_ex_s1_rf_waddr[k*`NCPU_REG_AW +: `NCPU_REG_AW]) &
                                       re[i] & ro_ex_s1_rf_we[k]);
                  assign cf_ex_s2[k] = ((raddr[i*`NCPU_REG_AW +: `NCPU_REG_AW] == ro_ex_s2_rf_waddr[k*`NCPU_REG_AW +: `NCPU_REG_AW]) &
                                       re[i] & ro_ex_s2_rf_we[k]);
                  assign cf_ex_s3[k] = ((raddr[i*`NCPU_REG_AW +: `NCPU_REG_AW] == ro_ex_s3_rf_waddr[k*`NCPU_REG_AW +: `NCPU_REG_AW]) &
                                       re[i] & ro_ex_s3_rf_we[k]);
                  assign cf_cmt[k] = ((raddr[i*`NCPU_REG_AW +: `NCPU_REG_AW] == ro_cmt_rf_waddr[k*`NCPU_REG_AW +: `NCPU_REG_AW]) &
                                       re[i] & ro_cmt_rf_we[k]);
                  
                  assign cf_ex_s1_rev[IW-k-1] = cf_ex_s1[k];
                  assign cf_ex_s2_rev[IW-k-1] = cf_ex_s2[k];
                  assign cf_ex_s3_rev[IW-k-1] = cf_ex_s3[k];
                  assign cf_cmt_rev[IW-k-1] = cf_cmt[k];
               end
            
            assign raw_dep_load0[i] = (cf_ex_s1[0] & ro_ex_s1_load0) |
                                       (cf_ex_s2[0] & ro_ex_s2_load0) |
                                       (cf_ex_s3[0] & ro_ex_s3_load0);
            
            mDFF_l #(.DW(IW)) ff_s1o_cf_ex_s1_rev(.CLK(clk), .LOAD(p_ce), .D(cf_ex_s1_rev), .Q(s1o_cf_ex_s1_rev) );
            mDFF_l #(.DW(IW)) ff_s1o_cf_ex_s2_rev(.CLK(clk), .LOAD(p_ce), .D(cf_ex_s2_rev), .Q(s1o_cf_ex_s2_rev) );
            mDFF_l #(.DW(IW)) ff_s1o_cf_ex_s3_rev(.CLK(clk), .LOAD(p_ce), .D(cf_ex_s3_rev), .Q(s1o_cf_ex_s3_rev) );
            mDFF_l #(.DW(IW)) ff_s1o_cf_cmt_rev(.CLK(clk), .LOAD(p_ce), .D(cf_cmt_rev), .Q(s1o_cf_cmt_rev) );

            pmux_v #(.SELW(IW), .DW(CONFIG_DW)) U_EX_S1_PMUX (.sel(s1o_cf_ex_s1_rev), .din(s1o_ex_s1_rf_dout_ff_rev), .dout(s1o_ex_s1_rf_dout_sel), .valid(s1o_use_ex_s1) );
            pmux_v #(.SELW(IW), .DW(CONFIG_DW)) U_EX_S2_PMUX (.sel(s1o_cf_ex_s2_rev), .din(s1o_ex_s2_rf_dout_ff_rev), .dout(s1o_ex_s2_rf_dout_sel), .valid(s1o_use_ex_s2) );
            pmux_v #(.SELW(IW), .DW(CONFIG_DW)) U_EX_S3_PMUX (.sel(s1o_cf_ex_s3_rev), .din(s1o_ex_s3_rf_dout_ff_rev), .dout(s1o_ex_s3_rf_dout_sel), .valid(s1o_use_ex_s3) );
            pmux_v #(.SELW(IW), .DW(CONFIG_DW)) U_CMT_PMUX (.sel(s1o_cf_cmt_rev), .din(s1o_cmt_rf_wdat_ff_rev), .dout(s1o_cmt_rf_wdat_sel), .valid(s1o_use_cmt) );
            
            assign byp_dout[i*CONFIG_DW +: CONFIG_DW] = (s1o_use_ex_s1)
                                                            ? s1o_ex_s1_rf_dout_sel
                                                            : (s1o_use_ex_s2)
                                                               ? s1o_ex_s2_rf_dout_sel
                                                               : (s1o_use_ex_s3)
                                                                  ? s1o_ex_s3_rf_dout_sel
                                                                  : (s1o_use_cmt)
                                                                     ? s1o_cmt_rf_wdat_sel
                                                                     : rf_din[i*CONFIG_DW +: CONFIG_DW];
         end
   endgenerate
   
   assign p_ce = (|re);
   
   mDFF_l #(.DW(CONFIG_DW*IW)) ff_s1o_ex_s1_rf_dout_ff(.CLK(clk), .LOAD(p_ce), .D(ro_ex_s1_rf_dout), .Q(s1o_ex_s1_rf_dout_ff) );
   mDFF_l #(.DW(CONFIG_DW*IW)) ff_s1o_ex_s2_rf_dout_ff(.CLK(clk), .LOAD(p_ce), .D(ro_ex_s2_rf_dout), .Q(s1o_ex_s2_rf_dout_ff) );
   mDFF_l #(.DW(CONFIG_DW*IW)) ff_s1o_ex_s3_rf_wdat_ff(.CLK(clk), .LOAD(p_ce), .D(ro_ex_s3_rf_dout), .Q(s1o_ex_s3_rf_dout_ff) );
   mDFF_l #(.DW(CONFIG_DW*IW)) ff_s1o_cmt_rf_wdat_ff(.CLK(clk), .LOAD(p_ce), .D(ro_cmt_rf_wdat), .Q(s1o_cmt_rf_wdat_ff) );
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_s1o_rf_dout_ff_rev
            assign s1o_ex_s1_rf_dout_ff_rev[(IW-i-1)*CONFIG_DW +: CONFIG_DW] = s1o_ex_s1_rf_dout_ff[i*CONFIG_DW +: CONFIG_DW];
            assign s1o_ex_s2_rf_dout_ff_rev[(IW-i-1)*CONFIG_DW +: CONFIG_DW] = s1o_ex_s2_rf_dout_ff[i*CONFIG_DW +: CONFIG_DW];
            assign s1o_ex_s3_rf_dout_ff_rev[(IW-i-1)*CONFIG_DW +: CONFIG_DW] = s1o_ex_s3_rf_dout_ff[i*CONFIG_DW +: CONFIG_DW];
            assign s1o_cmt_rf_wdat_ff_rev[(IW-i-1)*CONFIG_DW +: CONFIG_DW] = s1o_cmt_rf_wdat_ff[i*CONFIG_DW +: CONFIG_DW];
         end
   endgenerate
   
endmodule
