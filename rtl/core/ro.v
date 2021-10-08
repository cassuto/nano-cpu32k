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

module ro
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               flush,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ro_alu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_bpu_pred_taken,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ro_bpu_pred_tgt,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ro_bru_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_epu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ro_imm,
//   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ro_lpu_opc_bus,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_lsu_op,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0] ro_fe,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ro_pc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prd,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prd_we,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs1,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs1_re,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs2,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs2_re,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ro_rob_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ro_rob_bank,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_valid,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ready,
   // To PRF
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] prf_RE,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_PRF_AW-1:0] prf_RADDR,
   // From PRF
   input [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] prf_RDATA,
   // To EX
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_pred_taken,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_bpu_pred_tgt,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_op,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm,
//   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_op,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0] ex_fe,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prd,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prd_we,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand1,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand2,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id,
   output [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank,
   output [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_ready
);
   localparam IW                       = (1<<CONFIG_P_ISSUE_WIDTH);
   wire [IW-1:0]                       p_ce;
   wire [IW-1:0]                       s1o_prs1_re;
   wire [IW-1:0]                       s1o_prs2_re;
   genvar                              i;
   
   generate for(i=0;i<IW;i=i+1)
      begin : gen_ro
         hds_buf
            #(.BYPASS(1))
         U_BUF
            (
               .clk  (clk),
               .rst  (rst),
               .flush (flush),
               .A_en (1'b1),    // enable AREADY output
               .AVALID (ro_valid[i]),
               .AREADY (ro_ready[i]),
               .B_en (1'b1),    // enable BVALID output
               .BVALID (ex_valid[i]),
               .BREADY (ex_ready[i]),
               .p_ce (p_ce[i])
            );


         //
         // Pipeline stage
         //
         
         `mDFF_l # (.DW(`NCPU_ALU_IOPW)) ff_ex_alu_opc_bus (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]), .Q(ex_alu_opc_bus[i * `NCPU_ALU_IOPW +: `NCPU_ALU_IOPW]) );
                  
//            `mDFF_l # (.DW(`NCPU_LPU_IOPW)) ff_ex_lpu_opc_bus (.CLK(clk),`rst .LOAD(p_ce[i]),
//                     .D(ro_lpu_opc_bus[i * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]), .Q(ex_lpu_opc_bus[i * `NCPU_LPU_IOPW +: `NCPU_LPU_IOPW]) );
                  
         `mDFF_l # (.DW(1)) ff_ex_epu_opc_bus (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_epu_op[i]), .Q(ex_epu_op[i]) );
         
         `mDFF_l # (.DW(`NCPU_BRU_IOPW)) ff_ex_bru_opc_bus (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]), .Q(ex_bru_opc_bus[i * `NCPU_BRU_IOPW +: `NCPU_BRU_IOPW]) );
                  
         `mDFF_l # (.DW(1)) ff_ex_lsu_opc_bus (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_lsu_op[i]), .Q(ex_lsu_op[i]) );
         
         `mDFF_l # (.DW(`NCPU_FE_W)) ff_ex_fe (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_fe[i * `NCPU_FE_W +: `NCPU_FE_W]), .Q(ex_fe[i * `NCPU_FE_W +: `NCPU_FE_W]) );
                  
         `mDFF_l # (.DW(1)) ff_ex_bpu_pred_taken (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_bpu_pred_taken[i]), .Q(ex_bpu_pred_taken[i]) );
         
         `mDFF_l # (.DW(`PC_W)) ff_ex_bpu_pred_tgt (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_bpu_pred_tgt[i * `PC_W +: `PC_W]), .Q(ex_bpu_pred_tgt[i * `PC_W +: `PC_W]) );
                  
         `mDFF_l # (.DW(`PC_W)) ff_ex_pc (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_pc[i * `PC_W +: `PC_W]), .Q(ex_pc[i * `PC_W +: `PC_W]) );
                  
         `mDFF_l # (.DW(CONFIG_DW)) ff_ex_imm (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_imm[i * CONFIG_DW +: CONFIG_DW]), .Q(ex_imm[i * CONFIG_DW +: CONFIG_DW]) );
                  
         `mDFF_l # (.DW(1)) ff_ex_prd_we (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_prd_we[i]), .Q(ex_prd_we[i]) );
         
         `mDFF_l # (.DW(`NCPU_PRF_AW)) ff_ex_prd (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]), .Q(ex_prd[i * `NCPU_PRF_AW +: `NCPU_PRF_AW]) );
                  
         `mDFF_l # (.DW(CONFIG_P_ROB_DEPTH)) ff_ex_rob_id (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]), .Q(ex_rob_id[i * CONFIG_P_ROB_DEPTH +: CONFIG_P_ROB_DEPTH]) );
                  
         `mDFF_l # (.DW(CONFIG_P_COMMIT_WIDTH)) ff_ex_rob_bank (.CLK(clk),`rst .LOAD(p_ce[i]),
                  .D(ro_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]), .Q(ex_rob_bank[i * CONFIG_P_COMMIT_WIDTH +: CONFIG_P_COMMIT_WIDTH]) );
         
         `mDFF_l # (.DW(1)) ff_s1o_prs1_re (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_prs1_re[i]), .Q(s1o_prs1_re[i]) );
         `mDFF_l # (.DW(1)) ff_s1o_prs2_re (.CLK(clk),`rst .LOAD(p_ce[i]), .D(ro_prs2_re[i]), .Q(s1o_prs2_re[i]) );
         
         // PRF could be considered as a pipeline stage
         assign prf_RE[(i<<1)] = (p_ce[i] & ro_prs1_re[i]);
         assign prf_RE[(i<<1)+1] = (p_ce[i] & ro_prs2_re[i]);
         assign prf_RADDR[(i<<1)*`NCPU_PRF_AW +: `NCPU_PRF_AW] = ro_prs1[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
         assign prf_RADDR[((i<<1)+1)*`NCPU_PRF_AW +: `NCPU_PRF_AW] = ro_prs2[i * `NCPU_PRF_AW +: `NCPU_PRF_AW];
         
         // MUX for operand and immediate number
         assign ex_operand1[i*CONFIG_DW +: CONFIG_DW] = (s1o_prs1_re[i])
                                                            ? prf_RDATA[(i<<1)*CONFIG_DW +: CONFIG_DW]
                                                            : ex_imm[i*CONFIG_DW +: CONFIG_DW];
         assign ex_operand2[i*CONFIG_DW +: CONFIG_DW] = (s1o_prs2_re[i])
                                                            ? prf_RDATA[((i<<1)+1)*CONFIG_DW +: CONFIG_DW]
                                                            : ex_imm[i*CONFIG_DW +: CONFIG_DW];

      end
   endgenerate

`ifdef ENABLE_DIFFTEST
   wire [31:0] dbg_ro_pc [IW-1:0];
   generate for(i=0;i<IW;i=i+1)  
      begin : gen_dbg
         assign dbg_ro_pc[i] = {ro_pc[i*`PC_W +: `PC_W], 2'b00};
      end
   endgenerate
`endif

endmodule
