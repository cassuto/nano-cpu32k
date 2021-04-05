
`include "timescale.v"
`include "ncpu32k_config.h"

module tb_byp_arbiter;

   localparam WAYS = 4;
   localparam TAG_WIDTH = 4;
   localparam ID_WIDTH = 2;

   reg clk = 1'b0;
   reg rst_n = 1'b0;
   reg [WAYS-1:0]           fu_wb_BVALID;
   wire [WAYS-1:0]          fu_wb_BREADY;
   reg [WAYS*`NCPU_DW-1:0]  fu_wb_BDATA;
   reg [WAYS*TAG_WIDTH-1:0] fu_wb_BTAG;
   reg [WAYS*ID_WIDTH-1:0]  fu_wb_id;
   wire                     rob_wb_BVALID;
   reg                      rob_wb_BREADY;
   wire [`NCPU_DW-1:0]      rob_wb_BDATA;
   wire [TAG_WIDTH-1:0]     rob_wb_BTAG;
   wire [ID_WIDTH-1:0]      rob_wb_id;
   
   ncpu32k_byp_arbiter
      #(
         .WAYS (WAYS),
         .TAG_WIDTH (TAG_WIDTH),
         .ID_WIDTH (ID_WIDTH)
      )
   BYP_ARBITER
      (
         .clk                 (clk),
         .rst_n               (rst_n),
         .fu_wb_BVALID        (fu_wb_BVALID),
         .fu_wb_BREADY        (fu_wb_BREADY),
         .fu_wb_BDATA         (fu_wb_BDATA),
         .fu_wb_BTAG          (fu_wb_BTAG),
         .fu_wb_id            (fu_wb_id),
         .rob_wb_BVALID       (rob_wb_BVALID),
         .rob_wb_BREADY       (rob_wb_BREADY),
         .rob_wb_BDATA        (rob_wb_BDATA),
         .rob_wb_BTAG         (rob_wb_BTAG),
         .rob_wb_id           (rob_wb_id)
      );

   initial forever #10 clk = ~clk;
   initial #5 rst_n = 1'b1;
   
   initial
      begin
         fu_wb_BVALID = 4'b0000;
         rob_wb_BREADY = 1'b0;
         fu_wb_BDATA = {WAYS*`NCPU_DW{1'b0}};
         fu_wb_BTAG = {WAYS*TAG_WIDTH{1'b0}};
         fu_wb_id = {WAYS*ID_WIDTH{1'b0}};
         
         // FU #1 and #3 send B-packet
         @(posedge clk)
            begin
               fu_wb_BVALID = 4'b0101;
               fu_wb_BDATA[(0+1)*`NCPU_DW-1: 0*`NCPU_DW] = 32'hbadbeef;
               fu_wb_BTAG[(0+1)*TAG_WIDTH-1: 0*TAG_WIDTH] = 4'h1;
               fu_wb_id[(0+1)*ID_WIDTH-1: 0*ID_WIDTH] = 2'h0;
               
               fu_wb_BDATA[(2+1)*`NCPU_DW-1: 2*`NCPU_DW] = 32'h741235;
               fu_wb_BTAG[(2+1)*TAG_WIDTH-1: 2*TAG_WIDTH] = 4'h3;
               fu_wb_id[(2+1)*ID_WIDTH-1: 2*ID_WIDTH] = 2'h2;
            end
         @(posedge clk)
            begin
               if (fu_wb_BREADY[0] | fu_wb_BREADY[0])
                  $fatal(1, $time);
            end

         // ROB issues ready
         @(posedge clk)
            begin
               rob_wb_BREADY = 1'b1;
            end
            
         // Hand shake with FU #1
         @(posedge clk)
            begin
               if (~(fu_wb_BVALID[0] & rob_wb_BREADY))
                  $fatal(1, $time);
               if (~(rob_wb_BVALID & rob_wb_BREADY))
                  $fatal(1, $time);
               if (rob_wb_BDATA !== 32'hbadbeef)
                  $fatal(1, $time);
               if (rob_wb_BTAG !== 4'h1)
                  $fatal(1, $time);
               if (rob_wb_id !== 4'h0)
                  $fatal(1, $time);
            end
            
         // FU #3 and #4 send B-packet
         fu_wb_BVALID = 4'b1100;
         fu_wb_BDATA[(3+1)*`NCPU_DW-1: 3*`NCPU_DW] = 32'h333333;
         fu_wb_BTAG[(3+1)*TAG_WIDTH-1: 3*TAG_WIDTH] = 4'h4;
         fu_wb_id[(3+1)*ID_WIDTH-1: 3*ID_WIDTH] = 2'h3;
         
         // ROB clear ready
         rob_wb_BREADY = 1'b0;
         
         @(posedge clk)
            begin
               if (fu_wb_BREADY[2] | fu_wb_BREADY[2])
                  $fatal(1, $time);
            end
            
         // ROB issues ready again
         rob_wb_BREADY = 1'b1;
         
         // Hand shake with FU #3
         @(posedge clk)
            begin
               if (~(fu_wb_BVALID[2] & rob_wb_BREADY))
                  $fatal(1, $time);
               if (~(rob_wb_BVALID & rob_wb_BREADY))
                  $fatal(1, $time);
               if (rob_wb_BDATA !== 32'h741235)
                  $fatal(1, $time);
               if (rob_wb_BTAG !== 4'h3)
                  $fatal(1, $time);
               if (rob_wb_id !== 4'h2)
                  $fatal(1, $time);
            end
         fu_wb_BVALID = 4'b1000;
         
         // Hand shake with FU #4
         @(posedge clk)
            begin
               if (~(fu_wb_BVALID[3] & rob_wb_BREADY))
                  $fatal(1, $time);
               if (~(rob_wb_BVALID & rob_wb_BREADY))
                  $fatal(1, $time);
               if (rob_wb_BDATA !== 32'h333333)
                  $fatal(1, $time);
               if (rob_wb_BTAG !== 4'h4)
                  $fatal(1, $time);
               if (rob_wb_id !== 4'h3)
                  $fatal(1, $time);
            end
         fu_wb_BVALID = 4'b0000;
         
         @(posedge clk);
         $display("===============================");
         $display(" PASS !");
         $display("===============================");
         $finish();
      end
      
endmodule
