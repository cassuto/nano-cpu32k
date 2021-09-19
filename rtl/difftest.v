
`include "ncpu64k_config.vh"

`ifdef ENABLE_DIFFTEST

module difftest
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0
)
(
   input                               clk,
   input                               rst,
   input                               stall,
   input                               p_ce_s1,
   input                               p_ce_s2,
   input                               p_ce_s3,
   input [`NCPU_INSN_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_valid,
   input [`PC_W*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_pc,
   input [CONFIG_DW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_wdat,
   input [`NCPU_REG_AW*(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_waddr,
   input [(1<<CONFIG_P_ISSUE_WIDTH)-1:0] commit_rf_we,
   input [CONFIG_DW-1:0]               regfile [(1<<`NCPU_REG_AW)-1:0]
);
   localparam IW = (1<<CONFIG_P_ISSUE_WIDTH);
   
   //
   // Difftest access point
   //
   wire p_ce_id;
   wire [`NCPU_INSN_DW*IW-1:0] ex_ins, ex_s1o_ins, ex_s2o_ins, ex_s3o_ins;
   wire [`NCPU_INSN_DW*IW-1:0] commit_ins;
   wire [IW-1:0] commit_valid_ff;
   wire [`PC_W*IW-1:0] commit_pc_ff;
   wire [`NCPU_REG_AW*IW-1:0] commit_rf_waddr_ff;
   wire [CONFIG_DW*IW-1:0] commit_rf_wdat_ff;
   wire [IW-1:0] commit_rf_we_ff;
   
   // Extra pipeline in ID
   assign p_ce_id = (~stall);
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_ex_ins (.CLK(clk), .LOAD(p_ce_id), .D(id_ins), .Q(ex_ins) );
   
   // Extra pipeline in EX
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_ex_s1o_ins (.CLK(clk), .LOAD(p_ce_s1), .D(ex_ins), .Q(ex_s1o_ins) );
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_ex_s2o_ins (.CLK(clk), .LOAD(p_ce_s2), .D(ex_s1o_ins), .Q(ex_s2o_ins) );
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_ex_s3o_ins (.CLK(clk), .LOAD(p_ce_s3), .D(ex_s2o_ins), .Q(ex_s3o_ins) );
   
   // Extra pipeline in CMT
   mDFF_r #(.DW(IW)) ff_commit_valid (.CLK(clk), .RST(rst), .D(commit_valid & {IW{p_ce_s3}}), .Q(commit_valid_ff));
   mDFF #(.DW(`PC_W*IW)) ff_commit_pc (.CLK(clk), .D(commit_pc), .Q(commit_pc_ff));
   mDFF #(.DW(`NCPU_REG_AW*IW)) ff_commit_rf_waddr (.CLK(clk), .D(commit_rf_waddr), .Q(commit_rf_waddr_ff));
   mDFF #(.DW(CONFIG_DW*IW)) ff_commit_rf_wdat (.CLK(clk), .D(commit_rf_wdat), .Q(commit_rf_wdat_ff));
   mDFF_r #(.DW(IW)) ff_commit_rf_we (.CLK(clk), .RST(rst), .D(commit_rf_we), .Q(commit_rf_we_ff));
   mDFF # (.DW(`NCPU_INSN_DW*IW)) ff_commit_ins (.CLK(clk), .D(ex_s3o_ins), .Q(commit_ins) );
   
   
   difftest_commit_inst U_DIFFTEST_COMMIT_INST
      (
         .clk                             (clk),
         .valid1                          (commit_valid_ff[0]),
         .pc1                             ({commit_pc_ff[0*`PC_W +: `PC_W], {`NCPU_P_INSN_LEN{1'b0}}}),
         .insn1                           (commit_ins[0*`NCPU_INSN_DW +: `NCPU_INSN_DW]),
         .wen1                            (commit_rf_we_ff[0]),
         .wnum1                           (commit_rf_waddr_ff[0*`NCPU_REG_AW +: `NCPU_REG_AW]),
         .wdata1                          (commit_rf_wdat_ff[0*CONFIG_DW +: CONFIG_DW]),
         .valid2                          (commit_valid_ff[1]),
         .pc2                             ({commit_pc_ff[1*`PC_W +: `PC_W], {`NCPU_P_INSN_LEN{1'b0}}}),
         .insn2                           (commit_ins[1*`NCPU_INSN_DW +: `NCPU_INSN_DW]),
         .wen2                            (commit_rf_we_ff[1]),
         .wnum2                           (commit_rf_waddr_ff[1*`NCPU_REG_AW +: `NCPU_REG_AW]),
         .wdata2                          (commit_rf_wdat_ff[1*CONFIG_DW +: CONFIG_DW]),
         .EINT1                           (1'b0), // TODO
         .EINT2                           (1'b0) // TODO
      );
      
   difftest_regfile U_DIFFTEST_REGFILE
      (
         .clk                             (clk),
         .r0                              (regfile[0]),
         .r1                              (regfile[1]),
         .r2                              (regfile[2]),
         .r3                              (regfile[3]),
         .r4                              (regfile[4]),
         .r5                              (regfile[5]),
         .r6                              (regfile[6]),
         .r7                              (regfile[7]),
         .r8                              (regfile[8]),
         .r9                              (regfile[9]),
         .r10                             (regfile[10]),
         .r11                             (regfile[11]),
         .r12                             (regfile[12]),
         .r13                             (regfile[13]),
         .r14                             (regfile[14]),
         .r15                             (regfile[15]),
         .r16                             (regfile[16]),
         .r17                             (regfile[17]),
         .r18                             (regfile[18]),
         .r19                             (regfile[19]),
         .r20                             (regfile[20]),
         .r21                             (regfile[21]),
         .r22                             (regfile[22]),
         .r23                             (regfile[23]),
         .r24                             (regfile[24]),
         .r25                             (regfile[25]),
         .r26                             (regfile[26]),
         .r27                             (regfile[27]),
         .r28                             (regfile[28]),
         .r29                             (regfile[29]),
         .r30                             (regfile[30]),
         .r31                             (regfile[31])
      );
      
   difftest_clk U_DIFFTEST_CLK
      (
         .clk                             (clk),
         .msr_tsc_count                   ('b0) // TODO
      );

   wire [31:0] dbg_commit_pc[IW-1:0];
   generate
      for(genvar i=0;i<IW;i=i+1)  
         begin
            assign dbg_commit_pc[i] = {commit_pc[i*`PC_W +: `PC_W], 2'b00};
         end
   endgenerate
      
endmodule

`endif
