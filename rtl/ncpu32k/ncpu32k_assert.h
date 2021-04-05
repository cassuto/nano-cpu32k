// synthesis translate_off
`ifndef SYNTHESIS                   

integer __i__;

// Count the number of 1
// Not synthesizable
function integer count_1 (input [31:0] din);
   begin : count_1_blk
      count_1 = 0;
      for(__i__=0; __i__<32; __i__=__i__+1)
         if(din[__i__])
            count_1=count_1+1;
   end
endfunction

`endif
// synthesis translate_on
