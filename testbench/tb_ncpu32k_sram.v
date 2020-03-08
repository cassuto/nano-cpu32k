
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
   wire                 ibus_flush_req;
   wire [`NCPU_AW-1:0]  ibus_cmd_addr;
   wire                 ibus_cmd_ready;
   wire                 ibus_cmd_valid;
   wire                 ibus_flush_ack;
   wire [`NCPU_DW-1:0]  ibus_dout;
   wire                 icache_valid;
   wire                 icache_ready;
   wire [`NCPU_AW-1:0]  icache_out_id;
   wire [`NCPU_AW-1:0]  ibus_out_id_nxt;
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
   
   handshake_cmd_sram #(
      .DELAY   (128)
   ) d_ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .din        (dbus_din),
      .valid      (dbus_valid),
      .ready      (dbus_ready),
      .dout       (dbus_dout),
      .cmd_ready  (dbus_cmd_ready),
      .cmd_valid  (dbus_cmd_valid),
      .cmd_addr   (dbus_cmd_addr),
      .cmd_we     (dbus_cmd_we),
      .cmd_size   (dbus_cmd_size)
   );
   
   
   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY (128)
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
      .exp_imm_page_fault   (exp_imm_page_fault)
   );

endmodule
