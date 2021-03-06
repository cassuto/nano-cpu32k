`include "timescale.v"
`timescale 1ns / 1ps

module tb_pb_fb_DRAM_ctrl();

   reg clk = 0;
   reg rst_n;
   reg DRAM_CLK = 0;

   localparam tCK = 10; // ns

   initial begin
      // phrase +0.8ns (+28.8deg)
      #0.8 forever #(tCK/2) clk = ~clk;
   end
   initial begin
      forever #(tCK/2) DRAM_CLK = ~DRAM_CLK;
   end

   // Generate reset
   initial begin
      rst_n = 1'b0;
      #10 rst_n= 1'b1;
   end

   localparam ADDR_BITS = 13;
   localparam BA_BITS = 2;
   localparam DQ_BITS = 16;
   localparam DM_BITS = 2;

   wire                     DRAM_CKE;                           // Synchronous Clock Enable
   wire [ADDR_BITS - 1 : 0] DRAM_ADDR;                          // SDRAM Address
   wire   [BA_BITS - 1 : 0] DRAM_BA;                            // Bank Address
   wire   [DQ_BITS - 1 : 0] DRAM_DATA;                            // SDRAM I/O
   wire   [DM_BITS - 1 : 0] DRAM_DQM;                           // Data Mask

   wire [3:0] DRAM_CS_WE_RAS_CAS_L;

   sdr sdram0 (
      DRAM_DATA, DRAM_ADDR, DRAM_BA,
      DRAM_CLK, DRAM_CKE,
      DRAM_CS_WE_RAS_CAS_L[3], DRAM_CS_WE_RAS_CAS_L[1], DRAM_CS_WE_RAS_CAS_L[0], DRAM_CS_WE_RAS_CAS_L[2],
      DRAM_DQM
   );

   localparam CMD_ADDR_WIDTH = 23;
   localparam DW = 16;

   reg sdr_cmd_bst_we_req = 0;
   wire sdr_cmd_bst_we_ack;
   reg sdr_cmd_bst_rd_req = 0;
   wire sdr_cmd_bst_rd_ack;
   reg [CMD_ADDR_WIDTH-1:0] sdr_cmd_addr;
   reg [DW-1:0] sdr_din;
   wire [DW-1:0] sdr_dout;
   wire sdr_r_vld;
   wire sdr_w_rdy;

   pb_fb_DRAM_ctrl fb_DRAM_ctrl
   (
      .clk     (clk),
      .rst_n   (rst_n),
      .DRAM_CKE (DRAM_CKE),
      .DRAM_CS_WE_RAS_CAS_L (DRAM_CS_WE_RAS_CAS_L), // SDRAM #CS, #WE, #RAS, #CAS
      .DRAM_BA (DRAM_BA), // SDRAM bank address
      .DRAM_ADDR (DRAM_ADDR), // SDRAM address
      .DRAM_DATA (DRAM_DATA), // SDRAM data
      .DRAM_DQM (DRAM_DQM), // SDRAM DQM
      .sdr_cmd_bst_we_req (sdr_cmd_bst_we_req),
      .sdr_cmd_bst_we_ack (sdr_cmd_bst_we_ack),
      .sdr_cmd_bst_rd_req (sdr_cmd_bst_rd_req),
      .sdr_cmd_bst_rd_ack (sdr_cmd_bst_rd_ack),
      .sdr_cmd_addr (sdr_cmd_addr),
      .sdr_din (sdr_din),
      .sdr_dout (sdr_dout),
      .sdr_r_vld (sdr_r_vld),
      .sdr_w_rdy (sdr_w_rdy)
   );

   // test Write
   initial begin
      #30 sdr_cmd_addr = 23'd32;
      #30 sdr_din = 16'h1234;
      #30 sdr_cmd_bst_we_req <= 1'b1;
   end

   always @(posedge clk)
      if(sdr_cmd_bst_we_ack)
         sdr_cmd_bst_we_req <= 1'b0;

endmodule
