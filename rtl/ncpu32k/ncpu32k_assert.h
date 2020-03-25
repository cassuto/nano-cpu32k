// synthesis translate_off
`ifndef SYNTHESIS                   

// Count the number of 1
// Not synthesizable
function integer count_1 (input [31:0] din);
   begin : count_1_blk
      integer i;
      count_1 = 0;
      for(i=0; i<32; i=i+1)
         if(din[i])
            count_1=count_1+1;
   end
endfunction

`endif
// synthesis translate_on
