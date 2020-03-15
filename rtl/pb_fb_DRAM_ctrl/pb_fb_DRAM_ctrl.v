/***************************************************************************/
/*  Nano-cpu 32000 (Scalable Ultra-Low-Power Processor)                    */
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

module pb_fb_DRAM_ctrl
#(
   // SDRAM bus parameters
   parameter COL_BW = 9,  // Column bits
   parameter ROW_BW = 13, // Row bits
   parameter BA_BW = 2,  // Bank bits
   parameter DW = 16, // Word bits
   parameter DRAM_AW = 13, // Address bus bits
   parameter N_BW = 1, // = floor(log2(DW/8))
   
   // SDRAM timing parameters
   parameter tRP = 3,
   parameter tMRD = 2,
   parameter tRCD = 3,
   parameter tRC = 9,
   parameter tREF = 64, // ms
   parameter pREF = 9, // = floor(log2(Fclk*tREF/(2^ROW_BW)))
   parameter nCAS_Latency = 3, // CAS latency
   
   // Brust Length
   parameter BRUST_RD_LENGTH = 7'h20, // 32 x DW bits
   parameter BRUST_WE_LENGTH = 7'h20  // 32 x DW bits
)
(
   input                   clk,
   input                   rst_n,
   // SDRAM interface
   output                  DRAM_CKE,
   output reg [3:0]        DRAM_CS_WE_RAS_CAS_L, // SDRAM #CS, #WE, #RAS, #CAS
   output reg [BA_BW-1:0]  DRAM_BA, // SDRAM bank address
   output reg [DRAM_AW-1:0] DRAM_ADDR, // SDRAM address
   inout      [DW-1:0]     DRAM_DATA, // SDRAM data
   output reg [1:0]        DRAM_DQM, // SDRAM DQM
   
   // Cmd/Resp interface
   input                   cmd_bst_we_req,
   output reg              cmd_bst_we_ack,
   input                   cmd_bst_rd_req,
   output reg              cmd_bst_rd_ack,
   input [ROW_BW+BA_BW+COL_BW-N_BW-1:0] cmd_addr, // Algin at 2^N_BW words boundary
   input [DW-1:0]          din,
   output reg [DW-1:0]     dout,
   output reg              r_vld,   // dout valid
   output reg              w_rdy   // write ready
);

   // I/O flip flops
   reg [DW-1:0] din_r;   
   reg [2:0] dout_vld_r;

   always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
         dout_vld_r <= 0;
      end else begin
         dout_vld_r <= {dout_vld_r[1:0], w_rdy};
         din_r <= din;
         dout <= DRAM_DATA;
      end
   end
   
   assign DRAM_DATA = dout_vld_r[2] ? din_r : 16'hzzzz;

   assign DRAM_CKE = 1'b1;
   
   // Address ffs
   reg [COL_BW-N_BW-1:0] col_adr_r;
   reg [BA_BW-1:0] bank_adr_r;
   reg [ROW_BW-1:0] line_adr_r;

   // Book active
   reg [ROW_BW-1:0] line_prech_r[3:0];
   reg [(1<<BA_BW)-1:0] bank_act_r;
   
   // Main FSM
   localparam S_IDLE = 0;
   localparam S_NOP = 1;
   localparam S_PRECHARGE = 2;
   localparam S_LOAD_MODE = 3;
   localparam S_AUTO_REFRESH = 4;
   localparam S_WRITE_READ = 5;
   localparam S_END_WRITE_READ = 6;
   localparam S_INIT_WRITE_READ = 7;

   reg [2:0] status_r;
   reg [2:0] status_ret_r;
   reg [6:0] status_delay_r;

   reg [15:0] rf_cnt_r;
   reg rf_pending_r;
   
   always @(posedge clk or negedge rst_n) begin
      if(~rst_n) begin
         rf_cnt_r <= 0;
         rf_pending_r <= 1;
         status_r <= S_IDLE;
         bank_act_r <= 0;
         r_vld <= 1'b0;
         w_rdy <= 1'b0;
         cmd_bst_we_ack <= 1'b0;
         cmd_bst_rd_ack <= 1'b0;
         DRAM_DQM <= 2'b11;
         DRAM_CS_WE_RAS_CAS_L <= 4'b1111; // NOP
      end else begin
         rf_cnt_r <= rf_cnt_r + 1;
         status_delay_r <= status_delay_r - 1;
         
         // Default values
         DRAM_CS_WE_RAS_CAS_L <= 4'b1111; // NOP
         status_r <= S_NOP;
         
         case(status_r)
            S_IDLE: begin
               r_vld <= 1'b0;
               if(DRAM_DQM[0])
                  // Init sequence, wait >200uS
                  status_r <= rf_cnt_r[15] ? S_PRECHARGE : S_IDLE;
               else begin
                  if(rf_pending_r != rf_cnt_r[pREF]) begin
                     // Refreshing
                     rf_pending_r <= rf_cnt_r[pREF];
                     status_r <= S_PRECHARGE;
                  end else if(cmd_bst_rd_req | cmd_bst_we_req) begin
                     // Accept command. Assert (03141951)
                     cmd_bst_rd_ack <= cmd_bst_rd_req;
                     cmd_bst_we_ack <= cmd_bst_we_req;
                     {line_adr_r, bank_adr_r, col_adr_r} <= cmd_addr;
                     status_r <= S_WRITE_READ;
                  end else begin
                     // Wait for command
                     status_r <= S_IDLE;
                  end
               end
            end

            // NOP for status_delay_r clocks
            S_NOP: begin
               if(status_delay_r == 2)
                  w_rdy <= 1'b0;
               if(status_delay_r == 0)
                  status_r <= status_ret_r; // return to status_ret_r state
             end

            // Precharge all banks
            S_PRECHARGE: begin
               DRAM_CS_WE_RAS_CAS_L <= 4'b0001; // PRECHARGE
               DRAM_ADDR[10] <= 1'b1; // all banks are to be precharged
               status_ret_r <=
                  (
                     // Init sequence: Set Mode Register
                       DRAM_DQM[0] ? S_LOAD_MODE
                     // Common sequence
                     : S_AUTO_REFRESH
                  );
               status_delay_r <= tRP - 2;
               bank_act_r <= 0;
            end

            // Set Mode Register
            S_LOAD_MODE: begin
               DRAM_CS_WE_RAS_CAS_L <= 4'b0000; // LOAD MODE REGISTER
               //
               // Bitmap of Mode Register
               // +==========+===+=====+============+===+===========+
               // | 12 11 10 | 9 | 8 7 | 6 5 4      | 3 |  2 1 0    |
               // | Reserved | WB| OpM | CAS Latency| BT| Brust Len |
               // +==========+===+=====+============+===+===========+
               //
               // Current config:
               //    WB = programmed brust len;
               //    OpM = standard operation;
               //    CAS Latency = nCAS_Latency;
               //    BT = sequential;
               //    Brust Len = full page burst.
               //
               DRAM_ADDR <= 13'b000_0_00_000_0_111 + (nCAS_Latency<<4);
               DRAM_BA <= 2'b00;
               status_ret_r <= S_AUTO_REFRESH;
               status_delay_r <= tMRD - 2;
            end

            // Auto refresh
            S_AUTO_REFRESH: begin
               DRAM_CS_WE_RAS_CAS_L <= 4'b0100; // AUTO REFRESH
               if(rf_pending_r != rf_cnt_r[pREF])
                  status_ret_r <= S_AUTO_REFRESH;
               else begin
                  DRAM_DQM <= 2'b00;
                  status_ret_r <= S_IDLE;
               end
               status_delay_r <= tRC - 2;
            end

            // Read/Write
            S_WRITE_READ: begin
               DRAM_BA <= bank_adr_r;
               if(bank_act_r[bank_adr_r]) begin
                  // If the current line in L-Bank is precharged, then we can open it
                  // Otherwise we should close the last-opened line and then reopen the current.
                  if(line_prech_r[bank_adr_r] == line_adr_r) begin
                     DRAM_ADDR[10] <= 1'b0; // no auto precharge
                     DRAM_ADDR[COL_BW-1:0] <= {col_adr_r, {N_BW{1'b0}}};
                     status_ret_r <= S_INIT_WRITE_READ;
                     if(cmd_bst_rd_ack) begin
                        DRAM_CS_WE_RAS_CAS_L <= 4'b0110; // READ
                        status_delay_r <= nCAS_Latency - 1;
                     end else begin
                        status_delay_r <= 1;
                        // Begin brust writing
                        w_rdy <= 1'b1;
                     end
                  end else begin
                     // bank precharge
                     DRAM_CS_WE_RAS_CAS_L <= 4'b0001; // PRECHARGE
                     DRAM_ADDR[10] <= 1'b0;
                     bank_act_r[bank_adr_r] <= 1'b0;
                     status_ret_r <= S_WRITE_READ;
                     status_delay_r <= tRP - 2;
                  end
               end else begin // bank not activate ?
                  DRAM_CS_WE_RAS_CAS_L <= 4'b0101; // ACTIVE
                  DRAM_ADDR[ROW_BW-1:0] <= line_adr_r;
                  bank_act_r[bank_adr_r] <= 1'b1;
                  line_prech_r[bank_adr_r] <= line_adr_r;
                  status_ret_r <= S_WRITE_READ;
                  status_delay_r <= tRCD - 2;
               end
            end

            // End read/write phase
            S_END_WRITE_READ: begin
               cmd_bst_rd_ack <= 1'b0;
               cmd_bst_we_ack <= 1'b0;
               DRAM_CS_WE_RAS_CAS_L <= 4'b0011;  // BURST TERMINATE
               status_r <= cmd_bst_rd_ack ? S_NOP : S_IDLE; // read write
               status_ret_r <= S_IDLE;
               status_delay_r <= 2;
            end

            // Init read/write phase
            S_INIT_WRITE_READ: begin
               if(cmd_bst_rd_ack)
                  r_vld <= 1'b1;
               else
                  DRAM_CS_WE_RAS_CAS_L <= 4'b0010; // WRITE
               status_ret_r <= S_END_WRITE_READ;
               status_delay_r <= cmd_bst_rd_ack ? BRUST_RD_LENGTH - 6 : BRUST_WE_LENGTH - 2;
            end

         endcase
      end
   end

   
   // synthesis translate_off
`ifndef SYNTHESIS                   
                 
   // Assertions (03141951)
`ifdef NCPU_ENABLE_ASSERT
   always @(posedge clk) begin
      if((cmd_bst_rd_req | cmd_bst_we_req) & ~(cmd_bst_rd_req^cmd_bst_we_req))
         $fatal ("\n conflicting rd and we req.");
   end
`endif

`endif
   // synthesis translate_on
   
   
endmodule
