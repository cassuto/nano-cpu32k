
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
   
   wire                 dbus_in_valid;
   wire                 dbus_in_ready;
   wire [`NCPU_AW-1:0]  dbus_addr_o;
   wire [`NCPU_DW-1:0]  dbus_i;
   wire                 dbus_out_valid;
   wire                 dbus_out_ready;
   wire [`NCPU_DW-1:0]  dbus_o;
   wire [2:0]           dbus_size_o;
   wire                 ibus_dout_valid;
   wire                 ibus_dout_ready;
   wire [`NCPU_AW-1:0]  ibus_out_id;
   wire                 ibus_hld_id;
   wire                 ibus_cmd_flush;
   wire [`NCPU_AW-1:0]  ibus_cmd_addr;
   wire                 ibus_cmd_ready;
   wire                 ibus_cmd_valid;
   wire                 ibus_flush_ack;
   wire [`NCPU_DW-1:0]  ibus_dout;
   wire                 icache_dout_valid;
   wire                 icache_dout_ready;
   wire [`NCPU_AW-1:0]  icache_out_id;
   wire [`NCPU_AW-1:0]  ibus_out_id_nxt;
   wire                 icache_cmd_ready;
   wire                 icache_cmd_valid;
   wire [`NCPU_AW-1:0]  icache_cmd_addr;
   wire [`NCPU_DW-1:0]  icache_dout;
   
   handshake_sram d_ram(
      .clk     (clk),
      .rst_n   (rst_n),
      .addr    (dbus_addr_o),
      .in_valid   (dbus_in_valid),
      .in_ready   (dbus_in_ready),
      .din        (dbus_i),
      .out_valid  (dbus_out_valid),
      .out_ready  (dbus_out_ready),
      .out_id     (),
      .dout    (dbus_o),
      .size    (dbus_size_o)
   );
   
   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem")
   ) i_ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .cmd_addr    (icache_cmd_addr),
      .in_valid   (1'b0),
      .in_ready   (),
      .din        (),
      .out_valid  (icache_dout_valid),
      .out_ready  (icache_dout_ready),
      .cmd_ready  (icache_cmd_ready),
      .cmd_valid  (icache_cmd_valid),
      .dout    (icache_dout),
      .size    (3'd3)
   );
   
   ncpu32k_i_mmu i_mmu
   (
      .clk              (clk),
      .rst_n            (rst_n),
      .ibus_dout_valid    (ibus_dout_valid),
      .ibus_dout_ready    (ibus_dout_ready),
      .ibus_cmd_addr     (ibus_cmd_addr),
      .ibus_cmd_ready    (ibus_cmd_ready),
      .ibus_cmd_valid    (ibus_cmd_valid),
      .ibus_dout         (ibus_dout),
      .ibus_out_id       (ibus_out_id),
      .ibus_out_id_nxt   (ibus_out_id_nxt),
      .ibus_hld_id       (ibus_hld_id),
      .ibus_cmd_flush     (ibus_cmd_flush),
      .ibus_flush_ack      (ibus_flush_ack),
      .icache_dout_valid    (icache_dout_valid),
      .icache_dout_ready    (icache_dout_ready),
      .icache_cmd_ready    (icache_cmd_ready),
      .icache_cmd_valid    (icache_cmd_valid),
      .icache_cmd_addr     (icache_cmd_addr),
      .icache_dout         (icache_dout)
   );
   
   ncpu32k_core ncpu32k_inst(
      .clk           (clk),
      .rst_n         (rst_n),
      .dbus_addr_o   (dbus_addr_o),
      .dbus_in_valid (dbus_in_valid),
      .dbus_in_ready (dbus_in_ready),
      .dbus_o        (dbus_o),
      .dbus_out_valid (dbus_out_valid),
      .dbus_out_ready (dbus_out_ready),
      .dbus_i        (dbus_i),
      .dbus_size_o   (dbus_size_o),
      .ibus_cmd_addr   (ibus_cmd_addr),
      .ibus_cmd_ready    (ibus_cmd_ready),
      .ibus_cmd_valid    (ibus_cmd_valid),
      .ibus_dout_valid (ibus_dout_valid),
      .ibus_dout_ready (ibus_dout_ready),
      .ibus_out_id    (ibus_out_id),
      .ibus_out_id_nxt   (ibus_out_id_nxt),
      .ibus_hld_id    (ibus_hld_id),
      .ibus_dout         (ibus_dout),
      .ibus_cmd_flush     (ibus_cmd_flush),
      .ibus_flush_ack      (ibus_flush_ack)
   );

endmodule
