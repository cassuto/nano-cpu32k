#include <cstdio>
#include <string.h>
#include "Vtop.h"
#ifdef VM_TRACE
#include <verilated_vcd_c.h>
#endif

int main()
{
    Vtop* dut_ptr = new Vtop; //design under test
    uint32_t cycles;
    int n = 5;  //test times

#ifdef VM_TRACE
    VerilatedVcdC* tfp;
    Verilated::traceEverOn(true);   //verilator must compute traced signals
    VL_PRINTF("Enabling waves...\n");
    tfp = new VerilatedVcdC;
    dut_ptr->trace(tfp, 99);         //trace 99 levels of hierarchy
    tfp->open("vlt_dump.vcd");     //open the dump file
#endif

    while(n--){
        int i = scanf("%d %d", &dut_ptr->io_a, &dut_ptr->io_b);
        dut_ptr->clock = 0;
        dut_ptr->eval();
        dut_ptr->clock = 1;
        dut_ptr->eval();
#ifdef VM_TRACE
        tfp->dump(cycles);
#endif
        cycles++;
        printf("%d + %d = %d\n", dut_ptr->io_a, dut_ptr->io_b, dut_ptr->io_out);
    }
#ifdef VM_TRACE
      tfp->close();
#endif
    return 0;
}

/*
8.8
*/