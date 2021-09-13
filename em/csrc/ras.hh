#ifndef RAS_H_
#define RAS_H_

#include "common.hh"

class RAS
{
public:
    RAS(Symtable *symtable_);
    ~RAS();
    void push(vm_addr_t pc, vm_addr_t npc);
    void pop();
    void dump();

private:
    class info
    {
    public:
        info()
            : pc(0),
              npc(0)
        {
        }
        info(vm_addr_t pc_, vm_addr_t npc_)
            : pc(pc_),
              npc(npc_)
        {
        }
        vm_addr_t pc, npc;
    };
    const unsigned int stack_depth = 256;
    info *ras;
    unsigned int ras_pos;
    Symtable *symtable;
};

#endif