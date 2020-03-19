
/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module pb_fb_bootrom
#(
   parameter SIZE_BYTES = 512,
   parameter MEMH_FILE = "",
   parameter ENABLE_BYPASS
)
(
   input                      clk,
   input                      rst_n,
   output                     cmd_ready, /* bootm is ready to accept cmd */
   input                      cmd_valid, /* cmd is presented at bootm'input */
   input [`NCPU_AW-1:0]       cmd_addr,
   input [`NCPU_DW/8-1:0]     cmd_we_msk,
   output                     valid,
   input                      ready,
   output reg [`NCPU_DW-1:0]  dout,
   input [`NCPU_DW-1:0]       din
);
   reg[`NCPU_DW-1:0] mem[0:SIZE_BYTES-1];

   initial begin : initial_blk
      integer i;
      for(i=0;i<SIZE_BYTES;i=i+1) begin : for_size_bytes
         mem[i] = 8'b0;
      end
      if(MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (MEMH_FILE, mem);
      end
   end

   wire push = (cmd_valid & cmd_ready);
   wire pop = (valid & ready);
   wire valid_nxt = (push | ~pop);
   ncpu32k_cell_dff_lr #(1) dff_out_valid
                   (clk,rst_n, (push | pop), valid_nxt, valid);

generate
   if (ENABLE_BYPASS) begin : enable_bypass
      assign cmd_ready = ~valid | pop;
   end else
      assign cmd_ready = ~valid;
endgenerate

   wire [$clog2(SIZE_BYTES)-1:0] mem_addr = cmd_addr[$clog2(SIZE_BYTES)-1:0];

   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         dout <= {`NCPU_DW{1'b0}};
      else if(push & ~|cmd_we_msk)
         dout <= mem[mem_addr];
   end
   always @(posedge clk) begin
      if(push) begin
         if(cmd_we_msk[3])
            mem[mem_addr][31:24] <= din[31:24];
         if(cmd_we_msk[2])
            mem[mem_addr][23:16] <= din[23:16];
         if(cmd_we_msk[1])
            mem[mem_addr][15:8] <= din[15:8];
         if(cmd_we_msk[0])
            mem[mem_addr][7:0] <= din[7:0];
      end
   end
   
endmodule
