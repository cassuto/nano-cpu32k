
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
   
   wire                    fb_ibus_valid;
   wire                    fb_ibus_ready;
   wire [`NCPU_IW-1:0]     fb_ibus_dout;
   wire                    fb_ibus_cmd_ready;
   wire                    fb_ibus_cmd_valid;
   wire [`NCPU_AW-1:0]     fb_ibus_cmd_addr;

   wire                    fb_dbus_valid;
   wire                    fb_dbus_ready;
   wire [`NCPU_IW-1:0]     fb_dbus_dout;
   wire [`NCPU_DW-1:0]     fb_dbus_din;
   wire                    fb_dbus_cmd_ready;
   wire                    fb_dbus_cmd_valid;
   wire [`NCPU_AW-1:0]     fb_dbus_cmd_addr;
   wire [`NCPU_DW/8-1:0]   fb_dbus_cmd_we_msk;
   wire [`NCPU_NIRQ-1:0]   fb_irqs;
   
   wire                    fb_mbus_valid;
   wire                    fb_mbus_ready;
   wire [`NCPU_IW-1:0]     fb_mbus_dout;
   wire [`NCPU_DW-1:0]     fb_mbus_din;
   wire                    fb_mbus_cmd_ready;
   wire                    fb_mbus_cmd_valid;
   wire [`NCPU_AW-1:0]     fb_mbus_cmd_addr;
   wire [`NCPU_DW/8-1:0]   fb_mbus_cmd_we_msk;
   
   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY   (2)
   ) ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .din        (fb_mbus_din),
      .valid      (fb_mbus_valid),
      .ready      (fb_mbus_ready),
      .dout       (fb_mbus_dout),
      .cmd_ready  (fb_mbus_cmd_ready),
      .cmd_valid  (fb_mbus_cmd_valid),
      .cmd_addr   (fb_mbus_cmd_addr),
      .cmd_we_msk (fb_mbus_cmd_we_msk)
   );
   
   pb_fb_arbiter fb_arbi
   (
      .clk        (clk),
      .rst_n      (rst_n),
      .fb_ibus_valid       (fb_ibus_valid),
      .fb_ibus_ready       (fb_ibus_ready),
      .fb_ibus_dout        (fb_ibus_dout),
      .fb_ibus_cmd_ready   (fb_ibus_cmd_ready),
      .fb_ibus_cmd_valid   (fb_ibus_cmd_valid),
      .fb_ibus_cmd_addr    (fb_ibus_cmd_addr),
      .fb_dbus_valid       (fb_dbus_valid),
      .fb_dbus_ready       (fb_dbus_ready),
      .fb_dbus_dout        (fb_dbus_dout),
      .fb_dbus_din         (fb_dbus_din),
      .fb_dbus_cmd_ready   (fb_dbus_cmd_ready),
      .fb_dbus_cmd_valid   (fb_dbus_cmd_valid),
      .fb_dbus_cmd_addr    (fb_dbus_cmd_addr),
      .fb_dbus_cmd_we_msk  (fb_dbus_cmd_we_msk),
      
      .fb_mbus_valid       (fb_mbus_valid),
      .fb_mbus_ready       (fb_mbus_ready),
      .fb_mbus_dout        (fb_mbus_dout),
      .fb_mbus_din         (fb_mbus_din),
      .fb_mbus_cmd_ready   (fb_mbus_cmd_ready),
      .fb_mbus_cmd_valid   (fb_mbus_cmd_valid),
      .fb_mbus_cmd_addr    (fb_mbus_cmd_addr),
      .fb_mbus_cmd_we_msk  (fb_mbus_cmd_we_msk)
   );
   
   assign fb_irqs = {`NCPU_NIRQ{1'b0}};
   
   ncpu32k ncpu32k
   (
      .clk                 (clk),
      .rst_n               (rst_n),
      .fb_ibus_valid       (fb_ibus_valid),
      .fb_ibus_ready       (fb_ibus_ready),
      .fb_ibus_dout        (fb_ibus_dout),
      .fb_ibus_cmd_ready   (fb_ibus_cmd_ready),
      .fb_ibus_cmd_valid   (fb_ibus_cmd_valid),
      .fb_ibus_cmd_addr    (fb_ibus_cmd_addr),
      .fb_dbus_valid       (fb_dbus_valid),
      .fb_dbus_ready       (fb_dbus_ready),
      .fb_dbus_dout        (fb_dbus_dout),
      .fb_dbus_din         (fb_dbus_din),
      .fb_dbus_cmd_ready   (fb_dbus_cmd_ready),
      .fb_dbus_cmd_valid   (fb_dbus_cmd_valid),
      .fb_dbus_cmd_addr    (fb_dbus_cmd_addr),
      .fb_dbus_cmd_we_msk  (fb_dbus_cmd_we_msk),
      .fb_irqs             (fb_irqs)
   );
   
endmodule
