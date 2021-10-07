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

module id
#(
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
//   parameter                           CONFIG_ENABLE_MUL = 0,
//   parameter                           CONFIG_ENABLE_DIV = 0,
//   parameter                           CONFIG_ENABLE_DIVU = 0,
//   parameter                           CONFIG_ENABLE_MOD = 0,
//   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input                               rn_stall_req,
   // From frontend
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid,
   output [CONFIG_P_ISSUE_WIDTH:0]      id_pop_cnt,
   input [`NCPU_INSN_DW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   input [`PC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc,
   input [`FNT_EXC_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc,
   input [`BPU_UPD_W * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd,
   // IRQ
   input                               irq_async,
   // To EX
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0]                rn_valid,
   output [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_alu_opc_bus,
//   output [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lpu_opc_bus,
   output [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_epu_opc_bus,
   output [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bru_opc_bus,
   output [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lsu_opc_bus,
   output [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_fe,
   output [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bpu_upd,
   output [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_pc,
   output [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_imm,
   output [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs1,
   output [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs1_re,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs2_re,
   output [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd_we,
   output [CONFIG_P_ISSUE_WIDTH:0] rn_push_size
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   
   wire                                p_ce;
   wire [IW-1:0]                       valid;
   wire [`NCPU_ALU_IOPW*IW-1:0]        s1i_alu_opc_bus;
//   wire [`NCPU_LPU_IOPW*IW-1:0]        s1i_lpu_opc_bus;
   wire [`NCPU_EPU_IOPW*IW-1:0]        s1i_epu_opc_bus;
   wire [`NCPU_BRU_IOPW*IW-1:0]        s1i_bru_opc_bus;
   wire [`NCPU_LSU_IOPW*IW-1:0]        s1i_lsu_opc_bus;
   wire [CONFIG_DW*IW-1:0]             s1i_imm;
   wire [`NCPU_FE_W*IW-1:0]            s1i_fe;
   wire [IW-1:0]                       rf_we;
   wire [`NCPU_LRF_AW*IW-1:0]          rf_waddr;
   wire [IW-1:0]                       rf_rs1_re;
   wire [`NCPU_LRF_AW*IW-1:0]          rf_rs1_addr;
   wire [IW-1:0]                       rf_rs2_re;
   wire [`NCPU_LRF_AW*IW-1:0]          rf_rs2_addr;
   genvar i;
   
   generate
      for(i=0;i<IW;i=i+1)
         begin : gen_dec
            id_dec
               #(/*AUTOINSTPARAM*/
                 // Parameters
                 .CONFIG_DW             (CONFIG_DW),
                 .CONFIG_ENABLE_ASR     (CONFIG_ENABLE_ASR))
            U_DEC
               (
                  .id_valid            (id_valid[i]),
                  .id_ins              (id_ins[i*`NCPU_INSN_DW +: `NCPU_INSN_DW]),
                  .id_exc              (id_exc[i*`FNT_EXC_W +: `FNT_EXC_W]),
                  .irq_async           (irq_async),
                  
                  .alu_opc_bus         (s1i_alu_opc_bus[i*`NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]),
//                  .lpu_opc_bus         (s1i_lpu_opc_bus[i*`NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]),
                  .epu_opc_bus         (s1i_epu_opc_bus[i*`NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]),
                  .bru_opc_bus         (s1i_bru_opc_bus[i*`NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]),
                  .lsu_opc_bus         (s1i_lsu_opc_bus[i*`NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]),
                  .fe                  (s1i_fe[i*`NCPU_FE_W +: `NCPU_FE_W]),
                  .imm                 (s1i_imm[i*CONFIG_DW +: CONFIG_DW]),
                  .rf_we               (rf_we[i]),
                  .rf_waddr            (rf_waddr[i*`NCPU_LRF_AW +:`NCPU_LRF_AW]),
                  .rf_rs1_re           (rf_rs1_re[i]),
                  .rf_rs1_addr         (rf_rs1_addr[i*`NCPU_LRF_AW +:`NCPU_LRF_AW]),
                  .rf_rs2_re           (rf_rs2_re[i]),
                  .rf_rs2_addr         (rf_rs2_addr[i*`NCPU_LRF_AW +:`NCPU_LRF_AW])
               );
         end
   endgenerate
   
   assign p_ce = (~rn_stall_req);
   
   // Issue NOPs if RO is not ready.
   assign valid = (id_valid);
   
   // Count the number of inst that will be issued
   popcnt #(.DW(IW), .P_DW(CONFIG_P_ISSUE_WIDTH)) U_CLO (.bitmap(valid & {IW{p_ce}}), .count(id_pop_cnt) );

   //
   // Pipeline stage
   //
   mDFF_lr # (.DW(IW)) ff_rn_valid (.CLK(clk), .RST(rst), .LOAD(p_ce|flush), .D(valid & {IW{~flush}}), .Q(rn_valid) );
   `mDFF_l # (.DW(`NCPU_ALU_IOPW*IW)) ff_rn_alu_opc_bus (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_alu_opc_bus), .Q(rn_alu_opc_bus) );
//   `mDFF_l # (.DW(`NCPU_LPU_IOPW*IW)) ff_rn_lpu_opc_bus (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_lpu_opc_bus), .Q(rn_lpu_opc_bus) );
   `mDFF_l # (.DW(`NCPU_EPU_IOPW*IW)) ff_rn_epu_opc_bus (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_epu_opc_bus), .Q(rn_epu_opc_bus) );
   `mDFF_l # (.DW(`NCPU_BRU_IOPW*IW)) ff_rn_bru_opc_bus (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_bru_opc_bus), .Q(rn_bru_opc_bus) );
   `mDFF_l # (.DW(`NCPU_LSU_IOPW*IW)) ff_rn_lsu_opc_bus (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_lsu_opc_bus), .Q(rn_lsu_opc_bus) );
   `mDFF_l # (.DW(`NCPU_FE_W*IW)) ff_rn_fe (.CLK(clk), .LOAD(p_ce),`rst .D(s1i_fe), .Q(rn_fe) );
   `mDFF_l # (.DW(`BPU_UPD_W*IW)) ff_rn_bpu_upd (.CLK(clk),`rst .LOAD(p_ce), .D(id_bpu_upd), .Q(rn_bpu_upd) );
   `mDFF_l # (.DW(`PC_W*IW)) ff_rn_pc (.CLK(clk),`rst .LOAD(p_ce), .D(id_pc), .Q(rn_pc) );
   `mDFF_l # (.DW(CONFIG_DW*IW)) ff_rn_imm (.CLK(clk),`rst .LOAD(p_ce), .D(s1i_imm), .Q(rn_imm) );
   `mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_rn_lrs1 (.CLK(clk),`rst .LOAD(p_ce), .D(rf_rs1_addr), .Q(rn_lrs1) );
   `mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_rn_lrs2 (.CLK(clk),`rst .LOAD(p_ce), .D(rf_rs2_addr), .Q(rn_lrs2) );
   `mDFF_l # (.DW(IW)) ff_rn_lrs1_re (.CLK(clk),`rst .LOAD(p_ce), .D(rf_rs1_re), .Q(rn_lrs1_re) );
   `mDFF_l # (.DW(IW)) ff_rn_lrs2_re (.CLK(clk),`rst .LOAD(p_ce), .D(rf_rs2_re), .Q(rn_lrs2_re) );
   `mDFF_l # (.DW(IW)) ff_rn_lrd_we (.CLK(clk),`rst .LOAD(p_ce), .D(rf_we), .Q(rn_lrd_we) );
   `mDFF_l # (.DW(`NCPU_LRF_AW*IW)) ff_rn_lrd (.CLK(clk),`rst .LOAD(p_ce), .D(rf_waddr), .Q(rn_lrd) );
   mDFF_lr # (.DW(CONFIG_P_ISSUE_WIDTH+1)) ff_rn_push_size (.CLK(clk), .RST(rst), .LOAD(p_ce|flush), .D(id_pop_cnt & {CONFIG_P_ISSUE_WIDTH+1{~flush}}), .Q(rn_push_size) );
   
   
endmodule
