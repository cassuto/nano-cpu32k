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

#include "ras.hh"

RAS::RAS()
{
    ras = new info[stack_depth];
    ras_pos = 0;
}
RAS::~RAS()
{
    delete ras;
}

void RAS::push(vm_addr_t pc, vm_addr_t npc)
{
    ras[ras_pos] = info(pc, npc);
    ras_pos = (ras_pos + 1) % stack_depth;
}

void RAS::pop()
{
    ras_pos =(ras_pos - 1) % stack_depth;
}

void RAS::dump()
{
    for (int i = 0; i < ras_pos; i++)
    {
        fprintf(stderr, "[%d] pc=%#08x npc=%#08x\n", i, ras[i].pc, ras[i].npc);
    }
}
