// for testbench only

`include "ncpu32k_config.h"

module handshake_cmd_sram
#(
   parameter DW = 32, //`NCPU_DW,
   parameter AW = `NCPU_AW,
   parameter SIZE_BYTES = 32*1024,
   parameter MEMH_FILE = "",
   parameter DELAY=1
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

   wire [DW-1:0] dout_nxt = (size==3'd3) 
                        ? {mem[cmd_addr+3][7:0],
                           mem[cmd_addr+2][7:0],
                           mem[cmd_addr+1][7:0],
                           mem[cmd_addr][7:0]}
                        : (size==3'd2)
                           ? {8'b0,
                              8'b0,
                              mem[cmd_addr+1][7:0],
                              mem[cmd_addr][7:0]}
                           : {8'b0,
                              8'b0,
                              8'b0,
                              mem[cmd_addr][7:0]};
                        
   reg [1:0] status_r=2'b0;
   reg [1:0] status_nxt=2'b0;
         
   generate
      if(DELAY==3)  begin : delay_3
         reg [DW-1:0] dout_r;
         reg out_valid_r;
         assign out_valid = out_valid_r;
         
         always @(posedge clk) begin
            status_r <= status_nxt;
            
            case(status_nxt)
            2'd0: begin
               out_valid_r <= 1'b0;
            end
            2'd1: begin
               dout_r <= dout_nxt;
            end
            2'd2: begin
               out_valid_r <= 1'b1;
               dout <= dout_r;
            end
            endcase
         end
         always @(*) begin
            case(status_r)
            2'd0:
               status_nxt = out_ready ? 2'd1 : 2'd0;
            2'd1:
               status_nxt = 2'd2;
            2'd2:
               status_nxt = out_ready ? 2'd0 : 2'd2; // handshake with downstream
            endcase
         end
      end else if (DELAY==2) begin : delay_2
         reg out_valid_r;
         assign out_valid = out_valid_r;
         
         always @(posedge clk) begin
            status_r <= status_nxt;
            
            case(status_nxt)
            2'd0: begin
               out_valid_r <= 1'b0;
            end
            2'd1: begin
               dout <= dout_nxt;
               out_valid_r <= 1'b1;
            end
            endcase
         end
         always @(*) begin
            case(status_r)
            2'd0:
               status_nxt = out_ready ? 2'd1 : 2'd0;
            2'd1:
               status_nxt = out_ready ? 2'd0 : 2'd1; // handshake with downstream
            endcase
         end
      end else if(DELAY==1) begin : delay_1
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
