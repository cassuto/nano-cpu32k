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

   wire rst;
   reg [3:0] rst_rr;
   // IRAM
   wire [IRAM_AW-1:0] iram_addr;
   wire iram_re;
   reg [31:0] iram_insn;
   reg iram_valid;
   // DRAM
   wire [DRAM_AW-1:0] dram_addr;
   wire [7:0] dram_we;
   wire dram_re;
   wire [63:0] dram_din;
   reg [63:0] dram_dout;
   wire [63:0] dram_wmask;
   // Debug
   wire wb_i_valid;
   wire [63:0] wb_i_pc;
   wire [31:0] wb_i_insn;
   wire [4:0] wb_i_rd;
   wire wb_i_rf_we;
   wire [63:0] wb_i_rd_dat;
   wire [63:0] rf_regs [31:0];

   // Delayed reset
   initial
      rst_rr = 4'b1111;
   always @(posedge clock)
      rst_rr <= {rst_rr[2:0], reset};
   assign rst = rst_rr[3];

   cpu
      #(
         .IRAM_AW          (IRAM_AW),
         .DRAM_AW          (DRAM_AW)
      )
   CPU
      (
         .clk              (clock),
         .rst              (rst),

         .o_iram_addr      (iram_addr),
         .o_iram_re        (iram_re),
         .i_iram_insn      (iram_insn),
         .i_iram_valid     (iram_valid),

         .o_dram_addr      (dram_addr),
         .o_dram_we        (dram_we),
         .o_dram_re        (dram_re),
         .o_dram_din       (dram_din),
         .i_dram_dout      (dram_dout),

         .wb_i_valid       (wb_i_valid),
         .wb_i_pc          (wb_i_pc),
         .wb_i_insn        (wb_i_insn),
         .wb_i_rd          (wb_i_rd),
         .wb_i_rf_we       (wb_i_rf_we),
         .wb_i_rd_dat      (wb_i_rd_dat),
         .rf_regs          (rf_regs)
      );

   //
   // Difftest RAM
   //

   assign dram_wmask = { {8{dram_we[7]}},
                                {8{dram_we[6]}},
                                {8{dram_we[5]}},
                                {8{dram_we[4]}},
                                {8{dram_we[3]}},
                                {8{dram_we[2]}},
                                {8{dram_we[1]}},
                                {8{dram_we[0]}} };

   wire [63:0] iram_dout_64b = ram_read_helper(iram_re, ({iram_addr,2'b00}-64'h80000000) >> 3);

   always @(posedge clock)
      if (rst)
         begin
            iram_valid <= 'b0;
         end
      else
         begin
            iram_valid <= iram_re;
            
            if (iram_re)
               iram_insn <= iram_addr[0] ? iram_dout_64b[63:32] : iram_dout_64b[31:0];

            ram_write_helper((dram_addr-64'h80000000) >> 3, dram_din, dram_wmask, |dram_we);
         end

   assign dram_dout = ram_read_helper(dram_re, (dram_addr-64'h80000000) >> 3);

   //
   // Difftest
   //

   reg diff_valid_r;
   reg [63:0] diff_pc_r;
   reg [31:0] diff_insn_r;
   reg diff_wen_r;
   reg [7:0] diff_wdest_r;
   reg [63:0] diff_wdata_r;
   reg [63:0] cycle_cnt_r;
   reg [63:0] instr_cnt_r;

   always @(posedge clock)
      if (rst)
         begin
            diff_valid_r <= 1'b0;
         end
      else
         begin
            diff_valid_r <= wb_i_valid;
            diff_pc_r <= wb_i_pc;
            diff_insn_r <= wb_i_insn;
            diff_wen_r <= wb_i_rf_we & (|wb_i_rd);
            diff_wdest_r <= {3'b0, wb_i_rd[4:0]};
            diff_wdata_r <= wb_i_rd_dat;

            if (wb_i_valid)
               instr_cnt_r <= instr_cnt_r + 'b1;
            cycle_cnt_r <= cycle_cnt_r + 'b1;
         end

   DifftestInstrCommit inst_commit(
      .clock         (clock),
      .coreid        (8'd0),
      .index         (8'd0),
      .valid         (diff_valid_r),
      .pc            (diff_pc_r),
      .instr         (diff_insn_r),
      .skip          (1'b0),
      .isRVC         (1'b0),
      .scFailed      (1'b0),
      .wen           (diff_wen_r),
      .wdest         (diff_wdest_r),
      .wdata         (diff_wdata_r)
   );

   DifftestArchIntRegState DifftestArchIntRegState (
      .clock              (clock),
      .coreid             (8'd0),
      .gpr_0              (rf_regs[0]),
      .gpr_1              (rf_regs[1]),
      .gpr_2              (rf_regs[2]),
      .gpr_3              (rf_regs[3]),
      .gpr_4              (rf_regs[4]),
      .gpr_5              (rf_regs[5]),
      .gpr_6              (rf_regs[6]),
      .gpr_7              (rf_regs[7]),
      .gpr_8              (rf_regs[8]),
      .gpr_9              (rf_regs[9]),
      .gpr_10             (rf_regs[10]),
      .gpr_11             (rf_regs[11]),
      .gpr_12             (rf_regs[12]),
      .gpr_13             (rf_regs[13]),
      .gpr_14             (rf_regs[14]),
      .gpr_15             (rf_regs[15]),
      .gpr_16             (rf_regs[16]),
      .gpr_17             (rf_regs[17]),
      .gpr_18             (rf_regs[18]),
      .gpr_19             (rf_regs[19]),
      .gpr_20             (rf_regs[20]),
      .gpr_21             (rf_regs[21]),
      .gpr_22             (rf_regs[22]),
      .gpr_23             (rf_regs[23]),
      .gpr_24             (rf_regs[24]),
      .gpr_25             (rf_regs[25]),
      .gpr_26             (rf_regs[26]),
      .gpr_27             (rf_regs[27]),
      .gpr_28             (rf_regs[28]),
      .gpr_29             (rf_regs[29]),
      .gpr_30             (rf_regs[30]),
      .gpr_31             (rf_regs[31])
   );

   DifftestTrapEvent DifftestTrapEvent(
      .clock              (clock),
      .coreid             (8'd0),
      .valid              (diff_insn_r[6:0] == 7'h6b),
      .code               (rf_regs[10][7:0]),
      .pc                 (diff_pc_r),
      .cycleCnt           (cycle_cnt_r),
      .instrCnt           (instr_cnt_r)
      );

   DifftestCSRState DifftestCSRState(
      .clock              (clock),
      .coreid             (0),
      .priviledgeMode     (0),
      .mstatus            (0),
      .sstatus            (0),
      .mepc               (0),
      .sepc               (0),
      .mtval              (0),
      .stval              (0),
      .mtvec              (0),
      .stvec              (0),
      .mcause             (0),
      .scause             (0),
      .satp               (0),
      .mip                (0),
      .mie                (0),
      .mscratch           (0),
      .sscratch           (0),
      .mideleg            (0),
      .medeleg            (0)
   );

   DifftestArchFpRegState DifftestArchFpRegState(
      .clock              (clock),
      .coreid             (0),
      .fpr_0              (0),
      .fpr_1              (0),
      .fpr_2              (0),
      .fpr_3              (0),
      .fpr_4              (0),
      .fpr_5              (0),
      .fpr_6              (0),
      .fpr_7              (0),
      .fpr_8              (0),
      .fpr_9              (0),
      .fpr_10             (0),
      .fpr_11             (0),
      .fpr_12             (0),
      .fpr_13             (0),
      .fpr_14             (0),
      .fpr_15             (0),
      .fpr_16             (0),
      .fpr_17             (0),
      .fpr_18             (0),
      .fpr_19             (0),
      .fpr_20             (0),
      .fpr_21             (0),
      .fpr_22             (0),
      .fpr_23             (0),
      .fpr_24             (0),
      .fpr_25             (0),
      .fpr_26             (0),
      .fpr_27             (0),
      .fpr_28             (0),
      .fpr_29             (0),
      .fpr_30             (0),
      .fpr_31             (0)
   );

endmodule
