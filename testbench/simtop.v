`define AXI_TOP_INTERFACE(name) io_memAXI_0_``name

`define AXI_P_DW_BYTES      3
`define AXI_ADDR_WIDTH      64
`define AXI_DATA_WIDTH      ((1<<`AXI_P_DW_BYTES)*8)
`define AXI_ID_WIDTH        4
`define AXI_USER_WIDTH      1

module simtop
#(
   parameter AXI_P_DW_BYTES   = `AXI_P_DW_BYTES,
   parameter AXI_ADDR_WIDTH    = `AXI_ADDR_WIDTH,
   parameter AXI_ID_WIDTH      = `AXI_ID_WIDTH,
   parameter AXI_USER_WIDTH    = `AXI_USER_WIDTH
)
(
   input                               clock,
   input                               reset,

   input  [63:0]                       io_logCtrl_log_begin,
   input  [63:0]                       io_logCtrl_log_end,
   input  [63:0]                       io_logCtrl_log_level,
   input                               io_perfInfo_clean,
   input                               io_perfInfo_dump,

   output                              io_uart_out_valid,
   output [7:0]                        io_uart_out_ch,
   output                              io_uart_in_valid,
   input  [7:0]                        io_uart_in_ch,

   input                               `AXI_TOP_INTERFACE(aw_ready),
   output                              `AXI_TOP_INTERFACE(aw_valid),
   output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_addr),
   output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_prot),
   output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(aw_bits_id),
   output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_user),
   output [7:0]                        `AXI_TOP_INTERFACE(aw_bits_len),
   output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_size),
   output [1:0]                        `AXI_TOP_INTERFACE(aw_bits_burst),
   output                              `AXI_TOP_INTERFACE(aw_bits_lock),
   output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_cache),
   output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_qos),

   input                               `AXI_TOP_INTERFACE(w_ready),
   output                              `AXI_TOP_INTERFACE(w_valid),
   output [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(w_bits_data)         [3:0],
   output [`AXI_DATA_WIDTH/8-1:0]      `AXI_TOP_INTERFACE(w_bits_strb),
   output                              `AXI_TOP_INTERFACE(w_bits_last),

   output                              `AXI_TOP_INTERFACE(b_ready),
   input                               `AXI_TOP_INTERFACE(b_valid),
   input  [1:0]                        `AXI_TOP_INTERFACE(b_bits_resp),
   input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(b_bits_id),
   input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(b_bits_user),

   input                               `AXI_TOP_INTERFACE(ar_ready),
   output                              `AXI_TOP_INTERFACE(ar_valid),
   output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_addr),
   output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_prot),
   output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(ar_bits_id),
   output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_user),
   output [7:0]                        `AXI_TOP_INTERFACE(ar_bits_len),
   output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_size),
   output [1:0]                        `AXI_TOP_INTERFACE(ar_bits_burst),
   output                              `AXI_TOP_INTERFACE(ar_bits_lock),
   output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_cache),
   output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_qos),

   output                              `AXI_TOP_INTERFACE(r_ready),
   input                               `AXI_TOP_INTERFACE(r_valid),
   input  [1:0]                        `AXI_TOP_INTERFACE(r_bits_resp),
   input  [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_data)         [3:0],
   input                               `AXI_TOP_INTERFACE(r_bits_last),
   input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(r_bits_id),
   input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_user)
);
   
   wire clk;
   wire rst;
   
   wire axi_aw_ready_i;
   wire axi_aw_valid_o;
   wire [`AXI_ADDR_WIDTH-1:0] axi_aw_addr_o;
   wire [2:0] axi_aw_prot_o;
   wire [`AXI_ID_WIDTH-1:0] axi_aw_id_o;
   wire [`AXI_USER_WIDTH-1:0] axi_aw_user_o;
   wire [7:0] axi_aw_len_o;
   wire [2:0] axi_aw_size_o;
   wire [1:0] axi_aw_burst_o;
   wire axi_aw_lock_o;
   wire [3:0] axi_aw_cache_o;
   wire [3:0] axi_aw_qos_o;

   wire axi_w_ready_i;
   wire axi_w_valid_o;
   wire [`AXI_DATA_WIDTH-1:0] axi_w_data_o;
   wire [`AXI_DATA_WIDTH/8-1:0] axi_w_strb_o;
   wire axi_w_last_o;

   wire axi_b_ready_o;
   wire axi_b_valid_i;
   wire [1:0] axi_b_resp_i;
   wire [`AXI_ID_WIDTH-1:0] axi_b_id_i;
   wire [`AXI_USER_WIDTH-1:0] axi_b_user_i;

   wire axi_ar_ready_i;
   wire axi_ar_valid_o;
   wire [`AXI_ADDR_WIDTH-1:0] axi_ar_addr_o;
   wire [2:0] axi_ar_prot_o;
   wire [`AXI_ID_WIDTH-1:0] axi_ar_id_o;
   wire [`AXI_USER_WIDTH-1:0] axi_ar_user_o;
   wire [7:0] axi_ar_len_o;
   wire [2:0] axi_ar_size_o;
   wire [1:0] axi_ar_burst_o;
   wire axi_ar_lock_o;
   wire [3:0] axi_ar_cache_o;
   wire [3:0] axi_ar_qos_o;
   
/* verilator lint_off UNUSED */
   wire [3:0] axi_aw_region_o; // unused
   wire [`AXI_USER_WIDTH-1:0] axi_w_user_o; // unused
   wire [3:0] axi_ar_region_o; // unsued
/* verilator lint_on UNUSED */

   wire axi_r_ready_o;
   wire axi_r_valid_i;
   wire [1:0] axi_r_resp_i;
   wire [`AXI_DATA_WIDTH-1:0] axi_r_data_i;
   wire axi_r_last_i;
   wire [`AXI_ID_WIDTH-1:0] axi_r_id_i;
   wire [`AXI_USER_WIDTH-1:0] axi_r_user_i;

   assign axi_ar_ready_i                                 = `AXI_TOP_INTERFACE(ar_ready);
   assign `AXI_TOP_INTERFACE(ar_valid)             = axi_ar_valid_o;
   assign `AXI_TOP_INTERFACE(ar_bits_addr)         = axi_ar_addr_o;
   assign `AXI_TOP_INTERFACE(ar_bits_prot)         = axi_ar_prot_o;
   assign `AXI_TOP_INTERFACE(ar_bits_id)           = axi_ar_id_o;
   assign `AXI_TOP_INTERFACE(ar_bits_user)         = axi_ar_user_o;
   assign `AXI_TOP_INTERFACE(ar_bits_len)          = axi_ar_len_o;
   assign `AXI_TOP_INTERFACE(ar_bits_size)         = axi_ar_size_o;
   assign `AXI_TOP_INTERFACE(ar_bits_burst)        = axi_ar_burst_o;
   assign `AXI_TOP_INTERFACE(ar_bits_lock)         = axi_ar_lock_o;
   assign `AXI_TOP_INTERFACE(ar_bits_cache)        = axi_ar_cache_o;
   assign `AXI_TOP_INTERFACE(ar_bits_qos)          = axi_ar_qos_o;

   assign `AXI_TOP_INTERFACE(r_ready)              = axi_r_ready_o;
   assign axi_r_valid_i                                  = `AXI_TOP_INTERFACE(r_valid);
   assign axi_r_resp_i                                   = `AXI_TOP_INTERFACE(r_bits_resp);
   assign axi_r_data_i                                   = `AXI_TOP_INTERFACE(r_bits_data)[0];
   assign axi_r_last_i                                   = `AXI_TOP_INTERFACE(r_bits_last);
   assign axi_r_id_i                                     = `AXI_TOP_INTERFACE(r_bits_id);
   assign axi_r_user_i                                   = `AXI_TOP_INTERFACE(r_bits_user);

   assign axi_aw_ready_i                                 = `AXI_TOP_INTERFACE(aw_ready);
   assign `AXI_TOP_INTERFACE(aw_valid)             = axi_aw_valid_o;
   assign `AXI_TOP_INTERFACE(aw_bits_addr)         = axi_aw_addr_o;
   assign `AXI_TOP_INTERFACE(aw_bits_prot)         = axi_aw_prot_o;
   assign `AXI_TOP_INTERFACE(aw_bits_id)           = axi_aw_id_o;
   assign `AXI_TOP_INTERFACE(aw_bits_user)         = axi_aw_user_o;
   assign `AXI_TOP_INTERFACE(aw_bits_len)          = axi_aw_len_o;
   assign `AXI_TOP_INTERFACE(aw_bits_size)         = axi_aw_size_o;
   assign `AXI_TOP_INTERFACE(aw_bits_burst)        = axi_aw_burst_o;
   assign `AXI_TOP_INTERFACE(aw_bits_lock)         = axi_aw_lock_o;
   assign `AXI_TOP_INTERFACE(aw_bits_cache)        = axi_aw_cache_o;
   assign `AXI_TOP_INTERFACE(aw_bits_qos)          = axi_aw_qos_o;
   
   assign axi_w_ready_i                                  = `AXI_TOP_INTERFACE(w_ready);
   assign `AXI_TOP_INTERFACE(w_valid)              = axi_w_valid_o;
   assign `AXI_TOP_INTERFACE(w_bits_data)[0]       = axi_w_data_o;
   assign `AXI_TOP_INTERFACE(w_bits_data)[1]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_data)[2]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_data)[3]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_strb)          = axi_w_strb_o;
   assign `AXI_TOP_INTERFACE(w_bits_last)          = axi_w_last_o;
   
   assign `AXI_TOP_INTERFACE(b_ready)              = axi_b_ready_o;
   assign axi_b_valid_i                                  = `AXI_TOP_INTERFACE(b_valid);
   assign axi_b_resp_i                                   = `AXI_TOP_INTERFACE(b_bits_resp);
   assign axi_b_id_i                                     = `AXI_TOP_INTERFACE(b_bits_id);
   assign axi_b_user_i                                   = `AXI_TOP_INTERFACE(b_bits_user);
   
   assign clk = clock;
   assign rst = reset; // reset is high-active

   ncpu64k
   #(
   .AXI_P_DW_BYTES                     (AXI_P_DW_BYTES),
   .AXI_ADDR_WIDTH                     (AXI_ADDR_WIDTH),
   .AXI_ID_WIDTH                       (AXI_ID_WIDTH),
   .AXI_USER_WIDTH                     (AXI_USER_WIDTH)
   )
   DUT
   (/*AUTOINST*/
    // Outputs
    .ibus_ARVALID                       (ibus_ARVALID),
    .ibus_ARADDR                        (ibus_ARADDR[AXI_ADDR_WIDTH-1:0]),
    .ibus_ARPROT                        (ibus_ARPROT[2:0]),
    .ibus_ARID                          (ibus_ARID[AXI_ID_WIDTH-1:0]),
    .ibus_ARUSER                        (ibus_ARUSER[AXI_USER_WIDTH-1:0]),
    .ibus_ARLEN                         (ibus_ARLEN[7:0]),
    .ibus_ARSIZE                        (ibus_ARSIZE[2:0]),
    .ibus_ARBURST                       (ibus_ARBURST[1:0]),
    .ibus_ARLOCK                        (ibus_ARLOCK),
    .ibus_ARCACHE                       (ibus_ARCACHE[3:0]),
    .ibus_ARQOS                         (ibus_ARQOS[3:0]),
    .ibus_ARREGION                      (ibus_ARREGION[3:0]),
    .ibus_RREADY                        (ibus_RREADY),
    .dbus_ARVALID                       (dbus_ARVALID),
    .dbus_ARADDR                        (dbus_ARADDR[AXI_ADDR_WIDTH-1:0]),
    .dbus_ARPROT                        (dbus_ARPROT[2:0]),
    .dbus_ARID                          (dbus_ARID[AXI_ID_WIDTH-1:0]),
    .dbus_ARUSER                        (dbus_ARUSER[AXI_USER_WIDTH-1:0]),
    .dbus_ARLEN                         (dbus_ARLEN[7:0]),
    .dbus_ARSIZE                        (dbus_ARSIZE[2:0]),
    .dbus_ARBURST                       (dbus_ARBURST[1:0]),
    .dbus_ARLOCK                        (dbus_ARLOCK),
    .dbus_ARCACHE                       (dbus_ARCACHE[3:0]),
    .dbus_ARQOS                         (dbus_ARQOS[3:0]),
    .dbus_ARREGION                      (dbus_ARREGION[3:0]),
    .dbus_RREADY                        (dbus_RREADY),
    .dbus_AWVALID                       (dbus_AWVALID),
    .dbus_AWADDR                        (dbus_AWADDR[AXI_ADDR_WIDTH-1:0]),
    .dbus_AWPROT                        (dbus_AWPROT[2:0]),
    .dbus_AWID                          (dbus_AWID[AXI_ID_WIDTH-1:0]),
    .dbus_AWUSER                        (dbus_AWUSER[AXI_USER_WIDTH-1:0]),
    .dbus_AWLEN                         (dbus_AWLEN[7:0]),
    .dbus_AWSIZE                        (dbus_AWSIZE[2:0]),
    .dbus_AWBURST                       (dbus_AWBURST[1:0]),
    .dbus_AWLOCK                        (dbus_AWLOCK),
    .dbus_AWCACHE                       (dbus_AWCACHE[3:0]),
    .dbus_AWQOS                         (dbus_AWQOS[3:0]),
    .dbus_AWREGION                      (dbus_AWREGION[3:0]),
    .dbus_WVALID                        (dbus_WVALID),
    .dbus_WDATA                         (dbus_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .dbus_WSTRB                         (dbus_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
    .dbus_WLAST                         (dbus_WLAST),
    .dbus_WUSER                         (dbus_WUSER[AXI_USER_WIDTH-1:0]),
    .dbus_BREADY                        (dbus_BREADY),
    .uncached_ARVALID                   (uncached_ARVALID),
    .uncached_ARADDR                    (uncached_ARADDR[AXI_ADDR_WIDTH-1:0]),
    .uncached_ARPROT                    (uncached_ARPROT[2:0]),
    .uncached_ARID                      (uncached_ARID[AXI_ID_WIDTH-1:0]),
    .uncached_ARUSER                    (uncached_ARUSER[AXI_USER_WIDTH-1:0]),
    .uncached_ARLEN                     (uncached_ARLEN[7:0]),
    .uncached_ARSIZE                    (uncached_ARSIZE[2:0]),
    .uncached_ARBURST                   (uncached_ARBURST[1:0]),
    .uncached_ARLOCK                    (uncached_ARLOCK),
    .uncached_ARCACHE                   (uncached_ARCACHE[3:0]),
    .uncached_ARQOS                     (uncached_ARQOS[3:0]),
    .uncached_ARREGION                  (uncached_ARREGION[3:0]),
    .uncached_RREADY                    (uncached_RREADY),
    .uncached_AWVALID                   (uncached_AWVALID),
    .uncached_AWADDR                    (uncached_AWADDR[AXI_ADDR_WIDTH-1:0]),
    .uncached_AWPROT                    (uncached_AWPROT[2:0]),
    .uncached_AWID                      (uncached_AWID[AXI_ID_WIDTH-1:0]),
    .uncached_AWUSER                    (uncached_AWUSER[AXI_USER_WIDTH-1:0]),
    .uncached_AWLEN                     (uncached_AWLEN[7:0]),
    .uncached_AWSIZE                    (uncached_AWSIZE[2:0]),
    .uncached_AWBURST                   (uncached_AWBURST[1:0]),
    .uncached_AWLOCK                    (uncached_AWLOCK),
    .uncached_AWCACHE                   (uncached_AWCACHE[3:0]),
    .uncached_AWQOS                     (uncached_AWQOS[3:0]),
    .uncached_AWREGION                  (uncached_AWREGION[3:0]),
    .uncached_WVALID                    (uncached_WVALID),
    .uncached_WDATA                     (uncached_WDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .uncached_WSTRB                     (uncached_WSTRB[(1<<AXI_P_DW_BYTES)-1:0]),
    .uncached_WLAST                     (uncached_WLAST),
    .uncached_WUSER                     (uncached_WUSER[AXI_USER_WIDTH-1:0]),
    .uncached_BREADY                    (uncached_BREADY),
    // Inputs
    .clk                                (clk),
    .rst                                (rst),
    .ibus_ARREADY                       (ibus_ARREADY),
    .ibus_RVALID                        (ibus_RVALID),
    .ibus_RDATA                         (ibus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .ibus_RLAST                         (ibus_RLAST),
    .ibus_RRESP                         (ibus_RRESP[1:0]),
    .ibus_RID                           (ibus_RID[AXI_ID_WIDTH-1:0]),
    .ibus_RUSER                         (ibus_RUSER[AXI_USER_WIDTH-1:0]),
    .dbus_ARREADY                       (dbus_ARREADY),
    .dbus_RVALID                        (dbus_RVALID),
    .dbus_RDATA                         (dbus_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .dbus_RRESP                         (dbus_RRESP[1:0]),
    .dbus_RLAST                         (dbus_RLAST),
    .dbus_RID                           (dbus_RID[AXI_ID_WIDTH-1:0]),
    .dbus_RUSER                         (dbus_RUSER[AXI_USER_WIDTH-1:0]),
    .dbus_AWREADY                       (dbus_AWREADY),
    .dbus_WREADY                        (dbus_WREADY),
    .dbus_BVALID                        (dbus_BVALID),
    .dbus_BRESP                         (dbus_BRESP[1:0]),
    .dbus_BID                           (dbus_BID[AXI_ID_WIDTH-1:0]),
    .dbus_BUSER                         (dbus_BUSER[AXI_USER_WIDTH-1:0]),
    .uncached_ARREADY                   (uncached_ARREADY),
    .uncached_RVALID                    (uncached_RVALID),
    .uncached_RDATA                     (uncached_RDATA[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .uncached_RRESP                     (uncached_RRESP[1:0]),
    .uncached_RLAST                     (uncached_RLAST),
    .uncached_RID                       (uncached_RID[AXI_ID_WIDTH-1:0]),
    .uncached_RUSER                     (uncached_RUSER[AXI_USER_WIDTH-1:0]),
    .uncached_AWREADY                   (uncached_AWREADY),
    .uncached_WREADY                    (uncached_WREADY),
    .uncached_BVALID                    (uncached_BVALID),
    .uncached_BRESP                     (uncached_BRESP[1:0]),
    .uncached_BID                       (uncached_BID[AXI_ID_WIDTH-1:0]),
    .uncached_BUSER                     (uncached_BUSER[AXI_USER_WIDTH-1:0]),
    .irqs                               (irqs[CONFIG_NUM_IRQ-1:0]));

   assign io_uart_out_valid = 'b0;
   assign io_uart_out_ch = 'b0;
   assign io_uart_in_valid = 'b0;
    
endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../rtl"
// )
// End:
