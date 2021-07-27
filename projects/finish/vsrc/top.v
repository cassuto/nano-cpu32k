
module top (
    input clk
);

    always @(posedge clk) begin
        $finish;
    end

endmodule
