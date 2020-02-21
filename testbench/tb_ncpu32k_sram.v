
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
   wire                 ibus_out_valid;
   wire                 ibus_out_ready;
   wire [`NCPU_AW-1:0]  ibus_out_id;
   wire [`NCPU_AW-1:0]  ibus_addr_o;
   wire [`NCPU_DW-1:0]  ibus_o;
   wire [2:0]           dbus_size_o;
   
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
   
   handshake_sram #(
      .MEMH_FILE("insn.mem")
   ) i_ram
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .addr    (ibus_addr_o),
      .in_valid   (1'b0),
      .in_ready   (),
      .din        (),
      .out_valid  (ibus_out_valid),
      .out_ready  (ibus_out_ready),
      .out_id     (ibus_out_id),
      .dout    (ibus_o),
      .size    (3'd3)
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
      .ibus_addr_o   (ibus_addr_o),
      .ibus_out_valid (ibus_out_valid),
      .ibus_out_ready (ibus_out_ready),
      .ibus_out_id    (ibus_out_id),
      .ibus_o         (ibus_o)
   );

endmodule
