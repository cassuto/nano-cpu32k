// for testbench only

`include "ncpu32k_config.h"

module handshake_cmd_sram
#(
   parameter DW = 32, //`NCPU_DW,
   parameter AW = `NCPU_AW,
   parameter SIZE_BYTES = 32*1024,
   parameter MEMH_FILE = "",
   parameter DELAY=3
)
(
   input                      clk,
   input                      rst_n,
   input                      in_valid,
   output reg                 in_ready,
   input [DW-1:0]             din,
   output                     out_valid,
   input                      out_ready,
   output reg [DW-1:0]        dout,
   input [2:0]                size,
   output                     cmd_ready, /* sram is ready to accept cmd */
   input                      cmd_valid, /* cmd is presented at sram'input */
   input [`NCPU_AW-1:0]       cmd_addr
);
   reg[7:0] mem[0:SIZE_BYTES-1];

   initial begin
      integer i;
      for(i=0;i<SIZE_BYTES;i=i+1) begin : for_size_bytes
         mem[i] = 8'b0;
      end
      if(MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (MEMH_FILE, mem);
      end
      in_ready = 1'b0;
      dout = {DW{1'b0}};
   end

   wire [AW-1:0] addr_w;
   wire [DW-1:0] dout_nxt = (size==3'd3) 
                        ? {mem[addr_w+3][7:0],
                           mem[addr_w+2][7:0],
                           mem[addr_w+1][7:0],
                           mem[addr_w][7:0]}
                        : (size==3'd2)
                           ? {8'b0,
                              8'b0,
                              mem[addr_w+1][7:0],
                              mem[addr_w][7:0]}
                           : {8'b0,
                              8'b0,
                              8'b0,
                              mem[addr_w][7:0]};

   reg [AW-1:0] addr_r;
   generate
      if(DELAY>=3)  begin : delay_n
         wire push = (cmd_valid & cmd_ready);
         wire pop = (out_valid & out_ready);
         
         reg [3:0] valid_nxt;
         reg [3:0] valid_r = 4'd0;
         
         assign addr_w = addr_r;
         
         always @* begin
            if(valid_r==4'd0) begin
               valid_nxt = push ? 4'd1 : 4'd0;
            end else if(valid_r >= 4'd1 && valid_r < DELAY) begin
               valid_nxt = valid_r + 4'd1;
            end else if(valid_r == DELAY) begin
               valid_nxt = pop & push ? 4'd1 : pop ? 4'd0 : DELAY;
            end
         end
         always @(posedge clk) begin
            valid_r <= valid_nxt;
            case (valid_nxt)
            4'd1: begin
               addr_r <= cmd_addr; // Read address
            end
            DELAY: begin
               dout <= dout_nxt; // Output
            end
            endcase
         end
         assign out_valid = valid_r==DELAY;
         
         assign cmd_ready = valid_r==4'd0;

      end else if (DELAY==2) begin : delay_2
         assign addr_w = cmd_addr;
         wire push = (cmd_valid & cmd_ready);
         wire pop = (out_valid & out_ready);
         wire valid_nxt = (push | ~pop);
         ncpu32k_cell_dff_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, out_valid);
                         
         assign cmd_ready = ~out_valid;
         always @(posedge clk) begin
            if(push) begin
               dout <= dout_nxt;
            end
         end
      end else if(DELAY==1) begin : delay_1
         assign addr_w = cmd_addr;
         wire push = (cmd_valid & cmd_ready);
         wire pop = (out_valid & out_ready);
         wire valid_nxt = (push | ~pop);
         ncpu32k_cell_dff_lr #(1) dff_out_valid
                         (clk,rst_n, (push | pop), valid_nxt, out_valid);

         assign cmd_ready = ~out_valid | pop;
         always @(posedge clk) begin
            if(push) begin
               dout <= dout_nxt;
            end
         end
      end
   endgenerate
   
   always @(posedge clk) begin
      if(in_valid) begin
         if(size==3'd3) begin
            mem[cmd_addr+3][7:0] <= din[31:24];
            mem[cmd_addr+2][7:0] <= din[23:16];
            mem[cmd_addr+1][7:0] <= din[15:8];
            mem[cmd_addr][7:0] <= din[7:0];
         end else if(size==3'd2) begin
            mem[cmd_addr+1][7:0] <= din[15:8];
            mem[cmd_addr][7:0] <= din[7:0];
         end else if(size==3'd1) begin
            mem[cmd_addr][7:0] <= din[7:0];
         end
      end
      in_ready <= in_valid;
   end
   
CHECK_SIZE:
   assert property (@(posedge clk) 
                     ( ~(in_valid|out_ready) | (size !== 3'd0) )
                  )
   else $fatal ("\n error: size==0\n");

endmodule
