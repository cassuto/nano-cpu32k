// for testbench only

`include "ncpu32k_config.h"

module handshake_sram
#(
   parameter DW = 32, //`NCPU_DW,
   parameter AW = `NCPU_AW,
   parameter SIZE_BYTES = 32*1024,
   parameter MEMH_FILE = ""
)
(
   input                      clk,
   input                      rst_n,
   input [AW-1:0]             addr,
   input                      in_valid,
   output reg                 in_ready,
   input [DW-1:0]             din,
   output reg                 out_valid,
   input                      out_ready,
   output reg [DW-1:0]        dout,
   input [2:0]                size
);
   reg[7:0] mem[0:SIZE_BYTES-1];

   initial begin
      if(MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (MEMH_FILE, mem);
      end
      in_ready = 1'b0;
      out_valid = 1'b0;
      dout = {DW{1'b0}};
   end

   wire [DW-1:0] dout_nxt = (size==3'd3) 
                        ? {mem[addr+3][7:0],
                           mem[addr+2][7:0],
                           mem[addr+1][7:0],
                           mem[addr][7:0]}
                        : (size==3'd2)
                           ? {8'b0,
                              8'b0,
                              mem[addr+1][7:0],
                              mem[addr][7:0]}
                           : {8'b0,
                              8'b0,
                              8'b0,
                              mem[addr][7:0]};

   always @(posedge clk) begin
      if(out_ready) begin
         dout <= dout_nxt;
      end
      out_valid <= out_ready;
   end
   
   always @(posedge clk) begin
      if(in_valid) begin
         if(size==3'd3) begin
            mem[addr+3][7:0] <= din[31:24];
            mem[addr+2][7:0] <= din[23:16];
            mem[addr+1][7:0] <= din[15:8];
            mem[addr][7:0] <= din[7:0];
         end else if(size==3'd2) begin
            mem[addr+1][7:0] <= din[15:8];
            mem[addr][7:0] <= din[7:0];
         end else if(size==3'd1) begin
            mem[addr][7:0] <= din[7:0];
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
