/**@file
 * Cell - Double-port Sync RAM
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

module ncpu32k_cell_dpram_sclk
#(
   parameter ADDR_WIDTH = 32,
   parameter DATA_WIDTH = 32,
   parameter CLEAR_ON_INIT = 1,
   parameter ENABLE_BYPASS = 1
)
(
   input                           clk_i,
   input                           rst_n_i,
   input [ADDR_WIDTH-1:0]          raddr,
   input                           re,
   input [ADDR_WIDTH-1:0]          waddr,
   input                           we,
   input [DATA_WIDTH-1:0]          din,
   output [DATA_WIDTH-1:0]         dout,
   output                          dout_valid
);

   reg [DATA_WIDTH-1:0]            mem_vector[(1<<ADDR_WIDTH)-1:0];
   reg [DATA_WIDTH-1:0]            dout_r;
   reg                             re_r;
   wire [DATA_WIDTH-1:0]           dout_w;

   // Initial block. For verification only.
   generate
      if(CLEAR_ON_INIT) begin :clear_on_init
         integer i;
         initial
            for(i=0; i < (1<<ADDR_WIDTH); i=i+1)
               mem_vector[i] = {DATA_WIDTH{1'b0}};
      end
   endgenerate

   // Bypass
   reg bypass;
   generate
      if (ENABLE_BYPASS) begin : bypass_gen
         reg [DATA_WIDTH-1:0]  din_r;
         assign dout_w = bypass ? din_r : dout_r;

         always @(posedge clk_i)
            if (re)
               din_r <= din;

         always @(posedge clk_i)
            if (|raddr & waddr == raddr && we && re)
               bypass <= 1;
            else
               bypass <= 0;
      end else begin
         assign dout_w = dout_r;
      end
   endgenerate
   
   // Read output
   assign dout = dout_w;
   assign dout_valid = re_r;
   
   // Sync Read
   always @(posedge clk_i or negedge rst_n_i)
      if (!rst_n_i) begin
         re_r <= 1'b0;
         dout_r <= {DATA_WIDTH{1'b0}};
      end else
         re_r <= re;

   // Write & Read
   always @(posedge clk_i) begin
      if (we)
         mem_vector[waddr] <= din;
      if (re | bypass)
         dout_r <= mem_vector[raddr];
   end

endmodule
