
`include "ncpu32k_config.h"

module tb_ncpu32k_sram();

   //
   // Driving source
   //
   reg clk_50;
   reg rst_n;

   wire clk;

   // Generate Clock
   initial begin
      clk_50 = 1'b0;
      forever #10 clk_50 = ~clk_50;
   end
   assign clk = clk_50;

   // Generate reset
   initial begin
      rst_n = 1'b0;
      #10 rst_n= 1'b1;
      #450 $stop;
   end
   
   // Instruction memory.
   localparam InsnMemLen = 64 * 1024; // Bytes
   reg[7:0] insn_mem[0:InsnMemLen-1];

   initial $readmemh ("insn.mem", insn_mem);

   wire                insn_rd;
   wire [`NCPU_AW-1:0] insn_addr;
   wire [`NCPU_AW-1:0] insn_ram_addr = insn_addr;
   wire [`NCPU_IW-1:0] insn =  {insn_mem[insn_ram_addr+3][7:0],
                           insn_mem[insn_ram_addr+2][7:0],
                           insn_mem[insn_ram_addr+1][7:0],
                           insn_mem[insn_ram_addr][7:0]};
   wire insn_ready = 1'b1;

   ncpu32k_core ncpu32k_inst(
      .clk_i         (clk),
      .rst_n_i       (rst_n),
      .d_i           (),  // data
      .insn_i        (insn), // instruction
      .insn_ready_i  (insn_ready), // Insn bus is ready
      .dbus_rd_ready_i(), // Data bus Dout is ready
      .dbus_we_done_i(), // Data bus Writing is done
      .d_o           (),	// data
      .addr_o        (), // data address
      .dbus_rd_o     (), // data bus ReadEnable
      .dbus_we_o     (), // data bus WriteEnable
      .iaddr_o       (insn_addr), // instruction address
      .ibus_rd_o     (insn_rd) // instruction bus ReadEnable
   );

endmodule
