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
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_DW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_PHT_P_NUM = 0,
   parameter                           CONFIG_BTB_P_NUM = 0,
   parameter                           CONFIG_NUM_IRQ = 0,
   parameter                           CONFIG_DC_P_WAYS = 0,
   parameter                           CONFIG_DC_P_SETS = 0,
   parameter                           CONFIG_DC_P_LINE = 0,
   parameter                           CONFIG_P_PAGE_SIZE = 0,
   parameter                           CONFIG_DMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_ITLB_P_SETS = 0,
   parameter                           CONFIG_DTLB_P_SETS = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EITM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_ESYSCALL_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EINSN_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIRQ_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDTM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EALIGN_VECTOR = 0,
   parameter                           AXI_P_DW_BYTES    = 0,
   parameter                           AXI_ADDR_WIDTH    = 0,
   parameter                           AXI_ID_WIDTH      = 0,
   parameter                           AXI_USER_WIDTH    = 0
)
(
   input                               clk,
   input                               rst,
   output                              flush,
   output [`PC_W-1:0]                  flush_tgt,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_valid,
   input [`NCPU_EPU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_epu_opc_bus,
   input [`NCPU_LSU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lsu_opc_bus,
   input [`BPU_UPD_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_bpu_upd,
   input [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pc,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we,
   input [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pfree,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_bcc,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_brel,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_breg,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_exc,
   input [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_opera,
   input [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_operb,
   input [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls_tgt,
   // To ROB
   output [CONFIG_P_COMMIT_WIDTH:0]     cmt_pop_size,
   output [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire,
   // To WB
   output                              prf_WE_lsu_epu,
   output [`NCPU_PRF_AW-1:0]           prf_WADDR_lsu_epu,
   output [CONFIG_DW-1:0]              prf_WDATA_lsu_epu,
   // To BPU
   output                              bpu_wb,
   output                              bpu_wb_is_bcc,
   output                              bpu_wb_is_breg,
   output                              bpu_wb_is_brel,
   output                              bpu_wb_taken,
   output [`PC_W-1:0]                  bpu_wb_pc,
   output [`PC_W-1:0]                  bpu_wb_npc_act,
   output [`BPU_UPD_W-1:0]             bpu_wb_upd,
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
   
   // IRQS
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              irq_async,
   output                              tsc_irq,
   // PSR
   output                              msr_psr_imme,
   output                              msr_psr_rm,
   output                              msr_psr_ice,
   // IMMID
   input [CONFIG_DW-1:0]               msr_immid,
   // ITLBL
   output [CONFIG_ITLB_P_SETS-1:0]     msr_imm_tlbl_idx,
   output [CONFIG_DW-1:0]              msr_imm_tlbl_nxt,
   output                              msr_imm_tlbl_we,
   // ITLBH
   output [CONFIG_ITLB_P_SETS-1:0]     msr_imm_tlbh_idx,
   output [CONFIG_DW-1:0]              msr_imm_tlbh_nxt,
   output                              msr_imm_tlbh_we,
   // ICID
   input [CONFIG_DW-1:0]               msr_icid,
   // ICINV
   output [CONFIG_DW-1:0]              msr_icinv_nxt,
   output                              msr_icinv_we,
   input                               msr_icinv_ready
);
   localparam CW                       = (1<<CONFIG_P_COMMIT_WIDTH);
   localparam [1:0]                    S_IDLE = 2'b01;
   localparam [1:0]                    S_PENDING = 2'b10;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [CONFIG_DW-1:0] epu_wb_dout;            // From U_EPU of cmt_epu.v
   wire                 epu_wb_dout_sel;        // From U_EPU of cmt_epu.v
   wire                 epu_wb_valid;           // From U_EPU of cmt_epu.v
   wire                 exc_flush;              // From U_EPU of cmt_epu.v
   wire [`PC_W-1:0]     exc_flush_tgt;          // From U_EPU of cmt_epu.v
   wire                 lsu_EALIGN;             // From U_LSU of cmt_lsu.v
   wire                 lsu_EDPF;               // From U_LSU of cmt_lsu.v
   wire                 lsu_EDTM;               // From U_LSU of cmt_lsu.v
   wire                 lsu_stall_req;          // From U_LSU of cmt_lsu.v
   wire [CONFIG_AW-1:0] lsu_vaddr;              // From U_LSU of cmt_lsu.v
   wire [CONFIG_DW-1:0] lsu_wb_dout;            // From U_LSU of cmt_lsu.v
   wire                 lsu_wb_valid;           // From U_LSU of cmt_lsu.v
   wire [CONFIG_DW-1:0] msr_coreid;             // From U_PSR of cmt_psr.v
   wire [CONFIG_DW-1:0] msr_cpuid;              // From U_PSR of cmt_psr.v
   wire [CONFIG_DW-1:0] msr_dcfls_nxt;          // From U_EPU of cmt_epu.v
   wire                 msr_dcfls_we;           // From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_dcid;               // From U_LSU of cmt_lsu.v
   wire [CONFIG_DW-1:0] msr_dcinv_nxt;          // From U_EPU of cmt_epu.v
   wire                 msr_dcinv_we;           // From U_EPU of cmt_epu.v
   wire [CONFIG_DTLB_P_SETS-1:0] msr_dmm_tlbh_idx;// From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_dmm_tlbh_nxt;       // From U_EPU of cmt_epu.v
   wire                 msr_dmm_tlbh_we;        // From U_EPU of cmt_epu.v
   wire [CONFIG_DTLB_P_SETS-1:0] msr_dmm_tlbl_idx;// From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_dmm_tlbl_nxt;       // From U_EPU of cmt_epu.v
   wire                 msr_dmm_tlbl_we;        // From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_dmmid;              // From U_LSU of cmt_lsu.v
   wire [CONFIG_DW-1:0] msr_elsa;               // From U_PSR of cmt_psr.v
   wire [CONFIG_DW-1:0] msr_elsa_nxt;           // From U_EPU of cmt_epu.v
   wire                 msr_elsa_we;            // From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_epc;                // From U_PSR of cmt_psr.v
   wire [CONFIG_DW-1:0] msr_epc_nxt;            // From U_EPU of cmt_epu.v
   wire                 msr_epc_we;             // From U_EPU of cmt_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr;            // From U_PSR of cmt_psr.v
   wire [`NCPU_PSR_DW-1:0] msr_epsr_nxt;        // From U_EPU of cmt_epu.v
   wire                 msr_epsr_we;            // From U_EPU of cmt_epu.v
   wire [CONFIG_DW-1:0] msr_evect;              // From U_PSR of cmt_psr.v
   wire [CONFIG_AW-1:0] msr_evect_nxt;          // From U_EPU of cmt_epu.v
   wire                 msr_evect_we;           // From U_EPU of cmt_epu.v
   wire [`NCPU_PSR_DW-1:0] msr_psr;             // From U_PSR of cmt_psr.v
   wire                 msr_psr_dce;            // From U_PSR of cmt_psr.v
   wire                 msr_psr_dce_nxt;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_dce_we;         // From U_EPU of cmt_epu.v
   wire                 msr_psr_dmme;           // From U_PSR of cmt_psr.v
   wire                 msr_psr_dmme_nxt;       // From U_EPU of cmt_epu.v
   wire                 msr_psr_dmme_we;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_ice_nxt;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_ice_we;         // From U_EPU of cmt_epu.v
   wire                 msr_psr_imme_nxt;       // From U_EPU of cmt_epu.v
   wire                 msr_psr_imme_we;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_ire;            // From U_PSR of cmt_psr.v
   wire                 msr_psr_ire_nxt;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_ire_we;         // From U_EPU of cmt_epu.v
   wire                 msr_psr_restore;        // From U_EPU of cmt_epu.v
   wire                 msr_psr_rm_nxt;         // From U_EPU of cmt_epu.v
   wire                 msr_psr_rm_we;          // From U_EPU of cmt_epu.v
   wire                 msr_psr_save;           // From U_EPU of cmt_epu.v
   wire [CONFIG_DW*`NCPU_SR_NUM-1:0] msr_sr;    // From U_PSR of cmt_psr.v
   wire [CONFIG_DW-1:0] msr_sr_nxt;             // From U_EPU of cmt_epu.v
   wire [`NCPU_SR_NUM-1:0] msr_sr_we;           // From U_EPU of cmt_epu.v
   wire                 refetch;                // From U_EPU of cmt_epu.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                p_ce_s1;
   wire                                p_ce_s2;
   wire                                p_ce_s1_no_icinv_stall;
   wire                                icinv_stall_req;
   wire                                cmt_ce;
   wire [CW-1:0]                       lsu_req;
   wire                                lsu_req_valid;
   wire [CW-1:0]                       epu_req;
   wire                                epu_req_valid;
   wire                                pipe_req;
   wire                                pipe_finish;
   wire [CW-1:0]                       single_fu;
   reg [CW-1:0]                        cmt_mask;
   wire [`PC_W-1:0]                    cmt_npc_0;
   wire [CW-1:0]                       cmt_b;
   wire [1:0]                          fsm_state_ff;
   reg [1:0]                           fsm_state_nxt;
   wire [CW-1:0]                       cmt_ready_2_fire;
   wire                                s1i_se_fls;
   wire [`PC_W-1:0]                    s1i_se_tgt;
   wire                                s1o_se_fls;
   wire [`PC_W-1:0]                    s1o_se_tgt;
   genvar i;
   integer j;
   
   mADD
      #(.DW(`PC_W))
   U_NPC
      (
         .a                   (cmt_pc[0 * `PC_W +: `PC_W]),
         .b                   ('b1),
         .s                   ('b0),
         .sum                 (cmt_npc_0)
      );

   generate
      for(i=0;i<CW;i=i+1)
         begin
            assign lsu_req[i] = (~s1o_se_fls & (|cmt_lsu_opc_bus[i * `NCPU_LSU_IOPW +: `NCPU_LSU_IOPW]));
            assign epu_req[i] = (~s1o_se_fls & ((|cmt_epu_opc_bus[i * `NCPU_EPU_IOPW +: `NCPU_EPU_IOPW]) |
                                 cmt_exc[i]));
            assign cmt_b[i] = (cmt_is_bcc[i] | cmt_is_breg[i] | cmt_is_brel[i]);
         end
   endgenerate
   
   assign single_fu =
      (lsu_req | epu_req | cmt_fls | cmt_b);
   
   // `se_fls` has the highest priority
   assign flush = (s1o_se_fls | exc_flush);

   assign flush_tgt = (s1o_se_fls)
                        ? s1o_se_tgt
                        : exc_flush_tgt /* (exc_flush) */ ;

   // FSM for requesting LSU or EPU
   always @(*)
      begin
         fsm_state_nxt = fsm_state_ff;
         case(fsm_state_ff)
            S_IDLE:
               if (pipe_req)
                  fsm_state_nxt = S_PENDING;
            S_PENDING:
               if (pipe_finish)
                  fsm_state_nxt = S_IDLE;
            default:
               ;
         endcase
      end
      
   mDFF_r #(.DW(2), .RST_VECTOR(S_IDLE)) ff_fsm_state_ff (.CLK(clk), .RST(rst), .D(fsm_state_nxt), .Q(fsm_state_ff) );
   
   assign s1i_se_fls = (cmt_fls[0] | refetch) & ~s1o_se_fls;
   assign s1i_se_tgt = (cmt_fls[0])
                           ? cmt_fls_tgt[0 * `PC_W +: `PC_W]
                           : cmt_npc_0 /* (refetch) */;
   
   mDFF_lr #(.DW(1)) ff_s1o_se_fls (.CLK(clk), .RST(rst), .LOAD(cmt_fire[0]|s1o_se_fls), .D(s1i_se_fls), .Q(s1o_se_fls) );
   mDFF_l #(.DW(`PC_W)) ff_s1o_se_tgt (.CLK(clk), .LOAD(cmt_fire[0]), .D(s1i_se_tgt), .Q(s1o_se_tgt) );
   
   assign cmt_ce = (~pipe_req | pipe_finish);
   
   always @(*)
      begin
         cmt_mask[0] = 1'b1;
         cmt_mask[1] = ~single_fu[0] & ~single_fu[1];
         for(j=2;j<CW;j=j+1)
            cmt_mask[j] = cmt_mask[j-1] & ~single_fu[j];
      end
   assign cmt_ready_2_fire = (cmt_valid & cmt_mask);
   assign cmt_fire = (cmt_ready_2_fire & {CW{cmt_ce & ~flush}});

`ifdef ENABLE_DIFFTEST
   // Exceptions should be committed to difftest for inspection
   wire [CW-1:0] cmt_dft_fire = (cmt_ready_2_fire & {CW{cmt_ce & ~s1o_se_fls}});
`endif

   assign pipe_req = (cmt_ready_2_fire[0] & (lsu_req[0] | epu_req[0]));
   assign lsu_req_valid = ((fsm_state_ff==S_IDLE) & cmt_ready_2_fire[0] & lsu_req[0]);
   assign epu_req_valid = ((fsm_state_ff==S_IDLE) & cmt_ready_2_fire[0] & epu_req[0]);
   
   
   // Count the number of commits
   popcnt #(.DW(CW), .P_DW(CONFIG_P_COMMIT_WIDTH)) U_CLO (.bitmap(cmt_fire), .count(cmt_pop_size) );

   /* cmt_lsu AUTO_TEMPLATE(
         .cmt_req_valid                (lsu_req_valid),
         .cmt_wdat                     (cmt_operb[0 * CONFIG_DW +: CONFIG_DW]),
         .cmt_lsa                      (cmt_opera[0 * CONFIG_DW +: CONFIG_DW]),
      )*/
   cmt_lsu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_LSU
      (/*AUTOINST*/
       // Outputs
       .lsu_stall_req                   (lsu_stall_req),
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
       .lsu_EDTM                        (lsu_EDTM),
       .lsu_EDPF                        (lsu_EDPF),
       .lsu_EALIGN                      (lsu_EALIGN),
       .lsu_vaddr                       (lsu_vaddr[CONFIG_AW-1:0]),
       .lsu_wb_dout                     (lsu_wb_dout[CONFIG_DW-1:0]),
       .lsu_wb_valid                    (lsu_wb_valid),
       .msr_dmmid                       (msr_dmmid[CONFIG_DW-1:0]),
       .msr_dcid                        (msr_dcid[CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .p_ce_s1                         (p_ce_s1),
       .p_ce_s2                         (p_ce_s2),
       .cmt_req_valid                   (lsu_req_valid),         // Templated
       .cmt_lsu_opc_bus                 (cmt_lsu_opc_bus[`NCPU_LSU_IOPW-1:0]),
       .cmt_lsa                         (cmt_opera[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .cmt_wdat                        (cmt_operb[0 * CONFIG_DW +: CONFIG_DW]), // Templated
       .dbus_ARREADY                    (dbus_ARREADY),
       .dbus_RVALID                     (dbus_RVALID),
       .dbus_RDATA                      (dbus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .dbus_RRESP                      (dbus_RRESP[1:0]),
       .dbus_RLAST                      (dbus_RLAST),
       .dbus_RID                        (dbus_RID[AXI_ID_WIDTH-1:0]),
       .dbus_RUSER                      (dbus_RUSER[AXI_USER_WIDTH-1:0]),
       .dbus_AWREADY                    (dbus_AWREADY),
       .dbus_WREADY                     (dbus_WREADY),
       .dbus_BVALID                     (dbus_BVALID),
       .dbus_BRESP                      (dbus_BRESP[1:0]),
       .dbus_BID                        (dbus_BID[AXI_ID_WIDTH-1:0]),
       .dbus_BUSER                      (dbus_BUSER[AXI_USER_WIDTH-1:0]),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_dce                     (msr_psr_dce),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[CONFIG_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[CONFIG_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we));
   
   /* cmt_epu AUTO_TEMPLATE(
         .cmt_req_valid                (epu_req_valid),
         .cmt_wdat                     (cmt_operb[]),
         .cmt_addr                     (cmt_opera[]),
         .cmt_fe                       (cmt_opera[`NCPU_FE_W-1:0]),
         .cmt_exc                      (cmt_exc[0]),
         .cmt_npc                      (cmt_npc_0[]),
         .s2i_EDTM                     (lsu_EDTM),
         .s2i_EDPF                     (lsu_EDPF),
         .s2i_EALIGN                   (lsu_EALIGN),
         .s2i_vaddr                    (lsu_vaddr[]),
      )*/
   cmt_epu
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_EITM_VECTOR             (CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIPF_VECTOR             (CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_ESYSCALL_VECTOR         (CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EINSN_VECTOR            (CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIRQ_VECTOR             (CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDTM_VECTOR             (CONFIG_EDTM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDPF_VECTOR             (CONFIG_EDPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EALIGN_VECTOR           (CONFIG_EALIGN_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ))
   U_EPU
      (/*AUTOINST*/
       // Outputs
       .epu_wb_dout                     (epu_wb_dout[CONFIG_DW-1:0]),
       .epu_wb_dout_sel                 (epu_wb_dout_sel),
       .epu_wb_valid                    (epu_wb_valid),
       .exc_flush                       (exc_flush),
       .exc_flush_tgt                   (exc_flush_tgt[`PC_W-1:0]),
       .refetch                         (refetch),
       .irq_async                       (irq_async),
       .tsc_irq                         (tsc_irq),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_psr_ice_nxt                 (msr_psr_ice_nxt),
       .msr_psr_ice_we                  (msr_psr_ice_we),
       .msr_psr_dce_nxt                 (msr_psr_dce_nxt),
       .msr_psr_dce_we                  (msr_psr_dce_we),
       .msr_psr_save                    (msr_psr_save),
       .msr_psr_restore                 (msr_psr_restore),
       .msr_epc_nxt                     (msr_epc_nxt[CONFIG_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[CONFIG_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
       .msr_evect_nxt                   (msr_evect_nxt[CONFIG_AW-1:0]),
       .msr_evect_we                    (msr_evect_we),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_dmm_tlbl_idx                (msr_dmm_tlbl_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbl_nxt                (msr_dmm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbl_we                 (msr_dmm_tlbl_we),
       .msr_dmm_tlbh_idx                (msr_dmm_tlbh_idx[CONFIG_DTLB_P_SETS-1:0]),
       .msr_dmm_tlbh_nxt                (msr_dmm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_dmm_tlbh_we                 (msr_dmm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .msr_dcinv_nxt                   (msr_dcinv_nxt[CONFIG_DW-1:0]),
       .msr_dcinv_we                    (msr_dcinv_we),
       .msr_dcfls_nxt                   (msr_dcfls_nxt[CONFIG_DW-1:0]),
       .msr_dcfls_we                    (msr_dcfls_we),
       .msr_sr_nxt                      (msr_sr_nxt[CONFIG_DW-1:0]),
       .msr_sr_we                       (msr_sr_we[`NCPU_SR_NUM-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .p_ce_s1                         (p_ce_s1),
       .p_ce_s1_no_icinv_stall          (p_ce_s1_no_icinv_stall),
       .p_ce_s2                         (p_ce_s2),
       .cmt_pc                          (cmt_pc[`PC_W-1:0]),
       .cmt_npc                         (cmt_npc_0[`PC_W-1:0]),  // Templated
       .cmt_req_valid                   (epu_req_valid),         // Templated
       .cmt_epu_opc_bus                 (cmt_epu_opc_bus[`NCPU_EPU_IOPW-1:0]),
       .cmt_exc                         (cmt_exc[0]),            // Templated
       .cmt_fe                          (cmt_opera[`NCPU_FE_W-1:0]), // Templated
       .cmt_addr                        (cmt_opera[CONFIG_DW-1:0]), // Templated
       .cmt_wdat                        (cmt_operb[CONFIG_DW-1:0]), // Templated
       .s2i_EDTM                        (lsu_EDTM),              // Templated
       .s2i_EDPF                        (lsu_EDPF),              // Templated
       .s2i_EALIGN                      (lsu_EALIGN),            // Templated
       .s2i_vaddr                       (lsu_vaddr[CONFIG_AW-1:0]), // Templated
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_cpuid                       (msr_cpuid[CONFIG_DW-1:0]),
       .msr_epc                         (msr_epc[CONFIG_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_elsa                        (msr_elsa[CONFIG_DW-1:0]),
       .msr_evect                       (msr_evect[CONFIG_AW-1:0]),
       .msr_coreid                      (msr_coreid[CONFIG_DW-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_dmmid                       (msr_dmmid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .msr_dcid                        (msr_dcid[CONFIG_DW-1:0]),
       .msr_sr                          (msr_sr[CONFIG_DW*`NCPU_SR_NUM-1:0]));
   
   cmt_psr
      #(
        .CONFIG_DW                      (CONFIG_DW),
        .CPUID_VER                      (1),
        .CPUID_REV                      (0),
        .CPUID_FIMM                     (1),
        .CPUID_FDMM                     (1),
        .CPUID_FICA                     (1),
        .CPUID_FDCA                     (1),
        .CPUID_FDBG                     (0),
        .CPUID_FFPU                     (0),
        .CPUID_FIRQC                    (1),
        .CPUID_FTSC                     (1)
     )
   U_PSR
      (/*AUTOINST*/
       // Outputs
       .msr_psr                         (msr_psr[`NCPU_PSR_DW-1:0]),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ire                     (msr_psr_ire),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_dmme                    (msr_psr_dmme),
       .msr_psr_ice                     (msr_psr_ice),
       .msr_psr_dce                     (msr_psr_dce),
       .msr_cpuid                       (msr_cpuid[CONFIG_DW-1:0]),
       .msr_epsr                        (msr_epsr[`NCPU_PSR_DW-1:0]),
       .msr_epc                         (msr_epc[CONFIG_DW-1:0]),
       .msr_elsa                        (msr_elsa[CONFIG_DW-1:0]),
       .msr_coreid                      (msr_coreid[CONFIG_DW-1:0]),
       .msr_evect                       (msr_evect[CONFIG_DW-1:0]),
       .msr_sr                          (msr_sr[CONFIG_DW*`NCPU_SR_NUM-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .msr_psr_save                    (msr_psr_save),
       .msr_psr_restore                 (msr_psr_restore),
       .msr_psr_rm_nxt                  (msr_psr_rm_nxt),
       .msr_psr_rm_we                   (msr_psr_rm_we),
       .msr_psr_ire_nxt                 (msr_psr_ire_nxt),
       .msr_psr_ire_we                  (msr_psr_ire_we),
       .msr_psr_imme_nxt                (msr_psr_imme_nxt),
       .msr_psr_imme_we                 (msr_psr_imme_we),
       .msr_psr_dmme_nxt                (msr_psr_dmme_nxt),
       .msr_psr_dmme_we                 (msr_psr_dmme_we),
       .msr_psr_ice_nxt                 (msr_psr_ice_nxt),
       .msr_psr_ice_we                  (msr_psr_ice_we),
       .msr_psr_dce_nxt                 (msr_psr_dce_nxt),
       .msr_psr_dce_we                  (msr_psr_dce_we),
       .msr_epsr_nxt                    (msr_epsr_nxt[`NCPU_PSR_DW-1:0]),
       .msr_epsr_we                     (msr_epsr_we),
       .msr_epc_nxt                     (msr_epc_nxt[CONFIG_DW-1:0]),
       .msr_epc_we                      (msr_epc_we),
       .msr_elsa_nxt                    (msr_elsa_nxt[CONFIG_DW-1:0]),
       .msr_elsa_we                     (msr_elsa_we),
       .msr_evect_nxt                   (msr_evect_nxt[CONFIG_DW-1:0]),
       .msr_evect_we                    (msr_evect_we),
       .msr_sr_nxt                      (msr_sr_nxt[CONFIG_DW-1:0]),
       .msr_sr_we                       (msr_sr_we[`NCPU_SR_NUM-1:0]));

   // Stall if ICINV is temporarily unavailable during access
   assign icinv_stall_req = (msr_icinv_we & ~msr_icinv_ready);
       
   // Update BPU
   assign bpu_wb = (cmt_fire[0] & cmt_b[0]);
   assign bpu_wb_is_bcc = cmt_is_bcc[0];
   assign bpu_wb_is_breg = cmt_is_breg[0];
   assign bpu_wb_is_brel = cmt_is_brel[0];
   assign bpu_wb_taken = (cmt_bpu_upd[`BPU_UPD_TAKEN] ^ cmt_fls[0]); // Extract the first channel
   assign bpu_wb_pc = cmt_pc[0 +: `PC_W];
   assign bpu_wb_npc_act = (cmt_fls[0])
                              ? cmt_fls_tgt[0 * `PC_W +: `PC_W]
                              : cmt_bpu_upd[`BPU_UPD_TGT]; // Extract the first channel
   assign bpu_wb_upd = cmt_bpu_upd[0*`BPU_UPD_W +: `BPU_UPD_W];
   
       
   //
   // Pipeline stall scope:
   // +---------------------+-------------+
   // | Signal              | Scope       |
   // +---------------------+-------------+
   // | icinv_stall_req     | CMT(s1)     |
   // | lsu_stall_req       | CMT(s1,s2)  |
   // +---------------------+-------------+
   //
   assign p_ce_s1_no_icinv_stall = (~lsu_stall_req);
   assign p_ce_s1 = (p_ce_s1_no_icinv_stall & ~icinv_stall_req);
   assign p_ce_s2 = (~lsu_stall_req);
       
   assign pipe_finish = (lsu_wb_valid | epu_wb_valid);
   
   assign prf_WE_lsu_epu = (pipe_finish & ~flush & cmt_prd_we[0]);
   assign prf_WADDR_lsu_epu = cmt_prd[0*`NCPU_PRF_AW +: `NCPU_PRF_AW];
   assign prf_WDATA_lsu_epu = (epu_wb_dout_sel)
                                 ? epu_wb_dout
                                 : lsu_wb_dout;
   
`ifdef ENABLE_DIFFTEST
   wire [31:0] dbg_cmt_pc[CW-1:0];
   generate
      for(i=0;i<CW;i=i+1)  
         begin
            assign dbg_cmt_pc[i] = {cmt_pc[i*`PC_W +: `PC_W], 2'b00};
         end
   endgenerate
`endif

endmodule
