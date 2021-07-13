#include "tb.h"
#ifdef TESTBENCH_TOP

#include "verilated.h"
#include "Vtop.h"  
#include <cstdio>
#include <cstdint>

#ifdef VM_TRACE
#include <verilated_vcd_c.h>
static VerilatedVcdC* fp;
#endif

static Vtop* dut;

void test(int time)
{
    dut->clk = 1;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 2 + 1);
#endif

    dut->clk = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 2 + 2);
#endif
}

int tb_top_main()
{
    dut = new Vtop;  //instantiating module top

    dut->rst = 1;
    dut->clk = 0;
    dut->eval();
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

    int cycle=100;
    for(uint16_t i=0; i<cycle;i++) {
        test(i);
    }
#ifdef VM_TRACE
    fp->close();
    delete fp;
#endif
    delete dut;
    return 0;
}

#endif
