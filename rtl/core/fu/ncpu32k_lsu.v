/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module ncpu32k_lsu
#(
   parameter CONFIG_DBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_BYTES_LOG2
   `PARAM_NOT_SPECIFIED , /* = log2(CONFIG_DBUS_DW/8) */
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DMMU_PAGE_SIZE_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DMMU_ENABLE_UNCACHED_SEG
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DTLB_NSETS_LOG2
   `PARAM_NOT_SPECIFIED , // (2^CONFIG_DTLB_NSETS_LOG2) entries
   parameter CONFIG_DCACHE_P_LINE
   `PARAM_NOT_SPECIFIED , /* = log2(Size of a line) */
   parameter CONFIG_DCACHE_P_SETS
   `PARAM_NOT_SPECIFIED   /* = log2(Number of sets) */
)
(
   input                               clk,
   input                               rst_n,
   input                               stall_bck_nolsu,
   output                              lsu_stall,
   // From SCHEDULER
   input                               lsu_flush,
   input                               lsu_AVALID,
   input                               lsu_load,
   input                               lsu_store,
   input                               lsu_sign_ext,
   input                               lsu_barr,
   input [2:0]                         lsu_store_size,
   input [2:0]                         lsu_load_size,
   input [`NCPU_DW-1:0]                lsu_operand1,
   input [`NCPU_DW-1:0]                lsu_operand2,
   input [`NCPU_DW-1:0]                lsu_imm32,
   input [`NCPU_AW-3:0]                lsu_pc,
   input                               lsu_in_slot_1,
   // Async D-Bus Master
   input                               dbus_clk,
   input                               dbus_rst_n,   
   input                               dbus_AREADY,
   output                              dbus_AVALID,
   output [CONFIG_DBUS_AW-1:0]         dbus_AADDR,
   output [CONFIG_DBUS_DW/8-1:0]       dbus_AWMSK,
   output [CONFIG_DCACHE_P_LINE-1:0]   dbus_ALEN,
   output [CONFIG_DBUS_DW-1:0]         dbus_WDATA,
   input                               dbus_BVALID,
   output                              dbus_BREADY,
   input [CONFIG_DBUS_DW-1:0]          dbus_BDATA,
   input                               dbus_BWE,
   // Sync Uncached D-Bus master
   input                               uncached_dbus_AREADY,
   output                              uncached_dbus_AVALID,
   output [`NCPU_AW-1:0]               uncached_dbus_AADDR,
   output [`NCPU_DW/8-1:0]             uncached_dbus_AWMSK,
   output [`NCPU_DW-1:0]               uncached_dbus_ADATA,
   input                               uncached_dbus_BVALID,
   output                              uncached_dbus_BREADY,
   input [`NCPU_DW-1:0]                uncached_dbus_BDATA,
   // To WB
   output                              wb_lsu_AVALID,
   output                              wb_lsu_EDTM,
   output                              wb_lsu_EDPF,
   output                              wb_lsu_EALIGN,
   output [`NCPU_DW-1:0]               wb_lsu_dout,
   output [`NCPU_AW-3:0]               wb_lsu_pc,
   output                              wb_lsu_in_slot_1,
   output [`NCPU_AW-1:0]               wb_lsu_LSA,
   // PSR
   input                               msr_psr_dmme,
   input                               msr_psr_rm,
   // DMMID
   output [`NCPU_DW-1:0]               msr_dmmid,
   // DTLBL
   input [`NCPU_TLB_AW-1:0]            msr_dmm_tlbl_idx,
   input [`NCPU_DW-1:0]                msr_dmm_tlbl_nxt,
   input                               msr_dmm_tlbl_we,
   // DTLBH
   input [`NCPU_TLB_AW-1:0]            msr_dmm_tlbh_idx,
   input [`NCPU_DW-1:0]                msr_dmm_tlbh_nxt,
   input                               msr_dmm_tlbh_we
);
   wire                                dc_stall;
   wire                                dc_en;
   wire [`NCPU_AW-1:0]                 dc_vaddr;
   wire [`NCPU_DW/8-1:0]               dc_wmsk;
   wire [`NCPU_DW-1:0]                 dc_wdat;
   wire [`NCPU_DW-1:0]                 dc_rdat;
   wire                                tlb_uncached;
   wire                                cancel;
   wire                                pipe_cke;
   wire                                misalign;
   wire [`NCPU_DW-1:0]                 din_8b;
   wire [`NCPU_DW-1:0]                 din_16b;
   wire [`NCPU_AW-CONFIG_DMMU_PAGE_SIZE_LOG2-1:0] tlb_ppn;
   wire [3:0]                          we_msk_8b;
   wire [3:0]                          we_msk_16b;
   wire [`NCPU_DW-1:0]                 dout_w;
   wire [2:0]                          ls_size;
   wire [2:0]                          wb_size;
   wire                                wb_sign_ext;
   wire [7:0]                          wb_dout_8b;
   wire [15:0]                         wb_dout_16b;
   wire                                wb_AVALID_tmp_r;

   // Address Geneator
   assign dc_vaddr = lsu_operand1 + lsu_imm32;

   assign ls_size = lsu_load ? lsu_load_size : lsu_store_size;

   // Address alignment check
   assign misalign = (ls_size==3'd3 & |dc_vaddr[1:0]) |
                     (ls_size==3'd2 & dc_vaddr[0]);

   assign din_8b = {lsu_operand2[7:0], lsu_operand2[7:0], lsu_operand2[7:0], lsu_operand2[7:0]};
   assign din_16b = {lsu_operand2[15:0], lsu_operand2[15:0]};

   assign dc_wdat = ({`NCPU_DW{ls_size==3'd3}} & lsu_operand2) |
                     ({`NCPU_DW{ls_size==3'd2}} & din_16b) |
                     ({`NCPU_DW{ls_size==3'd1}} & din_8b);
   
   // B/HW align
   assign we_msk_8b = (dc_vaddr[1:0]==2'b00 ? 4'b0001 :
                        dc_vaddr[1:0]==2'b01 ? 4'b0010 :
                        dc_vaddr[1:0]==2'b10 ? 4'b0100 :
                        dc_vaddr[1:0]==2'b11 ? 4'b1000 : 4'b0000);
   assign we_msk_16b = dc_vaddr[1] ? 4'b1100 : 4'b0011;

   // Write byte mask
   assign dc_wmsk = {`NCPU_DW/8{lsu_store}} & (
                     ({`NCPU_DW/8{ls_size==3'd3}} & 4'b1111) |
                     ({`NCPU_DW/8{ls_size==3'd2}} & we_msk_16b) |
                     ({`NCPU_DW/8{ls_size==3'd1}} & we_msk_8b) );

   assign pipe_cke = ~lsu_stall;

   assign dc_en = (pipe_cke & lsu_AVALID);

   ncpu32k_dmmu
      #(
         .CONFIG_DMMU_PAGE_SIZE_LOG2   (CONFIG_DMMU_PAGE_SIZE_LOG2),
         .CONFIG_DMMU_ENABLE_UNCACHED_SEG (CONFIG_DMMU_ENABLE_UNCACHED_SEG),
         .CONFIG_DTLB_NSETS_LOG2       (CONFIG_DTLB_NSETS_LOG2)
      )
   D_MMU
      (
         .clk                          (clk),
         .rst_n                        (rst_n),
         .re                           (dc_en),
         .vpn                          (dc_vaddr[`NCPU_AW-1:CONFIG_DMMU_PAGE_SIZE_LOG2]),
         .we                           (lsu_store),
         .ppn                          (tlb_ppn),
         .EDTM                         (wb_lsu_EDTM),
         .EDPF                         (wb_lsu_EDPF),
         .uncached                     (tlb_uncached),
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

   assign cancel = (wb_lsu_EDTM|wb_lsu_EDPF|wb_lsu_EALIGN|lsu_flush);

   ncpu32k_dcache
      #(
         .CONFIG_DBUS_DW               (CONFIG_DBUS_DW),
         .CONFIG_DBUS_BYTES_LOG2       (CONFIG_DBUS_BYTES_LOG2),
         .CONFIG_DBUS_AW               (CONFIG_DBUS_AW),
         .CONFIG_DMMU_PAGE_SIZE_LOG2   (CONFIG_DMMU_PAGE_SIZE_LOG2),
         .CONFIG_DC_AW                 (`NCPU_AW),
         .CONFIG_DC_DW                 (`NCPU_DW),
         .CONFIG_DC_DW_BYTES_LOG2      (`NCPU_DW_BYTES_LOG2),
         .CONFIG_DC_P_LINE             (CONFIG_DCACHE_P_LINE),
         .CONFIG_DC_P_SETS             (CONFIG_DCACHE_P_SETS)
      )
   D_CACHE
      (
         .clk                          (clk),
         .rst_n                        (rst_n),
         .stall                        (dc_stall),
         .req                          (dc_en),
         .page_off                     (dc_vaddr[CONFIG_DMMU_PAGE_SIZE_LOG2-1:0]),
         .wmsk                         (dc_wmsk),
         .wdat                         (dc_wdat),
         .rdat                         (dc_rdat),
         .tlb_exc                      (cancel),
         .tlb_uncached                 (tlb_uncached),
         .tlb_ppn                      (tlb_ppn),
         .dbus_clk                     (dbus_clk),
         .dbus_rst_n                   (dbus_rst_n),
         .dbus_AREADY                  (dbus_AREADY),
         .dbus_AVALID                  (dbus_AVALID),
         .dbus_AADDR                   (dbus_AADDR),
         .dbus_AWMSK                   (dbus_AWMSK),
         .dbus_ALEN                    (dbus_ALEN),
         .dbus_WDATA                   (dbus_WDATA),
         .dbus_BVALID                  (dbus_BVALID),
         .dbus_BREADY                  (dbus_BREADY),
         .dbus_BDATA                   (dbus_BDATA),
         .dbus_BWE                     (dbus_BWE)
      );

   // Data path
   nDFF_l #(3) dff_wb_size
      (clk, pipe_cke, ls_size, wb_size);
   nDFF_l #(`NCPU_AW) dff_wb_lsu_lsa
      (clk, pipe_cke, dc_vaddr, wb_lsu_LSA);
   nDFF_l #(1) dff_wb_sign_ext
      (clk, pipe_cke, lsu_sign_ext, wb_sign_ext);
   nDFF_l #(`NCPU_AW-2) dff_wb_lsu_pc
      (clk, pipe_cke, lsu_pc, wb_lsu_pc);
   nDFF_l #(1) dff_wb_lsu_in_slot_1
      (clk, pipe_cke, lsu_in_slot_1, wb_lsu_in_slot_1);
   
   nDFF_l #(`NCPU_DW/8) dff_uncached_dbus_AWMSK
      (clk, pipe_cke, dc_wmsk, uncached_dbus_AWMSK);
   nDFF_l #(`NCPU_DW) dff_uncached_dbus_ADATA
      (clk, pipe_cke, dc_wdat, uncached_dbus_ADATA);

   // Control path
   nDFF_lr #(1) dff_wb_lsu_AVALID
      (clk, rst_n, pipe_cke, lsu_AVALID, wb_AVALID_tmp_r);
   nDFF_lr #(1) dff_wb_misalign
      (clk, rst_n, pipe_cke, misalign, wb_lsu_EALIGN);

   wire [1:0] uncached_state_r;
   reg [1:0] uncached_state_nxt;
   wire uncached_pending;
   wire [`NCPU_DW-1:0] uncached_dout_r;

   localparam [1:0] S_UNCACHED_IDLE = 2'b00;
   localparam [1:0] S_UNCACHED_AVALID = 2'b01;
   localparam [1:0] S_UNCACHED_BREADY = 2'b10;
   localparam [1:0] S_UNCACHED_OUT = 2'b11;

   always @(*)
      begin
         uncached_state_nxt = uncached_state_r;
         case (uncached_state_r)
         S_UNCACHED_IDLE:
            if (wb_AVALID_tmp_r & tlb_uncached)
               uncached_state_nxt = S_UNCACHED_AVALID;
         S_UNCACHED_AVALID:
            if (uncached_dbus_AREADY)
               uncached_state_nxt = S_UNCACHED_BREADY;
         S_UNCACHED_BREADY:
            if (uncached_dbus_BVALID)
               uncached_state_nxt = S_UNCACHED_OUT;
         S_UNCACHED_OUT:
            if (stall_bck_nolsu)
               uncached_state_nxt = S_UNCACHED_OUT;
            else
               uncached_state_nxt = S_UNCACHED_IDLE;
         endcase
      end

   nDFF_r #(2, S_UNCACHED_IDLE) dff_uncached_state_r
      (clk,rst_n, uncached_state_nxt, uncached_state_r);

   assign uncached_dbus_AADDR = wb_lsu_LSA;

   assign uncached_dbus_AVALID = (uncached_state_r == S_UNCACHED_AVALID);
   assign uncached_dbus_BREADY = (uncached_state_r == S_UNCACHED_BREADY);

   nDFF_l #(`NCPU_DW) dff_uncached_dout_r
      (clk, (uncached_dbus_BVALID & uncached_dbus_BREADY), uncached_dbus_BDATA, uncached_dout_r);

   assign uncached_pending = (uncached_state_r != S_UNCACHED_OUT) &
                              ((uncached_state_r != S_UNCACHED_IDLE) | (uncached_state_nxt != S_UNCACHED_IDLE));


   assign dout_w = (uncached_state_r==S_UNCACHED_OUT) ? uncached_dout_r : dc_rdat;

   assign lsu_stall = (dc_stall | uncached_pending);

   assign wb_lsu_AVALID = (wb_AVALID_tmp_r & ~lsu_flush);
   
   // B/HW align
   assign wb_dout_8b = ({8{wb_lsu_LSA[1:0]==2'b00}} & dout_w[7:0]) |
                          ({8{wb_lsu_LSA[1:0]==2'b01}} & dout_w[15:8]) |
                          ({8{wb_lsu_LSA[1:0]==2'b10}} & dout_w[23:16]) |
                          ({8{wb_lsu_LSA[1:0]==2'b11}} & dout_w[31:24]);
   assign wb_dout_16b = wb_lsu_LSA[1] ? dout_w[31:16] : dout_w[15:0];

   assign wb_lsu_dout =
      ({`NCPU_DW{wb_size==3'd3}} & dout_w) |
      ({`NCPU_DW{wb_size==3'd2}} & {{16{wb_sign_ext & wb_dout_16b[15]}}, wb_dout_16b[15:0]}) |
      ({`NCPU_DW{wb_size==3'd1}} & {{24{wb_sign_ext & wb_dout_8b[7]}}, wb_dout_8b[7:0]});

endmodule
