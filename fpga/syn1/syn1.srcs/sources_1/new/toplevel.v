`timescale 1ns / 1ps

module toplevel(
    input clk,
    input rst_n,
    /*AUTOINPUT*/
    // Beginning of automatic inputs (from unused autoinst inputs)
    input               io_interrupt,           // To CPU of ysyx_20210479.v
    input               io_master_arready,      // To CPU of ysyx_20210479.v
    input               io_master_awready,      // To CPU of ysyx_20210479.v
    input [3:0]         io_master_bid,          // To CPU of ysyx_20210479.v
    input [1:0]         io_master_bresp,        // To CPU of ysyx_20210479.v
    input               io_master_bvalid,       // To CPU of ysyx_20210479.v
    input [63:0]        io_master_rdata,        // To CPU of ysyx_20210479.v
    input [3:0]         io_master_rid,          // To CPU of ysyx_20210479.v
    input               io_master_rlast,        // To CPU of ysyx_20210479.v
    input [1:0]         io_master_rresp,        // To CPU of ysyx_20210479.v
    input               io_master_rvalid,       // To CPU of ysyx_20210479.v
    input               io_master_wready,       // To CPU of ysyx_20210479.v
    input [31:0]        io_slave_araddr,        // To CPU of ysyx_20210479.v
    input [1:0]         io_slave_arburst,       // To CPU of ysyx_20210479.v
    input [3:0]         io_slave_arid,          // To CPU of ysyx_20210479.v
    input [7:0]         io_slave_arlen,         // To CPU of ysyx_20210479.v
    input [2:0]         io_slave_arsize,        // To CPU of ysyx_20210479.v
    input               io_slave_arvalid,       // To CPU of ysyx_20210479.v
    input [31:0]        io_slave_awaddr,        // To CPU of ysyx_20210479.v
    input [1:0]         io_slave_awburst,       // To CPU of ysyx_20210479.v
    input [3:0]         io_slave_awid,          // To CPU of ysyx_20210479.v
    input [7:0]         io_slave_awlen,         // To CPU of ysyx_20210479.v
    input [2:0]         io_slave_awsize,        // To CPU of ysyx_20210479.v
    input               io_slave_awvalid,       // To CPU of ysyx_20210479.v
    input               io_slave_bready,        // To CPU of ysyx_20210479.v
    input               io_slave_rready,        // To CPU of ysyx_20210479.v
    input [63:0]        io_slave_wdata,         // To CPU of ysyx_20210479.v
    input               io_slave_wlast,         // To CPU of ysyx_20210479.v
    input [7:0]         io_slave_wstrb,         // To CPU of ysyx_20210479.v
    input               io_slave_wvalid,        // To CPU of ysyx_20210479.v
    // End of automatics
    /*AUTOOUTPUT*/
    // Beginning of automatic outputs (from unused autoinst outputs)
    output [31:0]       io_master_araddr,       // From CPU of ysyx_20210479.v
    output [1:0]        io_master_arburst,      // From CPU of ysyx_20210479.v
    output [3:0]        io_master_arid,         // From CPU of ysyx_20210479.v
    output [7:0]        io_master_arlen,        // From CPU of ysyx_20210479.v
    output [2:0]        io_master_arsize,       // From CPU of ysyx_20210479.v
    output              io_master_arvalid,      // From CPU of ysyx_20210479.v
    output [31:0]       io_master_awaddr,       // From CPU of ysyx_20210479.v
    output [1:0]        io_master_awburst,      // From CPU of ysyx_20210479.v
    output [3:0]        io_master_awid,         // From CPU of ysyx_20210479.v
    output [7:0]        io_master_awlen,        // From CPU of ysyx_20210479.v
    output [2:0]        io_master_awsize,       // From CPU of ysyx_20210479.v
    output              io_master_awvalid,      // From CPU of ysyx_20210479.v
    output              io_master_bready,       // From CPU of ysyx_20210479.v
    output              io_master_rready,       // From CPU of ysyx_20210479.v
    output [63:0]       io_master_wdata,        // From CPU of ysyx_20210479.v
    output              io_master_wlast,        // From CPU of ysyx_20210479.v
    output [7:0]        io_master_wstrb,        // From CPU of ysyx_20210479.v
    output              io_master_wvalid,       // From CPU of ysyx_20210479.v
    output              io_slave_arready,       // From CPU of ysyx_20210479.v
    output              io_slave_awready,       // From CPU of ysyx_20210479.v
    output [3:0]        io_slave_bid,           // From CPU of ysyx_20210479.v
    output [1:0]        io_slave_bresp,         // From CPU of ysyx_20210479.v
    output              io_slave_bvalid,        // From CPU of ysyx_20210479.v
    output [63:0]       io_slave_rdata,         // From CPU of ysyx_20210479.v
    output [3:0]        io_slave_rid,           // From CPU of ysyx_20210479.v
    output              io_slave_rlast,         // From CPU of ysyx_20210479.v
    output [1:0]        io_slave_rresp,         // From CPU of ysyx_20210479.v
    output              io_slave_rvalid,        // From CPU of ysyx_20210479.v
    output              io_slave_wready        // From CPU of ysyx_20210479.v
    // End of automatics
);
    wire clock;
    wire reset;
    /*AUTOWIRE*/
    
    assign reset = ~rst_n;
    
    clk_wiz_0 PLL
    (
        .clk_in1   (clk),
        .clk_out1  (clock),
        .reset      (rst_n),
        .locked   ()
    );
    
    ysyx_20210479 CPU(/*AUTOINST*/
                      // Outputs
                      .io_master_awvalid(io_master_awvalid),
                      .io_master_awaddr (io_master_awaddr[31:0]),
                      .io_master_awid   (io_master_awid[3:0]),
                      .io_master_awlen  (io_master_awlen[7:0]),
                      .io_master_awsize (io_master_awsize[2:0]),
                      .io_master_awburst(io_master_awburst[1:0]),
                      .io_master_wvalid (io_master_wvalid),
                      .io_master_wdata  (io_master_wdata[63:0]),
                      .io_master_wstrb  (io_master_wstrb[7:0]),
                      .io_master_wlast  (io_master_wlast),
                      .io_master_bready (io_master_bready),
                      .io_master_arvalid(io_master_arvalid),
                      .io_master_araddr (io_master_araddr[31:0]),
                      .io_master_arid   (io_master_arid[3:0]),
                      .io_master_arlen  (io_master_arlen[7:0]),
                      .io_master_arsize (io_master_arsize[2:0]),
                      .io_master_rready (io_master_rready),
                      .io_slave_awready (io_slave_awready),
                      .io_slave_wready  (io_slave_wready),
                      .io_slave_bvalid  (io_slave_bvalid),
                      .io_slave_bresp   (io_slave_bresp[1:0]),
                      .io_slave_bid     (io_slave_bid[3:0]),
                      .io_slave_arready (io_slave_arready),
                      .io_master_arburst(io_master_arburst[1:0]),
                      .io_slave_rvalid  (io_slave_rvalid),
                      .io_slave_rresp   (io_slave_rresp[1:0]),
                      .io_slave_rdata   (io_slave_rdata[63:0]),
                      .io_slave_rlast   (io_slave_rlast),
                      .io_slave_rid     (io_slave_rid[3:0]),
                      // Inputs
                      .clock            (clock),
                      .reset            (reset),
                      .io_interrupt     (io_interrupt),
                      .io_master_awready(io_master_awready),
                      .io_master_wready (io_master_wready),
                      .io_master_bvalid (io_master_bvalid),
                      .io_master_bresp  (io_master_bresp[1:0]),
                      .io_master_bid    (io_master_bid[3:0]),
                      .io_master_arready(io_master_arready),
                      .io_master_rvalid (io_master_rvalid),
                      .io_master_rresp  (io_master_rresp[1:0]),
                      .io_master_rdata  (io_master_rdata[63:0]),
                      .io_master_rlast  (io_master_rlast),
                      .io_master_rid    (io_master_rid[3:0]),
                      .io_slave_awvalid (io_slave_awvalid),
                      .io_slave_awaddr  (io_slave_awaddr[31:0]),
                      .io_slave_awid    (io_slave_awid[3:0]),
                      .io_slave_awlen   (io_slave_awlen[7:0]),
                      .io_slave_awsize  (io_slave_awsize[2:0]),
                      .io_slave_awburst (io_slave_awburst[1:0]),
                      .io_slave_wvalid  (io_slave_wvalid),
                      .io_slave_wdata   (io_slave_wdata[63:0]),
                      .io_slave_wstrb   (io_slave_wstrb[7:0]),
                      .io_slave_wlast   (io_slave_wlast),
                      .io_slave_bready  (io_slave_bready),
                      .io_slave_arvalid (io_slave_arvalid),
                      .io_slave_araddr  (io_slave_araddr[31:0]),
                      .io_slave_arid    (io_slave_arid[3:0]),
                      .io_slave_arlen   (io_slave_arlen[7:0]),
                      .io_slave_arsize  (io_slave_arsize[2:0]),
                      .io_slave_arburst (io_slave_arburst[1:0]),
                      .io_slave_rready  (io_slave_rready));

endmodule

// Local Variables:
// verilog-library-directories:(
//  "../../../../../rtl/port"
// )
// End:
