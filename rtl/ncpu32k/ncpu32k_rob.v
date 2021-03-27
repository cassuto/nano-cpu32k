/**
 *@file ROB - ReOrder Buffer
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

module ncpu32k_rob
#(
   parameter DEPTH_WIDTH,
   parameter TAG_WIDTH
)
(
   input                            clk,
   input                            rst_n,
   input                            i_flush_req,
   input                            i_issue_AVALID,
   output                           o_issue_AREADY,
   input                            i_issue_rd_we,
   input [`NCPU_REG_AW-1:0]         i_issue_rd_addr,
   input [`NCPU_REG_AW-1:0]         i_issue_rs1_addr,
   input [`NCPU_REG_AW-1:0]         i_issue_rs2_addr,
   output                           o_issue_rs1_from_ROB,
   output                           o_issue_rs1_in_ARF,
   output [`NCPU_DW-1:0]            o_issue_rs1_dat,
   output                           o_issue_rs2_from_ROB,
   output                           o_issue_rs2_in_ARF,
   output [`NCPU_DW-1:0]            o_issue_rs2_dat,
   output [DEPTH_WIDTH-1:0]         o_issue_id,
   output                           o_commit_BREADY,
   input                            i_commit_BVALID,
   input [`NCPU_DW-1:0]             i_commit_BDATA,
   input [TAG_WIDTH-1:0]            i_commit_BTAG,
   input [DEPTH_WIDTH-1:0]          i_commit_id,
   output                           o_retire_BVALID,
   input                            i_retire_BREADY,
   output                           o_retire_rd_we,
   output [`NCPU_REG_AW-1:0]        o_retire_rd_addr,
   output [`NCPU_DW-1:0]            o_retire_BDATA,
   output [TAG_WIDTH-1:0]           o_retire_BTAG
);

   localparam DEPTH = (1<<DEPTH_WIDTH);

   wire                             rob_push;
   wire                             rob_pop;
   wire                             rob_empty;
   wire                             rob_full;
   wire [DEPTH_WIDTH:0]             w_ptr_r;
   wire [DEPTH_WIDTH:0]             w_ptr_nxt;
   wire [DEPTH_WIDTH:0]             r_ptr_r;
   wire [DEPTH_WIDTH:0]             r_ptr_nxt;
   wire                             que_valid_r [DEPTH-1:0];
   wire                             que_rd_ready_r [DEPTH-1:0];
   wire                             que_rd_we_r [DEPTH-1:0];
   wire [`NCPU_REG_AW-1:0]          que_rd_addr_r [DEPTH-1:0];
   wire [`NCPU_DW-1:0]              que_dat_r [DEPTH-1:0];
   wire [TAG_WIDTH-1:0]             que_tag_r [DEPTH-1:0];
   wire [DEPTH-1:0]                 rs1_ROB_match, rs2_ROB_match;
   wire [DEPTH-1:0]                 rs1_ROB_match_bypass, rs2_ROB_match_bypass;
   wire [DEPTH-1:0]                 rs1_ROB_match_ready, rs2_ROB_match_ready;
   wire [DEPTH-2:0]                 rs1_prec_match, rs2_prec_match;
   wire [DEPTH-2:0]                 rs1_prec_bypass, rs2_prec_bypass;
   wire [DEPTH-2:0]                 rs1_prec_ready, rs2_prec_ready;
   wire [`NCPU_DW-1:0]              prec_dat [DEPTH-2:0];
   wire [DEPTH-2:0]                 rs1_prec_in_ARF, rs2_prec_in_ARF;
   wire [DEPTH-2:0]                 rs1_prec_from_ROB, rs2_prec_from_ROB;
   wire [DEPTH-2:0]                 rs1_first_match, rs2_first_match;

   genvar i;

   assign rob_push = (i_issue_AVALID & o_issue_AREADY);
   assign rob_pop = (i_retire_BREADY & o_retire_BVALID);
   
   assign w_ptr_nxt = w_ptr_r + 1'd1;
   assign r_ptr_nxt = r_ptr_r + 1'd1;

   nDFF_lr #(DEPTH_WIDTH + 1) dff_w_ptr_r
     (clk,rst_n, (rob_push|i_flush_req), (w_ptr_nxt & {DEPTH_WIDTH+1{~i_flush_req}}), w_ptr_r);
   nDFF_lr #(DEPTH_WIDTH + 1) dff_r_ptr_r
     (clk,rst_n, (rob_pop|i_flush_req), (r_ptr_nxt & {DEPTH_WIDTH+1{~i_flush_req}}), r_ptr_r);

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_DFFs
            wire this_issue, this_retire;

            assign this_issue = (i[DEPTH_WIDTH-1:0]==o_issue_id) & rob_push;
            assign this_commit = (i[DEPTH_WIDTH-1:0]==i_commit_id) & i_commit_BVALID & o_commit_BREADY;
            assign this_retire = (i[DEPTH_WIDTH-1:0]==r_ptr_r[DEPTH_WIDTH-1:0]) & rob_pop;

            nDFF_lr #(1) dff_que_valid_r
              (clk,rst_n, (this_issue|this_retire|i_flush_req), (this_issue|~this_retire)&~i_flush_req, que_valid_r[i]);
            nDFF_lr #(1) dff_que_rd_ready_r
              (clk,rst_n, (this_issue|this_commit), (~this_issue|this_commit), que_rd_ready_r[i]);
            nDFF_lr #(1) dff_que_rd_we_r
              (clk,rst_n, this_issue, i_issue_rd_we, que_rd_we_r[i]);
            nDFF_lr #(`NCPU_REG_AW) dff_que_rd_addr_r
              (clk,rst_n, this_issue, i_issue_rd_addr, que_rd_addr_r[i]);
            nDFF_lr #(`NCPU_DW) dff_que_dat_r
              (clk,rst_n, this_commit, i_commit_BDATA, que_dat_r[i]);
            nDFF_lr #(TAG_WIDTH) dff_que_tag_r
              (clk,rst_n, this_commit, i_commit_BTAG, que_tag_r[i]);
         end
   endgenerate

   assign rob_full = (w_ptr_r[DEPTH_WIDTH] != r_ptr_r[DEPTH_WIDTH]) &
                     (w_ptr_r[DEPTH_WIDTH-1:0] == r_ptr_r[DEPTH_WIDTH-1:0]);
   assign rob_empty = (w_ptr_r == r_ptr_r);

   assign o_issue_id = w_ptr_r[DEPTH_WIDTH-1:0];

   assign o_commit_BREADY = 1'b1;
   
   assign o_issue_AREADY = ~rob_full;
   assign o_retire_BVALID = ~rob_empty & que_rd_ready_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   
   // Output MUX for retire channel
   assign o_retire_rd_we = que_rd_we_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign o_retire_rd_addr = que_rd_addr_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign o_retire_BDATA = que_dat_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign o_retire_BTAG = que_tag_r[r_ptr_r[DEPTH_WIDTH-1:0]];

   // Read operands from ROB.
   // Note that ROB can be regarded as an extension of ARF.
   generate
      for(i=0;i<DEPTH;i=i+1)
         begin : gen_matches
            // If an entry matches the address of operand.
            assign rs1_ROB_match[i] = (que_valid_r[i] & que_rd_we_r[i] & (i_issue_rs1_addr==que_rd_addr_r[i]));
            assign rs2_ROB_match[i] = (que_valid_r[i] & que_rd_we_r[i] & (i_issue_rs2_addr==que_rd_addr_r[i]));

            // If the matched entry is ready
            assign rs1_ROB_match_ready[i] = (rs1_ROB_match[i] & que_rd_ready_r[i]);
            assign rs2_ROB_match_ready[i] = (rs2_ROB_match[i] & que_rd_ready_r[i]);

            // If the operand is being committed to the matched entry. (bypass)
            assign rs1_ROB_match_bypass[i] = (rs1_ROB_match[i] & o_commit_BREADY & i_commit_BVALID & (i_commit_id==i[DEPTH_WIDTH-1:0]));
            assign rs2_ROB_match_bypass[i] = (rs2_ROB_match[i] & o_commit_BREADY & i_commit_BVALID & (i_commit_id==i[DEPTH_WIDTH-1:0]));
            
            // synthesis translate_off
`ifndef SYNTHESIS

            // Assertions
`ifdef NCPU_ENABLE_ASSERT
            always @(posedge clk)
               begin
                  if (o_commit_BREADY & i_commit_BVALID & (i_commit_id==i[DEPTH_WIDTH-1:0]) & ~que_valid_r[i])
                     $fatal("\n Commit to a invalid entry of ROB. Please check ISSUE unit, DISPATCH unit or FU.\n");
                  if (o_commit_BREADY & i_commit_BVALID & (i_commit_id==i[DEPTH_WIDTH-1:0]) & que_rd_ready_r[i])
                     $fatal("\n Do not commit to the same entry once again. Please check ISSUE unit, DISPATCH unit or FU.\n");
               end
`endif

`endif
            // synthesis translate_on
         end
   endgenerate

   generate
      for(i=1;i<DEPTH;i=i+1)
         begin : gen_reads
            wire [DEPTH_WIDTH-1:0] id;

            // Look ahead N-1 insns.
            assign id = (o_issue_id - i[DEPTH_WIDTH-1:0]);

            assign rs1_prec_match[i-1] = rs1_ROB_match[id];
            assign rs2_prec_match[i-1] = rs2_ROB_match[id];
            assign rs1_prec_bypass[i-1] = rs1_ROB_match_bypass[id];
            assign rs2_prec_bypass[i-1] = rs2_ROB_match_bypass[id];
            assign rs1_prec_ready[i-1] = rs1_ROB_match_ready[id];
            assign rs2_prec_ready[i-1] = rs2_ROB_match_ready[id];
            
            assign prec_dat[i-1] = que_dat_r[id];

            assign rs1_prec_from_ROB[i-1] = rs1_prec_bypass[i-1] | rs1_prec_ready[i-1];
            assign rs2_prec_from_ROB[i-1] = rs2_prec_bypass[i-1] | rs2_prec_ready[i-1];

            // The address of operand is not presented in ROB, so the operand is in ARF.
            assign rs1_prec_in_ARF[i-1] = ~rs1_ROB_match[id];
            assign rs2_prec_in_ARF[i-1] = ~rs2_ROB_match[id];

            // synthesis translate_off
`ifndef SYNTHESIS

            // Assertions
`ifdef NCPU_ENABLE_ASSERT
            always @(posedge clk)
               begin
                  if (rs1_prec_ready[i-1] & rs1_prec_bypass[i-1])
                     $fatal("\n The operand should not be committed once more\n");
                  if (rs2_prec_ready[i-1] & rs2_prec_bypass[i-1])
                     $fatal("\n The operand should not be committed once more\n");
                  if (rs1_prec_from_ROB[i-1] & rs1_prec_in_ARF[i-1])
                     $fatal("\n Operands cannot be both in ARF and ROB.\n");
                  if (rs2_prec_from_ROB[i-1] & rs2_prec_in_ARF[i-1])
                     $fatal("\n Operands cannot be both in ARF and ROB.\n");
               end
`endif

`endif
            // synthesis translate_on

         end
   endgenerate
   
   // Priority MUX
   // Get the latest value of the operand,
   // which is corresponding to the oldest insn.
   ncpu32k_priority_onehot
      #(
         .DW (DEPTH - 1),
         .POLARITY_DIN (1),
         .POLARITY_DOUT (1)
      )
   P_ONEHOT_RS1_READY
      (
         .DIN  (rs1_prec_match),
         .DOUT (rs1_first_match)
      );
   ncpu32k_priority_onehot
      #(
         .DW (DEPTH - 1),
         .POLARITY_DIN (1),
         .POLARITY_DOUT (1)
      )
   P_ONEHOT_RS2_READY
      (
         .DIN  (rs2_prec_match),
         .DOUT (rs2_first_match)
      );

   // Output MUX for issue channel
   generate
      wire [`NCPU_DW-1:0] t_rs1_dat [DEPTH-1:0];
      wire [`NCPU_DW-1:0] t_rs2_dat [DEPTH-1:0];

      // Bypass from commit channel.
      assign t_rs1_dat[0] = ({`NCPU_DW{|(rs1_first_match & rs1_prec_bypass)}} & i_commit_BDATA);
      assign t_rs2_dat[0] = ({`NCPU_DW{|(rs2_first_match & rs2_prec_bypass)}} & i_commit_BDATA);
      
      // Get from ROB
      for(i=1;i<DEPTH;i=i+1)
         begin : gen_issue_output
            assign t_rs1_dat[i] = t_rs1_dat[i-1] | ({`NCPU_DW{rs1_first_match[i-1] & rs1_prec_ready[i-1]}} & prec_dat[i-1]);
            assign t_rs2_dat[i] = t_rs2_dat[i-1] | ({`NCPU_DW{rs2_first_match[i-1] & rs2_prec_ready[i-1]}} & prec_dat[i-1]);
         end

      assign o_issue_rs1_dat = t_rs1_dat[DEPTH-1];
      assign o_issue_rs2_dat = t_rs2_dat[DEPTH-1];
   endgenerate

   assign o_issue_rs1_from_ROB = |(rs1_first_match & rs1_prec_from_ROB);
   assign o_issue_rs2_from_ROB = |(rs2_first_match & rs2_prec_from_ROB);
   assign o_issue_rs1_in_ARF = &rs1_prec_in_ARF;
   assign o_issue_rs2_in_ARF = &rs2_prec_in_ARF;


   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if(count_1({rs1_first_match})>1)
            $fatal("\n `rs1_first_match` should be mutex\n");
         if(count_1({rs2_first_match})>1)
            $fatal("\n `rs2_first_match` should be mutex\n");
         // The following 4 assertions hold if there is only one commit channel.
         if(count_1({rs1_ROB_match_bypass})>1)
            $fatal("\n `rs1_ROB_match_bypass` should be mutex\n");
         if(count_1({rs2_ROB_match_bypass})>1)
            $fatal("\n `rs2_ROB_match_bypass` should be mutex\n");
         if(count_1({rs1_prec_bypass})>1)
            $fatal("\n `rs1_prec_bypass` should be mutex\n");
         if(count_1({rs2_prec_bypass})>1)
            $fatal("\n `rs2_prec_bypass` should be mutex\n");
            
         if( |(rs1_first_match & rs1_prec_bypass) & |(rs1_first_match & rs1_prec_ready) )
            $fatal("\n Commit to the matched entry once more\n");
         if( |(rs2_first_match & rs2_prec_bypass) & |(rs2_first_match & rs2_prec_ready) )
            $fatal("\n Commit to the matched entry once more\n");
      end
      
   reg assert_flush_req = 1'b0;
   always @(posedge clk)
      begin
         assert_flush_req <= i_flush_req;
         if (assert_flush_req & i_flush_req) $fatal("\n It's likely a bug?? 'i_flush_req' was not a 1-clk pulse\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
