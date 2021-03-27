
`include "ncpu32k_config.h"

module tb_rob;

   localparam DEPTH_WIDTH = 2;
   localparam TAG_WIDTH = 4;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg flush_req;
   reg issue_AVALID;
   wire issue_AREADY;
   reg issue_rd_we;
   reg [`NCPU_REG_AW-1:0] issue_rd_addr;
   reg [`NCPU_REG_AW-1:0] issue_rs1_addr;
   reg [`NCPU_REG_AW-1:0] issue_rs2_addr;
   wire issue_rs1_from_ROB;
   wire issue_rs1_in_ARF;
   wire [`NCPU_DW-1:0] issue_rs1_dat;
   wire issue_rs2_from_ROB;
   wire issue_rs2_in_ARF;
   wire [`NCPU_DW-1:0] issue_rs2_dat;
   wire [DEPTH_WIDTH-1:0] issue_id;
   wire commit_BREADY;
   reg commit_BVALID;
   reg [`NCPU_DW-1:0] commit_BDATA;
   reg [TAG_WIDTH-1:0] commit_BTAG;
   reg [DEPTH_WIDTH-1:0] commit_id;
   wire retire_BVALID;
   reg retire_BREADY;
   wire retire_rd_we;
   wire [`NCPU_REG_AW-1:0] retire_rd_addr;
   wire [`NCPU_DW-1:0] retire_BDATA;
   wire [TAG_WIDTH-1:0] retire_BTAG;

   ncpu32k_rob
      #(
         .DEPTH_WIDTH            (DEPTH_WIDTH),
         .TAG_WIDTH              (TAG_WIDTH)
      )
   ROB
      (
         .clk                    (clk),
         .rst_n                  (rst_n),
         .i_flush_req            (flush_req),
         .i_issue_AVALID         (issue_AVALID),
         .o_issue_AREADY         (issue_AREADY),
         .i_issue_rd_we          (issue_rd_we),
         .i_issue_rd_addr        (issue_rd_addr),
         .i_issue_rs1_addr       (issue_rs1_addr),
         .i_issue_rs2_addr       (issue_rs2_addr),
         .o_issue_rs1_from_ROB   (issue_rs1_from_ROB),
         .o_issue_rs1_in_ARF     (issue_rs1_in_ARF),
         .o_issue_rs1_dat        (issue_rs1_dat),
         .o_issue_rs2_from_ROB   (issue_rs2_from_ROB),
         .o_issue_rs2_in_ARF     (issue_rs2_in_ARF),
         .o_issue_rs2_dat        (issue_rs2_dat),
         .o_issue_id             (issue_id),
         .o_commit_BREADY        (commit_BREADY),
         .i_commit_BVALID        (commit_BVALID),
         .i_commit_BDATA         (commit_BDATA),
         .i_commit_BTAG          (commit_BTAG),
         .i_commit_id            (commit_id),
         .o_retire_BVALID        (retire_BVALID),
         .i_retire_BREADY        (retire_BREADY),
         .o_retire_rd_we         (retire_rd_we),
         .o_retire_rd_addr       (retire_rd_addr),
         .o_retire_BDATA         (retire_BDATA),
         .o_retire_BTAG          (retire_BTAG)
      );

   initial forever #10 clk = ~clk;
   initial #5 rst_n = 1'b1;

   task handshake_issue;
      begin
         @(posedge clk);
         if (~issue_AREADY | ~issue_AVALID)
            $fatal($time);
      end
   endtask
   task handshake_commit;
      begin
         @(posedge clk);
         if (~commit_BREADY | ~commit_BVALID)
            $fatal($time);
      end
   endtask
   task handshake_retire;
      begin
         @(posedge clk);
         if (~retire_BREADY | ~retire_BVALID)
            $fatal($time);
      end
   endtask

   initial
      begin
         flush_req = 1'b0;
         issue_AVALID = 1'b0;
         commit_BVALID = 1'b0;
         retire_BREADY = 1'b0;
         @(posedge clk);

         ///////////////////////////////////////////////////////////////////////
         // Testcase - Bypass from CDB
         ///////////////////////////////////////////////////////////////////////

         //
         // Issue #1
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h4;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd0)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join

         if (retire_BVALID)
            $fatal($time);

         //
         // Issue #2
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h3;
               issue_rs1_addr = 5'h5;
               issue_rs2_addr = 5'h6;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (issue_id != 2'd1)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join
         
         if (retire_BVALID)
            $fatal($time);
         
         //
         // Issue #3 - not write
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b0;
               issue_rd_addr = 5'h3;
               issue_rs1_addr = 5'h6;
               issue_rs2_addr = 5'h7;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (issue_id != 2'd2)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join
         
         if (retire_BVALID)
            $fatal($time);
         
         fork
            begin
               //
               // Commit #2
               //
               commit_BVALID = 1'b1;
               commit_BDATA = 32'hdad;
               commit_BTAG = 4'h2;
               commit_id = 2'd1;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               commit_BVALID = 1'b0;
               if (retire_BVALID)
                  $fatal($time);
            end
            begin
               //
               // Issue #4 - RAW #2
               //
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h4;
               issue_rs1_addr = 5'h3; // rd of #2
               issue_rs2_addr = 5'h9;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (issue_id != 2'd3)
                  $fatal($time);
               if (~issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join
         
         issue_AVALID = 1'b0;
         
         // Now queue is full
         @(posedge clk);
         if (issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
         
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Pipelined commit and retire
         ///////////////////////////////////////////////////////////////////////
         fork
            begin
               commit_BVALID = 1'b1;
               
               //
               // Commit #1
               //
               commit_BDATA = 32'h123;
               commit_BTAG = 4'h1;
               commit_id = 2'd0;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #3
               //
               commit_BDATA = 32'h321;
               commit_BTAG = 4'h3;
               commit_id = 2'd2;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #4
               //
               commit_BDATA = 32'h542;
               commit_BTAG = 4'h4;
               commit_id = 2'd3;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               
               commit_BVALID = 1'b0;

            end
            begin
               // Wait the first commit
               @(posedge clk);
               
               retire_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_retire;
               if (retire_BDATA != 32'h123)
                  $fatal($time);
               if (retire_BTAG != 4'h1)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #2
               //
               handshake_retire;
               if (retire_BDATA != 32'hdad)
                  $fatal($time);
               if (retire_BTAG != 4'h2)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h3)
                  $fatal($time);
                  
               //
               // Retire #3
               //
               handshake_retire;
               if (retire_BDATA != 32'h321)
                  $fatal($time);
               if (retire_BTAG != 4'h3)
                  $fatal($time);
               if (retire_rd_we != 1'b0)
                  $fatal($time);
               if (retire_rd_addr != 5'h3)
                  $fatal($time);
                  
               //
               // Retire #4
               //
               handshake_retire;
               if (retire_BDATA != 32'h542)
                  $fatal($time);
               if (retire_BTAG != 4'h4)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h4)
                  $fatal($time);
                  
               retire_BREADY = 1'b0;
            end
         join

         // Now queue is empty
         @(posedge clk);
         if (issue_id != 2'd0)
            $fatal($time);
         if (~issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Wrap around and read operands from ROB
         ///////////////////////////////////////////////////////////////////////
         
         //
         // Issue #1
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h4;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd0)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join

         if (retire_BVALID)
            $fatal($time);
            
         //
         // Issue #2
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h4;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd1)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join

         if (retire_BVALID)
            $fatal($time);
            
         //
         // Issue #3
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b1;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h4;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd2)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join

         if (retire_BVALID)
            $fatal($time);
            
         //
         // Issue #4 - not write
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b0;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h4;
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd3)
                  $fatal($time);
               if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                  $fatal($time);
            end
         join
         
         issue_AVALID = 1'b0;

         if (retire_BVALID)
            $fatal($time);
       
         //
         // Commit #1
         //
         commit_BVALID = 1'b1;
         commit_BDATA = 32'hff643;
         commit_BTAG = 4'h1;
         commit_id = 2'd0;
         if (~commit_BREADY)
            $fatal($time);
         handshake_commit;
         commit_BVALID = 1'b0;
         
         //
         // Retire #1
         //
         @(posedge clk); // Test delayed handshake
         retire_BREADY = 1'b1;
         if (~retire_BVALID)
            $fatal($time);
         handshake_retire;
         if (retire_BDATA != 32'hff643)
            $fatal($time);
         if (retire_BTAG != 4'h1)
            $fatal($time);
         if (retire_rd_we != 1'b1)
            $fatal($time);
         if (retire_rd_addr != 5'h2)
            $fatal($time);
         retire_BREADY = 1'b0;
         @(posedge clk);
         
         
         //
         // Commit #4
         //
         commit_BVALID = 1'b1;
         commit_BDATA = 32'h88eef;
         commit_BTAG = 4'h4;
         commit_id = 2'd3;
         if (~commit_BREADY)
            $fatal($time);
         handshake_commit;
         commit_BVALID = 1'b0;
         
         // Peek if issuing of #5 is right
         issue_AVALID = 1'b0;
         issue_rd_we = 1'b0;
         issue_rd_addr = 5'h2;
         issue_rs1_addr = 5'h3;
         issue_rs2_addr = 5'h2; // = rd of #3
         if (~issue_AREADY)
            $fatal($time);
         @(posedge clk);
         if (issue_rs1_from_ROB | issue_rs2_from_ROB)
            $fatal($time);
         if (~issue_rs1_in_ARF | issue_rs2_in_ARF)
            $fatal($time);
         
         
         //
         // Commit #3
         //
         
         // Peek if issuing of #5 is right
         issue_AVALID = 1'b0;
         issue_rd_we = 1'b0;
         issue_rd_addr = 5'h2;
         issue_rs1_addr = 5'h3;
         issue_rs2_addr = 5'h2; // = rd of #3
         if (~issue_AREADY)
            $fatal($time);
         @(posedge clk);
         if (issue_rs1_from_ROB | issue_rs2_from_ROB)
            $fatal($time);
         if (~issue_rs1_in_ARF | issue_rs2_in_ARF)
            $fatal($time);
         
         commit_BVALID = 1'b1;
         commit_BDATA = 32'h64eef;
         commit_BTAG = 4'h5;
         commit_id = 2'd2;
         if (~commit_BREADY)
            $fatal($time);
         handshake_commit;
         commit_BVALID = 1'b0;
           
         //
         // Issue #5 - RAW #3
         //
         fork
            begin
               issue_AVALID = 1'b1;
               issue_rd_we = 1'b0;
               issue_rd_addr = 5'h2;
               issue_rs1_addr = 5'h3;
               issue_rs2_addr = 5'h2; // = rd of #3
               if (~issue_AREADY)
                  $fatal($time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (issue_id != 2'd0) // Wrap around
                  $fatal($time);
               if (issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                  $fatal($time);
               if (~issue_rs1_in_ARF | issue_rs2_in_ARF)
                  $fatal($time);
               if (issue_rs2_dat != 32'h64eef)
                  $fatal($time);
            end
         join
         
         issue_AVALID = 1'b0;

         // Now the queue is full
         @(posedge clk);
         if (issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Flush. Pipelined read and bypass. Pipelined retire.
         //             Wrap around.
         ///////////////////////////////////////////////////////////////////////
         
         @(posedge clk);
         flush_req = 1'b1;
         @(posedge clk);
         // Now the queue is empty
         flush_req = 1'b0;
         @(posedge clk);
         if (~issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
         
         fork
            begin
               issue_AVALID = 1'b1;
               
               //
               // Issue #1
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd0)
                        $fatal($time);
                     if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                        $fatal($time);
                     if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                        $fatal($time);
                  end
               join
               //
               // Issue #2
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd1)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h123)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h123)
                        $fatal($time);
                  end
               join
               //
               // Issue #3
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd2)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h321)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h321)
                        $fatal($time);
                  end
               join
               //
               // Issue #4
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd3)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h542)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h542)
                        $fatal($time);
                  end
               join
               //
               // Issue #5 - Wrap around
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd0)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h245)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h245)
                        $fatal($time);
                  end
               join
               //
               // Issue #6 - Wrap around
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd1)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h555)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h555)
                        $fatal($time);
                  end
               join
               
               issue_AVALID = 1'b0;
            end
            begin
               @(posedge clk); // Wait for the first issue
               commit_BVALID = 1'b1;
               
               //
               // Commit #1
               //
               commit_BDATA = 32'h123;
               commit_BTAG = 4'h1;
               commit_id = 2'd0;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #2
               //
               commit_BDATA = 32'h321;
               commit_BTAG = 4'h2;
               commit_id = 2'd1;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #3
               //
               commit_BDATA = 32'h542;
               commit_BTAG = 4'h3;
               commit_id = 2'd2;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #4
               //
               commit_BDATA = 32'h245;
               commit_BTAG = 4'h4;
               commit_id = 2'd3;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #5
               //
               commit_BDATA = 32'h555;
               commit_BTAG = 4'h5;
               commit_id = 2'd0;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               //
               // Commit #6
               //
               commit_BDATA = 32'h666;
               commit_BTAG = 4'h6;
               commit_id = 2'd1;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               
               commit_BVALID = 1'b0;

            end
            begin
               @(posedge clk); // Wait for the first issue
               @(posedge clk); // Wait the first commit
               
               retire_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_retire;
               if (retire_BDATA != 32'h123)
                  $fatal($time);
               if (retire_BTAG != 4'h1)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #2
               //
               handshake_retire;
               if (retire_BDATA != 32'h321)
                  $fatal($time);
               if (retire_BTAG != 4'h2)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #3
               //
               handshake_retire;
               if (retire_BDATA != 32'h542)
                  $fatal($time);
               if (retire_BTAG != 4'h3)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #4
               //
               handshake_retire;
               if (retire_BDATA != 32'h245)
                  $fatal($time);
               if (retire_BTAG != 4'h4)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #5
               //
               handshake_retire;
               if (retire_BDATA != 32'h555)
                  $fatal($time);
               if (retire_BTAG != 4'h5)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
                  
               //
               // Retire #6
               //
               handshake_retire;
               if (retire_BDATA != 32'h666)
                  $fatal($time);
               if (retire_BTAG != 4'h6)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
               
               retire_BREADY = 1'b0;
            end
         join

         // Now the queue is empty
         @(posedge clk);
         if (~issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Operand not ready. Wrap around.
         ///////////////////////////////////////////////////////////////////////
         
         fork
            begin
               issue_AVALID = 1'b1;
               
               //
               // Issue #1
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd2)
                        $fatal($time);
                     if (issue_rs1_from_ROB | issue_rs2_from_ROB)
                        $fatal($time);
                     if (~issue_rs1_in_ARF | ~issue_rs2_in_ARF)
                        $fatal($time);
                  end
               join
               //
               // Issue #2
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd3)
                        $fatal($time);
                     if (~issue_rs1_from_ROB | ~issue_rs2_from_ROB)
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                     if (issue_rs1_dat != 32'h123)
                        $fatal($time);
                     if (issue_rs2_dat != 32'h123)
                        $fatal($time);
                  end
               join
               //
               // Issue #3
               //
               fork
                  begin
                     issue_rd_we = 1'b1;
                     issue_rd_addr = 5'h2;
                     issue_rs1_addr = 5'h2;
                     issue_rs2_addr = 5'h2;
                     if (~issue_AREADY)
                        $fatal($time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (issue_id != 2'd0) // Wrap around
                        $fatal($time);
                     if (issue_rs1_from_ROB | issue_rs2_from_ROB) // not ready
                        $fatal($time);
                     if (issue_rs1_in_ARF | issue_rs2_in_ARF)
                        $fatal($time);
                  end
               join
               
               
               issue_AVALID = 1'b0;
            end
            begin
               @(posedge clk); // Wait for the first issue
               commit_BVALID = 1'b1;
               
               //
               // Commit #1
               //
               commit_BVALID = 1'b1;
               commit_BDATA = 32'h123;
               commit_BTAG = 4'h1;
               commit_id = 2'd2;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               commit_BVALID = 1'b0;
               
               @(posedge clk); // Delay 1 clk
               
               //
               // Commit #2
               //
               commit_BVALID = 1'b1;
               commit_BDATA = 32'h321;
               commit_BTAG = 4'h2;
               commit_id = 2'd3;
               if (~commit_BREADY)
                  $fatal($time);
               handshake_commit;
               commit_BVALID = 1'b0;
               
            end
            begin
               @(posedge clk); // Wait for the first issue
               @(posedge clk); // Wait the first commit
               
               retire_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_retire;
               if (retire_BDATA != 32'h123)
                  $fatal($time);
               if (retire_BTAG != 4'h1)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
               retire_BREADY = 1'b0;
                  
               @(posedge clk); // Wait #2 to be committed
                  
               //
               // Retire #2
               //
               retire_BREADY = 1'b1;
               handshake_retire;
               if (retire_BDATA != 32'h321)
                  $fatal($time);
               if (retire_BTAG != 4'h2)
                  $fatal($time);
               if (retire_rd_we != 1'b1)
                  $fatal($time);
               if (retire_rd_addr != 5'h2)
                  $fatal($time);
               
               retire_BREADY = 1'b0;
               
            end
         join

         @(posedge clk);
         flush_req = 1'b1;
         @(posedge clk);
         // Now the queue is empty
         flush_req = 1'b0;
         @(posedge clk);
         if (~issue_AREADY)
            $fatal($time);
         if (retire_BVALID)
            $fatal($time);
         
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
         
      end

endmodule
