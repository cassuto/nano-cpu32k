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

#include "memory.hh"

Memory::Memory(size_t memory_size_, phy_addr_t dram_phy_start_, phy_addr_t mmio_phy_base_, phy_addr_t mmio_phy_end_addr_)
    : mmio8(nullptr),
      mmio16(nullptr),
      mmio32(nullptr),
      memory(new uint8_t[memory_size_]),
      memory_size(memory_size_),
      dram_phy_start(dram_phy_start_),
      mmio_phy_base(mmio_phy_base_),
      mmio_phy_end_addr(mmio_phy_end_addr_)
{
    assert(mmio_phy_base <= mmio_phy_end_addr);
}

Memory::~Memory()
{
    delete memory;
}

int Memory::load_address_fp(FILE *fp, phy_addr_t baseaddr)
{
    size_t pos = 0;
    size_t len;
    if (!(baseaddr >= dram_phy_start && baseaddr < (dram_phy_start + memory_size)))
    {
        fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, baseaddr);
        return -1;
    }
    fseek(fp, 0, SEEK_SET);
    while ((len = fread(memory + baseaddr - dram_phy_start + pos, 1, CHUNK_SIZE, fp)) > 0)
    {
        pos += len;
    }
    return 0;
}

Memory::mmio_node *
Memory::match_mmio_handler(mmio_node *domain, phy_addr_t addr, bool w)
{
    if (addr >= mmio_phy_base && addr <= mmio_phy_end_addr)
    {
        for (mmio_node *node = domain; node; node = node->next)
        {
            if (node->write == w && node->start_addr <= addr && addr <= node->end_addr)
            {
                return node;
            }
        }
        fprintf(stderr, "%s(): accessing invalid mmio address %#x.\n", __func__, addr);
        panic(1);
    }
    return 0;
}

/*
 * Register MMIO devices
 */
void Memory::mmio_append_node(mmio_node **doamin,
                              bool write,
                              phy_addr_t start_addr,
                              phy_addr_t end_addr,
                              MMIOCallback *callback,
                              void *opaque)
{
    /* sanity check */
    for (mmio_node *node = *doamin; node; node = node->next)
    {
        if (node->write == write && (node->start_addr < end_addr && node->end_addr > start_addr))
        {
            fprintf(stderr, "%s(): mmio address (%#x~%#x) is overlapped\n", __func__, start_addr, end_addr);
            panic(1);
        }
    }

    struct mmio_node *node = (struct mmio_node *)malloc(sizeof *node);
    node->write = write;
    node->start_addr = start_addr;
    node->end_addr = end_addr;
    node->callback = callback;
    node->opaque = opaque;
    node->next = *doamin;
    *doamin = node;
    fprintf(stderr, "MMIO Device (W=%d) is mapped at %#x ~ %#x\n", write, start_addr, end_addr);
}

void Memory::mmio_register_writem8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio8, 1, start_addr, end_addr, callback, opaque);
}

void Memory::mmio_register_writem16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio16, 1, start_addr, end_addr, callback, opaque);
}

void Memory::mmio_register_writem32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio32, 1, start_addr, end_addr, callback, opaque);
}

void Memory::mmio_register_readm8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio8, 0, start_addr, end_addr, callback, opaque);
}

void Memory::mmio_register_readm16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio16, 0, start_addr, end_addr, callback, opaque);
}

void Memory::mmio_register_readm32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque)
{
    mmio_append_node(&mmio32, 0, start_addr, end_addr, callback, opaque);
}
