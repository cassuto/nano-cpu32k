#ifndef PC_QUEUE_H_
#define PC_QUEUE_H_

#include "common.hh"

class PCQueue
{
public:
    PCQueue();
    ~PCQueue();
    void push(uint32_t pc);
    void dump();

private:
    const int n_pc_queue = 16;
    uint32_t *pc_queue;
    int pc_queue_pos;
};

#endif