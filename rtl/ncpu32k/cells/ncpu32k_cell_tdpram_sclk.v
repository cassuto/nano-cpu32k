/**@file
 * Cell - True Double-port Sync RAM
 * Timing info:
 * 1. WRITE-FIRST strategy for each port.
 * 2. Bypass the input of port B to the output of port A, if A and B operate on the same address.
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
   parameter AW,
   parameter DW,
   parameter ENABLE_BYPASS_B2A
)
(
   input                         clk,
   input                         rst_n,
   // Port A
   input [AW-1:0]                addr_a,
   input                         we_a,
   input [DW-1:0]                din_a,
   output [DW-1:0]               dout_a,
   input                         en_a,
   // Port B
   input [AW-1:0]                addr_b,
   input                         we_b,
   input [DW-1:0]                din_b,
   output [DW-1:0]               dout_b,
   input                         en_b
);

   //
   // TDPRAM block
   //
   // @Type WRITE-FIRST
   // @Input sram_en_a  Read/Write Enable A
   // @Input we_a       Write A
   // @Input addr_a     Address A
   // @Input din_a      Data Input A
   // @Output dout_a_r  Data Output A
   // @Input en_b       Read/Write Enable B
   // @Input we_b       Write B
   // @Input addr_b     Address B
   // @Input din_b      Data Input B
   // @Output dout_b_r  Data Output B
   //
   wire sram_en_a;
   reg [DW-1:0] dout_a_r = 0;
   reg [DW-1:0] dout_b_r = 0;
   reg [DW-1:0] mem_vector[(1<<AW)-1:0];

   // Read & Write Port A
   always @(posedge clk) begin
      if (sram_en_a & we_a) begin
         mem_vector[addr_a] <= din_a;
         dout_a_r <= din_a;
      end else if (sram_en_a) begin
         dout_a_r <= mem_vector[addr_a];
      end
   end

   // Read & Write Port B
   always @(posedge clk) begin
      if (en_b & we_b) begin
         mem_vector[addr_b] <= din_b;
         dout_b_r <= din_b;
      end else if (en_b) begin
         dout_b_r <= mem_vector[addr_b];
      end
   end

   // synthesis translate_off
`ifndef SYNTHESIS
   initial begin : ini
      integer i;
      for(i=0; i < (1<<AW); i=i+1)
         mem_vector[i] = {DW{1'b0}};
   end
`endif
   // synthesis translate_on


   // Bypass the writing value from port B to A
generate
   if (ENABLE_BYPASS_B2A) begin : bypass_on
      wire bypass_r;
      wire [DW-1:0] din_b_r;
      wire conflict = (addr_a == addr_b & en_b&we_b & en_a);

      // Bypass FSM
      nDFF_lr #(1, 1'b0) dff_bypass_r
        (clk,rst_n, conflict|en_a, (conflict | ~en_a), bypass_r); // Keep bypass_r valid till the next Read
      // Latch din B
      nDFF_l #(DW) dff_din_b_r
        (clk, en_a, din_b[DW-1:0], din_b_r[DW-1:0]);

      assign sram_en_a = en_a & ~conflict;
      assign dout_a = bypass_r ? din_b_r : dout_a_r;

   end else begin : bypass_off
      assign sram_en_a = en_a;
      assign dout_a = dout_a_r;
   end
endgenerate

   assign dout_b = dout_b_r;

   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions 03060725
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if(en_a&we_a & en_b&we_b & addr_a==addr_b)
            $fatal ("\n DPRAM writing conflict.\n");
         if(en_a&we_a & en_b&~we_b & addr_a==addr_b)
            $fatal ("\n DPRAM reading conflict A->B.\n");
         if (!ENABLE_BYPASS_B2A)
            begin
               if(en_a&~we_a & en_b&we_b & addr_a==addr_b)
                  $fatal ("\n DPRAM reading conflict B->A.\n");
            end
      end
`endif

`endif
   // synthesis translate_on

endmodule
