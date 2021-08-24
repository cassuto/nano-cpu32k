/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

`include "ncpu64k_config.vh"

module ncpu64k
#(
   parameter CONFIG_AW = 64,
   parameter CONFIG_DW = 64,
   parameter CONFIG_P_FETCH_WIDTH = 1,
   parameter CONFIG_P_PAGE_SIZE = 13,
   parameter CONFIG_IC_P_LINE = 6,
   parameter CONFIG_IC_P_SETS = 6,
   parameter CONFIG_IC_P_WAYS = 2,
   parameter AXI_P_DW_BYTES    = 3,
   parameter AXI_ADDR_WIDTH    = 64,
   parameter AXI_ID_WIDTH      = 4,
   parameter AXI_USER_WIDTH    = 1
)
(
   input                               clk,
   input                               rst,
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
   /*AUTOWIRE*/
   // Beginning of automatic wires (for undeclared instantiated-module outputs)
   wire [`NCPU_INSN_DW*(1<<CONFIG_P_FETCH_WIDTH)-1:0] fbuf_ins;// From U_IFU of ifu.v
   wire [(1<<CONFIG_P_FETCH_WIDTH)-1:0] fbuf_valid;// From U_IFU of ifu.v
   // End of automatics
   wire                               op_ic_inv;
   wire [CONFIG_AW-1:0]               op_ic_inv_paddr;

   ifu
   #(/*AUTOINSTPARAM*/
     // Parameters
     .CONFIG_AW                         (CONFIG_AW),
     .CONFIG_P_FETCH_WIDTH              (CONFIG_P_FETCH_WIDTH),
     .CONFIG_P_PAGE_SIZE                (CONFIG_P_PAGE_SIZE),
     .CONFIG_IC_P_LINE                  (CONFIG_IC_P_LINE),
     .CONFIG_IC_P_SETS                  (CONFIG_IC_P_SETS),
     .CONFIG_IC_P_WAYS                  (CONFIG_IC_P_WAYS),
     .AXI_P_DW_BYTES                    (AXI_P_DW_BYTES),
     .AXI_ADDR_WIDTH                    (AXI_ADDR_WIDTH),
     .AXI_ID_WIDTH                      (AXI_ID_WIDTH),
     .AXI_USER_WIDTH                    (AXI_USER_WIDTH))
   U_IFU
   (/*AUTOINST*/
    // Outputs
    .fbuf_ins                           (fbuf_ins[`NCPU_INSN_DW*(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
    .fbuf_valid                         (fbuf_valid[(1<<CONFIG_P_FETCH_WIDTH)-1:0]),
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
    .op_ic_inv                          (op_ic_inv),
    .op_ic_inv_paddr                    (op_ic_inv_paddr[CONFIG_AW-1:0]),
    .axi_ar_ready_i                     (axi_ar_ready_i),
    .axi_r_valid_i                      (axi_r_valid_i),
    .axi_r_data_i                       (axi_r_data_i[(1<<AXI_P_DW_BYTES)*8-1:0]),
    .axi_r_resp_i                       (axi_r_resp_i[1:0]),
    .axi_r_last_i                       (axi_r_last_i),
    .axi_r_id_i                         (axi_r_id_i[AXI_ID_WIDTH-1:0]),
    .axi_r_user_i                       (axi_r_user_i[AXI_USER_WIDTH-1:0]));

   assign op_ic_inv = 'b0;
   assign op_ic_inv_paddr = 'b0;
endmodule
