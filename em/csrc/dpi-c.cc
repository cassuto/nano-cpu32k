
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

void enable_difftest(CPU *cpu_, Emu *emu_, uint64_t commit_timeout_max_)
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

static void difftest_report_pc(vm_addr_t right, vm_addr_t wrong)
{
    fprintf(stderr, "Verilog PC:\n");
    rtl_pc_queue->dump();
    fprintf(stderr, "Emu PC:\n");
    dpic_emu_CPU->get_pc_queue()->dump();

    fprintf(stderr, "--------------------------------------------------------------\n");
    fprintf(stderr, "[%lu cycle] PC Error!\n", dpic_emu->get_cycle());
    fprintf(stderr, "    reference: PC = 0x%08x\n",
            right);
    fprintf(stderr, "    mycpu    : PC = 0x%08x\n",
            wrong);
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

static void difftest_report_reg(svBit valid1, svBit valid2, int pc1, int pc2)
{
    fprintf(stderr, "Verilog PC:\n");
    rtl_pc_queue->dump();
    fprintf(stderr, "Emu PC:\n");
    dpic_emu_CPU->get_pc_queue()->dump();

    fprintf(stderr, "--------------------------------------------------------------\n");
    fprintf(stderr, "[%lu cycle] Architectural Register Error!\n", dpic_emu->get_cycle());
    if (valid1)
        fprintf(stderr, "At pc[1] = %#8x\n", pc1);
    if (valid2)
        fprintf(stderr, "At pc[2] = %#8x\n", pc2);
    fprintf(stderr, "--------------------------------------------------------------\n");
    difftest_compare_reg(true);
}

void dpic_commit_inst(
    svBit valid1,
    int pc1,
    svBit wen1,
    char wnum1,
    int wdata1,
    svBit valid2,
    int pc2,
    svBit wen2,
    char wnum2,
    int wdata2,
    svBit EINT1,
    svBit EINT2)
{
    if (!dpic_enable)
        return;

    if (valid1)
        rtl_num_commit++;
    if (valid2)
        rtl_num_commit++;
    if (valid1 | valid2)
        rtl_last_commit_cycle = dpic_emu->get_cycle();
    if (dpic_emu->get_cycle() - rtl_last_commit_cycle > rtl_commit_timeout_max)
    {
        fprintf(stderr, "No commit after %ld cycles\n", dpic_emu->get_cycle() - rtl_last_commit_cycle);
        difftest_terminate();
        return;
    }

    if (dpic_emu->get_cycle() % 100000 == 0)
        fprintf(stderr, "[%ld] emu PC = %#x rtl PC=%#x\n", dpic_emu->get_cycle(), dpic_emu_CPU->get_pc(), rtl_pc);

    bool validated = true;
    if (valid1)
    {
        rtl_pc = pc1;
        rtl_pc_queue->push(pc1, 0); // FIXME
        if (wen1)
            rtl_regfile[wnum1] = wdata1;
            printf("wen1=%d wnum1=%d wdata1=%#x\n", wen1, wnum1, wdata1);

        vm_addr_t emu_pc = dpic_emu_CPU->get_pc();
        vm_addr_t emu_npc = dpic_emu_CPU->step(emu_pc);
        dpic_emu_CPU->set_pc(emu_npc);

        if (pc1 != emu_pc)
        {
            difftest_report_pc(emu_pc, pc1);
            validated = false;
        }
    }
    if (valid2)
    {
        rtl_pc = pc2;
        rtl_pc_queue->push(pc2, 0); // FIXME
        if (wen2)
            rtl_regfile[wnum2] = wdata2;
            printf("wen2=%d wnum2=%d wdata2=%#x\n", wen2, wnum2, wdata2);

        vm_addr_t emu_pc = dpic_emu_CPU->get_pc();
        vm_addr_t emu_npc = dpic_emu_CPU->step(emu_pc);
        dpic_emu_CPU->set_pc(emu_npc);

        if (pc2 != emu_pc)
        {
            difftest_report_pc(emu_pc, pc2);
            validated = false;
        }
    }
    if (difftest_compare_reg(false))
    {
        if (validated)
            difftest_report_reg(valid1, valid2, pc1, pc2);
        validated = false;
    }

    if (!validated)
    {
        difftest_terminate();
    }
}

void dpic_clk(
    int msr_tsr)
{
}

void dpic_regfile(
    int r0,
    int r1,
    int r2,
    int r3,
    int r4,
    int r5,
    int r6,
    int r7,
    int r8,
    int r9,
    int r10,
    int r11,
    int r12,
    int r13,
    int r14,
    int r15,
    int r16,
    int r17,
    int r18,
    int r19,
    int r20,
    int r21,
    int r22,
    int r23,
    int r24,
    int r25,
    int r26,
    int r27,
    int r28,
    int r29,
    int r30,
    int r31)
{
    /*rtl_regfile[0] = r0;
    rtl_regfile[1] = r1;
    rtl_regfile[2] = r2;
    rtl_regfile[3] = r3;
    rtl_regfile[4] = r4;
    rtl_regfile[5] = r5;
    rtl_regfile[6] = r6;
    rtl_regfile[7] = r7;
    rtl_regfile[8] = r8;
    rtl_regfile[9] = r9;
    rtl_regfile[10] = r10;
    rtl_regfile[11] = r11;
    rtl_regfile[12] = r12;
    rtl_regfile[13] = r13;
    rtl_regfile[14] = r14;
    rtl_regfile[15] = r15;
    rtl_regfile[16] = r16;
    rtl_regfile[17] = r17;
    rtl_regfile[18] = r18;
    rtl_regfile[19] = r19;
    rtl_regfile[20] = r20;
    rtl_regfile[21] = r21;
    rtl_regfile[22] = r22;
    rtl_regfile[23] = r23;
    rtl_regfile[24] = r24;
    rtl_regfile[25] = r25;
    rtl_regfile[26] = r26;
    rtl_regfile[27] = r27;
    rtl_regfile[28] = r28;
    rtl_regfile[29] = r29;
    rtl_regfile[30] = r30;
    rtl_regfile[31] = r31;*/
}