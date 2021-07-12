
#include "verilated.h"
#include "Vdram.h"  
#include <cstdio>
#include <cstdint>

#ifdef VM_TRACE
#include <verilated_vcd_c.h>
static VerilatedVcdC* fp;
#endif

static Vdram* dut;

void test_write(int time, uint16_t addr, uint64_t dat)
{
    dut->i_we = 0xff;
    dut->i_addr = addr;
    dut->i_dat = dat;
#ifdef VM_TRACE
    fp->dump(time * 3 + 1);
#endif
    dut->clk = 1;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 2);
#endif

    dut->clk = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 3);
#endif
}

void test_read(int time, uint16_t addr, uint64_t dat)
{
    dut->i_we = 0;
    dut->i_addr = addr;
#ifdef VM_TRACE
    fp->dump(time * 3 + 1);
#endif
    dut->clk = 1;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 2);
#endif

    if (dut->o_dat != dat) {
        printf("Reaout error! %#lx !== %#lx\n", dat, dut->o_dat);
        //exit(1);
    }

    dut->clk = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 3);
#endif
}


int main()
{
    dut = new Vdram;  //instantiating module top

    dut->rst = 0;
    dut->clk = 0;
    dut->eval();
    
#ifdef VM_TRACE
    ////// !!!  ATTENTION  !!!//////
    //  Call Verilated::traceEverOn(true) first.
    //  Then create a VerilatedVcdC object.    
    Verilated::traceEverOn(true);
    printf("Enabling waves ...\n");
    fp = new VerilatedVcdC;     //instantiating .vcd object   
    dut->trace(fp, 99);     //trace 99 levels of hierarchy
    fp->open("vlt_dump.vcd");   
    fp->dump(0);
#endif

    uint16_t limit = 512;
    int cycle=0;
    for(uint16_t i=0; i<limit;i++) {
        test_write(cycle++, i,i);
    }
    for(uint16_t i=0; i<limit;i++) {
        test_read(cycle++, i,i);
    }
#ifdef VM_TRACE
    fp->close();
    delete fp;
#endif
    delete dut;
    return 0;
}
