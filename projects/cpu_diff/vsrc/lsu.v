module lsu #(
   DRAM_AW = 64
)
(
   input lsu_i_valid,
   input [63:0] lsu_i_rop2,

   /* verilator lint_off UNUSED */
   input [63:0] lsu_i_alu_result,
   /* verilator lint_on UNUSED */

   input lsu_op_load,
   input lsu_op_store,
   input lsu_sigext,
   input [3:0] lsu_size,
   output reg [63:0] lsu_result,

   // RAM interface
   output [DRAM_AW-1:0] o_dram_addr,
   output [7:0] o_dram_we,
   output o_dram_re,
   output [63:0] o_dram_din,
   input reg [63:0] i_dram_dout
);

   wire [DRAM_AW-1:0] va;

   assign va = lsu_i_alu_result;

   assign o_dram_addr = {va[DRAM_AW-1:3], 3'b000};

   assign o_dram_we = {8{lsu_i_valid & lsu_op_store}} & (
      (lsu_size==4'd1)
         ? {(va[2:0]==3'b111),(va[2:0]==3'b110),(va[2:0]==3'b101),(va[2:0]==3'b100),
            (va[2:0]==3'b011),(va[2:0]==3'b010),(va[2:0]==3'b001),(va[2:0]==3'b000)}
         : (lsu_size==4'd2)
            ? {(va[2:1]==2'b11),(va[2:1]==2'b11),(va[2:1]==2'b10),(va[2:1]==2'b10),
               (va[2:1]==2'b01),(va[2:1]==2'b01),(va[2:1]==2'b00),(va[2:1]==2'b00)}
            : (lsu_size==4'd4)
               ? {va[2],va[2],va[2],va[2],
                  ~va[2],~va[2],~va[2],~va[2]}
               : 8'b11111111
   );

   assign o_dram_din =
      (lsu_size==4'd1)
         ? {lsu_i_rop2[7:0],lsu_i_rop2[7:0],lsu_i_rop2[7:0],lsu_i_rop2[7:0],
            lsu_i_rop2[7:0],lsu_i_rop2[7:0],lsu_i_rop2[7:0],lsu_i_rop2[7:0]}
         : (lsu_size==4'd2)
            ? {lsu_i_rop2[15:0],lsu_i_rop2[15:0],
               lsu_i_rop2[15:0],lsu_i_rop2[15:0]}
            : (lsu_size==4'd4)
               ? {lsu_i_rop2[31:0],lsu_i_rop2[31:0]}
               : lsu_i_rop2;

   assign o_dram_re = lsu_i_valid & lsu_op_load;

   reg [7:0] res_8b; // b
   reg [15:0] res_16b; // h
   reg [31:0] res_32b; // w
   reg [63:0] res_64b; // d

   always @(*)
      begin
         case(va[2:0])
         3'b000:
            res_8b = i_dram_dout[7:0];
         3'b001:
            res_8b = i_dram_dout[15:8];
         3'b010:
            res_8b = i_dram_dout[23:16];
         3'b011:
            res_8b = i_dram_dout[31:24];
         3'b100:
            res_8b = i_dram_dout[39:32];
         3'b101:
            res_8b = i_dram_dout[47:40];
         3'b110:
            res_8b = i_dram_dout[55:48];
         3'b111:
            res_8b = i_dram_dout[63:56];
         default:
            res_8b = i_dram_dout[63:56];
         endcase
      end

   always @(*)
      begin
         case(va[2:1])
         2'b00:
            res_16b = i_dram_dout[15:0];
         2'b01:
            res_16b = i_dram_dout[31:16];
         2'b10:
            res_16b = i_dram_dout[47:32];
         2'b11:
            res_16b = i_dram_dout[63:48];
         default:
            res_16b = i_dram_dout[63:48];
         endcase
      end

   always @(*)
      begin
         res_32b = va[2] ? i_dram_dout[63:32] : i_dram_dout[31:0];
         res_64b = i_dram_dout;
      end

   always @(*)
      case (lsu_size)
      4'd1:
         lsu_result = {{64-8{lsu_sigext & res_8b[7]}}, res_8b[7:0]};
      4'd2:
         lsu_result = {{64-16{lsu_sigext & res_16b[15]}}, res_16b[15:0]};
      4'd4:
         lsu_result = {{64-32{lsu_sigext & res_32b[31]}}, res_32b[31:0]};
      4'd8:
         lsu_result = res_64b;
      default:
         lsu_result = res_64b;
      endcase

endmodule
