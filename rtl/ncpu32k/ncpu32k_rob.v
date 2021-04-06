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
   parameter DEPTH_WIDTH `PARAM_NOT_SPECIFIED ,
   parameter TAG_WIDTH `PARAM_NOT_SPECIFIED
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
   localparam PAYLOAD_RF_DW = `NCPU_DW;
   localparam PAYLOAD_WB_DW = TAG_WIDTH + `NCPU_DW; // TAG + RD_DAT
   localparam PAYLOAD_DISP_DW = `NCPU_AW-2 + `NCPU_AW-2; // PC + pred_PC

   wire                             rob_push;
   wire                             rob_pop;
   wire                             rob_empty;
   wire                             rob_full;
   wire [DEPTH_WIDTH:0]             w_ptr_r;
   wire [DEPTH_WIDTH:0]             w_ptr_nxt;
   wire [DEPTH_WIDTH:0]             r_ptr_r;
   wire [DEPTH_WIDTH:0]             r_ptr_nxt;
   wire                             que_valid_r [DEPTH-1:0];
   //wire [`NCPU_AW-3:0]              que_pc_r [DEPTH-1:0];
   //wire [`NCPU_AW-3:0]              que_pred_tgt_r [DEPTH-1:0];
   wire                             que_rd_ready_r [DEPTH-1:0];
   wire                             que_rd_we_r [DEPTH-1:0];
   wire [`NCPU_REG_AW-1:0]          que_rd_addr_r [DEPTH-1:0];
   //wire [`NCPU_DW-1:0]              que_dat_r [DEPTH-1:0];
   //wire [TAG_WIDTH-1:0]             que_tag_r [DEPTH-1:0];
   wire [DEPTH-1:0]                 rs1_ROB_match, rs2_ROB_match;
   wire [DEPTH-1:0]                 rs1_ROB_match_bypass, rs2_ROB_match_bypass;
   wire [DEPTH-1:0]                 rs1_ROB_match_ready, rs2_ROB_match_ready;
   wire [DEPTH-2:0]                 rs1_prec_match, rs2_prec_match;
   wire [DEPTH-2:0]                 rs1_prec_bypass, rs2_prec_bypass;
   wire [DEPTH-2:0]                 rs1_prec_ready, rs2_prec_ready;
   wire [DEPTH_WIDTH-1:0]           prec_id [DEPTH-2:0];
   wire [DEPTH-2:0]                 rs1_prec_in_ARF, rs2_prec_in_ARF;
   wire [DEPTH-2:0]                 rs1_prec_in_ROB, rs2_prec_in_ROB;
   wire [DEPTH-2:0]                 rs1_first_match, rs2_first_match;
   wire [DEPTH_WIDTH-1:0]           payload_rs1_id, payload_rs2_id;
   wire [`NCPU_DW-1:0]              payload_rs1_dat, payload_rs2_dat;
   wire                             payload_bypass_rs1_nxt, payload_bypass_rs2_nxt;
   wire                             payload_bypass_rs1_r, payload_bypass_rs2_r;
   wire [DEPTH_WIDTH-1:0]           payload_wb_id;
   wire                             fwft_disp_state_r;
   wire                             fwft_disp_nxt;
   wire                             fwft_disp_clr_state;
   wire [PAYLOAD_DISP_DW-1:0]       fwft_disp_dout;
   wire [PAYLOAD_DISP_DW-1:0]       fwft_disp_din_r;
   wire [PAYLOAD_WB_DW-1:0]         payload_wb_din;
   wire [PAYLOAD_DISP_DW-1:0]       payload_disp_din;
   wire [PAYLOAD_DISP_DW-1:0]       payload_disp_dout;
   wire [PAYLOAD_WB_DW-1:0]         payload_wb_dout;
   wire [`NCPU_DW-1:0]              rob_wb_BDATA_r;
   wire                             rob_disp_rs1_in_ROB_nxt;
   wire                             rob_disp_rs2_in_ROB_nxt;
   wire                             rob_disp_rs1_in_ARF_nxt;
   wire                             rob_disp_rs2_in_ARF_nxt;

   genvar i;
   integer x;

   assign rob_push = (rob_disp_AVALID & rob_disp_AREADY);
   assign rob_pop = (rob_commit_BREADY & rob_commit_BVALID);
   
   assign w_ptr_nxt = (w_ptr_r + 1'd1) & {DEPTH_WIDTH+1{~flush}};
   assign r_ptr_nxt = (r_ptr_r + 1'd1) & {DEPTH_WIDTH+1{~flush}};

   nDFF_lr #(DEPTH_WIDTH + 1) dff_w_ptr_r
     (clk,rst_n, (rob_push|flush), w_ptr_nxt, w_ptr_r);
   nDFF_lr #(DEPTH_WIDTH + 1) dff_r_ptr_r
     (clk,rst_n, (rob_pop|flush), r_ptr_nxt, r_ptr_r);

   generate
      for (i=0;i<DEPTH;i=i+1)
         begin : gen_DFFs
            wire this_disp, this_wb, this_commit;

            assign this_disp = (i[DEPTH_WIDTH-1:0]==w_ptr_r[DEPTH_WIDTH-1:0]) & rob_push;
            assign this_wb = (i[DEPTH_WIDTH-1:0]==rob_wb_id) & rob_wb_BVALID & rob_wb_BREADY;
            assign this_commit = (i[DEPTH_WIDTH-1:0]==r_ptr_r[DEPTH_WIDTH-1:0]) & rob_pop;

            nDFF_lr #(1) dff_que_valid_r
              (clk,rst_n, (this_disp|this_commit|flush), (this_disp|~this_commit)&~flush, que_valid_r[i]);
            nDFF_lr #(1) dff_que_rd_ready_r
              (clk,rst_n, (this_disp|this_wb), (~this_disp|this_wb), que_rd_ready_r[i]);
            /*nDFF_l #(`NCPU_AW-2) dff_que_pc_r
              (clk, this_disp, rob_disp_pc, que_pc_r[i]);
            nDFF_l #(`NCPU_AW-2) dff_que_pred_tgt_r
              (clk, this_disp, rob_disp_pred_tgt, que_pred_tgt_r[i]);*/
            nDFF_l #(1) dff_que_rd_we_r
              (clk, this_disp, rob_disp_rd_we, que_rd_we_r[i]);
            nDFF_lr #(`NCPU_REG_AW) dff_que_rd_addr_r
              (clk,rst_n, this_disp, rob_disp_rd_addr, que_rd_addr_r[i]);
            /*nDFF_l #(`NCPU_DW) dff_que_dat_r
              (clk, this_wb, rob_wb_BDATA, que_dat_r[i]);
            nDFF_l #(TAG_WIDTH) dff_que_tag_r
              (clk, this_wb, rob_wb_BTAG, que_tag_r[i]);*/
         end
   endgenerate

   assign rob_full = (w_ptr_r[DEPTH_WIDTH] != r_ptr_r[DEPTH_WIDTH]) &
                     (w_ptr_r[DEPTH_WIDTH-1:0] == r_ptr_r[DEPTH_WIDTH-1:0]);
   assign rob_empty = (w_ptr_r == r_ptr_r);

   assign rob_wb_BREADY = 1'b1;
   
   assign rob_disp_AREADY = ~rob_full;
   assign rob_commit_BVALID = ~rob_empty & que_rd_ready_r[r_ptr_r[DEPTH_WIDTH-1:0]];

   assign byp_rd_we = que_rd_we_r[rob_wb_id];
   assign byp_rd_addr = que_rd_addr_r[rob_wb_id];

   ncpu32k_cell_mpram_1w2r
      #(
         .AW (DEPTH_WIDTH),
         .DW (PAYLOAD_RF_DW),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_RF
      (
         // Outputs
         .dout_1  (payload_rs1_dat),
         .dout_2  (payload_rs2_dat),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr_1 (payload_rs1_id),
         .re_1    (rob_push),
         .raddr_2 (payload_rs2_id),
         .re_2    (rob_push),
         .waddr   (rob_wb_id),
         .we      (rob_wb_BVALID & rob_wb_BREADY),
         .din     (rob_wb_BDATA)
      );
   
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (DEPTH_WIDTH),
         .DW (PAYLOAD_WB_DW),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_WB
      (
         // Outputs
         .dout    (payload_wb_dout),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (payload_wb_id),
         .re      (1'b1),
         .waddr   (rob_wb_id),
         .we      (rob_wb_BVALID & rob_wb_BREADY),
         .din     (payload_wb_din)
      );

   ncpu32k_cell_sdpram_sclk
      #(
         .AW (DEPTH_WIDTH),
         .DW (PAYLOAD_DISP_DW),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_DISP
      (
         // Outputs
         .dout    (fwft_disp_dout),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (r_ptr_nxt[DEPTH_WIDTH-1:0]),
         .re      (rob_pop),
         .waddr   (w_ptr_r[DEPTH_WIDTH-1:0]),
         .we      (rob_push),
         .din     (payload_disp_din)
      );

   assign payload_wb_din = {rob_wb_BTAG[TAG_WIDTH-1:0], rob_wb_BDATA[`NCPU_DW-1:0]};

   // Predicate the value of `r_ptr_r` in the next beat,
   // which must be strictly accurate.
   assign payload_wb_id = (rob_pop|flush) ? r_ptr_nxt[DEPTH_WIDTH-1:0] : r_ptr_r[DEPTH_WIDTH-1:0];

   assign payload_disp_din = {rob_disp_pc[`NCPU_AW-3:0], rob_disp_pred_tgt[`NCPU_AW-3:0]};

   // FWFT FSM for payload DISP
   nDFF_lr #(1) dff_fwft_disp_state_r
      (clk,rst_n, (fwft_disp_nxt|fwft_disp_clr_state), (fwft_disp_nxt|~fwft_disp_clr_state), fwft_disp_state_r);
   nDFF_l #(PAYLOAD_DISP_DW) dff_fwft_disp_din_r
      (clk, fwft_disp_nxt, payload_disp_din, fwft_disp_din_r);

   assign fwft_disp_nxt = ~fwft_disp_state_r & rob_empty & rob_push;
   assign fwft_disp_clr_state = fwft_disp_state_r & rob_pop;

   assign payload_disp_dout = fwft_disp_state_r ? fwft_disp_din_r : fwft_disp_dout;

   assign {rob_commit_pc[`NCPU_AW-3:0], rob_commit_pred_tgt[`NCPU_AW-3:0]} = payload_disp_dout;
   assign {rob_commit_BTAG[TAG_WIDTH-1:0], rob_commit_BDATA[`NCPU_DW-1:0]} = payload_wb_dout;
   
   // Output MUX for commit channel
   //assign rob_commit_pc = que_pc_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   //assign rob_commit_pred_tgt = que_pred_tgt_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_rd_we = que_rd_we_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   assign rob_commit_rd_addr = que_rd_addr_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   //assign rob_commit_BDATA = que_dat_r[r_ptr_r[DEPTH_WIDTH-1:0]];
   //assign rob_commit_BTAG = que_tag_r[r_ptr_r[DEPTH_WIDTH-1:0]];
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
                     $fatal(1, "\n Commit to a invalid entry of ROB. Please check ISSUE unit, DISPATCH unit or FU.\n");
                  if (rob_wb_BREADY & rob_wb_BVALID & (rob_wb_id==i[DEPTH_WIDTH-1:0]) & que_rd_ready_r[i])
                     $fatal(1, "\n Do not wb to the same entry once again. Please check ISSUE unit, DISPATCH unit or FU.\n");
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
            assign id = (w_ptr_r[DEPTH_WIDTH-1:0] - i[DEPTH_WIDTH-1:0]);

            assign rs1_prec_match[i-1] = rs1_ROB_match[id];
            assign rs2_prec_match[i-1] = rs2_ROB_match[id];
            assign rs1_prec_bypass[i-1] = rs1_ROB_match_bypass[id];
            assign rs2_prec_bypass[i-1] = rs2_ROB_match_bypass[id];
            assign rs1_prec_ready[i-1] = rs1_ROB_match_ready[id];
            assign rs2_prec_ready[i-1] = rs2_ROB_match_ready[id];
            
            assign prec_id[i-1] = id;

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
                     $fatal(1, "\n The operand should not be wbted once more\n");
                  if (rs2_prec_ready[i-1] & rs2_prec_bypass[i-1])
                     $fatal(1, "\n The operand should not be wbted once more\n");
                  if (rs1_prec_in_ROB[i-1] & rs1_prec_in_ARF[i-1])
                     $fatal(1, "\n Operands cannot be both in ARF and ROB.\n");
                  if (rs2_prec_in_ROB[i-1] & rs2_prec_in_ARF[i-1])
                     $fatal(1, "\n Operands cannot be both in ARF and ROB.\n");
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
      reg [DEPTH_WIDTH-1:0] t_rs1_id;
      reg [DEPTH_WIDTH-1:0] t_rs2_id;
      always @(*)
         begin
            t_rs1_id = {DEPTH_WIDTH{1'b0}};
            t_rs2_id = {DEPTH_WIDTH{1'b0}};
            
            // Get from ROB
            for(x=0; x < DEPTH-1; x=x+1)
               begin : gen_issue_output
                  t_rs1_id = t_rs1_id | ({DEPTH_WIDTH{rs1_first_match[x] & rs1_prec_ready[x]}} & prec_id[x]);
                  t_rs2_id = t_rs2_id | ({DEPTH_WIDTH{rs2_first_match[x] & rs2_prec_ready[x]}} & prec_id[x]);
               end
         end

      assign payload_rs1_id = t_rs1_id;
      assign payload_rs2_id = t_rs2_id;
   endgenerate

   // Bypass from wb channel
   assign payload_bypass_rs1_nxt = |(rs1_first_match & rs1_prec_bypass);
   assign payload_bypass_rs2_nxt = |(rs2_first_match & rs2_prec_bypass);

   nDFF_lr #(1) dff_payload_bypass_rs1
     (clk,rst_n, rob_push, payload_bypass_rs1_nxt, payload_bypass_rs1_r);
   nDFF_lr #(1) dff_payload_bypass_rs2
     (clk,rst_n, rob_push, payload_bypass_rs2_nxt, payload_bypass_rs2_r);
   nDFF_lr #(`NCPU_DW) dff_rob_wb_BDATA_r
     (clk,rst_n, rob_push, rob_wb_BDATA, rob_wb_BDATA_r);

   assign rob_disp_rs1_in_ROB_nxt = |(rs1_first_match & rs1_prec_in_ROB);
   assign rob_disp_rs2_in_ROB_nxt = |(rs2_first_match & rs2_prec_in_ROB);
   assign rob_disp_rs1_in_ARF_nxt = &rs1_prec_in_ARF;
   assign rob_disp_rs2_in_ARF_nxt = &rs2_prec_in_ARF;

   nDFF_lr #(1) dff_rob_disp_rs1_in_ROB
     (clk,rst_n, rob_push, rob_disp_rs1_in_ROB_nxt, rob_disp_rs1_in_ROB);
   nDFF_lr #(1) dff_rob_disp_rs2_in_ROB
     (clk,rst_n, rob_push, rob_disp_rs2_in_ROB_nxt, rob_disp_rs2_in_ROB);

   nDFF_lr #(1) dff_rob_disp_rs1_in_ARF
     (clk,rst_n, rob_push, rob_disp_rs1_in_ARF_nxt, rob_disp_rs1_in_ARF);
   nDFF_lr #(1) dff_rob_disp_rs2_in_ARF
     (clk,rst_n, rob_push, rob_disp_rs2_in_ARF_nxt, rob_disp_rs2_in_ARF);

   nDFF_lr #(DEPTH_WIDTH) dff_rob_disp_id
     (clk,rst_n, rob_push, w_ptr_r[DEPTH_WIDTH-1:0], rob_disp_id);

   assign rob_disp_rs1_dat = payload_bypass_rs1_r ? rob_wb_BDATA_r
                              : payload_rs1_dat;
   assign rob_disp_rs2_dat = payload_bypass_rs2_r ? rob_wb_BDATA_r
                              : payload_rs2_dat;

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         if(count_1({rs1_first_match})>1)
            $fatal(1, "\n `rs1_first_match` should be mutex\n");
         if(count_1({rs2_first_match})>1)
            $fatal(1, "\n `rs2_first_match` should be mutex\n");
         // The following 4 assertions hold if there is only one wb channel.
         if(count_1({rs1_ROB_match_bypass})>1)
            $fatal(1, "\n `rs1_ROB_match_bypass` should be mutex\n");
         if(count_1({rs2_ROB_match_bypass})>1)
            $fatal(1, "\n `rs2_ROB_match_bypass` should be mutex\n");
         if(count_1({rs1_prec_bypass})>1)
            $fatal(1, "\n `rs1_prec_bypass` should be mutex\n");
         if(count_1({rs2_prec_bypass})>1)
            $fatal(1, "\n `rs2_prec_bypass` should be mutex\n");
            
         if( |(rs1_first_match & rs1_prec_bypass) & |(rs1_first_match & rs1_prec_ready) )
            $fatal(1, "\n Commit to the matched entry once more\n");
         if( |(rs2_first_match & rs2_prec_bypass) & |(rs2_first_match & rs2_prec_ready) )
            $fatal(1, "\n Commit to the matched entry once more\n");
      end
      
   reg assert_flush_req = 1'b0;
   always @(posedge clk)
      begin
         assert_flush_req <= flush;
         if (assert_flush_req & flush) $fatal(1, "\n It's likely a bug?? 'flush' was not a 1-clk pulse\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
