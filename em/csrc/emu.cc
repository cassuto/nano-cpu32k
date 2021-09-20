/***************************************************************************************
* This code is based on XiangShan-difftest project.
*
* Copyright (c) 2020-2021 Institute of Computing Technology, Chinese Academy of Sciences
* Copyright (c) 2020-2021 Peng Cheng Laboratory
*
* XiangShan is licensed under Mulan PSL v2.
* You can use this software according to the terms and conditions of the Mulan PSL v2.
* You may obtain a copy of Mulan PSL v2 at:
*          http://license.coscl.org.cn/MulanPSL2
*
* THIS SOFTWARE IS PROVIDED ON AN "AS IS" BASIS, WITHOUT WARRANTIES OF ANY KIND,
* EITHER EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO NON-INFRINGEMENT,
* MERCHANTABILITY OR FIT FOR A PARTICULAR PURPOSE.
*
* See the Mulan PSL v2 for more details.
***************************************************************************************/

#include "Vsimtop.h"
#include <verilated_vcd_c.h>
#include "cpu.hh"
#include "memory.hh"
#include "peripheral/axi4.hh"
#include "peripheral/axi4-crossbar.hh"
#include "emu.hh"

Emu::Emu(const char *vcdfile_,
         uint64_t wave_start_, uint64_t wave_end_,
         CPU *cpu_,
         Memory *mem_)
    : dut_ptr(new Vsimtop()),
      vcdfile(vcdfile_),
      wave_begin(wave_start_),
      wave_end(wave_end_),
      num_inst_commit(0),
      cycles(0),
      cpu(cpu_),
      axi_crossbar(new Axi4Crossbar(mem_)),
      trace_fp(nullptr)
{
    reset(10);

#if VM_TRACE == 1
    if (!vcdfile.empty())
    {
        Verilated::traceEverOn(true); // Verilator must compute traced signals
        trace_fp = new VerilatedVcdC;
        dut_ptr->trace(trace_fp, 99); // Trace 99 levels of hierarchy
        trace_fp->open(vcdfile.c_str());
        fprintf(stderr, "Dump VCD to %s (%lu-%lu)\n", vcdfile.c_str(), wave_begin, wave_end);
    }
#endif
}

Emu::~Emu()
{
    delete dut_ptr;
    delete axi_crossbar;
}

void Emu::reset(int cycles)
{
    dut_ptr->reset = 1;
    for (int i = 0; i < cycles; i++)
    {
        dut_ptr->clock = 0;
        dut_ptr->eval();
        dut_ptr->clock = 1;
        dut_ptr->eval();
    }
    dut_ptr->reset = 0;
}

bool Emu::clk()
{
    if (Verilated::gotFinish())
        return true;

    dut_ptr->clock = 0;
    dut_ptr->eval();

    axi_channel axi;
    axi_copy_from_dut_ptr(dut_ptr, axi);
    axi_crossbar->clk_rising(axi);

    dut_ptr->clock = 1;
    dut_ptr->eval();

    axi_copy_from_dut_ptr(dut_ptr, axi);
    axi_crossbar->clk_falling(axi);
    axi_set_dut_ptr(dut_ptr, axi);
    dut_ptr->eval();

    if (dut_ptr->break_point)
        fprintf(stderr, "[%lu] Hit RTL break point!\n", cycles);

#if VM_TRACE == 1
    if (trace_fp)
    {
        bool in_range = (wave_begin <= cycles) && (cycles <= wave_end);
        if (in_range)
        {
            trace_fp->dump(cycles);
            trace_fp->flush();
        }
    }
#endif

    cycles++;

    return false;
}

void Emu::finish()
{
#if VM_TRACE == 1
    if (trace_fp)
        trace_fp->close();
#endif
}
