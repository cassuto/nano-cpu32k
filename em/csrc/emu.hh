#ifndef EMU_H_
#define EMU_H_

#include "common.hh"

class Vsimtop;
class VerilatedVcdC;

class Emu
{
public:
    Emu(const char *vcdfile_,
        uint64_t wave_start_, uint64_t wave_end_,
        CPU *cpu_,
        Memory *mem_);
    ~Emu();

    void reset(int cycles);
    bool clk();
    void finish();

    inline uint64_t get_cycle() const { return cycles; }
 
private:
    Vsimtop *dut_ptr;
    std::string vcdfile;
    uint64_t wave_begin, wave_end;
    uint64_t num_inst_commit;
    uint64_t cycles;
    CPU *cpu;
    DRAM *dram;
    VerilatedVcdC *trace_fp;
};

#endif