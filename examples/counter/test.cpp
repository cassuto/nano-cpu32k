//test.cpp
#include "verilated.h"     //Defines common routines
#include "Vtop.h"  
#include <cstdio>

#ifdef VM_TRACE         // --trace
#include <verilated_vcd_c.h>
static VerilatedVcdC* fp;      //to form *.vcd file
#endif

static Vtop* dut_ptr;   //design under test of top

void test(int time)
{
    dut_ptr->clk = 1;
    dut_ptr->eval();

#ifdef VM_TRACE
    fp->dump(time * 2 + 1);
#endif

    dut_ptr->clk = 0;
    dut_ptr->eval();

#ifdef VM_TRACE
    fp->dump(time * 2 + 2);
#endif
}

int main()
{
    dut_ptr = new Vtop;  //instantiating module top

    dut_ptr->reset = 0;
    dut_ptr->clk = 0;
    dut_ptr->eval();
    
#ifdef VM_TRACE
    ////// !!!  ATTENTION  !!!//////
    //  Call Verilated::traceEverOn(true) first.
    //  Then create a VerilatedVcdC object.    
    Verilated::traceEverOn(true);
    printf("Enabling waves ...\n");
    fp = new VerilatedVcdC;     //instantiating .vcd object   
    dut_ptr->trace(fp, 99);     //trace 99 levels of hierarchy
    fp->open("vlt_dump.vcd");   
    fp->dump(0);
#endif

    int cycle = 0;
    printf("Enter the test cycle:\t");
    int ret = scanf("%d", &cycle);
    for (int i = 0; i < cycle; i++) {
        test(i);
    }
#ifdef VM_TRACE
    fp->close();
    delete fp;
#endif
    delete dut_ptr;
    return 0;
}
