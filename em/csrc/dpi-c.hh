#ifndef DPI_C_HH_
#define DPI_C_HH_

#include "common.hh"
#include "Vsimtop.h"

extern "C" void dpic_sync_irqc(
    int irqc_irr
);

extern "C" void dpic_commit_inst(
    int cmt_index,
    svBit valid,
    int pc,
    int insn,
    svBit wen,
    char wnum,
    int wdata,
    svBit excp
);

extern "C" void dpic_step();

extern void startup_difftest(CPU *cpu_, Emu *emu_, uint64_t commit_timeout_max_);

#endif // DPI_C_HH_
