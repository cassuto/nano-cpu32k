`include "timescale.v"
`include "ncpu32k_config.h"

module tb_rob;

   localparam DEPTH_WIDTH = 2;
   localparam TAG_WIDTH = 4;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg flush;
   reg disp_AVALID;
   wire disp_AREADY;
   reg [`NCPU_AW-3:0] disp_pc;
   reg [`NCPU_AW-3:0] disp_pred_tgt;
   reg disp_rd_we;
   reg [`NCPU_REG_AW-1:0] disp_rd_addr;
   reg [`NCPU_REG_AW-1:0] disp_rs1_addr;
   reg [`NCPU_REG_AW-1:0] disp_rs2_addr;
   wire disp_rs1_in_ROB;
   wire disp_rs1_in_ARF;
   wire [`NCPU_DW-1:0] disp_rs1_dat;
   wire disp_rs2_in_ROB;
   wire disp_rs2_in_ARF;
   wire [`NCPU_DW-1:0] disp_rs2_dat;
   wire [DEPTH_WIDTH-1:0] disp_id;
   wire wb_BREADY;
   reg wb_BVALID;
   reg [`NCPU_DW-1:0] wb_BDATA;
   reg [TAG_WIDTH-1:0] wb_BTAG;
   reg [DEPTH_WIDTH-1:0] wb_id;
   wire commit_BVALID;
   reg commit_BREADY;
   wire commit_rd_we;
   wire [`NCPU_REG_AW-1:0] commit_rd_addr;
   wire [`NCPU_DW-1:0] commit_BDATA;
   wire [TAG_WIDTH-1:0] commit_BTAG;
   wire byp_rd_we;
   wire [`NCPU_REG_AW-1:0] byp_rd_addr;

   ncpu32k_rob
      #(
         .DEPTH_WIDTH               (DEPTH_WIDTH),
         .TAG_WIDTH                 (TAG_WIDTH)
      )
   ROB
      (
         .clk                       (clk),
         .rst_n                     (rst_n),
         .flush                     (flush),
         .rob_disp_AVALID           (disp_AVALID),
         .rob_disp_AREADY           (disp_AREADY),
         .rob_disp_pc               (disp_pc),
         .rob_disp_pred_tgt         (disp_pred_tgt),
         .rob_disp_rd_we            (disp_rd_we),
         .rob_disp_rd_addr          (disp_rd_addr),
         .rob_disp_rs1_addr         (disp_rs1_addr),
         .rob_disp_rs2_addr         (disp_rs2_addr),
         .rob_disp_rs1_in_ROB       (disp_rs1_in_ROB),
         .rob_disp_rs1_in_ARF       (disp_rs1_in_ARF),
         .rob_disp_rs1_dat          (disp_rs1_dat),
         .rob_disp_rs2_in_ROB       (disp_rs2_in_ROB),
         .rob_disp_rs2_in_ARF       (disp_rs2_in_ARF),
         .rob_disp_rs2_dat          (disp_rs2_dat),
         .rob_disp_id               (disp_id),
         .rob_wb_BREADY             (wb_BREADY),
         .rob_wb_BVALID             (wb_BVALID),
         .rob_wb_BDATA              (wb_BDATA),
         .rob_wb_BTAG               (wb_BTAG),
         .rob_wb_id                 (wb_id),
         .byp_rd_we                 (byp_rd_we),
         .byp_rd_addr               (byp_rd_addr),
         .rob_commit_BVALID         (commit_BVALID),
         .rob_commit_BREADY         (commit_BREADY),
         .rob_commit_pc             (),
         .rob_commit_pred_tgt       (),
         .rob_commit_rd_we          (commit_rd_we),
         .rob_commit_rd_addr        (commit_rd_addr),
         .rob_commit_BDATA          (commit_BDATA),
         .rob_commit_BTAG           (commit_BTAG),
         .rob_commit_ptr            ()
      );

   initial forever #10 clk = ~clk;
   initial #5 rst_n = 1'b1;

   task handshake_issue;
      begin
         @(posedge clk);
         if (~disp_AREADY | ~disp_AVALID)
            $fatal(1, $time);
      end
   endtask
   task handshake_wb;
      begin
         @(posedge clk);
         if (~wb_BREADY | ~wb_BVALID)
            $fatal(1, $time);
      end
   endtask
   task handshake_commit;
      begin
         @(posedge clk);
         if (~commit_BREADY | ~commit_BVALID)
            $fatal(1, $time);
      end
   endtask

   initial
      begin
         flush = 1'b0;
         disp_AVALID = 1'b0;
         disp_pc = {`NCPU_AW-2{1'b0}};
         disp_pred_tgt = {`NCPU_AW-2{1'b0}};
         wb_BVALID = 1'b0;
         commit_BREADY = 1'b0;
         @(posedge clk);

         ///////////////////////////////////////////////////////////////////////
         // Testcase - Bypass from BYP
         ///////////////////////////////////////////////////////////////////////

         //
         // Dispatch #1
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h4;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd0)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join

         if (commit_BVALID)
            $fatal(1, $time);

         //
         // Dispatch #2
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h3;
               disp_rs1_addr = 5'h5;
               disp_rs2_addr = 5'h6;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (disp_id !== 2'd1)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join
         
         if (commit_BVALID)
            $fatal(1, $time);
         
         //
         // Dispatch #3 - not write
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b0;
               disp_rd_addr = 5'h3;
               disp_rs1_addr = 5'h6;
               disp_rs2_addr = 5'h7;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (disp_id !== 2'd2)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join
         
         if (commit_BVALID)
            $fatal(1, $time);
         
         fork
            begin
               //
               // Writeback #2
               //
               wb_BVALID = 1'b1;
               wb_BDATA = 32'hdad;
               wb_BTAG = 4'h2;
               wb_id = 2'd1;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               wb_BVALID = 1'b0;
               if (commit_BVALID)
                  $fatal(1, $time);
               if (byp_rd_addr !== 5'h3 || byp_rd_we !== 1'b1)
                  $fatal(1, $time);
            end
            begin
               //
               // Dispatch #4 - RAW #2
               //
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h4;
               disp_rs1_addr = 5'h3; // rd of #2
               disp_rs2_addr = 5'h9;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk);
               if (disp_id !== 2'd3)
                  $fatal(1, $time);
               if (~disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join
         
         disp_AVALID = 1'b0;
         
         // Now queue is full
         @(posedge clk);
         if (disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
         
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Pipelined wb and commit
         ///////////////////////////////////////////////////////////////////////
         fork
            begin
               wb_BVALID = 1'b1;
               
               //
               // Writeback #1
               //
               wb_BDATA = 32'h123;
               wb_BTAG = 4'h1;
               wb_id = 2'd0;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #3
               //
               wb_BDATA = 32'h321;
               wb_BTAG = 4'h3;
               wb_id = 2'd2;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               if (byp_rd_addr !== 5'h3 || byp_rd_we !== 1'b0)
                  $fatal(1, $time);
               //
               // Writeback #4
               //
               wb_BDATA = 32'h542;
               wb_BTAG = 4'h4;
               wb_id = 2'd3;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               
               wb_BVALID = 1'b0;

            end
            begin
               // Wait the first wb
               @(posedge clk);
               
               commit_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_commit;
               if (commit_BDATA !== 32'h123)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h1)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #2
               //
               handshake_commit;
               if (commit_BDATA !== 32'hdad)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h2)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h3)
                  $fatal(1, $time);
                  
               //
               // Retire #3
               //
               handshake_commit;
               if (commit_BDATA !== 32'h321)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h3)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b0)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h3)
                  $fatal(1, $time);
                  
               //
               // Retire #4
               //
               handshake_commit;
               if (commit_BDATA !== 32'h542)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h4)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h4)
                  $fatal(1, $time);
                  
               commit_BREADY = 1'b0;
            end
         join

         // Now queue is empty
         @(posedge clk);
         if (disp_id !== 2'd0)
            $fatal(1, $time);
         if (~disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Wrap around and read operands from ROB
         ///////////////////////////////////////////////////////////////////////
         
         //
         // Dispatch #1
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h4;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd0)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join

         if (commit_BVALID)
            $fatal(1, $time);
            
         //
         // Dispatch #2
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h4;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd1)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join

         if (commit_BVALID)
            $fatal(1, $time);
            
         //
         // Dispatch #3
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b1;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h4;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd2)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join

         if (commit_BVALID)
            $fatal(1, $time);
            
         //
         // Dispatch #4 - not write
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b0;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h4;
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd3)
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                  $fatal(1, $time);
            end
         join
         
         disp_AVALID = 1'b0;

         if (commit_BVALID)
            $fatal(1, $time);
       
         //
         // Writeback #1
         //
         wb_BVALID = 1'b1;
         wb_BDATA = 32'hff643;
         wb_BTAG = 4'h1;
         wb_id = 2'd0;
         if (~wb_BREADY)
            $fatal(1, $time);
         handshake_wb;
         wb_BVALID = 1'b0;
         
         //
         // Retire #1
         //
         @(posedge clk); // Test delayed handshake
         commit_BREADY = 1'b1;
         if (~commit_BVALID)
            $fatal(1, $time);
         handshake_commit;
         if (commit_BDATA !== 32'hff643)
            $fatal(1, $time);
         if (commit_BTAG !== 4'h1)
            $fatal(1, $time);
         if (commit_rd_we !== 1'b1)
            $fatal(1, $time);
         if (commit_rd_addr !== 5'h2)
            $fatal(1, $time);
         commit_BREADY = 1'b0;
         @(posedge clk);
         
         
         //
         // Writeback #4
         //
         wb_BVALID = 1'b1;
         wb_BDATA = 32'h88eef;
         wb_BTAG = 4'h4;
         wb_id = 2'd3;
         if (~wb_BREADY)
            $fatal(1, $time);
         handshake_wb;
         wb_BVALID = 1'b0;
         
         // Peek if issuing of #5 is right
         disp_AVALID = 1'b0;
         disp_rd_we = 1'b0;
         disp_rd_addr = 5'h2;
         disp_rs1_addr = 5'h3;
         disp_rs2_addr = 5'h2; // = rd of #3
         if (~disp_AREADY)
            $fatal(1, $time);
         @(posedge clk);
         if (disp_rs1_in_ROB | disp_rs2_in_ROB)
            $fatal(1, $time);
         if (~disp_rs1_in_ARF | disp_rs2_in_ARF)
            $fatal(1, $time);
         
         
         //
         // Writeback #3
         //
         
         // Peek if issuing of #5 is right
         disp_AVALID = 1'b0;
         disp_rd_we = 1'b0;
         disp_rd_addr = 5'h2;
         disp_rs1_addr = 5'h3;
         disp_rs2_addr = 5'h2; // = rd of #3
         if (~disp_AREADY)
            $fatal(1, $time);
         @(posedge clk);
         if (disp_rs1_in_ROB | disp_rs2_in_ROB)
            $fatal(1, $time);
         if (~disp_rs1_in_ARF | disp_rs2_in_ARF)
            $fatal(1, $time);
         
         wb_BVALID = 1'b1;
         wb_BDATA = 32'h64eef;
         wb_BTAG = 4'h5;
         wb_id = 2'd2;
         if (~wb_BREADY)
            $fatal(1, $time);
         handshake_wb;
         wb_BVALID = 1'b0;
           
         //
         // Dispatch #5 - RAW #3
         //
         fork
            begin
               disp_AVALID = 1'b1;
               disp_rd_we = 1'b0;
               disp_rd_addr = 5'h2;
               disp_rs1_addr = 5'h3;
               disp_rs2_addr = 5'h2; // = rd of #3
               if (~disp_AREADY)
                  $fatal(1, $time);
               handshake_issue;
            end
            begin
               @(posedge clk)
               if (disp_id !== 2'd0) // Wrap around
                  $fatal(1, $time);
               if (disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                  $fatal(1, $time);
               if (~disp_rs1_in_ARF | disp_rs2_in_ARF)
                  $fatal(1, $time);
               if (disp_rs2_dat !== 32'h64eef)
                  $fatal(1, $time);
            end
         join
         
         disp_AVALID = 1'b0;

         // Now the queue is full
         @(posedge clk);
         if (disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Flush. Pipelined read and bypass. Pipelined commit.
         //             Wrap around.
         ///////////////////////////////////////////////////////////////////////
         
         @(posedge clk);
         flush = 1'b1;
         @(posedge clk);
         // Now the queue is empty
         flush = 1'b0;
         @(posedge clk);
         if (~disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
         
         fork
            begin
               disp_AVALID = 1'b1;
               
               //
               // Dispatch #1
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd0)
                        $fatal(1, $time);
                     if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #2
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd1)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h123)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h123)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #3
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd2)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h321)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h321)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #4
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd3)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h542)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h542)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #5 - Wrap around
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd0)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h245)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h245)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #6 - Wrap around
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd1)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h555)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h555)
                        $fatal(1, $time);
                  end
               join
               
               disp_AVALID = 1'b0;
            end
            begin
               @(posedge clk); // Wait for the first issue
               wb_BVALID = 1'b1;
               
               //
               // Writeback #1
               //
               wb_BDATA = 32'h123;
               wb_BTAG = 4'h1;
               wb_id = 2'd0;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #2
               //
               wb_BDATA = 32'h321;
               wb_BTAG = 4'h2;
               wb_id = 2'd1;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #3
               //
               wb_BDATA = 32'h542;
               wb_BTAG = 4'h3;
               wb_id = 2'd2;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #4
               //
               wb_BDATA = 32'h245;
               wb_BTAG = 4'h4;
               wb_id = 2'd3;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #5
               //
               wb_BDATA = 32'h555;
               wb_BTAG = 4'h5;
               wb_id = 2'd0;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               //
               // Writeback #6
               //
               wb_BDATA = 32'h666;
               wb_BTAG = 4'h6;
               wb_id = 2'd1;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               
               wb_BVALID = 1'b0;

            end
            begin
               @(posedge clk); // Wait for the first issue
               @(posedge clk); // Wait the first wb
               
               commit_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_commit;
               if (commit_BDATA !== 32'h123)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h1)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #2
               //
               handshake_commit;
               if (commit_BDATA !== 32'h321)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h2)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #3
               //
               handshake_commit;
               if (commit_BDATA !== 32'h542)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h3)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #4
               //
               handshake_commit;
               if (commit_BDATA !== 32'h245)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h4)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #5
               //
               handshake_commit;
               if (commit_BDATA !== 32'h555)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h5)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
                  
               //
               // Retire #6
               //
               handshake_commit;
               if (commit_BDATA !== 32'h666)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h6)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
               
               commit_BREADY = 1'b0;
            end
         join

         // Now the queue is empty
         @(posedge clk);
         if (~disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
            
         ///////////////////////////////////////////////////////////////////////
         // Testcase - Operand not ready. Wrap around.
         ///////////////////////////////////////////////////////////////////////
         
         fork
            begin
               disp_AVALID = 1'b1;
               
               //
               // Dispatch #1
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd2)
                        $fatal(1, $time);
                     if (disp_rs1_in_ROB | disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #2
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd3)
                        $fatal(1, $time);
                     if (~disp_rs1_in_ROB | ~disp_rs2_in_ROB)
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                     if (disp_rs1_dat !== 32'h123)
                        $fatal(1, $time);
                     if (disp_rs2_dat !== 32'h123)
                        $fatal(1, $time);
                  end
               join
               //
               // Dispatch #3
               //
               fork
                  begin
                     disp_rd_we = 1'b1;
                     disp_rd_addr = 5'h2;
                     disp_rs1_addr = 5'h2;
                     disp_rs2_addr = 5'h2;
                     if (~disp_AREADY)
                        $fatal(1, $time);
                     handshake_issue;
                  end
                  begin
                     @(posedge clk)
                     if (disp_id !== 2'd0) // Wrap around
                        $fatal(1, $time);
                     if (disp_rs1_in_ROB | disp_rs2_in_ROB) // not ready
                        $fatal(1, $time);
                     if (disp_rs1_in_ARF | disp_rs2_in_ARF)
                        $fatal(1, $time);
                  end
               join
               
               
               disp_AVALID = 1'b0;
            end
            begin
               @(posedge clk); // Wait for the first issue
               wb_BVALID = 1'b1;
               
               //
               // Writeback #1
               //
               wb_BVALID = 1'b1;
               wb_BDATA = 32'h123;
               wb_BTAG = 4'h1;
               wb_id = 2'd2;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               wb_BVALID = 1'b0;
               
               @(posedge clk); // Delay 1 clk
               
               //
               // Writeback #2
               //
               wb_BVALID = 1'b1;
               wb_BDATA = 32'h321;
               wb_BTAG = 4'h2;
               wb_id = 2'd3;
               if (~wb_BREADY)
                  $fatal(1, $time);
               handshake_wb;
               wb_BVALID = 1'b0;
               
            end
            begin
               @(posedge clk); // Wait for the first issue
               @(posedge clk); // Wait the first wb
               
               commit_BREADY = 1'b1;
               
               //
               // Retire #1
               //
               handshake_commit;
               if (commit_BDATA !== 32'h123)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h1)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
               commit_BREADY = 1'b0;
                  
               @(posedge clk); // Wait #2 to be wbted
                  
               //
               // Retire #2
               //
               commit_BREADY = 1'b1;
               handshake_commit;
               if (commit_BDATA !== 32'h321)
                  $fatal(1, $time);
               if (commit_BTAG !== 4'h2)
                  $fatal(1, $time);
               if (commit_rd_we !== 1'b1)
                  $fatal(1, $time);
               if (commit_rd_addr !== 5'h2)
                  $fatal(1, $time);
               
               commit_BREADY = 1'b0;
               
            end
         join

         @(posedge clk);
         flush = 1'b1;
         @(posedge clk);
         // Now the queue is empty
         flush = 1'b0;
         @(posedge clk);
         if (~disp_AREADY)
            $fatal(1, $time);
         if (commit_BVALID)
            $fatal(1, $time);
         
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
         
      end

endmodule
