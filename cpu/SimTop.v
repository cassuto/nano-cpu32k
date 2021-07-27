module SimTop(
    input         clock,
    input         reset,

    input  [63:0] io_logCtrl_log_begin,
    input  [63:0] io_logCtrl_log_end,
    input  [63:0] io_logCtrl_log_level,
    input         io_perfInfo_clean,
    input         io_perfInfo_dump,

    output        io_uart_out_valid,
    output [7:0]  io_uart_out_ch,
    output        io_uart_in_valid,
    input  [7:0]  io_uart_in_ch
  // ......
);
   localparam IRAM_AW = 62;
   localparam DRAM_AW = 64;

   // IRAM
   wire [IRAM_AW-1:0] iram_addr;
   wire iram_re;
   wire [31:0] iram_insn;
   // DRAM
   wire [DRAM_AW-1:0] dram_addr;
   wire [7:0] dram_we;
   wire dram_re;
   wire [63:0] dram_din;
   wire [63:0] dram_dout;
   wire [63:0] dram_wmask;

   cpu
      #(
         .IRAM_AW          (IRAM_AW),
         .DRAM_AW          (DRAM_AW)
      )
   CPU
      (
         .clk              (clock),
         .rst              (reset),

         .o_iram_addr      (iram_addr),
         .o_iram_re        (iram_re),
         .i_iram_insn      (iram_insn),

         .o_dram_addr      (dram_addr),
         .o_dram_we        (dram_we),
         .o_dram_re        (dram_re),
         .o_dram_din       (dram_din),
         .i_dram_dout      (dram_dout)
      );

   assign iram_insn = ram_read_helper(iram_re, {iram_addr,2'b00});

   assign dram_dout = ram_read_helper(dram_re, dram_addr);

   assign dram_wmask = { {8{dram_we[7]}},
                                {8{dram_we[6]}},
                                {8{dram_we[5]}},
                                {8{dram_we[4]}},
                                {8{dram_we[3]}},
                                {8{dram_we[2]}},
                                {8{dram_we[1]}},
                                {8{dram_we[0]}} };

   always @(posedge clock)
      begin
         ram_write_helper(dram_addr, dram_din, dram_wmask, |dram_we);
      end

endmodule
