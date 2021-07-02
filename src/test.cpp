//test.cpp
#include "verilated.h"     //Defines common routines
#include "Vtop.h"  
#include <cstdio>

#ifdef VM_TRACE         // --trace
#include <verilated_vcd_c.h>
VerilatedVcdC* fp;      //to form *.vcd file
#endif

Vtop* dut_ptr;   //design under test of half_adder

void test(int time)
{
    int ret = scanf("%hhd %hhd", &dut_ptr->in_a, &dut_ptr->in_b);
    dut_ptr->eval();
#ifdef VM_TRACE
    fp->dump(time + 1);
#endif
    printf("%d + %d = %d , carry = %d\n", dut_ptr->in_a, dut_ptr->in_b, dut_ptr->out_s, dut_ptr->out_c);
}

int main()
{
    dut_ptr = new Vtop;  //instantiating module half_adder
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
    int times = 0;
    printf("Enter the test times:\t");
    int ret = scanf("%d", &times);
    for (int i = 0; i < times; i++) {
        test(i);
    }
#ifdef VM_TRACE
    fp->dump(times + 1);
    fp->close();
    delete fp;
#endif
    delete dut_ptr;
    return 0;
}
