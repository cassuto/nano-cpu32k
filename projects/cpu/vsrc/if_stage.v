
/* verilator lint_off UNUSED */
//--xuezhen--

`include "defines.v"

module if_stage(
  input wire clk,
  input wire rst,
  
  output wire [63 : 0]inst_addr,
  output wire         inst_ena
  
);

reg [`REG_BUS]pc;

// fetch an instruction
always@( posedge clk )
begin
  if( rst == 1'b1 )
  begin
    pc <= `ZERO_WORD ;
  end
  else
  begin
    pc <= pc + 4;
  end
end

assign inst_addr = pc;
assign inst_ena  = ( rst == 1'b1 ) ? 0 : 1;


endmodule
