
//--xuezhen--

`include "defines.v"

module exe_stage(
  input wire rst,
  input wire [4 : 0]inst_type_i,
  input wire [7 : 0]inst_opcode,
  input wire [`REG_BUS]op1,
  input wire [`REG_BUS]op2,
  
  output wire [4 : 0]inst_type_o,
  output reg  [`REG_BUS]rd_data
);

assign inst_type_o = inst_type_i;

always@( * )
begin
  if( rst == 1'b1 )
  begin
    rd_data = `ZERO_WORD;
  end
  else
  begin
    case( inst_opcode )
	  `INST_ADD: begin rd_data = op1 + op2;  end
	  default:   begin rd_data = `ZERO_WORD; end
	endcase
  end
end



endmodule
