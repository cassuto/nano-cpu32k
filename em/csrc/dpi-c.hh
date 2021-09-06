#ifndef DPI_C_HH_
#define DPI_C_HH_

#include "common.hh"
#include "Vsimtop.h"

extern "C" void dpic_commit_inst(
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
    svBit EINT2
);

extern "C" void dpic_clk(
    int msr_tsr
);

extern "C" void dpic_regfile(
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
    int r31
);

extern void enable_difftest(CPU *cpu_, Emu *emu_, uint64_t commit_timeout_max_);

#endif // DPI_C_HH_
