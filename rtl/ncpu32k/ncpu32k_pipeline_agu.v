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

module ncpu32k_pipeline_agu
#(
   parameter CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2 `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_PIPEBUF_BYPASS `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ROB_DEPTH_LOG2 `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      rst_n,
   input                      flush,
   // From DISPATCH
   output                     issue_agu_AREADY,
   input                      issue_agu_AVALID,
   input [`NCPU_AGU_UOPW-1:0] issue_agu_uop,
   input [CONFIG_ROB_DEPTH_LOG2-1:0] issue_id,
   input                      issue_rs1_rdy,
   input [`NCPU_DW-1:0]       issue_rs1_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs1_addr,
   input                      issue_rs2_rdy,
   input [`NCPU_DW-1:0]       issue_rs2_dat,
   input [`NCPU_REG_AW-1:0]   issue_rs2_addr,
   input [`NCPU_DW-1:0]       issue_imm32,
   // Data Bus
   input                      dbus_AREADY,
   output                     dbus_AVALID,
   output [`NCPU_AW-1:0]      dbus_AADDR,
   output [`NCPU_DW/8-1:0]    dbus_AWMSK,
   output [`NCPU_DW-1:0]      dbus_ADATA,
   output                     dbus_BREADY,
   input                      dbus_BVALID,
   input [`NCPU_DW-1:0]       dbus_BDATA,
   input [1:0]                dbus_BEXC,
   // From ROB
   input [CONFIG_ROB_DEPTH_LOG2-1:0] rob_commit_ptr,
   // From BYP
   input                      byp_BVALID,
   input [`NCPU_DW-1:0]       byp_BDATA,
   input                      byp_rd_we,
   input [`NCPU_REG_AW-1:0]   byp_rd_addr,
   // To WRITEBACK
   input                      wb_agu_BREADY,
   output                     wb_agu_BVALID,
   output [`NCPU_DW-1:0]      wb_agu_BDATA,
   output [CONFIG_ROB_DEPTH_LOG2-1:0] wb_agu_BID,
   output                     wb_agu_BEDTM,
   output                     wb_agu_BEDPF,
   output                     wb_agu_BEALIGN,
   // To EPU
   output                     epu_commit_EDTM,
   output                     epu_commit_EDPF,
   output                     epu_commit_EALIGN,
   output [`NCPU_AW-1:0]      epu_commit_LSA
);
   localparam PAYLOAD_DW = `NCPU_DW + `NCPU_AGU_UOPW;
   /*AUTOWIRE*/
   wire                       rs_AREADY;
   wire                       rs_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       rs_id;
   wire [`NCPU_DW-1:0]        rs_operand_1, rs_operand_2;
   wire                       payload_re, payload_we;
   wire [CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2-1:0] payload_w_ptr;
   wire [CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2-1:0] payload_r_ptr;
   wire [PAYLOAD_DW-1:0]      payload_din, payload_dout;
   wire                       fire_AREADY;
   wire                       fire_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       fire_id;
   wire [`NCPU_DW-1:0]        fire_operand_1, fire_operand_2, fire_imm32;
   wire [`NCPU_AGU_UOPW-1:0]  fire_uop;
   wire                       fire_load, fire_store, fire_barr;
   wire                       fire_sign_ext;
   wire [2:0]                 fire_size;
   wire [`NCPU_DW/8-1:0]      fire_we_msk_8b;
   wire [31:0]                fire_din_8b;
   wire [`NCPU_DW/8-1:0]      fire_we_msk_16b;
   wire [31:0]                fire_din_16b;
   wire                       fire_misalign;
   wire                       commit;
   wire                       hds_dbus_a, hds_wb_b;
   wire                       wb_misalign;
   wire [2:0]                 wb_size;
   wire                       wb_sign_ext;
   wire [`NCPU_AW-1:0]        wb_lsa;
   wire [15:0]                wb_dout_16b;
   wire [7:0]                 wb_dout_8b;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0]       wb_id;
   
   ncpu32k_issue_queue
      #(
         .DEPTH            (1<<CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2),
         .DEPTH_WIDTH      (CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2),
         .UOP_WIDTH        (1),
         .ALGORITHM        (1), // FIFO
         .CONFIG_ROB_DEPTH_LOG2 (CONFIG_ROB_DEPTH_LOG2)
      )
   RS_AGU
      (
         .clk              (clk),
         .rst_n            (rst_n),
         .i_issue_AVALID   (issue_agu_AVALID),
         .o_issue_AREADY   (issue_agu_AREADY),
         .i_flush          (flush),
         .i_uop            (1'b0),
         .i_id             (issue_id),
         .i_rs1_rdy        (issue_rs1_rdy),
         .i_rs1_dat        (issue_rs1_dat),
         .i_rs1_addr       (issue_rs1_addr),
         .i_rs2_rdy        (issue_rs2_rdy),
         .i_rs2_dat        (issue_rs2_dat),
         .i_rs2_addr       (issue_rs2_addr),
         .byp_BVALID       (byp_BVALID),
         .byp_BDATA        (byp_BDATA),
         .byp_rd_we        (byp_rd_we),
         .byp_rd_addr      (byp_rd_addr),
         .i_fu_AREADY      (rs_AREADY),
         .o_fu_AVALID      (rs_AVALID),
         .o_fu_id          (rs_id),
         .o_fu_uop         (),
         .o_fu_rs1_dat     (rs_operand_1),
         .o_fu_rs2_dat     (rs_operand_2),
         .o_payload_w_ptr  (payload_w_ptr),
         .o_payload_r_ptr  (payload_r_ptr)
      );

   // Payload RAM to store uOPs and immediate numbers.
   // This design improved the timing.
   ncpu32k_cell_sdpram_sclk
      #(
         .AW (CONFIG_AGU_ISSUE_QUEUE_DEPTH_LOG2),
         .DW (PAYLOAD_DW),
         .ENABLE_BYPASS (1)
      )
   PAYLOAD_RAM
      (
         // Outputs
         .dout    (payload_dout),
         // Inputs
         .clk     (clk),
         .rst_n   (rst_n),
         .raddr   (payload_r_ptr),
         .re      (payload_re),
         .waddr   (payload_w_ptr),
         .we      (payload_we),
         .din     (payload_din)
      );

   assign payload_we = (issue_agu_AREADY & issue_agu_AVALID);
   assign payload_din = {issue_imm32[`NCPU_DW-1:0], issue_agu_uop[`NCPU_AGU_UOPW-1:0]};

   ncpu32k_cell_pipebuf
      #(
         .CONFIG_PIPEBUF_BYPASS (CONFIG_PIPEBUF_BYPASS)
      )
   PIPEBUF_PAYLOAD
      (
         .clk     (clk),
         .rst_n   (rst_n),
         .flush   (flush),
         .A_en    (1'b1),
         .AVALID  (rs_AVALID),
         .AREADY  (rs_AREADY),
         .B_en    (1'b1),
         .BVALID  (fire_AVALID),
         .BREADY  (fire_AREADY),
         .cke     (payload_re),
         .pending ()
      );

   nDFF_l #(CONFIG_ROB_DEPTH_LOG2) dff_fire_id
     (clk, payload_re, rs_id, fire_id);
   nDFF_l #(`NCPU_DW) dff_fire_operand_1
     (clk, payload_re, rs_operand_1, fire_operand_1);
   nDFF_l #(`NCPU_DW) dff_fire_operand_2
     (clk, payload_re, rs_operand_2, fire_operand_2);

   assign {fire_imm32[`NCPU_DW-1:0], fire_uop[`NCPU_AGU_UOPW-1:0]} = payload_dout;

   assign {fire_load, fire_store, fire_barr, fire_sign_ext, fire_size[2:0]} = fire_uop;

   assign commit = (rob_commit_ptr == fire_id) & ~flush;

   // Address Geneator
   assign dbus_AADDR = fire_operand_1 + fire_imm32;

   // Address alignment check
   assign fire_misalign = (fire_size==3'd3 & |dbus_AADDR[1:0]) |
                           (fire_size==3'd2 & dbus_AADDR[0]);

   assign fire_din_8b = {fire_operand_2[7:0], fire_operand_2[7:0], fire_operand_2[7:0], fire_operand_2[7:0]};
   assign fire_din_16b = {fire_operand_2[15:0], fire_operand_2[15:0]};

   assign dbus_ADATA = ({`NCPU_DW{fire_size==3'd3}} & fire_operand_2) |
                     ({`NCPU_DW{fire_size==3'd2}} & fire_din_16b) |
                     ({`NCPU_DW{fire_size==3'd1}} & fire_din_8b);
   
   // B/HW align
   assign fire_we_msk_8b = (dbus_AADDR[1:0]==2'b00 ? 4'b0001 :
                        dbus_AADDR[1:0]==2'b01 ? 4'b0010 :
                        dbus_AADDR[1:0]==2'b10 ? 4'b0100 :
                        dbus_AADDR[1:0]==2'b11 ? 4'b1000 : 4'b0000);
   assign fire_we_msk_16b = dbus_AADDR[1] ? 4'b1100 : 4'b0011;

   // Write byte mask
   assign dbus_AWMSK = {`NCPU_DW/8{fire_store}} & (
                            ({`NCPU_DW/8{fire_size==3'd3}} & 4'b1111) |
                            ({`NCPU_DW/8{fire_size==3'd2}} & fire_we_msk_16b) |
                            ({`NCPU_DW/8{fire_size==3'd1}} & fire_we_msk_8b) );

   // Send the request to dbus and remove the uOP from issue queue.
   // Notes:
   // 1) If LSA is misaligned, do not send the request
   // 2) When flushing is pending, do not send the request
   // 3) It originally supports the outstanding transmission. However, currently
   //    we only implement a single commit channel, and a transmission
   //    can only be sent after the previous transmission is completed.
   //    Thus the capacity of outstanding is 1.
   // Assert (2104021913)
   assign dbus_AVALID = fire_AVALID & ~fire_misalign & commit;
   assign fire_AREADY = (dbus_AREADY | fire_misalign) & commit;

   // Forward B-channel from dbus to wb
   assign dbus_BREADY = wb_agu_BREADY;
   assign wb_agu_BVALID = dbus_BVALID | wb_misalign;
   
   // FSM to maintain exception pending
   wire misalign_req = (fire_misalign & commit);
   nDFF_lr #(1) dff_wb_exc_pending_r
     (clk, rst_n, misalign_req|hds_wb_b|flush, (misalign_req|~hds_wb_b) & ~flush, wb_misalign);

   assign hds_dbus_a = (dbus_AREADY & dbus_AVALID);
   assign hds_wb_b = (wb_agu_BREADY & wb_agu_BVALID);

   nDFF_l #(3) dff_wb_size
     (clk, hds_dbus_a, fire_size, wb_size);
   nDFF_l #(1) dff_wb_sign_ext
     (clk, hds_dbus_a, fire_sign_ext, wb_sign_ext);
   nDFF_l #(`NCPU_AW) dff_wb_lsa
     (clk, hds_dbus_a, dbus_AADDR, wb_lsa);
   nDFF_l #(CONFIG_ROB_DEPTH_LOG2) dff_wb_id
     (clk, hds_dbus_a, fire_id, wb_id);

   // B/HW align
   assign wb_dout_8b = ({8{wb_lsa[1:0]==2'b00}} & dbus_BDATA[7:0]) |
                          ({8{wb_lsa[1:0]==2'b01}} & dbus_BDATA[15:8]) |
                          ({8{wb_lsa[1:0]==2'b10}} & dbus_BDATA[23:16]) |
                          ({8{wb_lsa[1:0]==2'b11}} & dbus_BDATA[31:24]);
   assign wb_dout_16b = wb_lsa[1] ? dbus_BDATA[31:16] : dbus_BDATA[15:0];

   assign wb_agu_BDATA =
      ({`NCPU_DW{wb_size==3'd3}} & dbus_BDATA) |
      ({`NCPU_DW{wb_size==3'd2}} & {{16{wb_sign_ext & wb_dout_16b[15]}}, wb_dout_16b[15:0]}) |
      ({`NCPU_DW{wb_size==3'd1}} & {{24{wb_sign_ext & wb_dout_8b[7]}}, wb_dout_8b[7:0]});

   assign wb_agu_BID = wb_id;

   // Assert (2104022032)
   assign wb_agu_BEDTM = dbus_BEXC[0];
   assign wb_agu_BEDPF = dbus_BEXC[1];
   assign wb_agu_BEALIGN = wb_misalign;

   // Commit MSR
   assign epu_commit_EDTM = (hds_wb_b & wb_agu_BEDTM);
   assign epu_commit_EDPF = (hds_wb_b & wb_agu_BEDPF);
   assign epu_commit_EALIGN = (hds_wb_b & wb_agu_BEALIGN);
   assign epu_commit_LSA = wb_lsa;

   // synthesis translate_off
`ifndef SYNTHESIS
   `include "ncpu32k_assert.h"

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk)
      begin
         // Assertion 2104021913
         if ((dbus_AVALID & dbus_AREADY) ^ (fire_AVALID & ~fire_misalign & fire_AREADY))
            $fatal(1, "\n Bugs on handshake between dbus and issue queue\n");
         if (fire_AVALID & fire_misalign & commit & ~fire_AREADY)
            $fatal(1, "\n Bugs on handshake between dbus and issue queue with exception\n");

         // Assertion 2104022032
         if (count_1({wb_agu_BEDTM, wb_agu_BEDPF, wb_agu_BEALIGN})>1)
            $fatal(1, "\n Bugs on exceptions of DMMU\n");
      end
`endif

`endif
   // synthesis translate_on

endmodule
