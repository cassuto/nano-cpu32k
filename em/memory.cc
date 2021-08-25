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

Memory::Memory(size_t memory_size_, phy_addr_t mmio_phy_base_)
    : mmio8(nullptr),
      mmio16(nullptr),
      mmio32(nullptr),
      memory(new uint8_t[memory_size_]),
      memory_size(memory_size_),
      mmio_phy_base(mmio_phy_base_)
{
}

Memory::~Memory()
{
    delete memory;
}

int Memory::load_address_fp(FILE *fp, phy_addr_t baseaddr)
{
    size_t pos = 0;
    size_t len;
    fseek(fp, 0, SEEK_SET);
    while ((len = fread(memory + baseaddr + pos, 1, CHUNK_SIZE, fp)) > 0)
    {
        pos += len;
    }
    return 0;
}

Memory::mmio_node *
Memory::match_mmio_handler(mmio_node *domain, phy_addr_t addr, bool w)
{
    if (addr >= mmio_phy_base)
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

/*
 * Physical Memory accessing functions, in little-endian.
 * Note that there is not any address translation for physical memory.
 * PhyMemory must be accessed through these funcs for CPU.
 */

void Memory::phy_writem8(phy_addr_t addr, uint8_t val)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio8, addr, 1);
    if (mmio_handler)
    {
        mmio_handler->callback->writem8(addr, val, mmio_handler->opaque);
    }
    else
    {
#ifdef CHECK_MEMORY_BOUND
        if (addr < memory_size)
            memory[addr] = val;
        else
        {
            fprintf(stderr, "WriteM8 out of bound.\n");
            panic(1);
        }
#else
        memory[addr] = val;
#endif
    }
}

void Memory::phy_writem16(phy_addr_t addr, uint16_t val)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio16, addr, 1);
    if (mmio_handler)
    {
        mmio_handler->callback->writem16(addr, val, mmio_handler->opaque);
    }
    else
    {
        phy_writem8(addr, uint8_t(val & 0x00ff));
        phy_writem8(addr + 1, uint8_t(val >> 8));
    }
}

void Memory::phy_writem32(phy_addr_t addr, uint32_t val)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio32, addr, 1);
    if (mmio_handler)
    {
        mmio_handler->callback->writem32(addr, val, mmio_handler->opaque);
    }
    else
    {
        phy_writem8(addr, uint8_t(val & 0xff));
        phy_writem8(addr + 1, uint8_t((val >> 8) & 0xff));
        phy_writem8(addr + 2, uint8_t((val >> 16) & 0xff));
        phy_writem8(addr + 3, uint8_t(val >> 24));
    }
}

uint8_t
Memory::phy_readm8(phy_addr_t addr)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio8, addr, 0);
    if (mmio_handler)
    {
        return mmio_handler->callback->readm8(addr, mmio_handler->opaque);
    }
    else
    {
#ifdef CHECK_MEMORY_BOUND
        if (addr >= memory_size)
        {
            fprintf(stderr, "Memory out of bound: paddr=%#x", addr);
            panic(1);
        }
#endif
        return memory[addr];
    }
}

uint16_t
Memory::phy_readm16(phy_addr_t addr)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio16, addr, 0);
    if (mmio_handler)
    {
        return mmio_handler->callback->readm16(addr, mmio_handler->opaque);
    }
    else
        return ((uint16_t)phy_readm8(addr + 1) << 8) | (uint16_t)phy_readm8(addr);
}

uint32_t
Memory::phy_readm32(phy_addr_t addr)
{
    struct mmio_node *mmio_handler = match_mmio_handler(mmio32, addr, 0);
    if (mmio_handler)
    {
        return mmio_handler->callback->readm32(addr, mmio_handler->opaque);
    }
    else
    {
        return ((uint32_t)phy_readm8(addr + 3) << 24) |
               ((uint32_t)phy_readm8(addr + 2) << 16) |
               ((uint32_t)phy_readm8(addr + 1) << 8) |
               (uint32_t)phy_readm8(addr);
    }
}
