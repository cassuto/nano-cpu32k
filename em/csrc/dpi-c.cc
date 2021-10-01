
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

#include "cpu.hh"
#include "emu.hh"
#include "pc-queue.hh"
#include "dpi-c.hh"
#include <verilated_vcd_c.h>

static bool dpic_enable;
static CPU *dpic_emu_CPU;
static Emu *dpic_emu;
static cpu_word_t rtl_regfile[32];
static vm_addr_t rtl_pc;
static uint64_t rtl_num_commit, rtl_last_commit_cycle, rtl_commit_timeout_max;
static PCQueue *rtl_pc_queue;
static const int rtl_num_channel = 2;
static svBit rtl_valid[rtl_num_channel];
static int rtl_cmt_pc[rtl_num_channel];
static int rtl_insn[rtl_num_channel];
static svBit rtl_wen[rtl_num_channel];
static char rtl_wnum[rtl_num_channel];
static int rtl_wdata[rtl_num_channel];

void startup_difftest(CPU *cpu_, Emu *emu_, uint64_t commit_timeout_max_)
{
    dpic_enable = true;
    dpic_emu_CPU = cpu_;
    dpic_emu = emu_;
    rtl_num_commit = 0;
    if (!rtl_pc_queue)
        rtl_pc_queue = new PCQueue();
    rtl_commit_timeout_max = commit_timeout_max_;
}

static void difftest_terminate()
{
    dpic_enable = false;
    for (int i = 0; i < 10; i++)
        if (dpic_emu->clk())
            break;

    dpic_emu->finish();
    panic(0);
}

static void difftest_report_item(const char *item, cpu_unsigned_word_t right, cpu_unsigned_word_t wrong)
{
    fprintf(stderr, "Verilog PC:\n");
    rtl_pc_queue->dump();
    fprintf(stderr, "Emu PC:\n");
    dpic_emu_CPU->get_pc_queue()->dump();

    fprintf(stderr, "--------------------------------------------------------------\n");
    fprintf(stderr, "[%lu cycle] PC Error!\n", dpic_emu->get_cycle());
    fprintf(stderr, "%s different: (right = %#8x, wrong = %#8x)\n", item, right, wrong);
    fprintf(stderr, "--------------------------------------------------------------\n");
}

static bool difftest_compare_reg(bool verbose)
{
    for (int i = 0; i < 32; i++)
    {
        cpu_word_t right = dpic_emu_CPU->get_reg(i);
        if (rtl_regfile[i] != right)
        {
            if (verbose)
                fprintf(stderr, "r%d different: (right = %#8x, wrong = %#8x)\n", i, right, rtl_regfile[i]);
            return true;
        }
    }
    return false;
}

static void difftest_report_reg(svBit valid[], int pc[])
{
    fprintf(stderr, "Verilog PC:\n");
    rtl_pc_queue->dump();
    fprintf(stderr, "Emu PC:\n");
    dpic_emu_CPU->get_pc_queue()->dump();

    fprintf(stderr, "Reference registers: (Next PC=%#X)\n", dpic_emu_CPU->get_pc());
    for (int i = 0; i < 32; i++)
    {
        cpu_word_t right = dpic_emu_CPU->get_reg(i);
        fprintf(stderr, "r%-2d = %-8x%c", i, right, ((i+1)%4==0 ? '\n' : ' '));
    }
    fprintf(stderr, "\n");

    fprintf(stderr, "--------------------------------------------------------------\n");
    fprintf(stderr, "[%lu cycle] Architectural Register Error!\n", dpic_emu->get_cycle());
    for (int i = 0; i < rtl_num_channel; i++)
    {
        if (valid[i])
            fprintf(stderr, "At pc[%d] = %#8x\n", i + 1, pc[i]);
    }
    difftest_compare_reg(true);
    fprintf(stderr, "--------------------------------------------------------------\n");
}

void dpic_sync_irqc(int irqc_irr)
{
    if (!dpic_enable)
        return;

    /* Synchronize the asynchronous exception from RTL */
    dpic_emu_CPU->irqc_set_irr(irqc_irr);
}

void dpic_commit_inst(
    int cmt_index,
    svBit valid,
    int pc,
    int insn,
    svBit wen,
    char wnum,
    int wdata)
{
    if (!dpic_enable)
        return;
    assert((unsigned int)cmt_index < rtl_num_channel);

    rtl_valid[(unsigned int)cmt_index] = valid;
    rtl_cmt_pc[(unsigned int)cmt_index] = pc;
    rtl_insn[(unsigned int)cmt_index] = insn;
    rtl_wen[(unsigned int)cmt_index] = wen;
    rtl_wnum[(unsigned int)cmt_index] = wnum;
    rtl_wdata[(unsigned int)cmt_index] = wdata;
}

void dpic_step()
{
    if (!dpic_enable)
        return;

    bool has_inst_committed = false;
    for (int i = 0; i < rtl_num_channel; i++)
        if (rtl_valid[i])
        {
            rtl_num_commit++;
            has_inst_committed = true;
        }

    if (dpic_emu->get_cycle() - rtl_last_commit_cycle > rtl_commit_timeout_max)
    {
        fprintf(stderr, "[%ld] No instruction commits after %ld cycles\n", rtl_last_commit_cycle, dpic_emu->get_cycle() - rtl_last_commit_cycle);
        difftest_terminate();
        return;
    }

    if (dpic_emu->get_cycle() % 100000 == 0)
        fprintf(stderr, "[%ld] emu PC = %#x rtl PC=%#x\n", dpic_emu->get_cycle(), dpic_emu_CPU->get_pc(), rtl_pc);

    if (!has_inst_committed)
        return;

    rtl_last_commit_cycle = dpic_emu->get_cycle();

    bool validated = true;
    for (int i = 0; i < rtl_num_channel; i++)
    {
        if (rtl_valid[i])
        {
            rtl_pc = rtl_cmt_pc[i];
            rtl_pc_queue->push(rtl_cmt_pc[i], rtl_insn[i]);
            if (rtl_wen[i])
            {
                if (rtl_wnum[i] == 0)
                {
                    fprintf(stderr, "BUG ON: Invalid writing to r0 reg!\n");
                    validated = false;
                    break;
                }
                rtl_regfile[(unsigned)rtl_wnum[i]] = rtl_wdata[i];
            }

            /* Handle RMSR carefully */
            if (INS32_GET_BITS(rtl_insn[i], OPCODE) == INS32_OP_RMSR)
            {
                uint8_t rs1 = INS32_GET_BITS(rtl_insn[i], RS1);
                uint8_t rd = INS32_GET_BITS(rtl_insn[i], RD);
                uint16_t uimm15 = INS32_GET_BITS(rtl_insn[i], IMM15);
                cpu_unsigned_word_t val = rtl_regfile[rd];
                switch (rtl_regfile[rs1] | uimm15)
                {
                case MSR_TSR:
                    /* Synchronize the value of TSR before reading */
                    dpic_emu_CPU->msr_set_tsr(val);
                    break;
                }
            }

            ArchEvent emu_event;
            vm_addr_t emu_pc = dpic_emu_CPU->get_pc();
            vm_addr_t emu_npc = dpic_emu_CPU->step(emu_pc, true, &emu_event);
            dpic_emu_CPU->set_pc(emu_npc);

            if (rtl_cmt_pc[i] != emu_pc)
            {
                difftest_report_item("PC", emu_pc, rtl_cmt_pc[i]);
                validated = false;
                break;
            }
            if (!emu_event.excp && rtl_insn[i] != emu_event.insn)
            {
                difftest_report_item("INST", emu_event.insn, rtl_insn[i]);
                validated = false;
                break;
            }
        }
    }

    if (difftest_compare_reg(false))
    {
        if (validated)
            difftest_report_reg(rtl_valid, rtl_cmt_pc);
        validated = false;
    }

    if (!validated)
    {
        difftest_terminate();
    }
}
