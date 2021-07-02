//top.v
module top(
    input   in_a, in_b, 
    output  out_s,  //sum
    output  out_c   //carry
);
    assign out_c = in_a & in_b;
    assign out_s = (~in_a & in_b) | (in_a & ~in_b);
endmodule
