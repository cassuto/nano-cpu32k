/**
 *@file Bypass Bus Arbiter
 */

/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
/*                                                                         */
/*  Copyright (C) 2021 cassuto <psc-system@outlook.com>, China.            */
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

module ncpu32k_byp_arbiter
#(
   parameter WAYS,
   parameter TAG_WIDTH,
   parameter ID_WIDTH
)
(
   input                      clk,
   input                      rst_n,
   input [WAYS-1:0]           fu_wb_BVALID,
   output [WAYS-1:0]          fu_wb_BREADY,
   input [WAYS*`NCPU_DW-1:0]  fu_wb_BDATA,
   input [WAYS*TAG_WIDTH-1:0] fu_wb_BTAG,
   input [WAYS*ID_WIDTH-1:0]  fu_wb_id,
   output                     rob_wb_BVALID,
   input                      rob_wb_BREADY,
   output reg [`NCPU_DW-1:0]  rob_wb_BDATA,
   output reg [TAG_WIDTH-1:0] rob_wb_BTAG,
   output reg [ID_WIDTH-1:0]  rob_wb_id
);

   wire [WAYS-1:0] grant;
   genvar i;
   integer x;
   
   ncpu32k_priority_onehot
      #(
         .DW            (WAYS),
         .POLARITY_DIN  (1),
         .POLARITY_DOUT (1)
      )
   P_ONEHOT_ARBITER
      (
         .DIN  (fu_wb_BVALID),
         .DOUT (grant)
      );
   
   generate
      wire [`NCPU_DW-1:0]  e_fu_wb_BDATA [WAYS:0];
      wire [TAG_WIDTH-1:0] e_fu_wb_BTAG  [WAYS:0];
      wire [ID_WIDTH-1:0]  e_fu_wb_id    [WAYS:0];
      
      for(i=0;i<WAYS;i=i+1)
         begin
            assign e_fu_wb_BDATA[i] = fu_wb_BDATA[(i+1)*`NCPU_DW-1: i*`NCPU_DW];
            assign e_fu_wb_BTAG[i] = fu_wb_BTAG[(i+1)*TAG_WIDTH-1: i*TAG_WIDTH];
            assign e_fu_wb_id[i] = fu_wb_id[(i+1)*ID_WIDTH-1: i*ID_WIDTH];
            assign fu_wb_BREADY[i] = grant[i] & rob_wb_BREADY;
         end

      always @(*)
         begin
            rob_wb_BDATA = {`NCPU_DW{1'b0}};
            rob_wb_BTAG = {TAG_WIDTH{1'b0}};
            rob_wb_id = {ID_WIDTH{1'b0}};
            
            for(x=0;x<WAYS;x=x+1)
               begin : gen_sel
                  rob_wb_BDATA = rob_wb_BDATA | (e_fu_wb_BDATA[x] & {`NCPU_DW{grant[x]}});
                  rob_wb_BTAG = rob_wb_BTAG | (e_fu_wb_BTAG[x] & {TAG_WIDTH{grant[x]}});
                  rob_wb_id = rob_wb_id | (e_fu_wb_id[x] & {ID_WIDTH{grant[x]}});
               end
         end
   endgenerate
   
   assign rob_wb_BVALID = |fu_wb_BVALID;

   
   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if (rob_wb_BVALID ^ |grant)
            $fatal("\n Check the bypass arbiter schema\n");
      end
`endif

`endif
   // synthesis translate_on
   
endmodule
