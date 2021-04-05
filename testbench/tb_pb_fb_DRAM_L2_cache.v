`include "timescale.v"

module tb_pb_fb_DRAM_L2_cache();

   reg clk = 0;
   reg sdr_clk = 0;
   reg rst_n;
   reg DRAM_CLK = 0;

   // DRAM clk 100MHz
   localparam tCK = 10; // ns
   initial begin
      // phrase +0.8ns (+28.8deg)
      #0.8 forever #(tCK/2) sdr_clk = ~sdr_clk;
   end
   initial begin
      forever #(tCK/2) DRAM_CLK = ~DRAM_CLK;
   end
   // Cache clk 80MHz
   initial begin
      forever #(12.5/2) clk = ~clk;
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

   sdr #(
      .MEMH_FILE_B0 ("sdram_test_b0.mem"),
      .MEMH_FILE_B1 ("sdram_test_b1.mem"),
      .MEMH_FILE_B2 ("sdram_test_b2.mem"),
      .MEMH_FILE_B3 ("sdram_test_b3.mem")
   )
   sdram0 (
      DRAM_DATA, DRAM_ADDR, DRAM_BA,
      DRAM_CLK, DRAM_CKE,
      DRAM_CS_WE_RAS_CAS_L[3], DRAM_CS_WE_RAS_CAS_L[1], DRAM_CS_WE_RAS_CAS_L[0], DRAM_CS_WE_RAS_CAS_L[2],
      DRAM_DQM
   );

   localparam AW = 25;
   localparam CMD_ADDR_WIDTH = AW-2; // 23
   localparam L2_DW = 32;
   localparam NL_DW = L2_DW / 2; // 16

   wire sdr_cmd_bst_we_req;
   wire sdr_cmd_bst_we_ack;
   wire sdr_cmd_bst_rd_req;
   wire sdr_cmd_bst_rd_ack;
   wire [CMD_ADDR_WIDTH-1:0] sdr_cmd_addr;
   wire [NL_DW-1:0] sdr_din;
   wire [NL_DW-1:0] sdr_dout;
   wire sdr_r_vld;
   wire sdr_w_rdy;

   wire                  l2_ch_BVALID;
   reg                   l2_ch_BREADY;
   wire [L2_DW/8-1:0]    l2_ch_AWMSK;
   wire                  l2_ch_AREADY; /* sram is ready to accept cmd */
   reg                   l2_ch_AVALID; /* cmd is presented at sram'input */
   reg [AW-1:0]          l2_ch_AADDR;
   wire [L2_DW-1:0]      l2_ch_BDATA;
   wire [L2_DW-1:0]      l2_ch_ADATA;
   reg                   l2_ch_flush = 0;

   pb_fb_DRAM_ctrl fb_DRAM_ctrl
   (
      .clk     (sdr_clk),
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

   pb_fb_L2_cache
   #(
      .CONFIG_PIPEBUF_BYPASS(0)
   )
   L2_cache
   (
      .clk           (clk),
      .rst_n         (rst_n),
      .l2_ch_BREADY  (l2_ch_BREADY),
      .l2_ch_BVALID  (l2_ch_BVALID),
      .l2_ch_AWMSK   (l2_ch_AWMSK),
      .l2_ch_AREADY  (l2_ch_AREADY),
      .l2_ch_AVALID  (l2_ch_AVALID),
      .l2_ch_AADDR   (l2_ch_AADDR),
      .l2_ch_BDATA   (l2_ch_BDATA),
      .l2_ch_ADATA   (l2_ch_ADATA),
      .l2_ch_flush   (l2_ch_flush),

      .sdr_clk       (sdr_clk),
      .sdr_rst_n     (rst_n),
      .sdr_din       (sdr_din),
      .sdr_dout      (sdr_dout),
      .sdr_cmd_bst_rd_req  (sdr_cmd_bst_rd_req),
      .sdr_cmd_bst_we_req  (sdr_cmd_bst_we_req),
      .sdr_cmd_addr  (sdr_cmd_addr),
      .sdr_w_rdy  (sdr_w_rdy),
      .sdr_r_vld  (sdr_r_vld)
   );

   assign l2_ch_ADATA = 32'h34567890;
   assign l2_ch_AWMSK = 4'b0000; //4'b1111;

   initial begin
      #0 l2_ch_AVALID = 1;
      #0 l2_ch_BREADY = 1;
      #0 l2_ch_AADDR = 25'h0;

      #334781.25 l2_ch_BREADY = 0;
   end
   initial begin
      #334832.25 l2_ch_BREADY = 1;
   end

   always @(posedge clk)
      if (l2_ch_AVALID & l2_ch_AREADY)
         l2_ch_AADDR <= l2_ch_AADDR + 1'b1;

   wire hds_cmd = l2_ch_AREADY & l2_ch_AVALID;
   wire hds_dout = l2_ch_BREADY & l2_ch_BVALID;

   always @(posedge clk) begin
      if(hds_cmd)
         l2_ch_AADDR <= l2_ch_AADDR + 'd4; //'d64;
   end
   always @(posedge clk) begin
      if(hds_dout) begin
         l2_ch_AVALID <= 1;
      end
   end

endmodule
