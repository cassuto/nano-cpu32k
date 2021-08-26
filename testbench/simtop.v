`define AXI_TOP_INTERFACE(name) io_memAXI_0_``name

`define AXI_P_DW_BYTES      3
`define AXI_ADDR_WIDTH      64
`define AXI_DATA_WIDTH      ((1<<`AXI_P_DW_BYTES)*8)
`define AXI_ID_WIDTH        4
`define AXI_USER_WIDTH      1

module simtop
#(
   parameter AXI_P_DW_BYTES   = `AXI_P_DW_BYTES,
   parameter AXI_ADDR_WIDTH    = `AXI_ADDR_WIDTH,
   parameter AXI_ID_WIDTH      = `AXI_ID_WIDTH,
   parameter AXI_USER_WIDTH    = `AXI_USER_WIDTH
)
(
   input                               clock,
   input                               reset,

   input  [63:0]                       io_logCtrl_log_begin,
   input  [63:0]                       io_logCtrl_log_end,
   input  [63:0]                       io_logCtrl_log_level,
   input                               io_perfInfo_clean,
   input                               io_perfInfo_dump,

   output                              io_uart_out_valid,
   output [7:0]                        io_uart_out_ch,
   output                              io_uart_in_valid,
   input  [7:0]                        io_uart_in_ch,

   input                               `AXI_TOP_INTERFACE(aw_ready),
   output                              `AXI_TOP_INTERFACE(aw_valid),
   output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_addr),
   output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_prot),
   output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(aw_bits_id),
   output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(aw_bits_user),
   output [7:0]                        `AXI_TOP_INTERFACE(aw_bits_len),
   output [2:0]                        `AXI_TOP_INTERFACE(aw_bits_size),
   output [1:0]                        `AXI_TOP_INTERFACE(aw_bits_burst),
   output                              `AXI_TOP_INTERFACE(aw_bits_lock),
   output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_cache),
   output [3:0]                        `AXI_TOP_INTERFACE(aw_bits_qos),

   input                               `AXI_TOP_INTERFACE(w_ready),
   output                              `AXI_TOP_INTERFACE(w_valid),
   output [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(w_bits_data)         [3:0],
   output [`AXI_DATA_WIDTH/8-1:0]      `AXI_TOP_INTERFACE(w_bits_strb),
   output                              `AXI_TOP_INTERFACE(w_bits_last),

   output                              `AXI_TOP_INTERFACE(b_ready),
   input                               `AXI_TOP_INTERFACE(b_valid),
   input  [1:0]                        `AXI_TOP_INTERFACE(b_bits_resp),
   input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(b_bits_id),
   input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(b_bits_user),

   input                               `AXI_TOP_INTERFACE(ar_ready),
   output                              `AXI_TOP_INTERFACE(ar_valid),
   output [`AXI_ADDR_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_addr),
   output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_prot),
   output [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(ar_bits_id),
   output [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(ar_bits_user),
   output [7:0]                        `AXI_TOP_INTERFACE(ar_bits_len),
   output [2:0]                        `AXI_TOP_INTERFACE(ar_bits_size),
   output [1:0]                        `AXI_TOP_INTERFACE(ar_bits_burst),
   output                              `AXI_TOP_INTERFACE(ar_bits_lock),
   output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_cache),
   output [3:0]                        `AXI_TOP_INTERFACE(ar_bits_qos),

   output                              `AXI_TOP_INTERFACE(r_ready),
   input                               `AXI_TOP_INTERFACE(r_valid),
   input  [1:0]                        `AXI_TOP_INTERFACE(r_bits_resp),
   input  [`AXI_DATA_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_data)         [3:0],
   input                               `AXI_TOP_INTERFACE(r_bits_last),
   input  [`AXI_ID_WIDTH-1:0]          `AXI_TOP_INTERFACE(r_bits_id),
   input  [`AXI_USER_WIDTH-1:0]        `AXI_TOP_INTERFACE(r_bits_user)
);
   
   wire clk;
   wire rst;
   
   wire axi_aw_ready_i;
   wire axi_aw_valid_o;
   wire [`AXI_ADDR_WIDTH-1:0] axi_aw_addr_o;
   wire [2:0] axi_aw_prot_o;
   wire [`AXI_ID_WIDTH-1:0] axi_aw_id_o;
   wire [`AXI_USER_WIDTH-1:0] axi_aw_user_o;
   wire [7:0] axi_aw_len_o;
   wire [2:0] axi_aw_size_o;
   wire [1:0] axi_aw_burst_o;
   wire axi_aw_lock_o;
   wire [3:0] axi_aw_cache_o;
   wire [3:0] axi_aw_qos_o;

   wire axi_w_ready_i;
   wire axi_w_valid_o;
   wire [`AXI_DATA_WIDTH-1:0] axi_w_data_o;
   wire [`AXI_DATA_WIDTH/8-1:0] axi_w_strb_o;
   wire axi_w_last_o;

   wire axi_b_ready_o;
   wire axi_b_valid_i;
   wire [1:0] axi_b_resp_i;
   wire [`AXI_ID_WIDTH-1:0] axi_b_id_i;
   wire [`AXI_USER_WIDTH-1:0] axi_b_user_i;

   wire axi_ar_ready_i;
   wire axi_ar_valid_o;
   wire [`AXI_ADDR_WIDTH-1:0] axi_ar_addr_o;
   wire [2:0] axi_ar_prot_o;
   wire [`AXI_ID_WIDTH-1:0] axi_ar_id_o;
   wire [`AXI_USER_WIDTH-1:0] axi_ar_user_o;
   wire [7:0] axi_ar_len_o;
   wire [2:0] axi_ar_size_o;
   wire [1:0] axi_ar_burst_o;
   wire axi_ar_lock_o;
   wire [3:0] axi_ar_cache_o;
   wire [3:0] axi_ar_qos_o;
   
/* verilator lint_off UNUSED */
   wire [3:0] axi_aw_region_o; // unused
   wire [`AXI_USER_WIDTH-1:0] axi_w_user_o; // unused
   wire [3:0] axi_ar_region_o; // unsued
/* verilator lint_on UNUSED */

   wire axi_r_ready_o;
   wire axi_r_valid_i;
   wire [1:0] axi_r_resp_i;
   wire [`AXI_DATA_WIDTH-1:0] axi_r_data_i;
   wire axi_r_last_i;
   wire [`AXI_ID_WIDTH-1:0] axi_r_id_i;
   wire [`AXI_USER_WIDTH-1:0] axi_r_user_i;

   assign axi_ar_ready_i                                 = `AXI_TOP_INTERFACE(ar_ready);
   assign `AXI_TOP_INTERFACE(ar_valid)             = axi_ar_valid_o;
   assign `AXI_TOP_INTERFACE(ar_bits_addr)         = axi_ar_addr_o;
   assign `AXI_TOP_INTERFACE(ar_bits_prot)         = axi_ar_prot_o;
   assign `AXI_TOP_INTERFACE(ar_bits_id)           = axi_ar_id_o;
   assign `AXI_TOP_INTERFACE(ar_bits_user)         = axi_ar_user_o;
   assign `AXI_TOP_INTERFACE(ar_bits_len)          = axi_ar_len_o;
   assign `AXI_TOP_INTERFACE(ar_bits_size)         = axi_ar_size_o;
   assign `AXI_TOP_INTERFACE(ar_bits_burst)        = axi_ar_burst_o;
   assign `AXI_TOP_INTERFACE(ar_bits_lock)         = axi_ar_lock_o;
   assign `AXI_TOP_INTERFACE(ar_bits_cache)        = axi_ar_cache_o;
   assign `AXI_TOP_INTERFACE(ar_bits_qos)          = axi_ar_qos_o;

   assign `AXI_TOP_INTERFACE(r_ready)              = axi_r_ready_o;
   assign axi_r_valid_i                                  = `AXI_TOP_INTERFACE(r_valid);
   assign axi_r_resp_i                                   = `AXI_TOP_INTERFACE(r_bits_resp);
   assign axi_r_data_i                                   = `AXI_TOP_INTERFACE(r_bits_data)[0];
   assign axi_r_last_i                                   = `AXI_TOP_INTERFACE(r_bits_last);
   assign axi_r_id_i                                     = `AXI_TOP_INTERFACE(r_bits_id);
   assign axi_r_user_i                                   = `AXI_TOP_INTERFACE(r_bits_user);

   assign axi_aw_ready_i                                 = `AXI_TOP_INTERFACE(aw_ready);
   assign `AXI_TOP_INTERFACE(aw_valid)             = axi_aw_valid_o;
   assign `AXI_TOP_INTERFACE(aw_bits_addr)         = axi_aw_addr_o;
   assign `AXI_TOP_INTERFACE(aw_bits_prot)         = axi_aw_prot_o;
   assign `AXI_TOP_INTERFACE(aw_bits_id)           = axi_aw_id_o;
   assign `AXI_TOP_INTERFACE(aw_bits_user)         = axi_aw_user_o;
   assign `AXI_TOP_INTERFACE(aw_bits_len)          = axi_aw_len_o;
   assign `AXI_TOP_INTERFACE(aw_bits_size)         = axi_aw_size_o;
   assign `AXI_TOP_INTERFACE(aw_bits_burst)        = axi_aw_burst_o;
   assign `AXI_TOP_INTERFACE(aw_bits_lock)         = axi_aw_lock_o;
   assign `AXI_TOP_INTERFACE(aw_bits_cache)        = axi_aw_cache_o;
   assign `AXI_TOP_INTERFACE(aw_bits_qos)          = axi_aw_qos_o;
   
   assign axi_w_ready_i                                  = `AXI_TOP_INTERFACE(w_ready);
   assign `AXI_TOP_INTERFACE(w_valid)              = axi_w_valid_o;
   assign `AXI_TOP_INTERFACE(w_bits_data)          = axi_w_data_o;
   assign `AXI_TOP_INTERFACE(w_bits_strb)          = axi_w_strb_o;
   assign `AXI_TOP_INTERFACE(w_bits_last)          = axi_w_last_o;
   
   assign `AXI_TOP_INTERFACE(b_ready)              = axi_b_ready_o;
   assign axi_b_valid_i                                  = `AXI_TOP_INTERFACE(b_valid);
   assign axi_b_resp_i                                   = `AXI_TOP_INTERFACE(b_bits_resp);
   assign axi_b_id_i                                     = `AXI_TOP_INTERFACE(b_bits_id);
   assign axi_b_user_i                                   = `AXI_TOP_INTERFACE(b_bits_user);
   
   assign clk = clock;
   assign rst = reset; // reset is high-active

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
    .axi_aw_valid_o                     (axi_aw_valid_o),
    .axi_aw_addr_o                      (axi_aw_addr_o[AXI_ADDR_WIDTH-1:0]),
    .axi_aw_prot_o                      (axi_aw_prot_o[2:0]),
    .axi_aw_id_o                        (axi_aw_id_o[AXI_ID_WIDTH-1:0]),
    .axi_aw_user_o                      (axi_aw_user_o[AXI_USER_WIDTH-1:0]),
    .axi_aw_len_o                       (axi_aw_len_o[7:0]),
    .axi_aw_size_o                      (axi_aw_size_o[2:0]),
    .axi_aw_burst_o                     (axi_aw_burst_o[1:0]),
    .axi_aw_lock_o                      (axi_aw_lock_o),
    .axi_aw_cache_o                     (axi_aw_cache_o[3:0]),
    .axi_aw_qos_o                       (axi_aw_qos_o[3:0]),
    .axi_aw_region_o                    (axi_aw_region_o[3:0]),
    .axi_w_valid_o                      (axi_w_valid_o),
    .axi_w_data_o                       (axi_w_data_o[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .axi_w_strb_o                       (axi_w_strb_o[(1<<AXI_P_DW_BYTES)-1:0]),
    .axi_w_last_o                       (axi_w_last_o),
    .axi_w_user_o                       (axi_w_user_o[AXI_USER_WIDTH-1:0]),
    .axi_b_ready_o                      (axi_b_ready_o),
    // Inputs
    .clk                                (clk),
    .rst                                (rst),
    .axi_ar_ready_i                     (axi_ar_ready_i),
    .axi_r_valid_i                      (axi_r_valid_i),
    .axi_r_data_i                       (axi_r_data_i[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .axi_r_resp_i                       (axi_r_resp_i[1:0]),
    .axi_r_last_i                       (axi_r_last_i),
    .axi_r_id_i                         (axi_r_id_i[AXI_ID_WIDTH-1:0]),
    .axi_r_user_i                       (axi_r_user_i[AXI_USER_WIDTH-1:0]),
    .axi_aw_ready_i                     (axi_aw_ready_i),
    .axi_w_ready_i                      (axi_w_ready_i),
    .axi_b_valid_i                      (axi_b_valid_i),
    .axi_b_resp_i                       (axi_b_resp_i[1:0]),
    .axi_b_id_i                         (axi_b_id_i[AXI_ID_WIDTH-1:0]),
    .axi_b_user_i                       (axi_b_user_i[AXI_USER_WIDTH-1:0]));

   assign io_uart_out_valid = 'b0;
   assign io_uart_out_ch = 'b0;
   assign io_uart_in_valid = 'b0;
    
endmodule

// Local Variables:
// verilog-library-directories:(
//  "."
//  "../rtl"
// )
// End:
