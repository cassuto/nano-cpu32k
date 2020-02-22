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
   reg ieu_mu_load = 0;
   reg ieu_mu_store = 1;
   wire dbus_in_ready;
   wire dbus_in_valid;
   wire dbus_out_ready;
   wire dbus_out_valid;
   reg wb_mu_in_ready = 0;
   wire wb_mu_in_valid;
   wire [31:0] dbus_i;
   wire [31:0] mu_load;
   reg [31:0] operand=32'b1;
   wire [31:0] dbus_o;
   wire [31:0] dbus_addr_o;
   wire [2:0] dbus_size_o;
   
   reg rr;
   always @(posedge clk) begin
      if(ieu_mu_in_ready) begin
         rr<=1;
         if(rr & ieu_mu_load)
            ieu_mu_load<=0;
         if(rr & ieu_mu_store)
            ieu_mu_store<=0;
      end
   end
   
   handshake_sram  #(
      .MEMH_FILE("insn.mem")
   ) d_ram(
      .clk     (clk),
      .rst_n   (rst_n),
      .addr    (dbus_addr_o),
      .in_valid   (dbus_in_valid),
      .in_ready   (dbus_in_ready),
      .din        (dbus_i),
      .out_valid  (dbus_out_valid),
      .out_ready  (dbus_out_ready),
      .out_id     (),
      .dout    (dbus_o),
      .size    (dbus_size_o)
   );
   
   always @(posedge clk) begin
      if(wb_mu_in_valid) begin
         wb_mu_in_ready<=1'b1;
      end
   end
   
   ncpu32k_ie_mu mu(         
      .clk(clk),
      .rst_n(rst_n),
      .dbus_addr_o(dbus_addr_o),
      .dbus_in_ready(dbus_in_ready), /* dbus is ready to store */
      .dbus_in_valid(dbus_in_valid), /* data is presented at dbus's input */
      .dbus_i(dbus_i),
      .dbus_out_ready(dbus_out_ready), /* MU is ready to load */
      .dbus_out_valid(dbus_out_valid), /* data is presented at dbus's output */
      .dbus_o(dbus_o),
      .dbus_size_o(dbus_size_o),
      .ieu_mu_in_ready(ieu_mu_in_ready), /* MU is ready to accept ops */
      .ieu_mu_in_valid(ieu_mu_in_valid), /* ops is presented at MU's input */
      .ieu_operand_1(32'b0),
      .ieu_operand_2(32'd4),
      .ieu_operand_3(operand),
      .ieu_mu_load(ieu_mu_load),
      .ieu_mu_store(ieu_mu_store),
      .ieu_mu_store_size(3'd3),
      .ieu_mu_load_size(3'd3),
      .mu_load(mu_load),
      .wb_mu_in_ready(wb_mu_in_ready), /* WB is ready to accept data */
      .wb_mu_in_valid(wb_mu_in_valid) /* data is presented at WB'input   */
   );

endmodule