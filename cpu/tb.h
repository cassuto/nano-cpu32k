#ifndef TB_H_
#define TB_H_

//#define TESTBENCH_DRAM
//#define TESTBENCH_ALU
#define TESTBENCH_TOP

extern int tb_dram_main();
extern int tb_alu_main();
extern int tb_top_main();

#endif