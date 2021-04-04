/**@file
 * ROB - ReOrder Buffer
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
   input                            flush,
   input                            rob_disp_AVALID,
   output                           rob_disp_AREADY,
   input [`NCPU_AW-3:0]             rob_disp_pc,
   input [`NCPU_AW-3:0]             rob_disp_pred_tgt,
   input                            rob_disp_rd_we,
   input [`NCPU_REG_AW-1:0]         rob_disp_rd_addr,
   input [`NCPU_REG_AW-1:0]         rob_disp_rs1_addr,
   input [`NCPU_REG_AW-1:0]         rob_disp_rs2_addr,
   output                           rob_disp_rs1_in_ROB,
   output                           rob_disp_rs1_in_ARF,
   output [`NCPU_DW-1:0]            rob_disp_rs1_dat,
   output                           rob_disp_rs2_in_ROB,
   output                           rob_disp_rs2_in_ARF,
   output [`NCPU_DW-1:0]            rob_disp_rs2_dat,
   output [DEPTH_WIDTH-1:0]         rob_disp_id,
   output                           rob_wb_BREADY,
   input                            rob_wb_BVALID,
   input [`NCPU_DW-1:0]             rob_wb_BDATA,
   input [TAG_WIDTH-1:0]            rob_wb_BTAG,
   input [DEPTH_WIDTH-1:0]          rob_wb_id,
   output                           byp_rd_we,
   output [`NCPU_REG_AW-1:0]        byp_rd_addr,
   output                           rob_commit_BVALID,
   input                            rob_commit_BREADY,
   output [`NCPU_AW-3:0]            rob_commit_pc,
   output [`NCPU_AW-3:0]            rob_commit_pred_tgt,
   output                           rob_commit_rd_we,
   output [`NCPU_REG_AW-1:0]        rob_commit_rd_addr,
   output [`NCPU_DW-1:0]            rob_commit_BDATA,
   output [TAG_WIDTH-1:0]           rob_commit_BTAG,
   output [DEPTH_WIDTH-1:0]         rob_commit_ptr
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
   wire [`NCPU_AW-3:0]              que_pc_r [DEPTH-1:0];
   wire [`NCPU_AW-3:0]              que_pred_tgt_r [DEPTH-1:0];
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
   wire [DEPTH-2:0]                 rs1_prec_in_ROB, rs2_prec_in_ROB;
   wire [DEPTH-2:0]                 rs1_first_match, rs2_first_match;

   genvar i;

   assign rob_push = (rob_disp_AVALID & rob_disp_AREADY);
   assign rob_pop = (rob_commit_BREADY & rob_commit_BVALID);
   
   assign w_ptr_nxt = w_ptr_r + 1'd1;
   assign r_ptr_nxt = r_ptr_r + 1'd1;

   nDFF_lr #(DEPTH_WIDTH + 1) dff_w_ptr_r
     (clk,rst_n, (rob_push|flush), (w_ptr_nxt & {DEPTH_WIDTH+1{~flush}}), w_ptr_r);
   nDFF_lr #(DEPTH_WIDTH + 1) dff_r_ptr_r
     (clk,rst_n, (rob_pop|flush), (r_ptr_nxt & {DEPTH_WIDTH+1{~flush}}), r_ptr_r);

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_DFFs
            wire this_disp, this_commit;

            assign this_disp = (i[DEPTH_WIDTH-1:0]==rob_disp_id) & rob_push;
            assign this_wb = (i[DEPTH_WIDTH-1:0]==rob_wb_id) & rob_wb_BVALID & rob_wb_BREADY;
            assign this_commit = (i[DEPTH_WIDTH-1:0]==r_ptr_r[DEPTH_WIDTH-1:0]) & rob_pop;

            nDFF_lr #(1) dff_que_valid_r
              (clk,rst_n, (this_disp|this_commit|flush), (this_disp|~this_commit)&~flush, que_valid_r[i]);
            nDFF_lr #(1) dff_que_rd_ready_r
              (clk,rst_n, (this_disp|this_wb), (~this_disp|this_wb), que_rd_ready_r[i]);
            nDFF_l #(`NCPU_AW-2) dff_que_pc_r
              (clk, this_disp, rob_disp_pc, que_pc_r[i]);
            nDFF_l #(`NCPU_AW-2) dff_que_pred_tgt_r
              (clk, this_disp, rob_disp_pred_tgt, que_pred_tgt_r[i]);
            nDFF_l #(1) dff_que_rd_we_r
              (clk, this_disp, rob_disp_rd_we, que_rd_we_r[i]);
            nDFF_lr #(`NCPU_REG_AW) dff_que_rd_addr_r
              (clk,rst_n, this_disp, rob_disp_rd_addr, que_rd_addr_r[i]);
            nDFF_l #(`NCPU_DW) dff_que_dat_r
              (clk, this_wb, rob_wb_BDATA, que_dat_r[i]);
            nDFF_l #(TAG_WIDTH) dff_que_tag_r
              (clk, this_wb, rob_wb_BTAG, que_tag_r[i]);
         end
   endgenerate

   assign rob_full = (w_ptr_r[DEPTH_WIDTH] != r_ptr_r[DEPTH_WIDTH]) &
                     (w_ptr_r[DEPTH_WIDTH-1:0] == r_ptr_r[DEPTH_WIDTH-1:0]);
   assign rob_empty = (w_ptr_r == r_ptr_r);

   assign rob_disp_id = w_ptr_r[DEPTH_WIDTH-1:0];

   assign rob_wb_BREADY = 1'b1;
   
   assign rob_disp_AREADY = ~rob_full;
   assign rob_commit_BVALID = ~rob_empty & que_rd_ready_r[r_ptr_r[DEPTH_WIDTH-1:0]];

   assign byp_rd_we = que_rd_we_r[rob_wb_id];
   assign byp_rd_addr = que_rd_addr_r[rob_wb_id];
   
   // Output MUX for commit channel
   assign rob_commit_pc = que_pc_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_pred_tgt = que_pred_tgt_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_rd_we = que_rd_we_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_rd_addr = que_rd_addr_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_BDATA = que_dat_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_BTAG = que_tag_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_ptr = r_ptr_r[DEPTH_WIDTH-1:0];

   // Read operands from ROB.
   // Note that ROB can be regarded as an extension of ARF.
   generate
      for(i=0;i<DEPTH;i=i+1)
         begin : gen_matches
            // If an entry matches the address of operand.
            assign rs1_ROB_match[i] = (que_valid_r[i] & que_rd_we_r[i] & (rob_disp_rs1_addr==que_rd_addr_r[i]));
            assign rs2_ROB_match[i] = (que_valid_r[i] & que_rd_we_r[i] & (rob_disp_rs2_addr==que_rd_addr_r[i]));

            // If the matched entry is ready
            assign rs1_ROB_match_ready[i] = (rs1_ROB_match[i] & que_rd_ready_r[i]);
            assign rs2_ROB_match_ready[i] = (rs2_ROB_match[i] & que_rd_ready_r[i]);

            // If the operand is being wbted to the matched entry. (bypass)
            assign rs1_ROB_match_bypass[i] = (rs1_ROB_match[i] & rob_wb_BREADY & rob_wb_BVALID & (rob_wb_id==i[DEPTH_WIDTH-1:0]));
            assign rs2_ROB_match_bypass[i] = (rs2_ROB_match[i] & rob_wb_BREADY & rob_wb_BVALID & (rob_wb_id==i[DEPTH_WIDTH-1:0]));
            
            // synthesis translate_off
`ifndef SYNTHESIS

            // Assertions
`ifdef NCPU_ENABLE_ASSERT
            always @(posedge clk)
               begin
                  if (rob_wb_BREADY & rob_wb_BVALID & (rob_wb_id==i[DEPTH_WIDTH-1:0]) & ~que_valid_r[i])
                     $fatal("\n Commit to a invalid entry of ROB. Please check ISSUE unit, DISPATCH unit or FU.\n");
                  if (rob_wb_BREADY & rob_wb_BVALID & (rob_wb_id==i[DEPTH_WIDTH-1:0]) & que_rd_ready_r[i])
                     $fatal("\n Do not wb to the same entry once again. Please check ISSUE unit, DISPATCH unit or FU.\n");
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
            assign id = (rob_disp_id - i[DEPTH_WIDTH-1:0]);

            assign rs1_prec_match[i-1] = rs1_ROB_match[id];
            assign rs2_prec_match[i-1] = rs2_ROB_match[id];
            assign rs1_prec_bypass[i-1] = rs1_ROB_match_bypass[id];
            assign rs2_prec_bypass[i-1] = rs2_ROB_match_bypass[id];
            assign rs1_prec_ready[i-1] = rs1_ROB_match_ready[id];
            assign rs2_prec_ready[i-1] = rs2_ROB_match_ready[id];
            
            assign prec_dat[i-1] = que_dat_r[id];

            assign rs1_prec_in_ROB[i-1] = rs1_prec_bypass[i-1] | rs1_prec_ready[i-1];
            assign rs2_prec_in_ROB[i-1] = rs2_prec_bypass[i-1] | rs2_prec_ready[i-1];

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
                     $fatal("\n The operand should not be wbted once more\n");
                  if (rs2_prec_ready[i-1] & rs2_prec_bypass[i-1])
                     $fatal("\n The operand should not be wbted once more\n");
                  if (rs1_prec_in_ROB[i-1] & rs1_prec_in_ARF[i-1])
                     $fatal("\n Operands cannot be both in ARF and ROB.\n");
                  if (rs2_prec_in_ROB[i-1] & rs2_prec_in_ARF[i-1])
                     $fatal("\n Operands cannot be both in ARF and ROB.\n");
               end
`endif

`endif
            // synthesis translate_on

         end
   endgenerate
   
   // Priority Arbiter
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

   // Output MUX for dispatch channel
   generate
      wire [`NCPU_DW-1:0] t_rs1_dat [DEPTH-1:0];
      wire [`NCPU_DW-1:0] t_rs2_dat [DEPTH-1:0];

      // Bypass from wb channel.
      assign t_rs1_dat[0] = ({`NCPU_DW{|(rs1_first_match & rs1_prec_bypass)}} & rob_wb_BDATA);
      assign t_rs2_dat[0] = ({`NCPU_DW{|(rs2_first_match & rs2_prec_bypass)}} & rob_wb_BDATA);
      
      // Get from ROB
      for(i=1;i<DEPTH;i=i+1)
         begin : gen_issue_output
            assign t_rs1_dat[i] = t_rs1_dat[i-1] | ({`NCPU_DW{rs1_first_match[i-1] & rs1_prec_ready[i-1]}} & prec_dat[i-1]);
            assign t_rs2_dat[i] = t_rs2_dat[i-1] | ({`NCPU_DW{rs2_first_match[i-1] & rs2_prec_ready[i-1]}} & prec_dat[i-1]);
         end

      assign rob_disp_rs1_dat = t_rs1_dat[DEPTH-1];
      assign rob_disp_rs2_dat = t_rs2_dat[DEPTH-1];
   endgenerate

   assign rob_disp_rs1_in_ROB = |(rs1_first_match & rs1_prec_in_ROB);
   assign rob_disp_rs2_in_ROB = |(rs2_first_match & rs2_prec_in_ROB);
   assign rob_disp_rs1_in_ARF = &rs1_prec_in_ARF;
   assign rob_disp_rs2_in_ARF = &rs2_prec_in_ARF;


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
         // The following 4 assertions hold if there is only one wb channel.
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
         assert_flush_req <= flush;
         if (assert_flush_req & flush) $fatal("\n It's likely a bug?? 'flush' was not a 1-clk pulse\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
