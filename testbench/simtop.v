module simtop
#(
   parameter AXI_P_DW_BYTES  = 3,
   parameter AXI_ADDR_WIDTH    = 64,
   parameter AXI_ID_WIDTH      = 4,
   parameter AXI_USER_WIDTH    = 1
)
(
   input clk,
   input rst,
   // AXI Master
   input                               axi_ar_ready_i,
   output                              axi_ar_valid_o,
   output [AXI_ADDR_WIDTH-1:0]         axi_ar_addr_o,
   output [2:0]                        axi_ar_prot_o,
   output [AXI_ID_WIDTH-1:0]           axi_ar_id_o,
   output [AXI_USER_WIDTH-1:0]         axi_ar_user_o,
   output [7:0]                        axi_ar_len_o,
   output [2:0]                        axi_ar_size_o,
   output [1:0]                        axi_ar_burst_o,
   output                              axi_ar_lock_o,
   output [3:0]                        axi_ar_cache_o,
   output [3:0]                        axi_ar_qos_o,
   output [3:0]                        axi_ar_region_o,

   output                              axi_r_ready_o,
   input                               axi_r_valid_i,
   input  [(1<<AXI_P_DW_BYTES)*8-1:0]  axi_r_data_i,
   input  [1:0]                        axi_r_resp_i,
   input                               axi_r_last_i,
   input  [AXI_ID_WIDTH-1:0]           axi_r_id_i,
   input  [AXI_USER_WIDTH-1:0]         axi_r_user_i
);

   ncpu64k
   #(
   .AXI_P_DW_BYTES                     (AXI_P_DW_BYTES),
   .AXI_ADDR_WIDTH                     (AXI_ADDR_WIDTH),
   .AXI_ID_WIDTH                       (AXI_ID_WIDTH),
   .AXI_USER_WIDTH                     (AXI_USER_WIDTH)
   )
   DUT
   (/*AUTOINST*/
    // Outputs
    .axi_ar_valid_o                     (axi_ar_valid_o),
    .axi_ar_addr_o                      (axi_ar_addr_o[AXI_ADDR_WIDTH-1:0]),
    .axi_ar_prot_o                      (axi_ar_prot_o[2:0]),
    .axi_ar_id_o                        (axi_ar_id_o[AXI_ID_WIDTH-1:0]),
    .axi_ar_user_o                      (axi_ar_user_o[AXI_USER_WIDTH-1:0]),
    .axi_ar_len_o                       (axi_ar_len_o[7:0]),
    .axi_ar_size_o                      (axi_ar_size_o[2:0]),
    .axi_ar_burst_o                     (axi_ar_burst_o[1:0]),
    .axi_ar_lock_o                      (axi_ar_lock_o),
    .axi_ar_cache_o                     (axi_ar_cache_o[3:0]),
    .axi_ar_qos_o                       (axi_ar_qos_o[3:0]),
    .axi_ar_region_o                    (axi_ar_region_o[3:0]),
    .axi_r_ready_o                      (axi_r_ready_o),
    // Inputs
    .clk                                (clk),
    .rst                                (rst),
    .axi_ar_ready_i                     (axi_ar_ready_i),
    .axi_r_valid_i                      (axi_r_valid_i),
    .axi_r_data_i                       (axi_r_data_i[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .axi_r_resp_i                       (axi_r_resp_i[1:0]),
    .axi_r_last_i                       (axi_r_last_i),
    .axi_r_id_i                         (axi_r_id_i[AXI_ID_WIDTH-1:0]),
    .axi_r_user_i                       (axi_r_user_i[AXI_USER_WIDTH-1:0]));

endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../rtl"
// )
// End:
