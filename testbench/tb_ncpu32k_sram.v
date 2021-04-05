`include "timescale.v"
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
   reg [`NCPU_NIRQ-1:0]    fb_irqs;

   wire                    fb_mbus_BVALID;
   wire                    fb_mbus_BREADY;
   wire [`NCPU_IW-1:0]     fb_mbus_BDATA;
   wire [1:0]              fb_mbus_BEXC;
   wire [`NCPU_DW-1:0]     fb_mbus_ADATA;
   wire                    fb_mbus_AREADY;
   wire                    fb_mbus_AVALID;
   wire [`NCPU_AW-1:0]     fb_mbus_AADDR;
   wire [`NCPU_DW/8-1:0]   fb_mbus_AWMSK;
   wire [1:0]              fb_mbus_AEXC;

   handshake_cmd_sram #(
      .MEMH_FILE("insn.mem"),
      .DELAY   (2)
   ) ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .ADATA   (fb_mbus_ADATA),
      .BVALID  (fb_mbus_BVALID),
      .BREADY  (fb_mbus_BREADY),
      .BDATA   (fb_mbus_BDATA),
      .BEXC    (fb_mbus_BEXC),
      .AREADY  (fb_mbus_AREADY),
      .AVALID  (fb_mbus_AVALID),
      .AADDR   (fb_mbus_AADDR),
      .AWMSK   (fb_mbus_AWMSK),
      .AEXC    (fb_mbus_AEXC)
   );

   pb_fb_arbiter fb_arbi
   (
      .clk              (clk),
      .rst_n            (rst_n),
      .fb_ibus_BVALID   (fb_ibus_BVALID),
      .fb_ibus_BREADY   (fb_ibus_BREADY),
      .fb_ibus_BDATA    (fb_ibus_BDATA),
      .fb_ibus_BEXC     (fb_ibus_BEXC),
      .fb_ibus_AREADY   (fb_ibus_AREADY),
      .fb_ibus_AVALID   (fb_ibus_AVALID),
      .fb_ibus_AADDR    (fb_ibus_AADDR),
      .fb_ibus_AEXC     (fb_ibus_AEXC),
      .fb_dbus_BVALID   (fb_dbus_BVALID),
      .fb_dbus_BREADY   (fb_dbus_BREADY),
      .fb_dbus_BDATA    (fb_dbus_BDATA),
      .fb_dbus_BEXC     (fb_dbus_BEXC),
      .fb_dbus_ADATA    (fb_dbus_ADATA),
      .fb_dbus_AREADY   (fb_dbus_AREADY),
      .fb_dbus_AVALID   (fb_dbus_AVALID),
      .fb_dbus_AADDR    (fb_dbus_AADDR),
      .fb_dbus_AWMSK    (fb_dbus_AWMSK),
      .fb_dbus_AEXC     (fb_dbus_AEXC),

      .fb_mbus_BVALID   (fb_mbus_BVALID),
      .fb_mbus_BREADY   (fb_mbus_BREADY),
      .fb_mbus_BDATA    (fb_mbus_BDATA),
      .fb_mbus_BEXC     (fb_mbus_BEXC),
      .fb_mbus_ADATA    (fb_mbus_ADATA),
      .fb_mbus_AREADY   (fb_mbus_AREADY),
      .fb_mbus_AVALID   (fb_mbus_AVALID),
      .fb_mbus_AADDR    (fb_mbus_AADDR),
      .fb_mbus_AWMSK    (fb_mbus_AWMSK),
      .fb_mbus_AEXC     (fb_mbus_AEXC)
   );

   // assign fb_irqs = {`NCPU_NIRQ{1'b0}};
   initial begin
      fb_irqs = 0;
      #500 fb_irqs = 32'b001;
   end

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
