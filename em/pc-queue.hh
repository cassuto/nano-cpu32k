#ifndef PC_QUEUE_H_
#define PC_QUEUE_H_

#include "common.hh"

class PCQueue
{
public:
    PCQueue();
    ~PCQueue();
    void push(vm_addr_t pc, insn_t insn);
    void dump();

private:
    class info
    {
    public:
        info()
            : pc(0),
              insn(0)
        {
        }
        info(vm_addr_t pc_, insn_t insn_)
            : pc(pc_),
              insn(insn_)
        {
        }
        vm_addr_t pc;
        insn_t insn;
    };
    const int n_pc_queue = 128;
    info *pc_queue;
    int pc_queue_pos;
};

#endif