// for testbench only

`include "ncpu32k_config.h"

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
   input [DW-1:0]             din,
   output                     valid,
   input                      ready,
   output reg [DW-1:0]        dout,
   input [DW/8-1:0]           cmd_we_msk,
   output                     cmd_ready, /* sram is ready to accept cmd */
   input                      cmd_valid, /* cmd is presented at sram'input */
   input [`NCPU_AW-1:0]       cmd_addr
);
   localparam SIZE_WORDS = SIZE_BYTES/DW*8;
   reg[DW-1:0] mem[0:SIZE_WORDS-1];

   initial begin
      integer i;
      for(i=0;i<SIZE_WORDS;i=i+1) begin : for_size_bytes
         mem[i] = {DW{1'b0}};
      end
      if(MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (MEMH_FILE, mem);
      end
      dout = {DW{1'b0}};
   end

   wire [AW-1:0] addr_w;
   wire [DW-1:0] dout_nxt = mem[addr_w[AW-1:2]];

   reg [AW-1:0] addr_r;
   reg [DW-1:0] din_r;
   reg [DW/8-1:0] we_msk_r;
   reg [10:0] delay_r=4;
   generate
      if(DELAY>=128) begin : delay_random
         localparam DELAY_MAX = 16;
         localparam DELAY_MIN = 3;// >=3
         wire push = (cmd_valid & cmd_ready);
         wire pop = (valid & ready);
         
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
         always @(posedge clk) begin
            valid_r <= valid_nxt;
            case (valid_nxt)
            10'd1: begin
               if (|cmd_we_msk) begin
                  din_r <= din; // Read din
               end
               addr_r <= cmd_addr; // Read address
               we_msk_r <= cmd_we_msk;
               delay_r <= ({$random} % DELAY_MAX) + DELAY_MIN; // Random delay
            end
            delay_r: begin
               if (|we_msk_r) begin
                  if(we_msk_r[3])
                     mem[addr_r[AW-1:2]][31:24] <= din[31:24];
                  if(we_msk_r[2])
                     mem[addr_r[AW-1:2]][23:16] <= din[23:16];
                  if(we_msk_r[1])
                     mem[addr_r[AW-1:2]][15:8] <= din[15:8];
                  if(we_msk_r[0])
                     mem[addr_r[AW-1:2]][7:0] <= din[7:0];
               end else begin
                  dout <= dout_nxt; // Output
               end
            end
            endcase
         end
         assign valid = valid_r==delay_r;
         
         assign cmd_ready = valid_r==10'd0;
         
      end else if(DELAY>=3)  begin : delay_n
         wire push = (cmd_valid & cmd_ready);
         wire pop = (valid & ready);
         
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
         always @(posedge clk) begin
            valid_r <= valid_nxt;
            case (valid_nxt)
            10'd1: begin
               if (|cmd_we_msk) begin
                  din_r <= din; // Read din
               end
               addr_r <= cmd_addr; // Read address
               we_msk_r <= cmd_we_msk;
            end
            DELAY: begin
               if (|we_msk_r) begin
                  if(we_msk_r[3])
                     mem[addr_r[AW-1:2]][31:24] <= din[31:24];
                  if(we_msk_r[2])
                     mem[addr_r[AW-1:2]][23:16] <= din[23:16];
                  if(we_msk_r[1])
                     mem[addr_r[AW-1:2]][15:8] <= din[15:8];
                  if(we_msk_r[0])
                     mem[addr_r[AW-1:2]][7:0] <= din[7:0];
               end else begin
                  dout <= dout_nxt; // Output
               end
            end
            endcase
         end
         assign valid = valid_r==DELAY;
         
         assign cmd_ready = valid_r==10'd0;

      end else if (DELAY==2) begin : delay_2
         assign addr_w = cmd_addr;
         wire push = (cmd_valid & cmd_ready);
         wire pop = (valid & ready);
         wire valid_nxt = (push | ~pop);
         ncpu32k_cell_dff_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, valid);
                         
         assign cmd_ready = ~valid;
         always @(posedge clk) begin
            if(push & ~|cmd_we_msk) begin
               dout <= dout_nxt;
            end
         end
         always @(posedge clk) begin
            if(push) begin
               if(cmd_we_msk[3])
                  mem[cmd_addr[AW-1:2]][31:24] <= din[31:24];
               if(cmd_we_msk[2])
                  mem[cmd_addr[AW-1:2]][23:16] <= din[23:16];
               if(cmd_we_msk[1])
                  mem[cmd_addr[AW-1:2]][15:8] <= din[15:8];
               if(cmd_we_msk[0])
                  mem[cmd_addr[AW-1:2]][7:0] <= din[7:0];
            end
         end
      end else if(DELAY==1) begin : delay_1
         assign addr_w = cmd_addr;
         wire push = (cmd_valid & cmd_ready);
         wire pop = (valid & ready);
         wire valid_nxt = (push | ~pop);
         ncpu32k_cell_dff_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, valid);

         assign cmd_ready = ~valid | pop;
         always @(posedge clk) begin
            if(push & ~|cmd_we_msk) begin
               dout <= dout_nxt;
            end
         end
         always @(posedge clk) begin
            if(push) begin
               if(cmd_we_msk[3])
                  mem[cmd_addr[AW-1:2]][31:24] <= din[31:24];
               if(cmd_we_msk[2])
                  mem[cmd_addr[AW-1:2]][23:16] <= din[23:16];
               if(cmd_we_msk[1])
                  mem[cmd_addr[AW-1:2]][15:8] <= din[15:8];
               if(cmd_we_msk[0])
                  mem[cmd_addr[AW-1:2]][7:0] <= din[7:0];
            end
         end
      end
   endgenerate
   
endmodule
