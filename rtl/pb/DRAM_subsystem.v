/***************************************************************************/
/*  Nano-cpu 32000 (High-Performance Superscalar Processor)                */
/*                                                                         */
/*  Copyright (C) 2019 cassuto <psc-system@outlook.com>, China.            */
/*  This project is free edition; you can redistribute it and/or           */
/*  modify it under the terms of the GNU Lesser General Public             */
/*  License(GPL) as published by the Free Software Foundation; either      */
/*  version 2.1 of the License, or (at your option) any later version.     */
/*                                                                         */
/*  This project is distributed in the hope that it will be useful,        */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of         */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU      */
/*  Lesser General Public License for more details.                        */
/***************************************************************************/

`include "ncpu32k_config.h"

module DRAM_subsystem
#(
   parameter CONFIG_SDR_ROW_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_BA_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_COL_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_DATA_BYTES_LOG2
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_SDR_DATA_BITS
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_ICACHE_P_LINE
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_IBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DBUS_DW
   `PARAM_NOT_SPECIFIED ,
   parameter CONFIG_DCACHE_P_LINE
   `PARAM_NOT_SPECIFIED
)
(
   input                               sdr_clk,
   input                               sdr_rst_n,
   // Async I-Bus Slave
   output                              ibus_AREADY,
   input                               ibus_AVALID,
   input [CONFIG_IBUS_AW-1:0]          ibus_AADDR,
   input                               ibus_ASEL_BOOTROM,
   input [CONFIG_ICACHE_P_LINE-1:0]    ibus_ALEN,
   input                               ibus_BREADY,
   output                              ibus_BVALID,
   output [CONFIG_IBUS_DW-1:0]         ibus_BDATA,
   // Async D-Bus Slave
   output                              dbus_AREADY,
   input                               dbus_AVALID,
   input [CONFIG_DBUS_AW-1:0]          dbus_AADDR,
   input [CONFIG_DBUS_DW/8-1:0]        dbus_AWMSK,
   input [CONFIG_DCACHE_P_LINE-1:0]    dbus_ALEN,
   input [CONFIG_DBUS_DW-1:0]          dbus_WDATA,
   output                              dbus_BVALID,
   input                               dbus_BREADY,
   output [CONFIG_DBUS_DW-1:0]         dbus_BDATA,
   output                              dbus_BWE,
   // SDR
   output reg                          sdr_cmd_bst_we_req,
   input                               sdr_cmd_bst_we_ack,
   output reg                          sdr_cmd_bst_rd_req,
   input                               sdr_cmd_bst_rd_ack,
   output reg [CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS-1:0] sdr_cmd_addr,
   output [CONFIG_SDR_DATA_BITS-1:0]   sdr_din,
   input  [CONFIG_SDR_DATA_BITS-1:0]   sdr_dout,
   input                               sdr_r_vld,   // sdr_dout valid
   input                               sdr_w_rdy,   // write ready
   // BootROM
   output reg                          bootrom_en,
   output reg [CONFIG_IBUS_AW-1:0]     bootrom_addr,
   input [CONFIG_IBUS_DW-1:0]          bootrom_dout
);
   reg [2:0]                           state_r;
   reg [CONFIG_ICACHE_P_LINE-1:0]      bootrom_burst_cnt;

   localparam [2:0]                    S_IDLE                     = 3'b000;
   localparam [2:0]                    S_DBUS_BURST_START         = 3'b001;
   localparam [2:0]                    S_DBUS_BURST_W_PENDING     = 3'b010;
   localparam [2:0]                    S_DBUS_BURST_R_PENDING     = 3'b011;
   localparam [2:0]                    S_IBUS_BURST_START         = 3'b111;
   localparam [2:0]                    S_IBUS_BURST_R_PENDING     = 3'b110;
   localparam [2:0]                    S_IBUS_BURST_START_BOOTROM = 3'b100;
   localparam [2:0]                    S_IBUS_BURST_BOOTROM_PENDING  = 3'b101;

   // D-BUS is prior to I-BUS
   assign dbus_AREADY = (state_r == S_IDLE);
   assign ibus_AREADY = (state_r == S_IDLE) & ~dbus_AVALID;

   // D-BUS Response
   assign dbus_BVALID = ((state_r == S_DBUS_BURST_W_PENDING) & sdr_w_rdy) |
                        ((state_r == S_DBUS_BURST_R_PENDING) & sdr_r_vld);
   assign dbus_BDATA = sdr_dout;
   assign dbus_BWE = sdr_w_rdy;
   assign sdr_din = dbus_WDATA;

   // I-BUS Response
   assign ibus_BVALID = ((state_r == S_IBUS_BURST_R_PENDING) & sdr_r_vld) |
                        (state_r == S_IBUS_BURST_BOOTROM_PENDING);
   assign ibus_BDATA = (state_r == S_IBUS_BURST_BOOTROM_PENDING) ? bootrom_dout : sdr_dout;

   always @(posedge sdr_clk or negedge sdr_rst_n)
      if (~sdr_rst_n)
         begin
            state_r <= S_IDLE;
            sdr_cmd_bst_we_req <= 1'b0;
            sdr_cmd_bst_rd_req <= 1'b0;
         end
      else
         begin
            case (state_r)
            S_IDLE:
               if (dbus_AVALID)
                  begin
                     sdr_cmd_bst_we_req <= |dbus_AWMSK;
                     sdr_cmd_bst_rd_req <= ~|dbus_AWMSK;
                     sdr_cmd_addr <= dbus_AADDR[CONFIG_SDR_DATA_BYTES_LOG2 +: CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS];
                     state_r <= S_DBUS_BURST_START;
                  end
               else if (ibus_AVALID & ibus_ASEL_BOOTROM) // Bootrom is selected
                  begin
                     bootrom_burst_cnt <= ibus_ALEN;
                     bootrom_en <= 1'b1;
                     bootrom_addr <= ibus_AADDR;
                     state_r <= S_IBUS_BURST_START_BOOTROM;
                  end
               else if (ibus_AVALID)
                  begin
                     sdr_cmd_bst_rd_req <= 1'b1;
                     sdr_cmd_addr <= ibus_AADDR[CONFIG_SDR_DATA_BYTES_LOG2 +: CONFIG_SDR_ROW_BITS+CONFIG_SDR_BA_BITS+CONFIG_SDR_COL_BITS];
                     state_r <= S_IBUS_BURST_START;
                  end

            S_DBUS_BURST_START:
               begin
                  if (sdr_cmd_bst_we_req & sdr_cmd_bst_we_ack)
                     begin
                        sdr_cmd_bst_we_req <= 1'b0;
                        state_r <= S_DBUS_BURST_W_PENDING;
                     end
                  if (sdr_cmd_bst_rd_req & sdr_cmd_bst_rd_ack)
                     begin
                        sdr_cmd_bst_rd_req <= 1'b0;
                        state_r <= S_DBUS_BURST_R_PENDING;
                     end
               end

            S_DBUS_BURST_W_PENDING:
               if (~sdr_cmd_bst_we_ack)
                  begin
                     state_r <= S_IDLE;
                  end
            S_DBUS_BURST_R_PENDING:
               if (~sdr_cmd_bst_rd_ack)
                  begin
                     state_r <= S_IDLE;
                  end

            S_IBUS_BURST_START:
               begin
                  if (sdr_cmd_bst_rd_ack)
                     begin
                        sdr_cmd_bst_rd_req <= 1'b0;
                        state_r <= S_IBUS_BURST_R_PENDING;
                     end
               end

            S_IBUS_BURST_R_PENDING:
               if (~sdr_cmd_bst_rd_ack)
                  begin
                     state_r <= S_IDLE;
                  end

            S_IBUS_BURST_START_BOOTROM:
               begin
                  state_r <= S_IBUS_BURST_BOOTROM_PENDING;
                  bootrom_burst_cnt <= bootrom_burst_cnt - 1'b1;
                  bootrom_addr <= bootrom_addr + (CONFIG_IBUS_DW/8);
               end

            S_IBUS_BURST_BOOTROM_PENDING:
               begin
                  if (|bootrom_burst_cnt)
                     begin
                        bootrom_burst_cnt <= bootrom_burst_cnt - 1'b1;
                        bootrom_addr <= bootrom_addr + (CONFIG_IBUS_DW/8);
                     end
                  else
                     begin
                        state_r <= S_IDLE;
                     end
               end

            endcase
         end


   // synthesis translate_off
`ifndef SYNTHESIS

   // Assertions
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge sdr_clk)
      begin
         if ( (sdr_cmd_bst_we_req & sdr_cmd_bst_rd_ack) |
               (sdr_cmd_bst_rd_req & sdr_cmd_bst_we_ack) )
            $fatal (1, "BUG ON: DRAM_ctrl");

         if ((dbus_BVALID & ~dbus_BREADY) |
               (ibus_BVALID & ~ibus_BREADY))
            $fatal(1, "TODO: Bus waiting while BVALID is asserted high is currently unsupported!");
      end
`endif

`endif
   // synthesis translate_on


endmodule
