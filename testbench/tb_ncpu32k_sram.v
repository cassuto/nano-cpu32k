
`include "ncpu32k_config.h"

module tb_ncpu32k_sram();

   //
   // Driving source
   //
   reg clk;
   reg rst_n;

   // Generate Clock
   initial begin
      clk = 1'b0;
      forever #10 clk = ~clk;
   end

   // Generate reset
   initial begin
      rst_n = 1'b0;
      #10 rst_n= 1'b1;
      //#450 $stop;
   end
   
   localparam IRQN_TSC = 0;
   
   wire                 dbus_cmd_valid;
   wire                 dbus_cmd_ready;
   wire [`NCPU_AW-1:0]  dbus_cmd_addr;
   wire [2:0]           dbus_cmd_size;
   wire                 dbus_cmd_we;
   wire [`NCPU_DW-1:0]  dbus_din;
   wire                 dbus_valid;
   wire                 dbus_ready;
   wire [`NCPU_DW-1:0]  dbus_dout;
   wire                 ibus_valid;
   wire                 ibus_ready;
   wire [`NCPU_AW-1:0]  ibus_out_id;
   wire [`NCPU_AW-1:0]  ibus_out_id_nxt;
   wire [`NCPU_AW-1:0]  ibus_cmd_addr;
   wire                 ibus_cmd_ready;
   wire                 ibus_cmd_valid;
   wire                 ibus_flush_ack;
   wire                 ibus_flush_req;
   wire [`NCPU_DW-1:0]  ibus_dout;
   wire                 dcache_valid;
   wire                 dcache_ready;
   wire                 dcache_cmd_ready;
   wire                 dcache_cmd_valid;
   wire [`NCPU_AW-1:0]  dcache_cmd_addr;
   wire [2:0]           dcache_cmd_size;
   wire                 dcache_cmd_we;
   wire [`NCPU_DW-1:0]  dcache_dout;
   wire [`NCPU_DW-1:0]  dcache_din;
   wire                 icache_valid;
   wire                 icache_ready;
   wire [`NCPU_AW-1:0]  icache_out_id;
   wire                 icache_cmd_ready;
   wire                 icache_cmd_valid;
   wire [`NCPU_AW-1:0]  icache_cmd_addr;
   wire [`NCPU_DW-1:0]  icache_dout;
   wire                 msr_psr_imme;
   wire                 msr_psr_rm;
   wire [`NCPU_DW-1:0]      msr_immid;
   wire [`NCPU_DW-1:0]      msr_imm_tlbl;
   wire [`NCPU_TLB_AW-1:0]  msr_imm_tlbl_idx;
   wire [`NCPU_DW-1:0]      msr_imm_tlbl_nxt;
   wire                     msr_imm_tlbl_we;
   wire [`NCPU_DW-1:0]      msr_imm_tlbh;
   wire [`NCPU_TLB_AW-1:0]  msr_imm_tlbh_idx;
   wire [`NCPU_DW-1:0]      msr_imm_tlbh_nxt;
   wire                     msr_imm_tlbh_we;
   wire                  exp_imm_tlb_miss;
   wire                  exp_imm_page_fault;
   wire                 msr_psr_dmme;
   wire [`NCPU_DW-1:0]      msr_dmmid;
   wire [`NCPU_DW-1:0]      msr_dmm_tlbl;
   wire [`NCPU_TLB_AW-1:0]  msr_dmm_tlbl_idx;
   wire [`NCPU_DW-1:0]      msr_dmm_tlbl_nxt;
   wire                     msr_dmm_tlbl_we;
   wire [`NCPU_DW-1:0]      msr_dmm_tlbh;
   wire [`NCPU_TLB_AW-1:0]  msr_dmm_tlbh_idx;
   wire [`NCPU_DW-1:0]      msr_dmm_tlbh_nxt;
   wire                     msr_dmm_tlbh_we;
   wire                  exp_dmm_tlb_miss;
   wire                  exp_dmm_page_fault;
   
   wire [`NCPU_NIRQ-1:0]    irqs_lvl_i;
   wire                     irqc_intr_sync;
   wire                     msr_psr_ire;
   wire [`NCPU_DW-1:0]      msr_irqc_imr;
   wire [`NCPU_DW-1:0]      msr_irqc_imr_nxt;
   wire                     msr_irqc_imr_we;
   wire [`NCPU_DW-1:0]      msr_irqc_irr;
   
   wire                     tsc_irq;
   wire [`NCPU_DW-1:0]      msr_tsc_tsr;
   wire [`NCPU_DW-1:0]      msr_tsc_tsr_nxt;
   wire                     msr_tsc_tsr_we;
   wire [`NCPU_DW-1:0]      msr_tsc_tcr;
   wire [`NCPU_DW-1:0]      msr_tsc_tcr_nxt;
   wire                     msr_tsc_tcr_we;
   
   handshake_cmd_sram #(
      .DELAY   (128)
   ) d_ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .din        (dcache_din),
      .valid      (dcache_valid),
      .ready      (dcache_ready),
      .dout       (dcache_dout),
      .cmd_ready  (dcache_cmd_ready),
      .cmd_valid  (dcache_cmd_valid),
      .cmd_addr   (dcache_cmd_addr),
      .cmd_we     (dcache_cmd_we),
      .cmd_size   (dcache_cmd_size)
   );
   
   
   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY (3)
   ) i_ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .din        (),
      .valid   (icache_valid),
      .ready   (icache_ready),
      .dout    (icache_dout),
      .cmd_ready  (icache_cmd_ready),
      .cmd_valid  (icache_cmd_valid),
      .cmd_addr   (icache_cmd_addr),
      .cmd_we     (1'b0),
      .cmd_size   (3'd3)
   );
   
   ncpu32k_i_mmu i_mmu
   (
      .clk              (clk),
      .rst_n            (rst_n),
      .ibus_valid       (ibus_valid),
      .ibus_ready       (ibus_ready),
      .ibus_cmd_addr     (ibus_cmd_addr),
      .ibus_cmd_ready    (ibus_cmd_ready),
      .ibus_cmd_valid    (ibus_cmd_valid),
      .ibus_dout         (ibus_dout),
      .ibus_out_id       (ibus_out_id),
      .ibus_out_id_nxt   (ibus_out_id_nxt),
      .ibus_flush_req     (ibus_flush_req),
      .ibus_flush_ack      (ibus_flush_ack),
      .icache_valid    (icache_valid),
      .icache_ready    (icache_ready),
      .icache_cmd_ready    (icache_cmd_ready),
      .icache_cmd_valid    (icache_cmd_valid),
      .icache_cmd_addr     (icache_cmd_addr),
      .icache_dout         (icache_dout),
      .msr_psr_imme     (msr_psr_imme),
      .msr_psr_rm       (msr_psr_rm),
      .msr_immid        (msr_immid),
      .msr_imm_tlbl     (msr_imm_tlbl),
      .msr_imm_tlbl_idx (msr_imm_tlbl_idx),
      .msr_imm_tlbl_nxt (msr_imm_tlbl_nxt),
      .msr_imm_tlbl_we  (msr_imm_tlbl_we),
      .msr_imm_tlbh     (msr_imm_tlbh),
      .msr_imm_tlbh_idx (msr_imm_tlbh_idx),
      .msr_imm_tlbh_nxt (msr_imm_tlbh_nxt),
      .msr_imm_tlbh_we  (msr_imm_tlbh_we),
      .exp_imm_tlb_miss     (exp_imm_tlb_miss),
      .exp_imm_page_fault   (exp_imm_page_fault)
   );
   
   ncpu32k_d_mmu d_mmu
   (
      .clk              (clk),
      .rst_n            (rst_n),
      .dbus_valid       (dbus_valid),
      .dbus_ready       (dbus_ready),
      .dbus_cmd_addr    (dbus_cmd_addr),
      .dbus_cmd_ready   (dbus_cmd_ready),
      .dbus_cmd_valid   (dbus_cmd_valid),
      .dbus_cmd_size    (dbus_cmd_size),
      .dbus_cmd_we      (dbus_cmd_we),
      .dbus_dout        (dbus_dout),
      .dbus_din         (dbus_din),
      .dcache_valid     (dcache_valid),
      .dcache_ready     (dcache_ready),
      .dcache_cmd_ready (dcache_cmd_ready),
      .dcache_cmd_valid (dcache_cmd_valid),
      .dcache_cmd_addr  (dcache_cmd_addr),
      .dcache_cmd_size  (dcache_cmd_size),
      .dcache_cmd_we    (dcache_cmd_we),
      .dcache_dout      (dcache_dout),
      .dcache_din       (dcache_din),
      .msr_psr_dmme     (msr_psr_dmme),
      .msr_psr_rm       (msr_psr_rm),
      .msr_dmmid        (msr_dmmid),
      .msr_dmm_tlbl     (msr_dmm_tlbl),
      .msr_dmm_tlbl_idx (msr_dmm_tlbl_idx),
      .msr_dmm_tlbl_nxt (msr_dmm_tlbl_nxt),
      .msr_dmm_tlbl_we  (msr_dmm_tlbl_we),
      .msr_dmm_tlbh     (msr_dmm_tlbh),
      .msr_dmm_tlbh_idx (msr_dmm_tlbh_idx),
      .msr_dmm_tlbh_nxt (msr_dmm_tlbh_nxt),
      .msr_dmm_tlbh_we  (msr_dmm_tlbh_we),
      .exp_dmm_tlb_miss     (exp_dmm_tlb_miss),
      .exp_dmm_page_fault   (exp_dmm_page_fault)
   );
   
   ncpu32k_irqc irqc(         
      .clk              (clk),
      .rst_n            (rst_n),
      .irqs_lvl_i       (irqs_lvl_i),
      .irqc_intr_sync   (irqc_intr_sync),
      .msr_psr_ire      (msr_psr_ire),
      .msr_irqc_imr     (msr_irqc_imr),
      .msr_irqc_imr_nxt (msr_irqc_imr_nxt),
      .msr_irqc_imr_we  (msr_irqc_imr_we),
      .msr_irqc_irr     (msr_irqc_irr)
   );
   
   ncpu32k_tsc tsc(
      .clk              (clk),
      .rst_n            (rst_n),
      .tsc_irq          (tsc_irq),
      .msr_tsc_tsr      (msr_tsc_tsr),
      .msr_tsc_tsr_nxt  (msr_tsc_tsr_nxt),
      .msr_tsc_tsr_we   (msr_tsc_tsr_we),
      .msr_tsc_tcr      (msr_tsc_tcr),
      .msr_tsc_tcr_nxt  (msr_tsc_tcr_nxt),
      .msr_tsc_tcr_we   (msr_tsc_tcr_we)
   );

   assign irqs_lvl_i[IRQN_TSC] = tsc_irq;
   assign irqs_lvl_i[`NCPU_NIRQ-1:1] = 31'b0;
   
   ncpu32k_core ncpu32k_inst(
      .clk           (clk),
      .rst_n         (rst_n),
      .dbus_dout     (dbus_dout),
      .dbus_valid    (dbus_valid),
      .dbus_ready    (dbus_ready),
      .dbus_din        (dbus_din),
      .dbus_cmd_valid  (dbus_cmd_valid),
      .dbus_cmd_ready  (dbus_cmd_ready),
      .dbus_cmd_addr   (dbus_cmd_addr),
      .dbus_cmd_size   (dbus_cmd_size),
      .dbus_cmd_we     (dbus_cmd_we),
      .ibus_cmd_addr   (ibus_cmd_addr),
      .ibus_cmd_ready    (ibus_cmd_ready),
      .ibus_cmd_valid    (ibus_cmd_valid),
      .ibus_valid       (ibus_valid),
      .ibus_ready       (ibus_ready),
      .ibus_out_id    (ibus_out_id),
      .ibus_out_id_nxt   (ibus_out_id_nxt),
      .ibus_dout         (ibus_dout),
      .ibus_flush_req     (ibus_flush_req),
      .ibus_flush_ack      (ibus_flush_ack),
      .msr_psr_rm       (msr_psr_rm),
      .msr_psr_imme     (msr_psr_imme),
      .msr_immid        (msr_immid),
      .msr_imm_tlbl     (msr_imm_tlbl),
      .msr_imm_tlbl_idx (msr_imm_tlbl_idx),
      .msr_imm_tlbl_nxt (msr_imm_tlbl_nxt),
      .msr_imm_tlbl_we  (msr_imm_tlbl_we),
      .msr_imm_tlbh     (msr_imm_tlbh),
      .msr_imm_tlbh_idx (msr_imm_tlbh_idx),
      .msr_imm_tlbh_nxt (msr_imm_tlbh_nxt),
      .msr_imm_tlbh_we  (msr_imm_tlbh_we),
      .exp_imm_tlb_miss     (exp_imm_tlb_miss),
      .exp_imm_page_fault   (exp_imm_page_fault),
      .msr_psr_dmme     (msr_psr_dmme),
      .msr_dmmid        (msr_dmmid),
      .msr_dmm_tlbl     (msr_dmm_tlbl),
      .msr_dmm_tlbl_idx (msr_dmm_tlbl_idx),
      .msr_dmm_tlbl_nxt (msr_dmm_tlbl_nxt),
      .msr_dmm_tlbl_we  (msr_dmm_tlbl_we),
      .msr_dmm_tlbh     (msr_dmm_tlbh),
      .msr_dmm_tlbh_idx (msr_dmm_tlbh_idx),
      .msr_dmm_tlbh_nxt (msr_dmm_tlbh_nxt),
      .msr_dmm_tlbh_we  (msr_dmm_tlbh_we),
      .exp_dmm_tlb_miss     (exp_dmm_tlb_miss),
      .exp_dmm_page_fault   (exp_dmm_page_fault),
      
      .irqc_intr_sync   (irqc_intr_sync),
      .msr_psr_ire      (msr_psr_ire),
      .msr_irqc_imr     (msr_irqc_imr),
      .msr_irqc_imr_nxt (msr_irqc_imr_nxt),
      .msr_irqc_imr_we  (msr_irqc_imr_we),
      .msr_irqc_irr     (msr_irqc_irr),
      
      .msr_tsc_tsr      (msr_tsc_tsr),
      .msr_tsc_tsr_nxt  (msr_tsc_tsr_nxt),
      .msr_tsc_tsr_we   (msr_tsc_tsr_we),
      .msr_tsc_tcr      (msr_tsc_tcr),
      .msr_tsc_tcr_nxt  (msr_tsc_tcr_nxt),
      .msr_tsc_tcr_we   (msr_tsc_tcr_we)
   );

endmodule
