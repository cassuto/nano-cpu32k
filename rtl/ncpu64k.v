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
   parameter [CONFIG_AW-1:0]           CONFIG_ERST_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EITM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_ESYSCALL_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EINSN_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EIRQ_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDTM_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EDPF_VECTOR = 0,
   parameter [CONFIG_AW-1:0]           CONFIG_EALIGN_VECTOR = 0,
   parameter                           CONFIG_NUM_IRQ = 32,
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
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_REG_AW-1:0] arf_RADDR;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0] arf_RE;// From U_ID of id.v
   wire                 bpu_wb;                 // From U_EX of ex.v
   wire                 bpu_wb_is_bcc;          // From U_EX of ex.v
   wire                 bpu_wb_is_breg;         // From U_EX of ex.v
   wire                 bpu_wb_is_brel;         // From U_EX of ex.v
   wire [`PC_W-1:0]     bpu_wb_npc_act;         // From U_EX of ex.v
   wire [`PC_W-1:0]     bpu_wb_pc;              // From U_EX of ex.v
   wire                 bpu_wb_taken;           // From U_EX of ex.v
   wire [`BPU_UPD_W-1:0] bpu_wb_upd;            // From U_EX of ex.v
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr;// From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we;// From U_EX of ex.v
   wire [`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_alu_opc_bus;// From U_ID of id.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bpu_upd;// From U_ID of id.v
   wire [`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_bru_opc_bus;// From U_ID of id.v
   wire [`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_epu_opc_bus;// From U_ID of id.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_imm;// From U_ID of id.v
   wire [`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lpu_opc_bus;// From U_ID of id.v
   wire [`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_lsu_opc_bus;// From U_ID of id.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand1;// From U_ID of id.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_operand2;// From U_ID of id.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_pc;// From U_ID of id.v
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_waddr;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_rf_we;// From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ex_valid;// From U_ID of id.v
   wire                 icop_stall_req;         // From U_FNT of frontend.v
   wire [`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_bpu_upd;// From U_FNT of frontend.v
   wire [`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_exc;// From U_FNT of frontend.v
   wire [`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins;// From U_FNT of frontend.v
   wire [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_pc;// From U_FNT of frontend.v
   wire [CONFIG_P_ISSUE_WIDTH:0] id_pop_cnt;    // From U_ID of id.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_valid;// From U_FNT of frontend.v
   wire                 irq_async;              // From U_EX of ex.v
   wire [CONFIG_DW-1:0] msr_icid;               // From U_FNT of frontend.v
   wire [CONFIG_DW-1:0] msr_icinv_nxt;          // From U_EX of ex.v
   wire                 msr_icinv_we;           // From U_EX of ex.v
   wire [CONFIG_ITLB_P_SETS-1:0] msr_imm_tlbh_idx;// From U_EX of ex.v
   wire [CONFIG_DW-1:0] msr_imm_tlbh_nxt;       // From U_EX of ex.v
   wire                 msr_imm_tlbh_we;        // From U_EX of ex.v
   wire [CONFIG_ITLB_P_SETS-1:0] msr_imm_tlbl_idx;// From U_EX of ex.v
   wire [CONFIG_DW-1:0] msr_imm_tlbl_nxt;       // From U_EX of ex.v
   wire                 msr_imm_tlbl_we;        // From U_EX of ex.v
   wire [CONFIG_DW-1:0] msr_immid;              // From U_FNT of frontend.v
   wire                 msr_psr_imme;           // From U_EX of ex.v
   wire                 msr_psr_rm;             // From U_EX of ex.v
   wire                 ro_ex_s1_load0;         // From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_dout;// From U_EX of ex.v
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_waddr;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s1_rf_we;// From U_EX of ex.v
   wire                 ro_ex_s2_load0;         // From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_dout;// From U_EX of ex.v
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_waddr;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s2_rf_we;// From U_EX of ex.v
   wire [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_waddr;// From U_EX of ex.v
   wire [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_wdat;// From U_EX of ex.v
   wire [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] ro_ex_s3_rf_we;// From U_EX of ex.v
   // End of automatics
   /*AUTOINPUT*/
   wire                                flush;                  // To U_IFU of frontend.v, ...
   wire [`PC_W-1:0]                    flush_tgt;             // To U_IFU of frontend.v
   wire                                stall;                  // To U_ID of id.v, ...
   wire [(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0] arf_RDATA;// To U_ID of id.v

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
        .CONFIG_ERST_VECTOR             (CONFIG_ERST_VECTOR[CONFIG_AW-1:0]),
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
       .icop_stall_req                  (icop_stall_req),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
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
       .ex_valid                        (ex_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_alu_opc_bus                  (ex_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_lpu_opc_bus                  (ex_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_epu_opc_bus                  (ex_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bru_opc_bus                  (ex_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_lsu_opc_bus                  (ex_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bpu_upd                      (ex_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_pc                           (ex_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_imm                          (ex_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand1                     (ex_operand1[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand2                     (ex_operand2[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_rf_waddr                     (ex_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_rf_we                        (ex_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .arf_RE                          (arf_RE[(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0]),
       .arf_RADDR                       (arf_RADDR[(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_REG_AW-1:0]),
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .flush                           (flush),
       .stall                           (stall),
       .id_valid                        (id_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_ins                          (id_ins[`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_pc                           (id_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_exc                          (id_exc[`FNT_EXC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .id_bpu_upd                      (id_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .irq_async                       (irq_async),
       .ro_ex_s1_rf_dout                (ro_ex_s1_rf_dout[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_dout                (ro_ex_s2_rf_dout[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_wdat                (ro_ex_s3_rf_wdat[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_rf_we                  (ro_ex_s1_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_we                  (ro_ex_s2_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_we                  (ro_ex_s3_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_rf_waddr               (ro_ex_s1_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_waddr               (ro_ex_s2_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_waddr               (ro_ex_s3_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_load0                  (ro_ex_s1_load0),
       .ro_ex_s2_load0                  (ro_ex_s2_load0),
       .arf_RDATA                       (arf_RDATA[(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0]));
      
   ex
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_AW                      (CONFIG_AW),
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_DW                    (CONFIG_P_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH),
        .CONFIG_PHT_P_NUM               (CONFIG_PHT_P_NUM),
        .CONFIG_BTB_P_NUM               (CONFIG_BTB_P_NUM),
        .CONFIG_ENABLE_MUL              (CONFIG_ENABLE_MUL),
        .CONFIG_ENABLE_DIV              (CONFIG_ENABLE_DIV),
        .CONFIG_ENABLE_DIVU             (CONFIG_ENABLE_DIVU),
        .CONFIG_ENABLE_MOD              (CONFIG_ENABLE_MOD),
        .CONFIG_ENABLE_MODU             (CONFIG_ENABLE_MODU),
        .CONFIG_ENABLE_ASR              (CONFIG_ENABLE_ASR),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ),
        .CONFIG_DC_P_WAYS               (CONFIG_DC_P_WAYS),
        .CONFIG_DC_P_SETS               (CONFIG_DC_P_SETS),
        .CONFIG_DC_P_LINE               (CONFIG_DC_P_LINE),
        .CONFIG_P_PAGE_SIZE             (CONFIG_P_PAGE_SIZE),
        .CONFIG_DMMU_ENABLE_UNCACHED_SEG(CONFIG_DMMU_ENABLE_UNCACHED_SEG),
        .CONFIG_ITLB_P_SETS             (CONFIG_ITLB_P_SETS),
        .CONFIG_DTLB_P_SETS             (CONFIG_DTLB_P_SETS),
        .CONFIG_EITM_VECTOR             (CONFIG_EITM_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EIPF_VECTOR             (CONFIG_EIPF_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_ESYSCALL_VECTOR         (CONFIG_ESYSCALL_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EINSN_VECTOR            (CONFIG_EINSN_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EIRQ_VECTOR             (CONFIG_EIRQ_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EDTM_VECTOR             (CONFIG_EDTM_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EDPF_VECTOR             (CONFIG_EDPF_VECTOR[CONFIG_AW-1:0]),
        .CONFIG_EALIGN_VECTOR           (CONFIG_EALIGN_VECTOR[CONFIG_AW-1:0]),
        .AXI_P_DW_BYTES                 (AXI_P_DW_BYTES),
        .AXI_ADDR_WIDTH                 (AXI_ADDR_WIDTH),
        .AXI_ID_WIDTH                   (AXI_ID_WIDTH),
        .AXI_USER_WIDTH                 (AXI_USER_WIDTH))
   U_EX
      (/*AUTOINST*/
       // Outputs
       .stall                           (stall),
       .flush                           (flush),
       .flush_tgt                       (flush_tgt[`PC_W-1:0]),
       .ro_ex_s1_rf_dout                (ro_ex_s1_rf_dout[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_dout                (ro_ex_s2_rf_dout[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_wdat                (ro_ex_s3_rf_wdat[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_rf_we                  (ro_ex_s1_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_we                  (ro_ex_s2_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_we                  (ro_ex_s3_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_rf_waddr               (ro_ex_s1_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s2_rf_waddr               (ro_ex_s2_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s3_rf_waddr               (ro_ex_s3_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ro_ex_s1_load0                  (ro_ex_s1_load0),
       .ro_ex_s2_load0                  (ro_ex_s2_load0),
       .commit_rf_wdat                  (commit_rf_wdat[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .commit_rf_waddr                 (commit_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .commit_rf_we                    (commit_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .bpu_wb                          (bpu_wb),
       .bpu_wb_is_bcc                   (bpu_wb_is_bcc),
       .bpu_wb_is_breg                  (bpu_wb_is_breg),
       .bpu_wb_is_brel                  (bpu_wb_is_brel),
       .bpu_wb_taken                    (bpu_wb_taken),
       .bpu_wb_pc                       (bpu_wb_pc[`PC_W-1:0]),
       .bpu_wb_npc_act                  (bpu_wb_npc_act[`PC_W-1:0]),
       .bpu_wb_upd                      (bpu_wb_upd[`BPU_UPD_W-1:0]),
       .irq_async                       (irq_async),
       .tsc_irq                         (tsc_irq),
       .msr_psr_imme                    (msr_psr_imme),
       .msr_psr_rm                      (msr_psr_rm),
       .msr_imm_tlbl_idx                (msr_imm_tlbl_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbl_nxt                (msr_imm_tlbl_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbl_we                 (msr_imm_tlbl_we),
       .msr_imm_tlbh_idx                (msr_imm_tlbh_idx[CONFIG_ITLB_P_SETS-1:0]),
       .msr_imm_tlbh_nxt                (msr_imm_tlbh_nxt[CONFIG_DW-1:0]),
       .msr_imm_tlbh_we                 (msr_imm_tlbh_we),
       .msr_icinv_nxt                   (msr_icinv_nxt[CONFIG_DW-1:0]),
       .msr_icinv_we                    (msr_icinv_we),
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
       // Inputs
       .clk                             (clk),
       .rst                             (rst),
       .ex_valid                        (ex_valid[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_alu_opc_bus                  (ex_alu_opc_bus[`NCPU_ALU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_lpu_opc_bus                  (ex_lpu_opc_bus[`NCPU_LPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_epu_opc_bus                  (ex_epu_opc_bus[`NCPU_EPU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bru_opc_bus                  (ex_bru_opc_bus[`NCPU_BRU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_lsu_opc_bus                  (ex_lsu_opc_bus[`NCPU_LSU_IOPW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_bpu_upd                      (ex_bpu_upd[`BPU_UPD_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_pc                           (ex_pc[`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_imm                          (ex_imm[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand1                     (ex_operand1[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_operand2                     (ex_operand2[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_rf_waddr                     (ex_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .ex_rf_we                        (ex_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .icop_stall_req                  (icop_stall_req),
       .irqs                            (irqs[CONFIG_NUM_IRQ-1:0]),
       .msr_immid                       (msr_immid[CONFIG_DW-1:0]),
       .msr_icid                        (msr_icid[CONFIG_DW-1:0]),
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
       .dbus_BUSER                      (dbus_BUSER[AXI_USER_WIDTH-1:0]));
   
   cmt
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_DW                      (CONFIG_DW),
        .CONFIG_P_ISSUE_WIDTH           (CONFIG_P_ISSUE_WIDTH))
   U_CMT
      (
       // Outputs
       .arf_RDATA                       (arf_RDATA[(1<<CONFIG_P_ISSUE_WIDTH)*2*CONFIG_DW-1:0]),
       // Inputs
       .clk                             (clk),
       .stall                           (stall),
`ifdef ENABLE_DIFFTEST
       .commit_valid                    (U_EX.commit_valid),
       .commit_pc                       (U_EX.commit_pc),
`endif
       .commit_rf_wdat                  (commit_rf_wdat[CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .commit_rf_waddr                 (commit_rf_waddr[`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .commit_rf_we                    (commit_rf_we[(1<<CONFIG_P_ISSUE_WIDTH)-1:0]),
       .arf_RE                          (arf_RE[(1<<CONFIG_P_ISSUE_WIDTH)*2-1:0]),
       .arf_RADDR                       (arf_RADDR[(1<<CONFIG_P_ISSUE_WIDTH)*2*`NCPU_REG_AW-1:0]));

endmodule
