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

module cmt
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0
)
(
   input                               clk,
   input                               stall,
`ifdef ENABLE_DIFFTEST
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_valid,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_pc,
`endif
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we,
   // ARF
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] arf_RE,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_REG_AW-1:0] arf_RADDR,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] arf_RDATA
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   
   mRF_nwnr
      #(
         .DW                           (CONFIG_DW),
         .AW                           (`NCPU_REG_AW),
         .NUM_READ                     (2*IW), // Each instruction has a maximum of 2 register operands
         .NUM_WRITE                    (IW)
      )
   U_ARF
      (
         .CLK                          (clk),
         .RE                           (arf_RE),
         .RADDR                        (arf_RADDR),
         .RDATA                        (arf_RDATA),
         .WE                           (commit_rf_we),
         .WADDR                        (commit_rf_waddr),
         .WDATA                        (commit_rf_wdat)
      );
      
`ifdef ENABLE_DIFFTEST
   //
   // Difftest access point
   //
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_valid_ff;
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_pc_ff;
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_ff;
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr_ff;
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat_ff;
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we_ff;
   
   mDFF_r #(.DW(1<<CONFIG_P_ISSUE_WIDTH)) ff_commit_valid (.CLK(clk), .RST(rst), .D(commit_valid & {(1<<CONFIG_P_ISSUE_WIDTH){~stall}}), .Q(commit_valid_ff));
   mDFF #(.DW(`PC_W*(1<<CONFIG_P_ISSUE_WIDTH))) ff_commit_pc (.CLK(clk), .D(commit_pc), .Q(commit_pc_ff));
   mDFF #(.DW(CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)))) ff_commit_rf (.CLK(clk), .D(commit_rf), .Q(commit_rf_ff));
   mDFF #(.DW(`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH))) ff_commit_rf_waddr (.CLK(clk), .D(commit_rf_waddr), .Q(commit_rf_waddr_ff));
   mDFF #(.DW(CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)))) ff_commit_rf_wdat (.CLK(clk), .D(commit_rf_wdat), .Q(commit_rf_wdat_ff));
   mDFF_r #(.DW(1<<CONFIG_P_ISSUE_WIDTH)) ff_commit_rf_we (.CLK(clk), .RST(rst), .D(commit_rf_we), .Q(commit_rf_we_ff));
   
   
   difftest_commit_inst U_DIFFTEST_COMMIT_INST
      (
         .clk                             (clk),
         .valid1                          (commit_valid_ff[0]),
         .pc1                             ({commit_pc_ff[0*`PC_W +: `PC_W], {NCPU_P_INSN_LEN{1'b0}}}),
         .wen1                            (commit_rf_we_ff[0]),
         .wnum1                           (commit_rf_waddr_ff[0*`NCPU_REG_AW +: `NCPU_REG_AW]),
         .wdata1                          (commit_rf_wdat_ff[0*CONFIG_DW +: CONFIG_DW]),
         .valid2                          (commit_valid_ff[1]),
         .pc2                             ({commit_pc_ff[1*`PC_W +: `PC_W], {NCPU_P_INSN_LEN{1'b0}}}),
         .wen2                            (commit_rf_we_ff[1]),
         .wnum2                           (commit_rf_waddr_ff[1*`NCPU_REG_AW +: `NCPU_REG_AW]),
         .wdata2                          (commit_rf_wdat_ff[1*CONFIG_DW +: CONFIG_DW]),
         .EINT1                           (1'b0), // TODO
         .EINT2                           (1'b0) // TODO
      );
      
   difftest_regfile U_DIFFTEST_REGFILE
      (
         .clk                             (clk),
         .r0                              (U_ARF.regfile[0]),
         .r1                              (U_ARF.regfile[1]),
         .r2                              (U_ARF.regfile[2]),
         .r3                              (U_ARF.regfile[3]),
         .r4                              (U_ARF.regfile[4]),
         .r5                              (U_ARF.regfile[5]),
         .r6                              (U_ARF.regfile[6]),
         .r7                              (U_ARF.regfile[7]),
         .r8                              (U_ARF.regfile[8]),
         .r9                              (U_ARF.regfile[9]),
         .r10                             (U_ARF.regfile[10]),
         .r11                             (U_ARF.regfile[11]),
         .r12                             (U_ARF.regfile[12]),
         .r13                             (U_ARF.regfile[13]),
         .r14                             (U_ARF.regfile[14]),
         .r15                             (U_ARF.regfile[15]),
         .r16                             (U_ARF.regfile[16]),
         .r17                             (U_ARF.regfile[17]),
         .r18                             (U_ARF.regfile[18]),
         .r19                             (U_ARF.regfile[19]),
         .r20                             (U_ARF.regfile[20]),
         .r21                             (U_ARF.regfile[21]),
         .r22                             (U_ARF.regfile[22]),
         .r23                             (U_ARF.regfile[23]),
         .r24                             (U_ARF.regfile[24]),
         .r25                             (U_ARF.regfile[25]),
         .r26                             (U_ARF.regfile[26]),
         .r27                             (U_ARF.regfile[27]),
         .r28                             (U_ARF.regfile[28]),
         .r29                             (U_ARF.regfile[29]),
         .r30                             (U_ARF.regfile[30]),
         .r31                             (U_ARF.regfile[31])
      );
      
   difftest_clk U_DIFFTEST_CLK
      (
         .clk                             (clk),
         .msr_tsc_count                   ('b0) // TODO
      );
   
`endif

endmodule
