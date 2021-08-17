#include "verilated.h"
#include <cstdio>
#include <cstdint>

#ifdef VM_TRACE
#include <verilated_vcd_c.h>
static VerilatedVcdC* fp;
#endif

//#define TESTBENCH_DRAM
//#define TESTBENCH_ALU
#define TESTBENCH_TOP

int tb_dram_main();
int tb_alu_main();
int tb_top_main();


////////////////////////////////////////////////////////////////////////////////////////////
#ifdef TESTBENCH_ALU
#include "Valu.h"

const int N_ITERATIONS = 100000;

typedef uint64_t (*pfnOperator)(uint64_t operand1, uint64_t operand2);

struct testcase {
    uint8_t fu_sel;
    pfnOperator pfnOp;
};

static uint64_t opNone(uint64_t, uint64_t);
static uint64_t opAdd(uint64_t, uint64_t);
static uint64_t opSub(uint64_t, uint64_t);
static uint64_t opAnd(uint64_t, uint64_t);
static uint64_t opOr(uint64_t, uint64_t);
static uint64_t opXor(uint64_t, uint64_t);
static uint64_t opSll(uint64_t, uint64_t);
static uint64_t opSrl(uint64_t, uint64_t);

static testcase tests[] = {
    {0, &opNone},
    {(1U<<0), &opAdd},
    {(1U<<1), &opSub},
    {(1U<<2), &opAnd},
    {(1U<<3), &opOr},
    {(1U<<4), &opXor},
    {(1U<<5), &opSll},
    {(1U<<6), &opSrl},
};

#ifdef VM_TRACE
#include <verilated_vcd_c.h>
static VerilatedVcdC* fp;
#endif

static Valu* dut;

static uint64_t opNone(uint64_t operand1, uint64_t operand2)
{
    return 0;
}
static uint64_t opAdd(uint64_t operand1, uint64_t operand2)
{
    return operand1 + operand2;
}
static uint64_t opSub(uint64_t operand1, uint64_t operand2)
{
    return operand1 - operand2;
}
static uint64_t opAnd(uint64_t operand1, uint64_t operand2)
{
    return operand1 & operand2;
}
static uint64_t opOr(uint64_t operand1, uint64_t operand2)
{
    return operand1 | operand2;
}
static uint64_t opXor(uint64_t operand1, uint64_t operand2)
{
    return operand1 ^ operand2;
}
static uint64_t opSll(uint64_t operand1, uint64_t operand2)
{
    return operand1 << operand2;
}
static uint64_t opSrl(uint64_t operand1, uint64_t operand2)
{
    return operand1 >> operand2;
}


int test_alu(int iteration, testcase *test)
{
    uint64_t operand1, operand2, expected;

    operand1 = double(rand())/RAND_MAX * UINT64_MAX;
    operand2 = double(rand())/RAND_MAX * UINT64_MAX;

    dut->i_fu_sel = test->fu_sel;
    dut->i_operand1 = operand1;
    dut->i_operand2 = operand2;
    dut->eval();
    expected = test->pfnOp(operand1, operand2);
    if (dut->o_result != expected) {
        fprintf(stderr, "Error output of ALU: Expected = %#lx, Actual = %#lx\n", dut->o_result, expected);
        return 1;
    }
    if (iteration % 100 == 0)
        printf("#%d: PASS! fu_sel=%x operand1=%#lx, operand1=%#lx, result=%#lx,\n", iteration, test->fu_sel, operand1, operand2, dut->o_result);
    return 0;
}

int tb_alu_main()
{
    int ret = 0;
    dut = new Valu;  //instantiating module top

    for(int i=0;i<N_ITERATIONS;i++) {
        for(int j=0;j<sizeof(tests)/sizeof(*tests);j++) {
            if (test_alu(i, &tests[j])) {
                ret = 1;
                goto out;
            }
        }
    }

out:
    delete dut;
    return ret;
}

#endif

////////////////////////////////////////////////////////////////////////////////////////////
#ifdef TESTBENCH_DRAM
#include "Vdram.h"

static Vdram* dut;

void test_write(int time, uint16_t addr, uint64_t dat)
{
    dut->i_we = 0xff;
    dut->i_re = 0;
    dut->i_addr = addr;
    dut->i_dat = dat;
#ifdef VM_TRACE
    fp->dump(time * 3 + 0);
#endif
    dut->clk = 1;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 1);
#endif

    dut->clk = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 2);
#endif
}

void test_read(int time, uint16_t addr, uint64_t dat)
{
    dut->i_we = 0;
    dut->i_re = 1;
    dut->i_addr = addr;
#ifdef VM_TRACE
    fp->dump(time * 3 + 0);
#endif
    dut->clk = 1;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 1);
#endif

    if (dut->o_dat != dat) {
        printf("Reaout error! %#lx !== %#lx\n", dat, dut->o_dat);
        //exit(1);
    }

    dut->clk = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 3 + 2);
#endif
}


int tb_dram_main()
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

#endif

////////////////////////////////////////////////////////////////////////////////////////////
#ifdef TESTBENCH_TOP
#include "Vtop.h"

static Vtop* dut;

void reset(int time)
{
    dut->rst = 1;
    dut->eval();
    dut->clk = 1;
    dut->eval();
#ifdef VM_TRACE
    fp->dump(time * 2 + 1);
#endif

    dut->clk = 0;
    dut->rst = 0;
    dut->eval();

#ifdef VM_TRACE
    fp->dump(time * 2 + 2);
#endif
}

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

    reset(0);
    int cycle=20;
    for(uint16_t i=1; i<=cycle;i++) {
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

////////////////////////////////////////////////////////////////////////////////////////////

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
#ifdef TESTBENCH_TOP
   if ((ret = tb_top_main()))
        return ret;
#endif

    return 0;
}
