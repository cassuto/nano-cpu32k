
//top.v
import "DPI-C" function int add (input int a, input int b);

module top (
    input clk
);
    reg [31:0] a;

    initial begin
        a = 0;
    end
    
    always @(posedge clk) begin
        a = add(a, 1);
        $display("a = %d", a);
    end
    
endmodule
