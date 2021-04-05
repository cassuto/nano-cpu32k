`include "timescale.v"
`include "ncpu32k_config.h"

module tb_issue_queue_FIFO;

   localparam CONFIG_ROB_DEPTH_LOG2 = 3;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg issue_AVALID;
   wire issue_AREADY;
   reg [CONFIG_ROB_DEPTH_LOG2-1:0] id;
   reg [3:0] uop;
   reg rs1_rdy;
   reg [`NCPU_DW-1:0] rs1_dat;
   reg [`NCPU_REG_AW-1:0] rs1_addr;
   reg rs2_rdy;
   reg [`NCPU_DW-1:0] rs2_dat;
   reg [`NCPU_REG_AW-1:0] rs2_addr;
   reg byp_BVALID;
   reg [`NCPU_DW-1:0] byp_BDATA;
   reg byp_rd_we;
   reg [`NCPU_REG_AW-1:0] byp_rd_addr;
   reg fu_AREADY;
   wire fu_AVALID;
   wire [CONFIG_ROB_DEPTH_LOG2-1:0] fu_id;
   wire [3:0] fu_uop;
   wire [`NCPU_DW-1:0] fu_rs1_dat;
   wire [`NCPU_DW-1:0] fu_rs2_dat;

   initial forever #10 clk = ~clk;
   initial #5 rst_n = 1'b1;

   ncpu32k_issue_queue
      #(
         .DEPTH(4),
         .DEPTH_WIDTH(2),
         .UOP_WIDTH(4),
         .ALGORITHM(1), // FIFO
         .CONFIG_ROB_DEPTH_LOG2(CONFIG_ROB_DEPTH_LOG2)
      )
   ISSUE_QUEUE
      (
         .clk              (clk),
         .rst_n            (rst_n),
         .i_issue_AVALID   (issue_AVALID),
         .o_issue_AREADY   (issue_AREADY),
         .i_flush          (1'b0),
         .i_id             (id),
         .i_uop            (uop),
         .i_rs1_rdy        (rs1_rdy),
         .i_rs1_dat        (rs1_dat),
         .i_rs1_addr       (rs1_addr),
         .i_rs2_rdy        (rs2_rdy),
         .i_rs2_dat        (rs2_dat),
         .i_rs2_addr       (rs2_addr),
         .byp_BVALID       (byp_BVALID),
         .byp_BDATA        (byp_BDATA),
         .byp_rd_we        (byp_rd_we),
         .byp_rd_addr      (byp_rd_addr),
         .i_fu_AREADY      (fu_AREADY),
         .o_fu_AVALID      (fu_AVALID),
         .o_fu_id          (fu_id),
         .o_fu_uop         (fu_uop),
         .o_fu_rs1_dat     (fu_rs1_dat),
         .o_fu_rs2_dat     (fu_rs2_dat),
         .o_payload_w_ptr  (),
         .o_payload_r_ptr  ()
      );
      
   task handshake_issue;
      begin
         @(posedge clk);
         if (~issue_AREADY | ~issue_AVALID)
            $fatal(1, $time);
      end
   endtask
   task handshake_fu;
      begin
         @(posedge clk);
         if (~fu_AREADY | ~fu_AVALID)
            $fatal(1, $time);
      end
   endtask
   
   initial
      begin
         issue_AVALID = 1'b0;
         id = {CONFIG_ROB_DEPTH_LOG2{1'b0}};
         fu_AREADY = 1'b0;
         @(posedge clk);
         
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Basics
         ///////////////////////////////////////////////////////////////////////
         
         //
         // Push 1
         //
         byp_BVALID = 1'b0;
         byp_BDATA = 32'h32;
         byp_rd_we = 1'b0;
         byp_rd_addr = 5'h4;
         
         issue_AVALID = 1'b1;
         uop = 4'h1;
         rs1_rdy = 1'b1;
         rs1_dat = 32'h6;
         rs1_addr = 5'h0;

         rs2_rdy = 1'b0;
         rs2_dat = 32'h2;
         rs2_addr = 5'h4;

         handshake_issue;
         issue_AVALID = 1'b0;

         //
         // Push 2
         //
         byp_BVALID = 1'b0;
         byp_BDATA = 32'h32;
         byp_rd_we = 1'b0;
         byp_rd_addr = 5'h4;
         
         issue_AVALID = 1'b1;
         uop = 4'h2;
         rs1_rdy = 1'b1;
         rs1_dat = 32'hfeedba;
         rs1_addr = 5'h0;

         rs2_rdy = 1'b0;
         rs2_dat = 32'hbadbeef;
         rs2_addr = 5'h5;

         handshake_issue;
         issue_AVALID = 1'b0;

         //
         // Push 3
         //
         byp_BVALID = 1'b0;
         byp_BDATA = 32'h32;
         byp_rd_we = 1'b1;
         byp_rd_addr = 5'h4;
         
         issue_AVALID = 1'b1;
         uop = 4'h3;
         rs1_rdy = 1'b1;
         rs1_dat = 32'hfeedba;
         rs1_addr = 5'h0;

         rs2_rdy = 1'b1;
         rs2_dat = 32'hbadbeef;
         rs2_addr = 5'h5;
         
         handshake_issue;
         issue_AVALID = 1'b0;

         //
         // Push 4
         //
         byp_BVALID = 1'b0;
         byp_BDATA = 32'h32;
         byp_rd_we = 1'b0;
         byp_rd_addr = 5'h4;
         
         issue_AVALID = 1'b1;
         uop = 4'h4;
         rs1_rdy = 1'b0;
         rs1_dat = 32'hfeedba;
         rs1_addr = 5'h6;

         rs2_rdy = 1'b1;
         rs2_dat = 32'hbadbeef;
         rs2_addr = 5'h5;
         
         handshake_issue;
         issue_AVALID = 1'b0;

         //
         // Try to Push 5 (wrap around)
         //
         @(posedge clk);
         if (fu_AVALID)
            $fatal(1, $time);

         //
         // Try to Pop 1
         //
         if (fu_AVALID)
            $fatal(1, $time);

         // BYP address not matched
         byp_BVALID = 1'b1;
         byp_BDATA = 32'h32;
         byp_rd_we = 1'b1;
         byp_rd_addr = 5'h3;
         @(posedge clk);
         if (fu_AVALID)
            $fatal(1, $time);
         
         // BYP we not matched
         byp_BVALID = 1'b1;
         byp_BDATA = 32'h33;
         byp_rd_we = 1'b0;
         byp_rd_addr = 5'h4;
         @(posedge clk);
         if (fu_AVALID)
            $fatal(1, $time);
         
         // BYP valid for #2
         byp_BVALID = 1'b1;
         byp_BDATA = 32'hfaf;
         byp_rd_we = 1'b1;
         byp_rd_addr = 5'h5; // the same as the rd_addr of #2
         @(posedge clk);
         if (fu_AVALID)
            $fatal(1, $time);
         
         // BYP valid for #1
         byp_BVALID = 1'b1;
         byp_BDATA = 32'h4;
         byp_rd_we = 1'b1;
         byp_rd_addr = 5'h4; // the same as the rd_addr of #1
         @(posedge clk);
         byp_BVALID = 1'b0;

         // Pop #1
         fu_AREADY = 1'b1;
         handshake_fu;
         if (fu_uop !== 4'h1)
            $fatal(1, $time);
         if (fu_rs1_dat !== 32'h6)
            $fatal(1, $time);
         if (fu_rs2_dat !== 32'h4)
            $fatal(1, $time);
         fu_AREADY = 1'b0;

         fork
            begin
               //
               // Push 5 (wrap around)
               //
               byp_BVALID = 1'b0;
               byp_BDATA = 32'h32;
               byp_rd_we = 1'b1;
               byp_rd_addr = 5'h4;
               
               issue_AVALID = 1'b1;
               uop = 4'h5;
               rs1_rdy = 1'b1;
               rs1_dat = 32'hfeedba;
               rs1_addr = 5'h0;

               rs2_rdy = 1'b0;
               rs2_dat = 32'hbadbeef;
               rs2_addr = 5'h5;

               handshake_issue;
               issue_AVALID = 1'b0;

               // BYP valid for #4
               byp_BVALID = 1'b1;
               byp_BDATA = 32'h666;
               byp_rd_we = 1'b1;
               byp_rd_addr = 5'h6; // the same as the rd_addr of #4
               @(posedge clk);
               byp_BVALID = 1'b0;

               // BYP valid for #5
               byp_BVALID = 1'b1;
               byp_BDATA = 32'hafa;
               byp_rd_we = 1'b1;
               byp_rd_addr = 5'h5; // the same as the rd_addr of #5
               @(posedge clk);
               byp_BVALID = 1'b0;

               //
               // Push 6 with bypass
               //
               byp_BVALID = 1'b1;
               byp_BDATA = 32'hcad;
               byp_rd_we = 1'b1;
               byp_rd_addr = 5'h5;  // the same as the rd_addr of #6
               
               issue_AVALID = 1'b1;
               uop = 4'h6;
               rs1_rdy = 1'b1;
               rs1_dat = 32'heda;
               rs1_addr = 5'h0;

               rs2_rdy = 1'b0;
               rs2_dat = 32'hbad;
               rs2_addr = 5'h5;

               handshake_issue;
               issue_AVALID = 1'b0;
               byp_BVALID = 1'b0;
            end
            begin
               // Pop #2
               fu_AREADY = 1'b1;
               handshake_fu;
               if (fu_uop !== 4'h2)
                  $fatal(1, $time);
               if (fu_rs1_dat !== 32'hfeedba)
                  $fatal(1, $time);
               if (fu_rs2_dat !== 32'hfaf)
                  $fatal(1, $time);
               fu_AREADY = 1'b0;

               // Pop #3
               fu_AREADY = 1'b1;
               handshake_fu;
               if (fu_uop !== 4'h3)
                  $fatal(1, $time);
               if (fu_rs1_dat !== 32'hfeedba)
                  $fatal(1, $time);
               if (fu_rs2_dat !== 32'hbadbeef)
                  $fatal(1, $time);
               fu_AREADY = 1'b0;

               // Pop #4
               fu_AREADY = 1'b1;
               handshake_fu;
               if (fu_uop !== 4'h4)
                  $fatal(1, $time);
               if (fu_rs1_dat !== 32'h666)
                  $fatal(1, $time);
               if (fu_rs2_dat !== 32'hbadbeef)
                  $fatal(1, $time);
               fu_AREADY = 1'b0;

               // Pop #5
               fu_AREADY = 1'b1;
               handshake_fu;
               if (fu_uop !== 4'h5)
                  $fatal(1, $time);
               if (fu_rs1_dat !== 32'hfeedba)
                  $fatal(1, $time);
               if (fu_rs2_dat !== 32'hafa)
                  $fatal(1, $time);
               fu_AREADY = 1'b0;

               // Pop #6
               fu_AREADY = 1'b1;
               handshake_fu;
               if (fu_uop !== 4'h6)
                  $fatal(1, $time);
               if (fu_rs1_dat !== 32'heda)
                  $fatal(1, $time);
               if (fu_rs2_dat !== 32'hcad)
                  $fatal(1, $time);
               fu_AREADY = 1'b0;
            end
         join
         
         
         @(posedge clk);
         
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
      end
      
      

endmodule
