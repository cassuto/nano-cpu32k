
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

static void difftest_report_reg(int num_commit, svBit valid[], int pc[])
{
    fprintf(stderr, "Verilog PC:\n");
    rtl_pc_queue->dump();
    fprintf(stderr, "Emu PC:\n");
    dpic_emu_CPU->get_pc_queue()->dump();

    fprintf(stderr, "--------------------------------------------------------------\n");
    fprintf(stderr, "[%lu cycle] Architectural Register Error!\n", dpic_emu->get_cycle());
    for (int i = 0; i < num_commit; i++)
    {
        if (valid[i])
            fprintf(stderr, "At pc[%d] = %#8x\n", i + 1, pc[i]);
    }
    difftest_compare_reg(true);
    fprintf(stderr, "--------------------------------------------------------------\n");
}

void dpic_commit_inst(
    svBit valid1,
    int pc1,
    int insn1,
    svBit wen1,
    char wnum1,
    int wdata1,
    svBit valid2,
    int pc2,
    int insn2,
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
        fprintf(stderr, "[%ld] No commit after %ld cycles\n", rtl_last_commit_cycle, dpic_emu->get_cycle() - rtl_last_commit_cycle);
        difftest_terminate();
        return;
    }

    if (dpic_emu->get_cycle() % 100000 == 0)
        fprintf(stderr, "[%ld] emu PC = %#x rtl PC=%#x\n", dpic_emu->get_cycle(), dpic_emu_CPU->get_pc(), rtl_pc);

    const int num_commit = 2;

    svBit valid[num_commit];
    int pc[num_commit];
    int insn[num_commit];
    svBit wen[num_commit];
    char wnum[num_commit];
    int wdata[num_commit];

    /* Hardcoded number of commit */
    valid[0] = valid1;
    valid[1] = valid2;
    pc[0] = pc1;
    pc[1] = pc2;
    insn[0] = insn1;
    insn[1] = insn2;
    wen[0] = wen1;
    wen[1] = wen2;
    wnum[0] = wnum1;
    wnum[1] = wnum2;
    wdata[0] = wdata1;
    wdata[1] = wdata2;

    bool validated = true;
    for (int i = 0; i < num_commit; i++)
    {
        if (valid[i])
        {
            rtl_pc = pc[i];
            rtl_pc_queue->push(pc[i], insn[i]);
            if (wen[i])
                rtl_regfile[(unsigned)wnum[i]] = wdata[i];

            bool emu_excp;
            insn_t emu_insn;
            vm_addr_t emu_pc = dpic_emu_CPU->get_pc();
            vm_addr_t emu_npc = dpic_emu_CPU->step(emu_pc, &emu_excp, &emu_insn);
            dpic_emu_CPU->set_pc(emu_npc);

            if (pc[i] != emu_pc)
            {
                difftest_report_item("PC", emu_pc, pc[i]);
                validated = false;
                break;
            }
            if (!emu_excp && insn[i] != emu_insn)
            {
                difftest_report_item("INST", emu_insn, insn[i]);
                validated = false;
                break;
            }
        }
    }

    if (difftest_compare_reg(false))
    {
        if (validated)
            difftest_report_reg(num_commit, valid, pc);
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