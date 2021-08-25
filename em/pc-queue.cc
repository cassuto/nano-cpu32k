/*
Copyright 2021 GaoZiBo <diyer175@hotmail.com>
Powered by YSYX https://oscpu.github.io/ysyx

Licensed under The MIT License (MIT).
-------------------------------------
Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of
the Software, and to permit persons to whom the Software is furnished to do so,
subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED,INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS
FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR
COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#include "pc-queue.hh"

PCQueue::PCQueue()
{
    pc_queue = new info[n_pc_queue];
    pc_queue_pos = 0;
}
PCQueue::~PCQueue()
{
    delete pc_queue;
}

void PCQueue::push(vm_addr_t pc, insn_t insn)
{
    if (pc_queue_pos < n_pc_queue)
    {
        pc_queue[pc_queue_pos++] = info(pc, insn);
    }
    else
    {
        std::memmove(pc_queue, &pc_queue[1], (sizeof(uint32_t) * n_pc_queue) - sizeof(uint32_t));
        pc_queue[n_pc_queue - 1] = info(pc, insn);
    }
}

void PCQueue::dump()
{
    for (int i = 0; i < pc_queue_pos; i++)
    {
        fprintf(stderr, "[%d] pc=%#08x insn=%#08x\n", i, pc_queue[i].pc, pc_queue[i].insn);
    }
}
