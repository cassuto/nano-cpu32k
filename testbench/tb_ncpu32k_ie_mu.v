module tb_ncpu32k_ie_mu;

   reg clk;
   reg rst_n;
   reg [3:0] din;
   
   initial begin
      din =4'b0;
      clk = 1'b0;
      rst_n = 1'b0;
      #15 rst_n = 1'b1;
      forever #10 clk = ~clk;
   end
   
   wire ieu_mu_in_ready;
   reg ieu_mu_in_valid = 1;
   reg ieu_mu_load = 1;
   reg ieu_mu_store = 0;
   reg dbus_in_ready=0;
   wire dbus_in_valid;
   wire dbus_out_ready;
   reg dbus_out_valid=0;
   reg wb_in_ready = 0;
   wire wb_in_valid;
   reg [31:0] dbus_i=32'b1;
   wire [31:0] mu_load;
   reg [31:0] operand=32'b1;
   wire [31:0] dbus_o;
   
   always @(posedge clk) begin
      if(dbus_in_valid) begin // store
         dbus_in_ready<=1'b1;
         operand<=operand+32'b1;
      end
   end
   always @(posedge clk) begin
      if(dbus_out_ready) begin // load
         dbus_out_valid<=1'b1;
         dbus_i<=dbus_i+32'b1;
      end
   end
   
   always @(posedge clk) begin
      if(wb_in_valid) begin
         wb_in_ready<=1'b1;
      end
   end
   
   ncpu32k_ie_mu mu(         
      .clk(clk),
      .rst_n(rst_n),
      //.dbus_addr_o,
      .dbus_in_ready(dbus_in_ready), /* dbus is ready to store */
      .dbus_in_valid(dbus_in_valid), /* data is presented at dbus's input */
      .dbus_i(dbus_i),
      .dbus_out_ready(dbus_out_ready), /* MU is ready to load */
      .dbus_out_valid(dbus_out_valid), /* data is presented at dbus's output */
      .dbus_o(dbus_o),
      //.dbus_size_o,
      .ieu_mu_in_ready(ieu_mu_in_ready), /* MU is ready to accept ops */
      .ieu_mu_in_valid(ieu_mu_in_valid), /* ops is presented at MU's input */
      //.ieu_operand_1,
      //.ieu_operand_2,
      .ieu_operand_3(operand),
      .ieu_mu_load(ieu_mu_load),
      .ieu_mu_store(ieu_mu_store),
      //.ieu_mu_store_size,
      //.ieu_mu_load_size,
      .mu_load(mu_load),
      .wb_in_ready(wb_in_ready), /* WB is ready to accept data */
      .wb_in_valid(wb_in_valid) /* data is presented at WB'input   */
   );

endmodule