// for testbench only

`include "ncpu32k_config.h"

// synthesis translate_off
`ifndef SYNTHESIS

module handshake_cmd_sram
#(
   parameter DW = 32, //`NCPU_DW,
   parameter AW = `NCPU_AW,
   parameter SIZE_BYTES = 32*1024*1024,
   parameter MEMH_FILE = "",
   parameter DELAY=3
)
(
   input                      clk,
   input                      rst_n,
   output                     BVALID,
   input                      BREADY,
   output reg [DW-1:0]        BDATA,
   output reg [1:0]           BEXC,
   input [DW/8-1:0]           AWMSK,
   output                     AREADY,
   input                      AVALID,
   input [`NCPU_AW-1:0]       AADDR,
   input [DW-1:0]             ADATA,
   input [1:0]                AEXC
);
   localparam SIZE_WORDS = SIZE_BYTES/DW*8;
   reg[DW-1:0] mem[0:SIZE_WORDS-1];

   initial begin : initial_blk
      integer i;
      for(i=0;i<SIZE_WORDS;i=i+1) begin : for_size_bytes
         mem[i] = {DW{1'b0}};
      end
      if(MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (MEMH_FILE, mem);
      end
      BDATA = {DW{1'b0}};
      BEXC = {DW/8{1'b0}};
   end

   wire [AW-1:0] addr_w;
   wire [DW-1:0] dout_nxt = mem[addr_w[AW-1:2]];
   wire [DW/8-1:0] awmsk_w;

   reg [AW-1:0] addr_r;
   reg [DW-1:0] din_r;
   reg [1:0] exc_r;
   reg [DW/8-1:0] we_msk_r;
   reg [10:0] delay_r=4;

   assign awmsk_w = AWMSK & {DW/8{~|AEXC}};

   generate
      if(DELAY>=128) begin : delay_random
         localparam DELAY_MAX = 16;
         localparam DELAY_MIN = 3;// >=3
         wire push = (AVALID & AREADY);
         wire pop = (BVALID & BREADY);
         
         reg [10:0] valid_nxt;
         reg [10:0] valid_r = 10'd0;
         
         assign addr_w = addr_r;
         
         always @* begin
            if(valid_r==10'd0) begin
               valid_nxt = push ? 10'd1 : 10'd0;
            end else if(valid_r >= 10'd1 && valid_r < delay_r) begin
               valid_nxt = valid_r + 10'd1;
            end else if(valid_r == delay_r) begin
               valid_nxt = pop & push ? 10'd1 : pop ? 10'd0 : delay_r;
            end
         end
         always @(posedge clk or negedge rst_n) begin
            if (~rst_n)
               begin
                  valid_r <= 10'd0;
               end
            else
               begin
                  valid_r <= valid_nxt;
                  case (valid_nxt)
                  10'd1: begin
                     if (|awmsk_w) begin
                        din_r <= ADATA; // Read ADATA
                     end
                     addr_r <= AADDR; // Read address
                     exc_r <= AEXC;
                     we_msk_r <= awmsk_w;
                     delay_r <= ({$random} % DELAY_MAX) + DELAY_MIN; // Random delay
                  end
                  delay_r: begin
                     if (|we_msk_r) begin
                        if(we_msk_r[3])
                           mem[addr_r[AW-1:2]][31:24] <= ADATA[31:24];
                        if(we_msk_r[2])
                           mem[addr_r[AW-1:2]][23:16] <= ADATA[23:16];
                        if(we_msk_r[1])
                           mem[addr_r[AW-1:2]][15:8] <= ADATA[15:8];
                        if(we_msk_r[0])
                           mem[addr_r[AW-1:2]][7:0] <= ADATA[7:0];
                     end else begin
                        BDATA <= dout_nxt; // Output
                        BEXC <= exc_r;
                     end
                  end
                  endcase
               end
         end
         assign BVALID = valid_r==delay_r;
         
         assign AREADY = valid_r==10'd0;
         
      end else if(DELAY>=3)  begin : delay_n
         wire push = (AVALID & AREADY);
         wire pop = (BVALID & BREADY);
         
         reg [10:0] valid_nxt;
         reg [10:0] valid_r = 10'd0;
         
         assign addr_w = addr_r;
         
         always @* begin
            if(valid_r==10'd0) begin
               valid_nxt = push ? 10'd1 : 10'd0;
            end else if(valid_r >= 10'd1 && valid_r < DELAY) begin
               valid_nxt = valid_r + 10'd1;
            end else if(valid_r == DELAY) begin
               valid_nxt = pop & push ? 10'd1 : pop ? 10'd0 : DELAY;
            end
         end
         always @(posedge clk or negedge rst_n) begin
            if (~rst_n)
               begin
                  valid_r <= 10'd0;
               end
            else
               begin
                  valid_r <= valid_nxt;
                  case (valid_nxt)
                  10'd1: begin
                     if (|awmsk_w) begin
                        din_r <= ADATA; // Read ADATA
                     end
                     addr_r <= AADDR; // Read address
                     exc_r <= AEXC;
                     we_msk_r <= awmsk_w;
                  end
                  DELAY: begin
                     if (|we_msk_r) begin
                        if(we_msk_r[3])
                           mem[addr_r[AW-1:2]][31:24] <= ADATA[31:24];
                        if(we_msk_r[2])
                           mem[addr_r[AW-1:2]][23:16] <= ADATA[23:16];
                        if(we_msk_r[1])
                           mem[addr_r[AW-1:2]][15:8] <= ADATA[15:8];
                        if(we_msk_r[0])
                           mem[addr_r[AW-1:2]][7:0] <= ADATA[7:0];
                     end else begin
                        BDATA <= dout_nxt; // Output
                        BEXC <= exc_r;
                     end
                  end
                  endcase
               end
         end
         assign BVALID = valid_r==DELAY;
         
         assign AREADY = valid_r==10'd0;

      end else if (DELAY==2) begin : delay_2
         assign addr_w = AADDR;
         wire push = (AVALID & AREADY);
         wire pop = (BVALID & BREADY);
         wire valid_nxt = (push | ~pop);
         nDFF_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, BVALID);
                         
         assign AREADY = ~BVALID;
         always @(posedge clk) begin
            if(push & ~|awmsk_w) begin
               BDATA <= dout_nxt;
               BEXC <= AEXC;
            end
         end
         always @(posedge clk) begin
            if(push) begin
               if(awmsk_w[3])
                  mem[AADDR[AW-1:2]][31:24] <= ADATA[31:24];
               if(awmsk_w[2])
                  mem[AADDR[AW-1:2]][23:16] <= ADATA[23:16];
               if(awmsk_w[1])
                  mem[AADDR[AW-1:2]][15:8] <= ADATA[15:8];
               if(awmsk_w[0])
                  mem[AADDR[AW-1:2]][7:0] <= ADATA[7:0];
            end
         end
      end else if(DELAY==1) begin : delay_1
         assign addr_w = AADDR;
         wire push = (AVALID & AREADY);
         wire pop = (BVALID & BREADY);
         wire valid_nxt = (push | ~pop);
         nDFF_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, BVALID);

         assign AREADY = ~BVALID | pop;
         always @(posedge clk) begin
            if(push & ~|awmsk_w) begin
               BDATA <= dout_nxt;
               BEXC <= AEXC;
            end
         end
         always @(posedge clk) begin
            if(push) begin
               if(awmsk_w[3])
                  mem[AADDR[AW-1:2]][31:24] <= ADATA[31:24];
               if(awmsk_w[2])
                  mem[AADDR[AW-1:2]][23:16] <= ADATA[23:16];
               if(awmsk_w[1])
                  mem[AADDR[AW-1:2]][15:8] <= ADATA[15:8];
               if(awmsk_w[0])
                  mem[AADDR[AW-1:2]][7:0] <= ADATA[7:0];
            end
         end
      end
   endgenerate

endmodule

`endif
// synthesis translate_on
