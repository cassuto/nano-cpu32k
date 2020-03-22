/**@file
 * Cell - True Double-port Sync RAM
 * Timing info:
 * 1. WRITE first strategy (On the same port, dout is valid immediately when din is
 *       written and dout is enabled)
 *
 * 2. Anything about 're' (ReadEnable) signal:
 *    dout will go valid in the next clk when re == 1
 *    dout will keep its value in the next clk when re == 1 and we == 0
 *    dout will change to its new value in the next clk when re == 1 and we == 1
 */

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

module ncpu32k_cell_tdpram_sclk
#(
   parameter AW=-1,
   parameter DW=-1,
   parameter ENABLE_READ_ENABLE=-1,
   parameter CLEAR_ON_INIT = 1
)
(
   input                         clk,
   input                         rst_n,
   // Port A
   input [AW-1:0]                addr_a,
   input                         we_a,
   input [DW-1:0]                din_a,
   output [DW-1:0]               dout_a,
   input                         re_a,
   // Port B
   input [AW-1:0]                addr_b,
   input                         we_b,
   input [DW-1:0]                din_b,
   output [DW-1:0]               dout_b,
   input                         re_b
);
   reg [DW-1:0] mem_vector[(1<<AW)-1:0];
   
   // Initial block. For verification only.
   generate
      if(CLEAR_ON_INIT) begin :clear_on_init
         integer i;
         initial
            for(i=0; i < (1<<AW); i=i+1)
               mem_vector[i] = {DW{1'b0}};
      end
   endgenerate

   //
   // Read & Write Port A
   //
   reg [DW-1:0]     dout_a_r;

   always @(posedge clk) begin
      if (we_a) begin
         mem_vector[addr_a] <= din_a;
         dout_a_r <= din_a;
      end else begin
         dout_a_r <= mem_vector[addr_a];
      end
   end
   
   //
   // Read & Write Port B
   //
   reg [DW-1:0]     dout_b_r;

   always @(posedge clk) begin
      if (we_b) begin
         mem_vector[addr_b] <= din_b;
         dout_b_r <= din_b;
      end else begin
         dout_b_r <= mem_vector[addr_b];
      end
   end
   
   always @(posedge clk or negedge rst_n)
      if(~rst_n) begin
         dout_a_r <= {DW{1'b0}};
         dout_b_r <= {DW{1'b0}};
      end
   
generate
   if(ENABLE_READ_ENABLE) begin : enable_read_enable
      //
      // Read Enable Control
      //
      reg ram_vld_a_r;
      reg ram_vld_b_r;
      reg [DW-1:0] last_a_r;
      reg [DW-1:0] last_b_r;
      
      assign dout_a = ram_vld_a_r ? dout_a_r : last_a_r;
      assign dout_b = ram_vld_b_r ? dout_b_r : last_b_r;

      always @(posedge clk or negedge rst_n)
         if(~rst_n) begin
            last_a_r <= {DW{1'b0}};
            last_b_r <= {DW{1'b0}};
            ram_vld_a_r <= 1;
            ram_vld_b_r <= 1;
         end else begin
            if (ram_vld_a_r | we_a)
               last_a_r <= we_a ? din_a : dout_a_r; // Sync last_r with dout_r in writing
            if (ram_vld_b_r | we_b)
               last_b_r <= we_b ? din_b : dout_b_r; // Sync last_r with dout_r in writing
         end

      // Bypass FSM
      always @(posedge clk) begin
         ram_vld_a_r <= re_a;
         ram_vld_b_r <= re_b;
      end
   end else begin
      // No ReadEnable Control
      assign dout_a = dout_a_r;
      assign dout_b = dout_b_r;
   end
endgenerate

endmodule
