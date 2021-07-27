#include "Vtop.h"
#include "verilated.h"

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);
    Vtop* top = new Vtop;
    
    top->clk = 0;
    top->eval();

    while (!Verilated::gotFinish()) {
        top->clk = !top->clk;
        printf("clk : %d\n", top->clk);
        top->eval();
    }
    delete top;
    return 0;
}
