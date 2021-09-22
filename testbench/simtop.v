`define AXI_TOP_INTERFACE(name) io_memAXI_0_``name

`define AXI_P_DW_BYTES      3
`define AXI_ADDR_WIDTH      32
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
   input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_user),
   
   output                              break_point
);
   
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [31:0]          io_master_araddr;       // From U_DUT of ysyx_20210479.v
   wire [1:0]           io_master_arburst;      // From U_DUT of ysyx_20210479.v
   wire [3:0]           io_master_arid;         // From U_DUT of ysyx_20210479.v
   wire [7:0]           io_master_arlen;        // From U_DUT of ysyx_20210479.v
   wire [2:0]           io_master_arsize;       // From U_DUT of ysyx_20210479.v
   wire                 io_master_arvalid;      // From U_DUT of ysyx_20210479.v
   wire [31:0]          io_master_awaddr;       // From U_DUT of ysyx_20210479.v
   wire [1:0]           io_master_awburst;      // From U_DUT of ysyx_20210479.v
   wire [3:0]           io_master_awid;         // From U_DUT of ysyx_20210479.v
   wire [7:0]           io_master_awlen;        // From U_DUT of ysyx_20210479.v
   wire [2:0]           io_master_awsize;       // From U_DUT of ysyx_20210479.v
   wire                 io_master_awvalid;      // From U_DUT of ysyx_20210479.v
   wire                 io_master_bready;       // From U_DUT of ysyx_20210479.v
   wire                 io_master_rready;       // From U_DUT of ysyx_20210479.v
   wire [63:0]          io_master_wdata;        // From U_DUT of ysyx_20210479.v
   wire                 io_master_wlast;        // From U_DUT of ysyx_20210479.v
   wire [7:0]           io_master_wstrb;        // From U_DUT of ysyx_20210479.v
   wire                 io_master_wvalid;       // From U_DUT of ysyx_20210479.v
   wire                 io_slave_arready;       // From U_DUT of ysyx_20210479.v
   wire                 io_slave_awready;       // From U_DUT of ysyx_20210479.v
   wire [3:0]           io_slave_bid;           // From U_DUT of ysyx_20210479.v
   wire [1:0]           io_slave_bresp;         // From U_DUT of ysyx_20210479.v
   wire                 io_slave_bvalid;        // From U_DUT of ysyx_20210479.v
   wire [63:0]          io_slave_rdata;         // From U_DUT of ysyx_20210479.v
   wire [3:0]           io_slave_rid;           // From U_DUT of ysyx_20210479.v
   wire                 io_slave_rlast;         // From U_DUT of ysyx_20210479.v
   wire [1:0]           io_slave_rresp;         // From U_DUT of ysyx_20210479.v
   wire                 io_slave_rvalid;        // From U_DUT of ysyx_20210479.v
   wire                 io_slave_wready;        // From U_DUT of ysyx_20210479.v
   // End of automatics
   /*AUTOINPUT*/
   wire                 io_master_arready;      // To U_DUT of ysyx_20210479.v
   wire                 io_master_awready;      // To U_DUT of ysyx_20210479.v
   wire  [3:0]          io_master_bid;          // To U_DUT of ysyx_20210479.v
   wire  [1:0]          io_master_bresp;        // To U_DUT of ysyx_20210479.v
   wire                 io_master_bvalid;       // To U_DUT of ysyx_20210479.v
   wire  [63:0]         io_master_rdata;        // To U_DUT of ysyx_20210479.v
   wire  [3:0]          io_master_rid;          // To U_DUT of ysyx_20210479.v
   wire                 io_master_rlast;        // To U_DUT of ysyx_20210479.v
   wire  [1:0]          io_master_rresp;        // To U_DUT of ysyx_20210479.v
   wire                 io_master_rvalid;       // To U_DUT of ysyx_20210479.v
   wire                 io_master_wready;       // To U_DUT of ysyx_20210479.v
   wire  [31:0]         io_slave_araddr;        // To U_DUT of ysyx_20210479.v
   wire  [1:0]          io_slave_arburst;       // To U_DUT of ysyx_20210479.v
   wire  [3:0]          io_slave_arid;          // To U_DUT of ysyx_20210479.v
   wire  [7:0]          io_slave_arlen;         // To U_DUT of ysyx_20210479.v
   wire  [2:0]          io_slave_arsize;        // To U_DUT of ysyx_20210479.v
   wire                 io_slave_arvalid;       // To U_DUT of ysyx_20210479.v
   wire  [31:0]         io_slave_awaddr;        // To U_DUT of ysyx_20210479.v
   wire  [1:0]          io_slave_awburst;       // To U_DUT of ysyx_20210479.v
   wire  [3:0]          io_slave_awid;          // To U_DUT of ysyx_20210479.v
   wire  [7:0]          io_slave_awlen;         // To U_DUT of ysyx_20210479.v
   wire  [2:0]          io_slave_awsize;        // To U_DUT of ysyx_20210479.v
   wire                 io_slave_awvalid;       // To U_DUT of ysyx_20210479.v
   wire                 io_slave_bready;        // To U_DUT of ysyx_20210479.v
   wire                 io_slave_rready;        // To U_DUT of ysyx_20210479.v
   wire  [63:0]         io_slave_wdata;         // To U_DUT of ysyx_20210479.v
   wire                 io_slave_wlast;         // To U_DUT of ysyx_20210479.v
   wire  [7:0]          io_slave_wstrb;         // To U_DUT of ysyx_20210479.v
   wire                 io_slave_wvalid;        // To U_DUT of ysyx_20210479.v
   wire                 io_interrupt;

   assign io_master_arready                                 = `AXI_TOP_INTERFACE(ar_ready);
   assign `AXI_TOP_INTERFACE(ar_valid)             = io_master_arvalid;
   assign `AXI_TOP_INTERFACE(ar_bits_addr)         = io_master_araddr;
   assign `AXI_TOP_INTERFACE(ar_bits_prot)         = 'b0; //io_master_arprot;
   assign `AXI_TOP_INTERFACE(ar_bits_id)           = io_master_arid;
   assign `AXI_TOP_INTERFACE(ar_bits_user)         = 'b0; //io_master_aruser;
   assign `AXI_TOP_INTERFACE(ar_bits_len)          = io_master_arlen;
   assign `AXI_TOP_INTERFACE(ar_bits_size)         = io_master_arsize;
   assign `AXI_TOP_INTERFACE(ar_bits_burst)        = io_master_arburst;
   assign `AXI_TOP_INTERFACE(ar_bits_lock)         = 'b0; //io_master_arlock;
   assign `AXI_TOP_INTERFACE(ar_bits_cache)        = 'b0; //io_master_arcache;
   assign `AXI_TOP_INTERFACE(ar_bits_qos)          = 'b0; //io_master_arqos;

   assign `AXI_TOP_INTERFACE(r_ready)              = io_master_rready;
   assign io_master_rvalid                                  = `AXI_TOP_INTERFACE(r_valid);
   assign io_master_rresp                                   = `AXI_TOP_INTERFACE(r_bits_resp);
   assign io_master_rdata                                   = `AXI_TOP_INTERFACE(r_bits_data)[0];
   assign io_master_rlast                                   = `AXI_TOP_INTERFACE(r_bits_last);
   assign io_master_rid                                     = `AXI_TOP_INTERFACE(r_bits_id);
   //assign io_master_ruser                                   = `AXI_TOP_INTERFACE(r_bits_user);

   assign io_master_awready                                 = `AXI_TOP_INTERFACE(aw_ready);
   assign `AXI_TOP_INTERFACE(aw_valid)             = io_master_awvalid;
   assign `AXI_TOP_INTERFACE(aw_bits_addr)         = io_master_awaddr;
   assign `AXI_TOP_INTERFACE(aw_bits_prot)         = 'b0; //io_master_awprot;
   assign `AXI_TOP_INTERFACE(aw_bits_id)           = io_master_awid;
   assign `AXI_TOP_INTERFACE(aw_bits_user)         = 'b0; //io_master_awuser;
   assign `AXI_TOP_INTERFACE(aw_bits_len)          = io_master_awlen;
   assign `AXI_TOP_INTERFACE(aw_bits_size)         = io_master_awsize;
   assign `AXI_TOP_INTERFACE(aw_bits_burst)        = io_master_awburst;
   assign `AXI_TOP_INTERFACE(aw_bits_lock)         = 'b0; //io_master_awlock;
   assign `AXI_TOP_INTERFACE(aw_bits_cache)        = 'b0; //io_master_awcache;
   assign `AXI_TOP_INTERFACE(aw_bits_qos)          = 'b0; //io_master_awqos;
   
   assign io_master_wready                                  = `AXI_TOP_INTERFACE(w_ready);
   assign `AXI_TOP_INTERFACE(w_valid)              = io_master_wvalid;
   assign `AXI_TOP_INTERFACE(w_bits_data)[0]       = io_master_wdata;
   assign `AXI_TOP_INTERFACE(w_bits_data)[1]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_data)[2]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_data)[3]       = 'b0;
   assign `AXI_TOP_INTERFACE(w_bits_strb)          = io_master_wstrb;
   assign `AXI_TOP_INTERFACE(w_bits_last)          = io_master_wlast;
   
   assign `AXI_TOP_INTERFACE(b_ready)              = io_master_bready;
   assign io_master_bvalid                                  = `AXI_TOP_INTERFACE(b_valid);
   assign io_master_bresp                                   = `AXI_TOP_INTERFACE(b_bits_resp);
   assign io_master_bid                                     = `AXI_TOP_INTERFACE(b_bits_id);
   //assign io_master_buser                                   = `AXI_TOP_INTERFACE(b_bits_user);
   
   assign io_slave_araddr = 'b0;
   assign io_slave_arburst = 'b0;
   assign io_slave_arid = 'b0;
   assign io_slave_arlen = 'b0;
   assign io_slave_arsize = 'b0;
   assign io_slave_arvalid = 'b0;
   assign io_slave_awaddr = 'b0;
   assign io_slave_awburst = 'b0;
   assign io_slave_awid = 'b0;
   assign io_slave_awlen = 'b0;
   assign io_slave_awsize = 'b0;
   assign io_slave_awvalid = 'b0;
   assign io_slave_bready = 'b0;
   assign io_slave_rready = 'b0;
   assign io_slave_wdata = 'b0;
   assign io_slave_wlast = 'b0;
   assign io_slave_wstrb = 'b0;
   assign io_slave_wvalid = 'b0;
   
   assign io_interrupt = 'b0;
   
   ysyx_20210479 U_DUT
      (/*AUTOINST*/
       // Outputs
       .io_master_awvalid               (io_master_awvalid),
       .io_master_awaddr                (io_master_awaddr[31:0]),
       .io_master_awid                  (io_master_awid[3:0]),
       .io_master_awlen                 (io_master_awlen[7:0]),
       .io_master_awsize                (io_master_awsize[2:0]),
       .io_master_awburst               (io_master_awburst[1:0]),
       .io_master_wvalid                (io_master_wvalid),
       .io_master_wdata                 (io_master_wdata[63:0]),
       .io_master_wstrb                 (io_master_wstrb[7:0]),
       .io_master_wlast                 (io_master_wlast),
       .io_master_bready                (io_master_bready),
       .io_master_arvalid               (io_master_arvalid),
       .io_master_araddr                (io_master_araddr[31:0]),
       .io_master_arid                  (io_master_arid[3:0]),
       .io_master_arlen                 (io_master_arlen[7:0]),
       .io_master_arsize                (io_master_arsize[2:0]),
       .io_master_rready                (io_master_rready),
       .io_slave_awready                (io_slave_awready),
       .io_slave_wready                 (io_slave_wready),
       .io_slave_bvalid                 (io_slave_bvalid),
       .io_slave_bresp                  (io_slave_bresp[1:0]),
       .io_slave_bid                    (io_slave_bid[3:0]),
       .io_slave_arready                (io_slave_arready),
       .io_master_arburst               (io_master_arburst[1:0]),
       .io_slave_rvalid                 (io_slave_rvalid),
       .io_slave_rresp                  (io_slave_rresp[1:0]),
       .io_slave_rdata                  (io_slave_rdata[63:0]),
       .io_slave_rlast                  (io_slave_rlast),
       .io_slave_rid                    (io_slave_rid[3:0]),
       // Inputs
       .clock                           (clock),
       .reset                           (reset),
       .io_interrupt                    (io_interrupt),
       .io_master_awready               (io_master_awready),
       .io_master_wready                (io_master_wready),
       .io_master_bvalid                (io_master_bvalid),
       .io_master_bresp                 (io_master_bresp[1:0]),
       .io_master_bid                   (io_master_bid[3:0]),
       .io_master_arready               (io_master_arready),
       .io_master_rvalid                (io_master_rvalid),
       .io_master_rresp                 (io_master_rresp[1:0]),
       .io_master_rdata                 (io_master_rdata[63:0]),
       .io_master_rlast                 (io_master_rlast),
       .io_master_rid                   (io_master_rid[3:0]),
       .io_slave_awvalid                (io_slave_awvalid),
       .io_slave_awaddr                 (io_slave_awaddr[31:0]),
       .io_slave_awid                   (io_slave_awid[3:0]),
       .io_slave_awlen                  (io_slave_awlen[7:0]),
       .io_slave_awsize                 (io_slave_awsize[2:0]),
       .io_slave_awburst                (io_slave_awburst[1:0]),
       .io_slave_wvalid                 (io_slave_wvalid),
       .io_slave_wdata                  (io_slave_wdata[63:0]),
       .io_slave_wstrb                  (io_slave_wstrb[7:0]),
       .io_slave_wlast                  (io_slave_wlast),
       .io_slave_bready                 (io_slave_bready),
       .io_slave_arvalid                (io_slave_arvalid),
       .io_slave_araddr                 (io_slave_araddr[31:0]),
       .io_slave_arid                   (io_slave_arid[3:0]),
       .io_slave_arlen                  (io_slave_arlen[7:0]),
       .io_slave_arsize                 (io_slave_arsize[2:0]),
       .io_slave_arburst                (io_slave_arburst[1:0]),
       .io_slave_rready                 (io_slave_rready));
   
   assign io_uart_out_valid = 'b0;
   assign io_uart_out_ch = 'b0;
   assign io_uart_in_valid = 'b0;
    
   assign break_point = /*(U_DUT.U_CORE.U_EX.U_LSU.U_D_CACHE.fls);*/
                        (U_DUT.U_CORE.U_EX.U_EPU.msr_evect_we);
   /*'b0;*/
    
endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../rtl"
//  "../rtl/port"
// )
// End:
