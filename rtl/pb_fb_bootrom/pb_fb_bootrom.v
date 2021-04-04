
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
   parameter CONFIG_BOOTROM_SIZE_BYTES,
   parameter CONFIG_BOOTROM_MEMH_FILE,
   parameter CONFIG_PIPEBUF_BYPASS
)
(
   input                      clk,
   input                      rst_n,
   output                     AREADY, /* bootm is BREADY to accept cmd */
   input                      AVALID, /* cmd is presented at bootm'input */
   input [`NCPU_AW-1:0]       AADDR,
   input [`NCPU_DW/8-1:0]     AWMSK,
   input [`NCPU_DW-1:0]       ADATA,
   output                     BVALID,
   input                      BREADY,
   output [`NCPU_DW-1:0]      BDATA

);
   // important: for parameters only
function integer clogb2 (input integer bit_depth);
   begin
      for(clogb2=0; bit_depth>1; clogb2=clogb2+1)
         bit_depth = bit_depth>>1;
   end
endfunction
   localparam WORD_BYTES = `NCPU_DW/8;
   localparam SIZE_WORDS = CONFIG_BOOTROM_SIZE_BYTES/WORD_BYTES;
   localparam ADDR_BITS = 10;

   wire push = (AVALID & AREADY);
   wire pop = (BVALID & BREADY);
   wire valid_nxt = (push | ~pop);
   nDFF_lr #(1) dff_out_valid
                   (clk,rst_n, (push | pop), valid_nxt, BVALID);

generate
   if (CONFIG_PIPEBUF_BYPASS) begin : enable_bypass
      assign AREADY = ~BVALID | pop;
   end else
      assign AREADY = ~BVALID;
endgenerate

   localparam N_BW = clogb2(WORD_BYTES);

   wire [ADDR_BITS-1:0] mem_addr = AADDR[ADDR_BITS+N_BW-1:N_BW];

`ifdef PLATFORM_XILINX_XC6
   ramblk_bootrom mem
   (
      .clka(clk),
      .addra(mem_addr[ADDR_BITS-1:0]),
      .dina(ADATA[`NCPU_DW-1:0]),
      .ena(push),
      .wea(AWMSK[`NCPU_DW/8-1:0]),
      .douta(BDATA[`NCPU_DW-1:0])
   );
`else
   reg[`NCPU_DW-1:0] mem[0:SIZE_WORDS-1];

   initial begin : initial_blk
      integer i;
      for(i=0;i<SIZE_WORDS;i=i+1) begin : for_size_bytes
         mem[i] = {`NCPU_DW{1'b0}};
      end
      if(CONFIG_BOOTROM_MEMH_FILE !== "") begin :memh_file_not_emp
         $readmemh (CONFIG_BOOTROM_MEMH_FILE, mem);
      end
   end

   reg [`NCPU_AW-1:0] dout_r;
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n)
         dout_r <= {`NCPU_DW{1'b0}};
      else if(push & ~|AWMSK)
         dout_r <= mem[mem_addr];
   end
   assign BDATA = dout_r;
   always @(posedge clk) begin
      if(push) begin
         if(AWMSK[3])
            mem[mem_addr][31:24] <= ADATA[31:24];
         if(AWMSK[2])
            mem[mem_addr][23:16] <= ADATA[23:16];
         if(AWMSK[1])
            mem[mem_addr][15:8] <= ADATA[15:8];
         if(AWMSK[0])
            mem[mem_addr][7:0] <= ADATA[7:0];
      end
   end
`endif

endmodule
