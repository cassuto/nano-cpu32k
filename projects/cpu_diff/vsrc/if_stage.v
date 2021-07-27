
/* verilator lint_off UNUSED */
//--xuezhen--

`include "defines.v"


module if_stage(
  input wire clk,
  input wire rst,
  
  output wire [63 : 0]pc_o
);

reg [`REG_BUS]pc;

// fetch an instruction
always@( posedge clk )
begin
  if( rst == 1'b1 )
  begin
    pc <= `PC_START;
  end
  else
  begin
    pc <= pc + 4;
  end
end

assign pc_o = pc;

endmodule
