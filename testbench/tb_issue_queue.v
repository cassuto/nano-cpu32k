
`include "ncpu32k_config.h"

module tb_issue_queue;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg issue_valid;
   wire issue_ready;
   reg [3:0] uop;
   reg rs1_rdy;
   reg [`NCPU_DW-1:0] rs1_dat;
   reg [`NCPU_REG_AW-1:0] rs1_addr;
   reg rs2_rdy;
   reg [`NCPU_DW-1:0] rs2_dat;
   reg [`NCPU_REG_AW-1:0] rs2_addr;
   reg cdb_BVALID;
   reg [`NCPU_DW-1:0] cdb_BDATA;
   reg cdb_rd_we;
   reg [`NCPU_REG_AW-1:0] cdb_rd_addr;
   reg [`NCPU_DW-1:0] cdb_rd_dat;
   reg fu_ready;
   wire fu_valid;
   wire [3:0] fu_uop;
   wire [`NCPU_DW-1:0] fu_rs1_dat;
   wire [`NCPU_DW-1:0] fu_rs2_dat;

   initial forever #10 clk = ~clk;
   initial #20 rst_n = 1'b1;

   ncpu32k_issue_queue
      #(
         .DEPTH(4),
         .UOP_WIDTH(4)
      )
   ISSUE_QUEUE
      (
         .clk              (clk),
         .rst_n            (rst_n),
         .i_issue_valid    (issue_valid),
         .o_issue_ready    (issue_ready),
         .i_uop            (uop),
         .i_rs1_rdy        (rs1_rdy),
         .i_rs1_dat        (rs1_dat),
         .i_rs1_addr       (rs1_addr),
         .i_rs2_rdy        (rs2_rdy),
         .i_rs2_dat        (rs2_dat),
         .i_rs2_addr       (rs2_addr),
         .cdb_BVALID       (cdb_BVALID),
         .cdb_BDATA        (cdb_BDATA),
         .cdb_rd_we        (cdb_rd_we),
         .cdb_rd_addr      (cdb_rd_addr),
         .i_fu_ready       (fu_ready),
         .o_fu_valid       (fu_valid),
         .o_fu_uop         (fu_uop),
         .o_fu_rs1_dat     (fu_rs1_dat),
         .o_fu_rs2_dat     (fu_rs2_dat)
      );
      
   task handshake_issue;
      begin
         @(posedge clk);
         if (~issue_ready | ~issue_valid)
            $fatal($time);
      end
   endtask
   task handshake_fu;
      begin
         @(posedge clk);
         if (~fu_ready | ~fu_valid)
            $fatal($time);
      end
   endtask
   
   task checkpoint_2_5;
      case (fu_uop)
      4'h2:
         begin
            if (fu_rs1_dat != 32'h10)
               $fatal($time);
            if (fu_rs2_dat != 32'h88)
               $fatal($time);
         end
      4'h5:
         begin
            if (fu_rs1_dat != 32'h88)
               $fatal($time);
            if (fu_rs2_dat != 32'h56)
               $fatal($time);
         end
      endcase
   endtask
   
   initial
      begin
         issue_valid = 1'b0;
         @(posedge clk);
         
         //
         // Testcase - Push 1
         //
         cdb_BVALID = 1'b0;
         cdb_BDATA = 32'h32;
         cdb_rd_we = 1'b0;
         cdb_rd_addr = 5'h4;
         
         issue_valid = 1'b1;
         uop = 4'h1;
         rs1_rdy = 1'b1;
         rs1_dat = 32'h6;
         rs1_addr = 5'h0;

         rs2_rdy = 1'b0;
         rs2_dat = 32'h2;
         rs2_addr = 5'h4;

         fu_ready = 1'b0;
         if (~issue_ready)
            $fatal($time);
         handshake_issue;
         issue_valid = 1'b0;

         // CDB address not matched
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h32;
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h3;
         @(posedge clk);
         
         // CDB we not matched
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h33;
         cdb_rd_we = 1'b0;
         cdb_rd_addr = 5'h4;
         @(posedge clk);
         
         // CDB valid
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h4; // the same as the rd_addr
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h4;
         @(posedge clk);
         
         @(posedge clk);
         if (~fu_valid)
            $fatal($time);
         if (fu_uop != 4'h1)
            $fatal($time);
         if (fu_rs1_dat != 32'h6)
            $fatal($time);
         if (fu_rs2_dat != 32'h4)
            $fatal($time);
         
         // CDB valid afer element poped
         @(posedge clk);
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h35;
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h0;
         @(posedge clk);
         cdb_BVALID = 1'b0;
         
         
         //
         // Testcase - Push 2 (rs2 not ready)
         //
         @(posedge clk);
         issue_valid = 1'b1;
         uop = 4'h2;
         rs1_rdy = 1'b1;
         rs1_dat = 32'h10;
         rs1_addr = 5'h1;

         rs2_rdy = 1'b0;
         rs2_dat = 32'h2;
         rs2_addr = 5'h5;
         if (~issue_ready)
            $fatal($time);
         handshake_issue;
         
         //
         // Testcase - Push 3 (rs1 not ready)
         //
         issue_valid = 1'b1;
         uop = 4'h3;
         rs1_rdy = 1'b0;
         rs1_dat = 32'h3;
         rs1_addr = 5'h2;

         rs2_rdy = 1'b1;
         rs2_dat = 32'h8;
         rs2_addr = 5'h6;
         if (~issue_ready)
            $fatal($time);
         handshake_issue;
         
         //
         // Testcase - Push 4
         //
         issue_valid = 1'b1;
         uop = 4'h4;
         rs1_rdy = 1'b1;
         rs1_dat = 32'h4;
         rs1_addr = 5'h3;

         rs2_rdy = 1'b0;
         rs2_dat = 32'h4;
         rs2_addr = 5'h7;
         if (~issue_ready)
            $fatal($time);
         
         // CDB valid
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h44;
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h7;
         @(posedge clk);
         cdb_BVALID = 1'b0;
         issue_valid = 1'b0;
         @(posedge clk);
         if (issue_ready)
            $fatal($time);
         
         
         //
         // Testcase - pop 1
         //
         if (~fu_valid)
            $fatal($time);
         fu_ready = 1'b1;
         handshake_fu;
         if (fu_uop != 4'h1)
            $fatal($time);
         if (fu_rs1_dat != 32'h6)
            $fatal($time);
         if (fu_rs2_dat != 32'h4)
            $fatal($time);
         
         //
         // Testcase - pop 4
         //
         if (~fu_valid)
            $fatal($time);
         fu_ready = 1'b1;
         handshake_fu;
         if (fu_uop != 4'h4)
            $fatal($time);
         if (fu_rs1_dat != 32'h4)
            $fatal($time);
         if (fu_rs2_dat != 32'h44)
            $fatal($time);
            
         if (~issue_ready)
            $fatal($time);
            
         //
         // Testcase - wake-up 3
         //
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h66;
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h2;
         @(posedge clk);
         cdb_BVALID = 1'b0;
         fu_ready = 1'b1;
         handshake_fu;
         if (fu_uop != 4'h3)
            $fatal($time);
         if (fu_rs1_dat != 32'h66)
            $fatal($time);
         if (fu_rs2_dat != 32'h8)
            $fatal($time);
            
         if (~issue_ready)
            $fatal($time);
            
         //
         // Testcase - push 5 (rs1 not ready)
         //
         issue_valid = 1'b1;
         uop = 4'h5;
         rs1_rdy = 1'b0;
         rs1_dat = 32'h55;
         rs1_addr = 5'h5;

         rs2_rdy = 1'b1;
         rs2_dat = 32'h56;
         rs2_addr = 5'h5;
         handshake_issue;
         
         issue_valid = 1'b0;
         
         // Now #2 and #5 are not ready
         // rs2 of #2 == rs1 of #5
         
         //
         // Testcase - Wake up #2 and #5
         //
         cdb_BVALID = 1'b1;
         cdb_BDATA = 32'h88;
         cdb_rd_we = 1'b1;
         cdb_rd_addr = 5'h5;
         @(posedge clk);
         cdb_BVALID = 1'b0;
         
         //
         // Testcase Pop #2 or #5
         //
         fu_ready = 1'b1;
         handshake_fu;
         checkpoint_2_5;
         
         fu_ready = 1'b1;
         handshake_fu;
         checkpoint_2_5;
         
         @(posedge clk);
         if (fu_valid)
            $fatal($time);
         
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
      end


endmodule
