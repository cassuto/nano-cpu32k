#include "tb.h"

int main()
{
    int ret = 0;
#ifdef TESTBENCH_DRAM
    if ((ret = tb_dram_main()))
        return ret;
#endif
#ifdef TESTBENCH_ALU
    if ((ret = tb_alu_main()))
        return ret;
#endif
#ifdef TESTBENCH_CPU
   if ((ret = tb_cpu_main()))
        return ret;
#endif

    return 0;
}
