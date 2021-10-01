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

module ncpu64k
#(
   parameter                           CONFIG_AW = 32,
   parameter                           CONFIG_DW = 32,
   parameter                           CONFIG_P_DW = 5,
   parameter                           CONFIG_P_FETCH_WIDTH = 1,
   parameter                           CONFIG_P_ISSUE_WIDTH = 1,
   parameter                           CONFIG_P_PAGE_SIZE = 13,
   parameter                           CONFIG_IC_P_LINE = 6,
   parameter                           CONFIG_IC_P_SETS = 6,
   parameter                           CONFIG_IC_P_WAYS = 2,
   parameter                           CONFIG_DC_P_LINE = 6,
   parameter                           CONFIG_DC_P_SETS = 6,
   parameter                           CONFIG_DC_P_WAYS = 2,
   parameter                           CONFIG_PHT_P_NUM = 9,
   parameter                           CONFIG_BTB_P_NUM = 9,
   parameter                           CONFIG_P_IQ_DEPTH = 4,
   parameter                           CONFIG_ENABLE_MUL = 0,
   parameter                           CONFIG_ENABLE_DIV = 0,
   parameter                           CONFIG_ENABLE_DIVU = 0,
   parameter                           CONFIG_ENABLE_MOD = 0,
   parameter                           CONFIG_ENABLE_MODU = 0,
   parameter                           CONFIG_ENABLE_ASR = 0,
   parameter                           CONFIG_IMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_DMMU_ENABLE_UNCACHED_SEG = 0,
   parameter                           CONFIG_DTLB_P_SETS = 7,
   parameter                           CONFIG_ITLB_P_SETS = 7,
   parameter [CONFIG_AW-1:0]           CONFIG_PC_RST = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EITM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_ESYSCALL_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EINSN_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EIRQ_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDTM_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EDPF_VECTOR = 0,
   parameter [`EXCP_VECT_W-1:0]        CONFIG_EALIGN_VECTOR = 0,
   parameter                           CONFIG_NUM_IRQ = 32,
   parameter                           CONFIG_P_RS_DEPTH = 2,
   parameter                           CONFIG_P_ROB_DEPTH = 3,
   
   parameter                           AXI_P_DW_BYTES    = 3,
   parameter                           AXI_UNCACHED_P_DW_BYTES = 2,
   parameter                           AXI_ADDR_WIDTH    = 64,
   parameter                           AXI_ID_WIDTH      = 4,
   parameter                           AXI_USER_WIDTH    = 1
)
(
   input                               clk,
   input                               rst,
   
   // AXI Master (Inst Bus)
   input                               ibus_ARREADY,
   output                              ibus_ARVALID,
   output [AXI_ADDR_WIDTH-1:0]         ibus_ARADDR,
   output [2:0]                        ibus_ARPROT,
   output [AXI_ID_WIDTH-1:0]           ibus_ARID,
   output [AXI_USER_WIDTH-1:0]         ibus_ARUSER,
   output [7:0]                        ibus_ARLEN,
   output [2:0]                        ibus_ARSIZE,
   output [1:0]                        ibus_ARBURST,
   output                              ibus_ARLOCK,
   output [3:0]                        ibus_ARCACHE,
   output [3:0]                        ibus_ARQOS,
   output [3:0]                        ibus_ARREGION,
   output                              ibus_RREADY,
   input                               ibus_RVALID,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  ibus_RDATA,
   input                               ibus_RLAST,
   input  [1:0]                        ibus_RRESP,
   input  [AXI_ID_WIDTH-1:0]           ibus_RID,
   input  [AXI_USER_WIDTH-1:0]         ibus_RUSER,

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
   
   // IRQs
   input [CONFIG_NUM_IRQ-1:0]          irqs,
   output                              tsc_irq
);
   localparam                          CONFIG_P_WRITEBACK_WIDTH = CONFIG_P_ISSUE_WIDTH;
   localparam                          CONFIG_P_COMMIT_WIDTH = CONFIG_P_ISSUE_WIDTH;
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire                 bpu_wb;                 // From U_CMT of cmt.v
   wire                 bpu_wb_is_bcc;          // From U_CMT of cmt.v
   wire                 bpu_wb_is_breg;         // From U_CMT of cmt.v
   wire                 bpu_wb_is_brel;         // From U_CMT of cmt.v
   wire [`PC_W-1:0]     bpu_wb_npc_act;         // From U_CMT of cmt.v
   wire [`PC_W-1:0]     bpu_wb_pc;              // From U_CMT of cmt.v
   wire                 bpu_wb_taken;           // From U_CMT of cmt.v
   wire [`BPU_UPD_W-1:0] bpu_wb_upd;            // From U_CMT of cmt.v
   wire [(1<<`NCPU_PRF_AW)-1:0] busytable;      // From U_RN of rn.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_bpu_upd;// From U_ROB of rob.v
   wire [`NCPU_EPU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_epu_opc_bus;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_exc;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire;// From U_CMT of cmt.v
   wire [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls;// From U_ROB of rob.v
   wire [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fls_tgt;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_bcc;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_breg;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] cmt_is_brel;// From U_ROB of rob.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lrd;// From U_ROB of rob.v
   wire [`NCPU_LSU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lsu_opc_bus;// From U_ROB of rob.v
   wire [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_opera;// From U_ROB of rob.v
   wire [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_operb;// From U_ROB of rob.v
   wire [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pc;// From U_ROB of rob.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pfree;// From U_ROB of rob.v
   wire [CONFIG_P_COMMIT_WIDTH:0] cmt_pop_size; // From U_CMT of cmt.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_prd_we;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_valid;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ex_alu_opc_bus;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_pred_taken;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_bpu_pred_tgt;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ex_bru_opc_bus;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_op;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0] ex_fe;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_imm;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ex_lpu_opc_bus;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_op;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand1;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ex_operand2;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ex_pc;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ex_prd;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_prd_we;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_ready;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ex_rob_bank;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ex_rob_id;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid;// From U_RO of ro.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd;// From U_FNT of frontend.v
   wire [`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc;// From U_FNT of frontend.v
   wire [`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins;// From U_FNT of frontend.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc;// From U_FNT of frontend.v
   wire [CONFIG_P_ISSUE_WIDTH:0] id_pop_cnt;    // From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid;// From U_FNT of frontend.v
   wire                 irq_async;              // From U_CMT of cmt.v
   wire [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_alu_opc_bus;// From U_RN of rn.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bpu_upd;// From U_RN of rn.v
   wire [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_bru_opc_bus;// From U_RN of rn.v
   wire [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_epu_opc_bus;// From U_RN of rn.v
   wire [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_fe;// From U_RN of rn.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_imm;// From U_RN of rn.v
   wire [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lpu_opc_bus;// From U_RN of rn.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lrd;// From U_RN of rn.v
   wire [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_lsu_opc_bus;// From U_RN of rn.v
   wire                 issue_p_ce;             // From U_RN of rn.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pc;// From U_RN of rn.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_pfree;// From U_RN of rn.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd;// From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prd_we;// From U_RN of rn.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1;// From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs1_re;// From U_RN of rn.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2;// From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_prs2_re;// From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_push;// From U_RN of rn.v
   wire [CONFIG_P_ISSUE_WIDTH:0] issue_push_size;// From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] issue_ready;// From U_ISSUE of issue.v
   wire [CONFIG_DW-1:0] msr_icid;               // From U_FNT of frontend.v
   wire [CONFIG_DW-1:0] msr_icinv_nxt;          // From U_CMT of cmt.v
   wire                 msr_icinv_ready;        // From U_FNT of frontend.v
   wire                 msr_icinv_we;           // From U_CMT of cmt.v
   wire [CONFIG_ITLB_P_SETS-1:0] msr_imm_tlbh_idx;// From U_CMT of cmt.v
   wire [CONFIG_DW-1:0] msr_imm_tlbh_nxt;       // From U_CMT of cmt.v
   wire                 msr_imm_tlbh_we;        // From U_CMT of cmt.v
   wire [CONFIG_ITLB_P_SETS-1:0] msr_imm_tlbl_idx;// From U_CMT of cmt.v
   wire [CONFIG_DW-1:0] msr_imm_tlbl_nxt;       // From U_CMT of cmt.v
   wire                 msr_imm_tlbl_we;        // From U_CMT of cmt.v
   wire [CONFIG_DW-1:0] msr_immid;              // From U_FNT of frontend.v
   wire                 msr_psr_ice;            // From U_CMT of cmt.v
   wire                 msr_psr_imme;           // From U_CMT of cmt.v
   wire                 msr_psr_rm;             // From U_CMT of cmt.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_PRF_AW-1:0] prf_RADDR;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] prf_RDATA;// From U_PRF of prf.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] prf_RE;// From U_RO of ro.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WADDR;// From U_WB_MUX of wb_mux.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WADDR_ex;// From U_EX of ex.v
   wire [`NCPU_PRF_AW-1:0] prf_WADDR_lsu_epu;   // From U_CMT of cmt.v
   wire [CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WDATA;// From U_WB_MUX of wb_mux.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WDATA_ex;// From U_EX of ex.v
   wire [CONFIG_DW-1:0] prf_WDATA_lsu_epu;      // From U_CMT of cmt.v
   wire [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] prf_WE;// From U_WB_MUX of wb_mux.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] prf_WE_ex;// From U_EX of ex.v
   wire                 prf_WE_lsu_epu;         // From U_CMT of cmt.v
   wire [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_alu_opc_bus;// From U_ID of id.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bpu_upd;// From U_ID of id.v
   wire [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_bru_opc_bus;// From U_ID of id.v
   wire [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_epu_opc_bus;// From U_ID of id.v
   wire [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_fe;// From U_ID of id.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_imm;// From U_ID of id.v
   wire [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lpu_opc_bus;// From U_ID of id.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrd_we;// From U_ID of id.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs1;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs1_re;// From U_ID of id.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs2;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lrs2_re;// From U_ID of id.v
   wire [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_lsu_opc_bus;// From U_ID of id.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_pc;// From U_ID of id.v
   wire [CONFIG_P_ISSUE_WIDTH:0] rn_push_size;  // From U_ID of id.v
   wire                 rn_stall_req;           // From U_RN of rn.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rn_valid;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0] ro_alu_opc_bus;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_bpu_pred_taken;// From U_ISSUE of issue.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_bpu_pred_tgt;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0] ro_bru_opc_bus;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_epu_op;// From U_ISSUE of issue.v
   wire [`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_fe;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0] ro_imm;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0] ro_lpu_opc_bus;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_lsu_op;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0] ro_pc;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prd;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prd_we;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs1;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs1_re;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0] ro_prs2;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_prs2_re;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ready;// From U_RO of ro.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] ro_rob_bank;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] ro_rob_id;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_valid;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id;// From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0] rob_push_bpu_upd;// From U_ISSUE of issue.v
   wire [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_epu_opc_bus;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_bcc;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_breg;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_is_brel;// From U_ISSUE of issue.v
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_lrd;// From U_ISSUE of issue.v
   wire [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_lsu_opc_bus;// From U_ISSUE of issue.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pc;// From U_ISSUE of issue.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_pfree;// From U_ISSUE of issue.v
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] rob_push_prd;// From U_ISSUE of issue.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] rob_push_prd_we;// From U_ISSUE of issue.v
   wire [CONFIG_P_COMMIT_WIDTH:0] rob_push_size;// From U_ISSUE of issue.v
   wire                 rob_ready;              // From U_ROB of rob.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_exc; // From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_fls; // From U_EX of ex.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_fls_tgt;// From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_opera;// From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_operb;// From U_EX of ex.v
   wire [(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0] wb_ready;// From U_WB_MUX of wb_mux.v, ...
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] wb_rob_bank;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] wb_rob_id;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] wb_valid;// From U_EX of ex.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                flush;                  // To U_IFU of frontend.v, ...
   wire [`PC_W-1:0]                    flush_tgt;             // To U_IFU of frontend.v
   wire                                stall;                  // To U_ID of id.v, ...

   frontend
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_FETCH_WIDTH           (CONFIG_P_FETCH_WIDTH),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_IQ_DEPTH              (CONFIG_P_IQ_DEPTH),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_IC_P_LINE               (CONFIG_IC_P_LINE),
        .CONFIG_IC_P_SETS               (CONFIG_IC_P_SETS),
        .CONFIG_IC_P_WAYS               (CONFIG_IC_P_WAYS),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_PC_RST                  (CONFIG_PC_RST[CONFIG_AW-1:0]),
        .CONFIG_IMMU_ENABLE_UNCACHED_SEG(CONFIG_IMMU_ENABLE_UNCACHED_SEG),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_UNCACHED_P_DW_BYTES        (AXI_UNCACHED_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_FNT
      (/*AUTOINST*/
       // Outputs
       .id_valid                        (id_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_ins                          (id_ins[`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_pc                           (id_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_exc                          (id_exc[`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_bpu_upd                      (id_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .msr_icinv_ready                 (msr_icinv_ready),
       .ibus_ARVALID                    (ibus_ARVALID),
       .ibus_ARADDR                     (ibus_ARADDR[AXI_ADDR_WIDTH-1:0]),
       .ibus_ARPROT                     (ibus_ARPROT[2:0]),
       .ibus_ARID                       (ibus_ARID[AXI_ID_WIDTH-1:0]),
       .ibus_ARUSER                     (ibus_ARUSER[AXI_USER_WIDTH-1:0]),
       .ibus_ARLEN                      (ibus_ARLEN[7:0]),
       .ibus_ARSIZE                     (ibus_ARSIZE[2:0]),
       .ibus_ARBURST                    (ibus_ARBURST[1:0]),
       .ibus_ARLOCK                     (ibus_ARLOCK),
       .ibus_ARCACHE                    (ibus_ARCACHE[3:0]),
       .ibus_ARQOS                      (ibus_ARQOS[3:0]),
       .ibus_ARREGION                   (ibus_ARREGION[3:0]),
       .ibus_RREADY                     (ibus_RREADY),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`PC_W-1:0]),
       .id_pop_cnt                      (id_pop_cnt[CONFIG_P_ISSUE_WIDTH:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_is_bcc                   (bpu_wb_is_bcc),
       .bpu_wb_is_breg                  (bpu_wb_is_breg),
       .bpu_wb_is_brel                  (bpu_wb_is_brel),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_pc                       (bpu_wb_pc[`PC_W-1:0]),
       .bpu_wb_npc_act                  (bpu_wb_npc_act[`PC_W-1:0]),
       .bpu_wb_upd                      (bpu_wb_upd[`BPU_UPD_W-1:0]),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ice                     (msr_psr_ice),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       .ibus_ARREADY                    (ibus_ARREADY),
       .ibus_RVALID                     (ibus_RVALID),
       .ibus_RDATA                      (ibus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
       .ibus_RRESP                      (ibus_RRESP[1:0]),
       .ibus_RLAST                      (ibus_RLAST),
       .ibus_RID                        (ibus_RID[AXI_ID_WIDTH-1:0]),
       .ibus_RUSER                      (ibus_RUSER[AXI_USER_WIDTH-1:0]));

   id
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_ENABLE_MUL              (CONFIG_ENABLE_MUL),
        .CONFIG_ENABLE_DIV              (CONFIG_ENABLE_DIV),
        .CONFIG_ENABLE_DIVU             (CONFIG_ENABLE_DIVU),
        .CONFIG_ENABLE_MOD              (CONFIG_ENABLE_MOD),
        .CONFIG_ENABLE_MODU             (CONFIG_ENABLE_MODU),
        .CONFIG_ENABLE_ASR              (CONFIG_ENABLE_ASR))
   U_ID
      (/*AUTOINST*/
       // Outputs
       .id_pop_cnt                      (id_pop_cnt[CONFIG_P_ISSUE_WIDTH:0]),
       .rn_valid                        (rn_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_alu_opc_bus                  (rn_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lpu_opc_bus                  (rn_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_epu_opc_bus                  (rn_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_bru_opc_bus                  (rn_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lsu_opc_bus                  (rn_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_fe                           (rn_fe[`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_bpu_upd                      (rn_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_pc                           (rn_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_imm                          (rn_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrs1                         (rn_lrs1[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrs2                         (rn_lrs2[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrs1_re                      (rn_lrs1_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrs2_re                      (rn_lrs2_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrd                          (rn_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrd_we                       (rn_lrd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_push_size                    (rn_push_size[CONFIG_P_ISSUE_WIDTH:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .rn_stall_req                    (rn_stall_req),
       .id_valid                        (id_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_ins                          (id_ins[`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_pc                           (id_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_exc                          (id_exc[`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_bpu_upd                      (id_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .irq_async                       (irq_async));
      
   rn
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_P_WRITEBACK_WIDTH       (CONFIG_P_WRITEBACK_WIDTH))
   U_RN
      (/*AUTOINST*/
       // Outputs
       .rn_stall_req                    (rn_stall_req),
       .issue_p_ce                      (issue_p_ce),
       .issue_alu_opc_bus               (issue_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lpu_opc_bus               (issue_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_epu_opc_bus               (issue_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_bru_opc_bus               (issue_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lsu_opc_bus               (issue_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_fe                        (issue_fe[`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_bpu_upd                   (issue_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_pc                        (issue_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_imm                       (issue_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs1                      (issue_prs1[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs1_re                   (issue_prs1_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs2                      (issue_prs2[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs2_re                   (issue_prs2_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lrd                       (issue_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prd                       (issue_prd[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prd_we                    (issue_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_pfree                     (issue_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_push                      (issue_push[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_push_size                 (issue_push_size[CONFIG_P_ISSUE_WIDTH:0]),
       .busytable                       (busytable[(1<<`NCPU_PRF_AW)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .rn_valid                        (rn_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_alu_opc_bus                  (rn_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lpu_opc_bus                  (rn_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_epu_opc_bus                  (rn_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_bru_opc_bus                  (rn_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lsu_opc_bus                  (rn_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_fe                           (rn_fe[`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_bpu_upd                      (rn_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_pc                           (rn_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_imm                          (rn_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrs1                         (rn_lrs1[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0]),
       .rn_lrs1_re                      (rn_lrs1_re[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rn_lrs2                         (rn_lrs2[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0]),
       .rn_lrs2_re                      (rn_lrs2_re[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rn_lrd                          (rn_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_lrd_we                       (rn_lrd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rn_push_size                    (rn_push_size[CONFIG_P_ISSUE_WIDTH:0]),
       .cmt_fire                        (cmt_fire[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_lrd                         (cmt_lrd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_LRF_AW-1:0]),
       .cmt_pfree                       (cmt_pfree[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .cmt_prd                         (cmt_prd[(1<<CONFIG_P_COMMIT_WIDTH)*`NCPU_PRF_AW-1:0]),
       .cmt_prd_we                      (cmt_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .prf_WADDR                       (prf_WADDR[(1<<CONFIG_P_WRITEBACK_WIDTH)*`NCPU_PRF_AW-1:0]),
       .prf_WE                          (prf_WE[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .issue_ready                     (issue_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]));
   
   issue
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_P_ROB_DEPTH             (CONFIG_P_ROB_DEPTH),
        .CONFIG_P_RS_DEPTH              (CONFIG_P_RS_DEPTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM))
   U_ISSUE
      (/*AUTOINST*/
       // Outputs
       .issue_ready                     (issue_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_epu_opc_bus            (rob_push_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_lsu_opc_bus            (rob_push_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_bpu_upd                (rob_push_bpu_upd[(1<<CONFIG_P_ISSUE_WIDTH)*`BPU_UPD_W-1:0]),
       .rob_push_pc                     (rob_push_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_lrd                    (rob_push_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rob_push_prd                    (rob_push_prd[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rob_push_prd_we                 (rob_push_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_pfree                  (rob_push_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_bcc                 (rob_push_is_bcc[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_brel                (rob_push_is_brel[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_breg                (rob_push_is_breg[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_size                   (rob_push_size[CONFIG_P_COMMIT_WIDTH:0]),
       .ro_alu_opc_bus                  (ro_alu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0]),
       .ro_bpu_pred_taken               (ro_bpu_pred_taken[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_bpu_pred_tgt                 (ro_bpu_pred_tgt[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_bru_opc_bus                  (ro_bru_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0]),
       .ro_epu_op                       (ro_epu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_imm                          (ro_imm[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ro_lpu_opc_bus                  (ro_lpu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0]),
       .ro_lsu_op                       (ro_lsu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_fe                           (ro_fe[`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_pc                           (ro_pc[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ro_prd                          (ro_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prd_we                       (ro_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_prs1                         (ro_prs1[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prs1_re                      (ro_prs1_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_prs2                         (ro_prs2[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prs2_re                      (ro_prs2_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_rob_id                       (ro_rob_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .ro_rob_bank                     (ro_rob_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .ro_valid                        (ro_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .issue_p_ce                      (issue_p_ce),
       .issue_alu_opc_bus               (issue_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lpu_opc_bus               (issue_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_epu_opc_bus               (issue_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_bru_opc_bus               (issue_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lsu_opc_bus               (issue_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_fe                        (issue_fe[`NCPU_FE_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_bpu_upd                   (issue_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_pc                        (issue_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_imm                       (issue_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs1                      (issue_prs1[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs1_re                   (issue_prs1_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs2                      (issue_prs2[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prs2_re                   (issue_prs2_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_lrd                       (issue_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prd                       (issue_prd[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_prd_we                    (issue_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_pfree                     (issue_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_push                      (issue_push[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .issue_push_size                 (issue_push_size[CONFIG_P_ISSUE_WIDTH:0]),
       .busytable                       (busytable[(1<<`NCPU_PRF_AW)-1:0]),
       .rob_ready                       (rob_ready),
       .rob_free_id                     (rob_free_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .rob_free_bank                   (rob_free_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .ro_ready                        (ro_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]));
   
   ro
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_P_ROB_DEPTH             (CONFIG_P_ROB_DEPTH),
        .CONFIG_P_RS_DEPTH              (CONFIG_P_RS_DEPTH))
   U_RO
      (/*AUTOINST*/
       // Outputs
       .ro_ready                        (ro_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .prf_RE                          (prf_RE[(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0]),
       .prf_RADDR                       (prf_RADDR[(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_PRF_AW-1:0]),
       .ex_alu_opc_bus                  (ex_alu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0]),
       .ex_bpu_pred_taken               (ex_bpu_pred_taken[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bpu_pred_tgt                 (ex_bpu_pred_tgt[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ex_bru_opc_bus                  (ex_bru_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0]),
       .ex_epu_op                       (ex_epu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_imm                          (ex_imm[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_lpu_opc_bus                  (ex_lpu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0]),
       .ex_lsu_op                       (ex_lsu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_fe                           (ex_fe[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0]),
       .ex_pc                           (ex_pc[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ex_prd                          (ex_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ex_prd_we                       (ex_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand1                     (ex_operand1[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_operand2                     (ex_operand2[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_rob_id                       (ex_rob_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .ex_rob_bank                     (ex_rob_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .ex_valid                        (ex_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .ro_alu_opc_bus                  (ro_alu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0]),
       .ro_bpu_pred_taken               (ro_bpu_pred_taken[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_bpu_pred_tgt                 (ro_bpu_pred_tgt[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ro_bru_opc_bus                  (ro_bru_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0]),
       .ro_epu_op                       (ro_epu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_imm                          (ro_imm[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ro_lpu_opc_bus                  (ro_lpu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0]),
       .ro_lsu_op                       (ro_lsu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_fe                           (ro_fe[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0]),
       .ro_pc                           (ro_pc[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ro_prd                          (ro_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prd_we                       (ro_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_prs1                         (ro_prs1[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prs1_re                      (ro_prs1_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_prs2                         (ro_prs2[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ro_prs2_re                      (ro_prs2_re[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_rob_id                       (ro_rob_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .ro_rob_bank                     (ro_rob_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .ro_valid                        (ro_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .prf_RDATA                       (prf_RDATA[(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0]),
       .ex_ready                        (ex_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]));
      
   ex
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_P_ROB_DEPTH             (CONFIG_P_ROB_DEPTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_ENABLE_MUL              (CONFIG_ENABLE_MUL),
        .CONFIG_ENABLE_DIV              (CONFIG_ENABLE_DIV),
        .CONFIG_ENABLE_DIVU             (CONFIG_ENABLE_DIVU),
        .CONFIG_ENABLE_MOD              (CONFIG_ENABLE_MOD),
        .CONFIG_ENABLE_MODU             (CONFIG_ENABLE_MODU),
        .CONFIG_ENABLE_ASR              (CONFIG_ENABLE_ASR))
   U_EX
      (/*AUTOINST*/
       // Outputs
       .ex_ready                        (ex_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_valid                        (wb_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_rob_id                       (wb_rob_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .wb_rob_bank                     (wb_rob_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .wb_fls                          (wb_fls[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_exc                          (wb_exc[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_opera                        (wb_opera[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_operb                        (wb_operb[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_fls_tgt                      (wb_fls_tgt[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .prf_WADDR_ex                    (prf_WADDR_ex[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .prf_WDATA_ex                    (prf_WDATA_ex[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .prf_WE_ex                       (prf_WE_ex[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .ex_alu_opc_bus                  (ex_alu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_ALU_IOPW-1:0]),
       .ex_bpu_pred_taken               (ex_bpu_pred_taken[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bpu_pred_tgt                 (ex_bpu_pred_tgt[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ex_bru_opc_bus                  (ex_bru_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_BRU_IOPW-1:0]),
       .ex_epu_op                       (ex_epu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_imm                          (ex_imm[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_lpu_opc_bus                  (ex_lpu_opc_bus[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_LPU_IOPW-1:0]),
       .ex_lsu_op                       (ex_lsu_op[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_fe                           (ex_fe[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_FE_W-1:0]),
       .ex_pc                           (ex_pc[(1<<CONFIG_P_ISSUE_WIDTH)*`PC_W-1:0]),
       .ex_prd                          (ex_prd[(1<<CONFIG_P_ISSUE_WIDTH)*`NCPU_PRF_AW-1:0]),
       .ex_prd_we                       (ex_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand1                     (ex_operand1[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_operand2                     (ex_operand2[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_DW-1:0]),
       .ex_rob_id                       (ex_rob_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .ex_rob_bank                     (ex_rob_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .ex_valid                        (ex_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_ready                        (wb_ready[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]));
   
   wb_mux
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_WRITEBACK_WIDTH       (CONFIG_P_WRITEBACK_WIDTH))
   U_WB_MUX
      (/*AUTOINST*/
       // Outputs
       .wb_ready                        (wb_ready[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WE                          (prf_WE[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WADDR                       (prf_WADDR[`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WDATA                       (prf_WDATA[CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       // Inputs
       .prf_WE_ex                       (prf_WE_ex[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WADDR_ex                    (prf_WADDR_ex[`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WDATA_ex                    (prf_WDATA_ex[CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WE_lsu_epu                  (prf_WE_lsu_epu),
       .prf_WADDR_lsu_epu               (prf_WADDR_lsu_epu[`NCPU_PRF_AW-1:0]),
       .prf_WDATA_lsu_epu               (prf_WDATA_lsu_epu[CONFIG_DW-1:0]));
   
   cmt
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_EITM_VECTOR             (CONFIG_EITM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIPF_VECTOR             (CONFIG_EIPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_ESYSCALL_VECTOR         (CONFIG_ESYSCALL_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EINSN_VECTOR            (CONFIG_EINSN_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EIRQ_VECTOR             (CONFIG_EIRQ_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDTM_VECTOR             (CONFIG_EDTM_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EDPF_VECTOR             (CONFIG_EDPF_VECTOR[`EXCP_VECT_W-1:0]),
        .CONFIG_EALIGN_VECTOR           (CONFIG_EALIGN_VECTOR[`EXCP_VECT_W-1:0]),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_CMT
      (/*AUTOINST*/
       // Outputs
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`PC_W-1:0]),
       .cmt_pop_size                    (cmt_pop_size[CONFIG_P_COMMIT_WIDTH:0]),
       .cmt_fire                        (cmt_fire[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .prf_WE_lsu_epu                  (prf_WE_lsu_epu),
       .prf_WADDR_lsu_epu               (prf_WADDR_lsu_epu[`NCPU_PRF_AW-1:0]),
       .prf_WDATA_lsu_epu               (prf_WDATA_lsu_epu[CONFIG_DW-1:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_is_bcc                   (bpu_wb_is_bcc),
       .bpu_wb_is_breg                  (bpu_wb_is_breg),
       .bpu_wb_is_brel                  (bpu_wb_is_brel),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_pc                       (bpu_wb_pc[`PC_W-1:0]),
       .bpu_wb_npc_act                  (bpu_wb_npc_act[`PC_W-1:0]),
       .bpu_wb_upd                      (bpu_wb_upd[`BPU_UPD_W-1:0]),
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
       .irq_async                       (irq_async),
       .tsc_irq                         (tsc_irq),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_psr_ice                     (msr_psr_ice),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .cmt_valid                       (cmt_valid[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_epu_opc_bus                 (cmt_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_lsu_opc_bus                 (cmt_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_bpu_upd                     (cmt_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_pc                          (cmt_pc[`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd                         (cmt_prd[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd_we                      (cmt_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_pfree                       (cmt_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_is_bcc                      (cmt_is_bcc[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_is_brel                     (cmt_is_brel[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_is_breg                     (cmt_is_breg[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_fls                         (cmt_fls[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_exc                         (cmt_exc[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_opera                       (cmt_opera[CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_operb                       (cmt_operb[CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_fls_tgt                     (cmt_fls_tgt[`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
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
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
       .msr_icinv_ready                 (msr_icinv_ready));
       
   rob
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_P_WRITEBACK_WIDTH       (CONFIG_P_WRITEBACK_WIDTH),
        .CONFIG_P_ROB_DEPTH             (CONFIG_P_ROB_DEPTH))
   U_ROB
      (/*AUTOINST*/
       // Outputs
       .rob_ready                       (rob_ready),
       .rob_free_id                     (rob_free_id[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .rob_free_bank                   (rob_free_bank[(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .wb_ready                        (wb_ready[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .cmt_valid                       (cmt_valid[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_epu_opc_bus                 (cmt_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_lsu_opc_bus                 (cmt_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_bpu_upd                     (cmt_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_pc                          (cmt_pc[`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_lrd                         (cmt_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd                         (cmt_prd[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_prd_we                      (cmt_prd_we[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_pfree                       (cmt_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_is_bcc                      (cmt_is_bcc[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_is_brel                     (cmt_is_brel[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_is_breg                     (cmt_is_breg[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .cmt_fls                         (cmt_fls[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_exc                         (cmt_exc[(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_opera                       (cmt_opera[CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_operb                       (cmt_operb[CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .cmt_fls_tgt                     (cmt_fls_tgt[`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .rob_push_size                   (rob_push_size[CONFIG_P_ISSUE_WIDTH:0]),
       .rob_push_epu_opc_bus            (rob_push_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_lsu_opc_bus            (rob_push_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_bpu_upd                (rob_push_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_pc                     (rob_push_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_lrd                    (rob_push_lrd[`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rob_push_prd                    (rob_push_prd[`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0]),
       .rob_push_prd_we                 (rob_push_prd_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_pfree                  (rob_push_pfree[`NCPU_PRF_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_bcc                 (rob_push_is_bcc[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_brel                (rob_push_is_brel[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .rob_push_is_breg                (rob_push_is_breg[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .wb_valid                        (wb_valid[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .wb_rob_id                       (wb_rob_id[(1<<CONFIG_P_WRITEBACK_WIDTH)*CONFIG_P_ROB_DEPTH-1:0]),
       .wb_rob_bank                     (wb_rob_bank[(1<<CONFIG_P_WRITEBACK_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0]),
       .wb_fls                          (wb_fls[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .wb_exc                          (wb_exc[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .wb_opera                        (wb_opera[CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .wb_operb                        (wb_operb[CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .wb_fls_tgt                      (wb_fls_tgt[`PC_W*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .cmt_pop_size                    (cmt_pop_size[CONFIG_P_COMMIT_WIDTH:0]));
       
   prf
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_WRITEBACK_WIDTH       (CONFIG_P_WRITEBACK_WIDTH))
   U_PRF
      (/*AUTOINST*/
       // Outputs
       .prf_RDATA                       (prf_RDATA[(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .prf_RE                          (prf_RE[(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0]),
       .prf_RADDR                       (prf_RADDR[(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_PRF_AW-1:0]),
       .prf_WE                          (prf_WE[(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WADDR                       (prf_WADDR[`NCPU_PRF_AW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]),
       .prf_WDATA                       (prf_WDATA[CONFIG_DW*(1<<CONFIG_P_WRITEBACK_WIDTH)-1:0]));
       
`ifdef ENABLE_DIFFTEST
   wire [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] dft_cmtf_lrd;
   wire [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] dft_cmtf_lrd_dat;
   wire [`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] dft_cmtf_prd;

   mDFF #(.DW(`NCPU_PRF_AW*(1<<CONFIG_P_COMMIT_WIDTH))) ff_dft_cmtf_prd (.CLK(clk), .D(U_CMT.cmt_prd), .Q(dft_cmtf_prd) );
   generate
      for(genvar i=0;i<(1<<CONFIG_P_COMMIT_WIDTH);i=i+1)
         begin
            assign dft_cmtf_lrd[i*`NCPU_LRF_AW +: `NCPU_LRF_AW] = U_RN.U_RAT.arat_inv[dft_cmtf_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]];
            assign dft_cmtf_lrd_dat[i*CONFIG_DW +: CONFIG_DW] = U_PRF.U_PRF.regfile[dft_cmtf_prd[i*`NCPU_PRF_AW +: `NCPU_PRF_AW]];
         end 
   endgenerate
   
   difftest
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_P_COMMIT_WIDTH          (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ),
        .CONFIG_P_ROB_DEPTH             (CONFIG_P_ROB_DEPTH))
   U_DIFFTEST
      (
         .clk                             (clk),
         .rst                             (rst),
         .id_ins                          (U_ID.id_ins),
         .id_p_ce                         (U_ID.p_ce),
         .rn_p_ce_s1                      (U_RN.p_ce_s1),
         .rob_free_id                     (U_ROB.rob_free_id),
         .rob_free_bank                   (U_ROB.rob_free_bank),
         .rob_push_size                   (U_ROB.rob_push_size),
         .rob_head_l                      (U_ROB.head_l),
         .rob_que_rptr                    (U_ROB.que_rptr),
         .cmt_dft_fire                    (U_CMT.cmt_dft_fire),
         .cmt_exc_flush                   (U_CMT.exc_flush),
         .cmt_pc                          (U_CMT.cmt_pc),
         .cmtf_lrd                        (dft_cmtf_lrd),
         .cmtf_lrd_dat                    (dft_cmtf_lrd_dat),
         .cmt_lrd_we                      (U_CMT.cmt_prd_we),
         .cmt_p_ce_s1                     (U_CMT.p_ce_s1),
         .msr_irqc_irr                    (U_CMT.U_EPU.msr_irqc_irr)
      );
`endif

endmodule
