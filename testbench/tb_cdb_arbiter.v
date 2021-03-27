
`include "ncpu32k_config.h"

module tb_cdb_arbiter;

   localparam WAYS = 4;
   localparam TAG_WIDTH = 4;
   localparam ID_WIDTH = 2;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg [WAYS-1:0]           fu_commit_BVALID;
   wire [WAYS-1:0]          fu_commit_BREADY;
   reg [WAYS*`NCPU_DW-1:0]  fu_commit_BDATA;
   reg [WAYS*TAG_WIDTH-1:0] fu_commit_BTAG;
   reg [WAYS*ID_WIDTH-1:0]  fu_commit_id;
   wire                     rob_commit_BVALID;
   reg                      rob_commit_BREADY;
   wire [`NCPU_DW-1:0]      rob_commit_BDATA;
   wire [TAG_WIDTH-1:0]     rob_commit_BTAG;
   wire [ID_WIDTH-1:0]      rob_commit_id;
   
   ncpu32k_cdb_arbiter
      #(
         .WAYS (WAYS),
         .TAG_WIDTH (TAG_WIDTH),
         .ID_WIDTH (ID_WIDTH)
      )
   CDB_ARBITER
      (
         .clk                 (clk),
         .rst_n               (rst_n),
         .fu_commit_BVALID    (fu_commit_BVALID),
         .fu_commit_BREADY    (fu_commit_BREADY),
         .fu_commit_BDATA     (fu_commit_BDATA),
         .fu_commit_BTAG      (fu_commit_BTAG),
         .fu_commit_id        (fu_commit_id),
         .rob_commit_BVALID   (rob_commit_BVALID),
         .rob_commit_BREADY   (rob_commit_BREADY),
         .rob_commit_BDATA    (rob_commit_BDATA),
         .rob_commit_BTAG     (rob_commit_BTAG),
         .rob_commit_id       (rob_commit_id)
      );

   initial forever #10 clk = ~clk;
   initial #5 rst_n = 1'b1;
   
   initial
      begin
         fu_commit_BVALID = 4'b0000;
         rob_commit_BREADY = 1'b0;
         fu_commit_BDATA = {WAYS*`NCPU_DW{1'b0}};
         fu_commit_BTAG = {WAYS*TAG_WIDTH{1'b0}};
         fu_commit_id = {WAYS*ID_WIDTH{1'b0}};
         
         // FU #1 and #3 send B-packet
         @(posedge clk)
            begin
               fu_commit_BVALID = 4'b0101;
               fu_commit_BDATA[(0+1)*`NCPU_DW-1: 0*`NCPU_DW] = 32'hbadbeef;
               fu_commit_BTAG[(0+1)*TAG_WIDTH-1: 0*TAG_WIDTH] = 4'h1;
               fu_commit_id[(0+1)*ID_WIDTH-1: 0*ID_WIDTH] = 2'h0;
               
               fu_commit_BDATA[(2+1)*`NCPU_DW-1: 2*`NCPU_DW] = 32'h741235;
               fu_commit_BTAG[(2+1)*TAG_WIDTH-1: 2*TAG_WIDTH] = 4'h3;
               fu_commit_id[(2+1)*ID_WIDTH-1: 2*ID_WIDTH] = 2'h2;
            end
         @(posedge clk)
            begin
               if (fu_commit_BREADY[0] | fu_commit_BREADY[0])
                  $fatal($time);
            end

         // ROB issues ready
         @(posedge clk)
            begin
               rob_commit_BREADY = 1'b1;
            end
            
         // Hand shake with FU #1
         @(posedge clk)
            begin
               if (~(fu_commit_BVALID[0] & rob_commit_BREADY))
                  $fatal($time);
               if (~(rob_commit_BVALID & rob_commit_BREADY))
                  $fatal($time);
               if (rob_commit_BDATA != 32'hbadbeef)
                  $fatal($time);
               if (rob_commit_BTAG != 4'h1)
                  $fatal($time);
               if (rob_commit_id != 4'h0)
                  $fatal($time);
            end
            
         // FU #3 and #4 send B-packet
         fu_commit_BVALID = 4'b1100;
         fu_commit_BDATA[(3+1)*`NCPU_DW-1: 3*`NCPU_DW] = 32'h333333;
         fu_commit_BTAG[(3+1)*TAG_WIDTH-1: 3*TAG_WIDTH] = 4'h4;
         fu_commit_id[(3+1)*ID_WIDTH-1: 3*ID_WIDTH] = 2'h3;
         
         // ROB clear ready
         rob_commit_BREADY = 1'b0;
         
         @(posedge clk)
            begin
               if (fu_commit_BREADY[2] | fu_commit_BREADY[2])
                  $fatal($time);
            end
            
         // ROB issues ready again
         rob_commit_BREADY = 1'b1;
         
         // Hand shake with FU #3
         @(posedge clk)
            begin
               if (~(fu_commit_BVALID[2] & rob_commit_BREADY))
                  $fatal($time);
               if (~(rob_commit_BVALID & rob_commit_BREADY))
                  $fatal($time);
               if (rob_commit_BDATA != 32'h741235)
                  $fatal($time);
               if (rob_commit_BTAG != 4'h3)
                  $fatal($time);
               if (rob_commit_id != 4'h2)
                  $fatal($time);
            end
         fu_commit_BVALID = 4'b1000;
         
         // Hand shake with FU #4
         @(posedge clk)
            begin
               if (~(fu_commit_BVALID[3] & rob_commit_BREADY))
                  $fatal($time);
               if (~(rob_commit_BVALID & rob_commit_BREADY))
                  $fatal($time);
               if (rob_commit_BDATA != 32'h333333)
                  $fatal($time);
               if (rob_commit_BTAG != 4'h4)
                  $fatal($time);
               if (rob_commit_id != 4'h3)
                  $fatal($time);
            end
         fu_commit_BVALID = 4'b0000;
         
         @(posedge clk);
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
      end
      
endmodule
