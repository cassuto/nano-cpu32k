module dram #(
   parameter DRAM_AW = 16
)
(
   input clk,
   input rst,
   output reg [63:0] o_dat,
   input reg [63:0] i_dat,
   input [7:0] i_we,
   input i_re,
   input [DRAM_AW-1:0] i_addr
);

   reg [63:0] dmem[1<<DRAM_AW];
   
   always @(posedge clk)
      begin
         if (rst)
            o_dat <= 'b0;
         else if (|i_we)
            begin
               if (i_we[0])
                  dmem[i_addr][7:0] <= i_dat[7:0];
               if (i_we[1])
                  dmem[i_addr][15:8] <= i_dat[15:8];
               if (i_we[2])
                  dmem[i_addr][23:16] <= i_dat[23:16];
               if (i_we[3])
                  dmem[i_addr][31:24] <= i_dat[31:24];
               if (i_we[4])
                  dmem[i_addr][39:32] <= i_dat[39:32];
               if (i_we[5])
                  dmem[i_addr][47:40] <= i_dat[47:40];
               if (i_we[6])
                  dmem[i_addr][55:48] <= i_dat[55:48];
               if (i_we[7])
                  dmem[i_addr][63:56] <= i_dat[63:56];
            end
         else if (i_re)
            o_dat <= dmem[i_addr];
      end

endmodule
