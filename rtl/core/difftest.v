
`include "ncpu64k_config.vh"

`ifdef ENABLE_DIFFTEST

module difftest
#(
   parameter                           CONFIG_DW = 0,
   parameter                           CONFIG_AW = 0,
   parameter                           CONFIG_P_ISSUE_WIDTH = 0,
   parameter                           CONFIG_P_COMMIT_WIDTH = 0,
   parameter                           CONFIG_NUM_IRQ = 0,
   parameter                           CONFIG_P_ROB_DEPTH = 0
)
(
   input                               clk,
   input                               rst,
   
   // From ID
   input [`NCPU_INSN_DW * (1<<CONFIG_P_ISSUE_WIDTH)-1:0] id_ins,
   input                               id_p_ce,
   // From RN
   input                               rn_p_ce_s1,
   // From ROB
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_ROB_DEPTH-1:0] rob_free_id,
   input [(1<<CONFIG_P_ISSUE_WIDTH)*CONFIG_P_COMMIT_WIDTH-1:0] rob_free_bank,
   input [CONFIG_P_ISSUE_WIDTH:0]      rob_push_size,
   input [CONFIG_P_COMMIT_WIDTH-1:0]   rob_head_l   [(1<<CONFIG_P_COMMIT_WIDTH)-1:0],
   input [CONFIG_P_ROB_DEPTH-1:0]      rob_que_rptr [(1<<CONFIG_P_COMMIT_WIDTH)-1:0],
   // From CMT
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_fire,
   input [`PC_W*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_pc,
   input [`NCPU_LRF_AW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmtf_lrd,
   input [CONFIG_DW*(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmtf_lrd_dat,
   input [(1<<CONFIG_P_COMMIT_WIDTH)-1:0] cmt_lrd_we,
   input                               cmt_exc,
   input [CONFIG_DW-1:0]               cmt_exc_vect,
   input                               cmt_p_ce_s1,
   input [CONFIG_NUM_IRQ-1:0]          msr_irqc_irr
);
   localparam IW = (1<<CONFIG_P_ISSUE_WIDTH);
   localparam CW = (1<<CONFIG_P_COMMIT_WIDTH);
   localparam ROB_DEPTH = (1<<CONFIG_P_ROB_DEPTH);
   genvar i;
   
   //
   // Difftest access point
   //
   wire [CONFIG_NUM_IRQ-1:0] s1o_msr_irqc_irr;
   wire [CW-1:0] commit_valid_ff;
   wire [`PC_W*CW-1:0] commit_pc_ff;
   wire [`NCPU_INSN_DW*CW-1:0] commit_ins_ff; 
   wire [`NCPU_LRF_AW*CW-1:0] commit_rf_waddr_ff;
   wire [CONFIG_DW*CW-1:0] commit_rf_wdat_ff;
   wire [CW-1:0] commit_rf_we_ff;
   wire commit_excp_ff;
   wire [31:0] commit_excp_vect_ff;
   wire [CONFIG_NUM_IRQ-1:0] commit_irqc_irr_ff;
   
   // Extra pipeline in ID
   wire [`NCPU_INSN_DW*IW-1:0] rn_ins;
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_rn_ins (.CLK(clk), .LOAD(id_p_ce), .D(id_ins), .Q(rn_ins) );
   
   // Extra pipeline in RN
   wire [`NCPU_INSN_DW*IW-1:0] issue_ins;
   mDFF_l # (.DW(`NCPU_INSN_DW*IW)) ff_issue_ins (.CLK(clk), .LOAD(rn_p_ce_s1), .D(rn_ins), .Q(issue_ins) );
   
   // Extra ROB entry
   reg [`NCPU_INSN_DW-1:0] rob_ins [CW-1:0][ROB_DEPTH-1:0];
   wire [`NCPU_INSN_DW*CW-1:0] cmt_ins;
   generate
      for(i=0;i<CW;i=i+1)
         begin
            always @(posedge clk)
               if (i < rob_push_size)
                  begin
                     rob_ins[rob_free_bank[i*CONFIG_P_COMMIT_WIDTH+:CONFIG_P_COMMIT_WIDTH]]
                              [rob_free_id[i*CONFIG_P_ROB_DEPTH+:CONFIG_P_ROB_DEPTH]] <= issue_ins[i * `NCPU_INSN_DW +: `NCPU_INSN_DW];
                  end
            
            assign cmt_ins[i * `NCPU_INSN_DW +: `NCPU_INSN_DW] = rob_ins[rob_head_l[i]][rob_que_rptr[rob_head_l[i]]];
         end
   endgenerate
   
   // Extra pipeline in CMT
   mDFF_l #(.DW(CONFIG_DW)) ff_s1o_msr_irqc_irr (.CLK(clk), .LOAD(cmt_p_ce_s1), .D(msr_irqc_irr), .Q(s1o_msr_irqc_irr));
   
   mDFF_r #(.DW(CW)) ff_commit_valid (.CLK(clk), .RST(rst), .D(cmt_fire), .Q(commit_valid_ff));
   mDFF #(.DW(`PC_W*CW)) ff_commit_pc (.CLK(clk), .D(cmt_pc), .Q(commit_pc_ff));
   mDFF #(.DW(`NCPU_INSN_DW*CW)) ff_commit_ins (.CLK(clk), .D(cmt_ins), .Q(commit_ins_ff));
   assign commit_rf_waddr_ff = cmtf_lrd;
   assign commit_rf_wdat_ff = cmtf_lrd_dat;
   mDFF_r #(.DW(CW)) ff_commit_rf_we (.CLK(clk), .RST(rst), .D(cmt_lrd_we), .Q(commit_rf_we_ff));
   mDFF #(.DW(1)) ff_commit_excp (.CLK(clk), .D(cmt_exc), .Q(commit_excp_ff) );
   mDFF #(.DW(32)) ff_commit_excp_vect (.CLK(clk), .D(cmt_exc_vect), .Q(commit_excp_vect_ff) );
   mDFF #(.DW(CONFIG_NUM_IRQ)) ff_commit_irqc_irr (.CLK(clk), .D(s1o_msr_irqc_irr), .Q(commit_irqc_irr_ff) );
   
   
   difftest_commit_inst
      #(/*AUTOINSTPARAM*/
        // Parameters
        .CONFIG_P_COMMIT_WIDTH           (CONFIG_P_COMMIT_WIDTH),
        .CONFIG_NUM_IRQ                 (CONFIG_NUM_IRQ))
   U_DIFFTEST_COMMIT_INST
      (
         .clk                             (clk),
         .valid                           (commit_valid_ff),
         .pc                              (commit_pc_ff),
         .insn                            (commit_ins_ff),
         .wen                             (commit_rf_we_ff),
         .wnum                            (commit_rf_waddr_ff),
         .wdata                           (commit_rf_wdat_ff),
         .excp                            ({{CW-1{1'b0}}, commit_excp_ff}),
         .excp_vect                       ({{CW-1{{32{1'b0}}}}, commit_excp_vect_ff}),
         .irqc_irr                        ({{CW-1{{CONFIG_NUM_IRQ{1'b0}}}}, commit_irqc_irr_ff})
      );
      
   wire [31:0] dbg_commit_pc[CW-1:0];
   generate
      for(i=0;i<CW;i=i+1)  
         begin
            assign dbg_commit_pc[i] = {commit_pc_ff[i*`PC_W +: `PC_W], 2'b00};
         end
   endgenerate
      
endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../em/vsrc"
// )
// End:


`endif
