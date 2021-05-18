/**@file
 * Tracer for simulation validation
 */

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

`ifdef NCPU_ENABLE_TRACER

module ncpu32k_tracer
#(
   parameter CONFIG_DBUS_AW
   `PARAM_NOT_SPECIFIED
)
(
   input                      clk,
   input                      stall_bck,
   // WB 1st slot (LISTENING)
   input                      wb_slot_1_BVALID,
   input                      wb_slot_1_rd_we,
   input [`NCPU_REG_AW-1:0]   wb_slot_1_rd_addr,
   input [`NCPU_DW-1:0]       wb_slot_1_dout,
   input [`NCPU_AW-3:0]       wb_slot_1_pc,
   // WB 2rd slot (LISTENING)
   input                      wb_slot_2_BVALID,
   input                      wb_slot_2_rd_we,
   input [`NCPU_REG_AW-1:0]   wb_slot_2_rd_addr,
   input [`NCPU_DW-1:0]       wb_slot_2_dout,
   input [`NCPU_AW-3:0]       wb_slot_2_pc
);

   // synthesis translate_off
`ifndef SYNTHESIS

   integer fp_trace;
   integer fp_trace_arf;
   integer fp_trace_lsu;
   integer feof_trace_arf;
   integer feof_trace_lsu;
   integer cfg_enable_compare;
   integer cfg_log_on_display;
   integer cfg_log_on_file;
   integer cfg_terminate_when_mismatch;

   initial
      begin
         // Configurations
         cfg_enable_compare = 0;
         cfg_log_on_display = 1;
         cfg_log_on_file = 0;
         cfg_terminate_when_mismatch = 1;

         if (cfg_log_on_file)
            fp_trace = $fopen("trace_sim.txt", "w");
         
         fp_trace_arf = $fopen("traces/coremark.arf", "r");
         feof_trace_arf = 0;
         if (!fp_trace_arf)
            begin
               $display("Warning: Can't not open trace source file for ARF to compare the result!");
               feof_trace_arf = 1;
            end
         
         fp_trace_lsu = $fopen("traces/coremark.lsu", "r");
         feof_trace_lsu = 0;
         if (!fp_trace_lsu)
            begin
               $display("Warning: Can't not open trace source file for LSU to compare the result!");
               feof_trace_lsu = 1;
            end
      end

   //
   // Compare ARF operation sequence with given trace file
   //
   task trace_compare_arf;
      input [`NCPU_REG_AW-1:0]   wb_rd_addr;
      input [`NCPU_DW-1:0]       wb_dout;
      input [`NCPU_AW-3:0]       wb_pc;
      if (cfg_enable_compare)
         begin : cmp_arf
            integer org_wb_pc;
            integer org_wb_rd_addr;
            integer org_wb_dout;

            if (cfg_log_on_file)
               $fwrite(fp_trace, "%08x %02x %08x\n", wb_pc*4, wb_rd_addr, wb_dout);

            if (!feof_trace_arf)
               if ($fscanf(fp_trace_arf, "%x %x %x", org_wb_pc, org_wb_rd_addr, org_wb_dout) != 3)
                  feof_trace_arf = 1;

            if (feof_trace_arf)
               begin
                  if (cfg_log_on_display)
                     $display("UNKNOWN %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);
               end
            else
               begin
                  if (org_wb_pc != wb_pc*4 ||
                     org_wb_rd_addr != wb_rd_addr ||
                     org_wb_dout != wb_dout)
                     begin
                        if (cfg_log_on_display)
                           $display("DIE %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);

                        if (cfg_terminate_when_mismatch)
                           $fatal(1, "Expected %08x %02x %08x",
                                 org_wb_pc, org_wb_rd_addr, org_wb_dout);
                        else
                           $display("Expected %08x %02x %08x",
                                 org_wb_pc, org_wb_rd_addr, org_wb_dout);
                     end
                  else
                     begin
                        if (cfg_log_on_display)
                           $display("PASS %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);
                     end
               end
         end
   endtask

   //
   // Compare LSU operation sequence with given trace file
   //
   task trace_compare_lsu;
      input [CONFIG_DBUS_AW-1:0] paddr;
      input                      lsu_store;
      input [2:0]                lsu_size;
      input [`NCPU_DW-1:0]       lsu_val;
      input [`NCPU_AW-3:0]       lsu_pc;
      if (cfg_enable_compare)
         begin : cmp_arf
            /*integer org_wb_pc;
            integer org_wb_rd_addr;
            integer org_wb_dout;

            if (cfg_log_on_file)
               $fwrite(fp_trace, "%08x %02x %08x\n", wb_pc*4, wb_rd_addr, wb_dout);

            if (!feof_trace_arf)
               if ($fscanf(fp_trace_arf, "%x %x %x", org_wb_pc, org_wb_rd_addr, org_wb_dout) != 3)
                  feof_trace_arf = 1;

            if (feof_trace_arf)
               begin
                  if (cfg_log_on_display)
                     $display("UNKNOWN %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);
               end
            else
               begin
                  if (org_wb_pc != wb_pc*4 ||
                     org_wb_rd_addr != wb_rd_addr ||
                     org_wb_dout != wb_dout)
                     begin
                        if (cfg_log_on_display)
                           $display("DIE %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);

                        if (cfg_terminate_when_mismatch)
                           $fatal(1, "Expected %08x %02x %08x",
                                 org_wb_pc, org_wb_rd_addr, org_wb_dout);
                        else
                           $display("Expected %08x %02x %08x",
                                 org_wb_pc, org_wb_rd_addr, org_wb_dout);
                     end
                  else
                     begin
                        if (cfg_log_on_display)
                           $display("PASS %08x %02x %08x", wb_pc*4, wb_rd_addr, wb_dout);
                     end
               end*/
         end
   endtask

   always @(posedge clk)
      if (~stall_bck)
         begin
            if (wb_slot_1_BVALID & wb_slot_1_rd_we)
               begin
                  trace_compare_arf(wb_slot_1_rd_addr, wb_slot_1_dout, wb_slot_1_pc);
               end
            if (wb_slot_2_BVALID & wb_slot_2_rd_we)
               begin
                  trace_compare_arf(wb_slot_2_rd_addr, wb_slot_2_dout, wb_slot_2_pc);
               end
         end
`endif
   // synthesis translate_on

endmodule

`endif
