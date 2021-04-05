`include "timescale.v"
`include "ncpu32k_config.h"

module tb_ncpu32k_sep_sram();

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

   wire                    fb_ibus_BVALID;
   wire                    fb_ibus_BREADY;
   wire [`NCPU_IW-1:0]     fb_ibus_BDATA;
   wire [1:0]              fb_ibus_BEXC;
   wire                    fb_ibus_AREADY;
   wire                    fb_ibus_AVALID;
   wire [`NCPU_AW-1:0]     fb_ibus_AADDR;
   wire [1:0]              fb_ibus_AEXC;

   wire                    fb_dbus_BVALID;
   wire                    fb_dbus_BREADY;
   wire [`NCPU_IW-1:0]     fb_dbus_BDATA;
   wire [1:0]              fb_dbus_BEXC;
   wire [`NCPU_DW-1:0]     fb_dbus_ADATA;
   wire                    fb_dbus_AREADY;
   wire                    fb_dbus_AVALID;
   wire [`NCPU_AW-1:0]     fb_dbus_AADDR;
   wire [`NCPU_DW/8-1:0]   fb_dbus_AWMSK;
   wire [1:0]              fb_dbus_AEXC;
   wire [`NCPU_NIRQ-1:0]   fb_irqs;

   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY   (1)
   ) d_ram
   (
      .clk                 (clk),
      .rst_n               (rst_n),
      .ADATA               (fb_dbus_ADATA),
      .BVALID              (fb_dbus_BVALID),
      .BREADY              (fb_dbus_BREADY),
      .BDATA               (fb_dbus_BDATA),
      .BEXC                (fb_dbus_BEXC),
      .AREADY              (fb_dbus_AREADY),
      .AVALID              (fb_dbus_AVALID),
      .AADDR               (fb_dbus_AADDR),
      .AWMSK               (fb_dbus_AWMSK),
      .AEXC                (fb_dbus_AEXC)
   );


   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY (1)
   ) i_ram
   (
      .clk                 (clk),
      .rst_n               (rst_n),
      .ADATA               (),
      .BVALID              (fb_ibus_BVALID),
      .BREADY              (fb_ibus_BREADY),
      .BDATA               (fb_ibus_BDATA),
      .BEXC                (fb_dbus_BEXC),
      .AREADY              (fb_ibus_AREADY),
      .AVALID              (fb_ibus_AVALID),
      .AADDR               (fb_ibus_AADDR),
      .AWMSK               (4'b0),
      .AEXC                (fb_dbus_AEXC)
   );

   assign fb_irqs = {`NCPU_NIRQ{1'b0}};

   ncpu32k ncpu32k
   (
      .clk                 (clk),
      .rst_n               (rst_n),
      .fb_ibus_BVALID      (fb_ibus_BVALID),
      .fb_ibus_BREADY      (fb_ibus_BREADY),
      .fb_ibus_BDATA       (fb_ibus_BDATA),
      .fb_ibus_BEXC        (fb_ibus_BEXC),
      .fb_ibus_AREADY      (fb_ibus_AREADY),
      .fb_ibus_AVALID      (fb_ibus_AVALID),
      .fb_ibus_AADDR       (fb_ibus_AADDR),
      .fb_ibus_AEXC        (fb_ibus_AEXC),
      .fb_dbus_BVALID      (fb_dbus_BVALID),
      .fb_dbus_BREADY      (fb_dbus_BREADY),
      .fb_dbus_BDATA       (fb_dbus_BDATA),
      .fb_dbus_BEXC        (fb_dbus_BEXC),
      .fb_dbus_ADATA       (fb_dbus_ADATA),
      .fb_dbus_AREADY      (fb_dbus_AREADY),
      .fb_dbus_AVALID      (fb_dbus_AVALID),
      .fb_dbus_AADDR       (fb_dbus_AADDR),
      .fb_dbus_AWMSK       (fb_dbus_AWMSK),
      .fb_dbus_AEXC        (fb_dbus_AEXC),
      .fb_irqs             (fb_irqs)
   );

endmodule
