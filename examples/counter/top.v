//top.v
module top (
    input clk,
    input reset,
    output reg [3:0] out);
    
    always @(posedge clk) begin
        out <= reset ? 0 : out + 1;
    end
    
endmodule
