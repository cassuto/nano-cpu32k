// Validate ROB operand readout
initial
   begin
      @(posedge clk); // 117

      @(posedge clk); // 126 Dispatch #1

      @(posedge clk); // 150 Dispatch #2
      
      // Check Dispatch #1
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);

      @(posedge clk); // 183 Dispatch #3
      
      // Check Dispatch #2
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);
      
      @(posedge clk); // 195 Dispatch #4

      // Check Dispatch #3
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);

      @(posedge clk); // 236
    
      // Check Dispatch #4
      if (~disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);
         
      repeat(5)
         @(posedge clk); // 245
         
      @(posedge clk); // 345
      
      @(posedge clk); // 360 Dispatch #1
      
      @(posedge clk); // 388 Dispatch #2
      
      // Check Dispatch #1
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);
         
      @(posedge clk); // 412 Dispatch #3
      
      // Check Dispatch #2
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);
         
      @(posedge clk); // 437 Dispatch #4
      
      // Check Dispatch #3
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);
      
      @(posedge clk); // 464 Writeback #1
      
      // Check Dispatch #4
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | ~disp_rs2_in_ARF)
         $fatal(1, $time);

      @(posedge clk); // 470
      
      @(posedge clk); // 474
      
      @(posedge clk); // 484
      
      @(posedge clk); // 496
      
      @(posedge clk); // 507
      
      @(posedge clk); // 522
      
      // Check 508
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | disp_rs2_in_ARF)
         $fatal(1, $time);
         
      @(posedge clk); // 531
         
      // Check 523
      if (disp_rs1_in_ROB | disp_rs2_in_ROB)
         $fatal(1, $time);
      if (~disp_rs1_in_ARF | disp_rs2_in_ARF)
         $fatal(1, $time);
   end
