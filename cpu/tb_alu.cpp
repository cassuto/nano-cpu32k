#include "tb.h"
#ifdef TESTBENCH_ALU

#include "verilated.h"
#include "Valu.h"  
#include <cstdio>
#include <cstdint>

const int N_ITERATIONS = 100000;

typedef uint64_t (*pfnOperator)(uint64_t operand1, uint64_t operand2);

struct testcase {
    uint8_t fu_sel;
    pfnOperator pfnOp;
};

static uint64_t opAdd(uint64_t, uint64_t);
static uint64_t opSub(uint64_t, uint64_t);
static uint64_t opAnd(uint64_t, uint64_t);
static uint64_t opOr(uint64_t, uint64_t);
static uint64_t opXor(uint64_t, uint64_t);
static uint64_t opSll(uint64_t, uint64_t);
static uint64_t opSrl(uint64_t, uint64_t);

static testcase tests[] = {
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


int test_alu(testcase *test)
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
    return 0;
}

int tb_alu_main()
{
    int ret = 0;
    dut = new Valu;  //instantiating module top

    for(int i=0;i<N_ITERATIONS;i++) {
        for(int j=0;j<sizeof(tests)/sizeof(*tests);j++) {
            printf("#%d: Testing fu_sel=%x\n", i, tests[j].fu_sel);
            if (test_alu(&tests[j])) {
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