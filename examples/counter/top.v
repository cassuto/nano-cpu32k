//top.v
module top (
    input clk,
    input reset,
    output reg [3:0] out);
    
    always @(posedge clk) begin
        if(reset) begin
            out <= 4'b0;
        end
        else begin
            out <= out + 4'b1;
        end
    end
endmodule
