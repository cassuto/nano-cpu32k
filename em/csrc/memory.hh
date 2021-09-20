#ifndef MEMORY_H_
#define MEMORY_H_

#include "common.hh"
#include "cpu.hh"
#include "ras.hh"

class MMIOCallback
{
public:
    MMIOCallback() {}
    virtual ~MMIOCallback() {}
    virtual void writem8(phy_addr_t addr, uint8_t val, void *opaque) {}
    virtual void writem16(phy_addr_t addr, uint16_t val, void *opaque) {}
    virtual void writem32(phy_addr_t addr, uint32_t val, void *opaque) {}
    virtual void writem64(phy_addr_t addr, uint32_t val, void *opaque) {}
    virtual uint8_t readm8(phy_addr_t addr, void *opaque) { return 0; }
    virtual uint16_t readm16(phy_addr_t addr, void *opaque) { return 0; }
    virtual uint32_t readm32(phy_addr_t addr, void *opaque) { return 0; }
    virtual uint32_t readm64(phy_addr_t addr, void *opaque) { return 0; }
};

class Memory
{
public:
    Memory(CPU *cpu_, size_t memory_size_, phy_addr_t dram_phy_start_, phy_addr_t mmio_phy_base_, phy_addr_t mmio_phy_end_addr_);
    ~Memory();
    int load_address_fp(FILE *fp, phy_addr_t baseaddr);

    void mmio_register_writem8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_writem16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_writem32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_writem64(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm64(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);

    /*
     * Physical Memory accessing functions, in little-endian.
     * Note that there is not any address translation for physical memory.
     * PhyMemory must be accessed through these funcs for CPU.
     */

    inline void
    phy_writem8(phy_addr_t addr, uint8_t val)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio8, addr, 1);
        if (mmio_handler)
        {
            mmio_handler->callback->writem8(addr, val, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            memory[addr - dram_phy_start] = val;
        }
        else
        {
            if (cpu)
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x emu_pc=%#x\n", __func__, addr, cpu->get_pc());
            else
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, addr);
            panic(1);
        }
    }

    inline void
    phy_writem16(phy_addr_t addr, uint16_t val)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio16, addr, 1);
        if (mmio_handler)
        {
            mmio_handler->callback->writem16(addr, val, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            phy_writem8(addr, uint8_t(val & 0x00ff));
            phy_writem8(addr + 1, uint8_t(val >> 8));
        }
    }

    inline void
    phy_writem32(phy_addr_t addr, uint32_t val)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio32, addr, 1);
        if (mmio_handler)
        {
            mmio_handler->callback->writem32(addr, val, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            phy_writem8(addr, uint8_t(val & 0xff));
            phy_writem8(addr + 1, uint8_t(val >> 8));
            phy_writem8(addr + 2, uint8_t(val >> 16));
            phy_writem8(addr + 3, uint8_t(val >> 24));
        }
    }

    inline void
    phy_writem64(phy_addr_t addr, uint64_t val)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio64, addr, 1);
        if (mmio_handler)
        {
            mmio_handler->callback->writem64(addr, val, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            phy_writem8(addr, uint8_t(val & 0xff));
            phy_writem8(addr + 1, uint8_t(val >> 8));
            phy_writem8(addr + 2, uint8_t(val >> 16));
            phy_writem8(addr + 3, uint8_t(val >> 24));
            phy_writem8(addr + 4, uint8_t(val >> 32));
            phy_writem8(addr + 5, uint8_t(val >> 40));
            phy_writem8(addr + 6, uint8_t(val >> 48));
            phy_writem8(addr + 7, uint8_t(val >> 56));
        }
    }

    inline uint8_t
    phy_readm8(phy_addr_t addr)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio8, addr, 0);
        if (mmio_handler)
        {
            return mmio_handler->callback->readm8(addr, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            return memory[addr - dram_phy_start];
        }
        else
        {
            if (cpu)
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x emu_pc=%#x\n", __func__, addr, cpu->get_pc());
            else
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, addr);
            panic(1);
            return 0;
        }
    }

    inline uint16_t
    phy_readm16(phy_addr_t addr)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio16, addr, 0);
        if (mmio_handler)
        {
            return mmio_handler->callback->readm16(addr, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            return ((uint16_t)phy_readm8(addr + 1) << 8) | (uint16_t)phy_readm8(addr);
        }
        else
        {
            if (cpu)
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x emu_pc=%#x\n", __func__, addr, cpu->get_pc());
            else
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, addr);
            panic(1);
            return 0;
        }
    }

    inline uint32_t
    phy_readm32(phy_addr_t addr)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio32, addr, 0);
        if (mmio_handler)
        {
            return mmio_handler->callback->readm32(addr, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            return ((uint32_t)phy_readm8(addr + 3) << 24) |
                   ((uint32_t)phy_readm8(addr + 2) << 16) |
                   ((uint32_t)phy_readm8(addr + 1) << 8) |
                   (uint32_t)phy_readm8(addr);
        }
        else
        {
            if (cpu)
            {
                cpu->get_ras()->dump();
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x emu_pc=%#x\n", __func__, addr, cpu->get_pc());
            }
            else
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, addr);
            panic(1);
            return 0;
        }
    }

    inline uint64_t
    phy_readm64(phy_addr_t addr)
    {
        struct mmio_node *mmio_handler = match_mmio_handler(mmio64, addr, 0);
        if (mmio_handler)
        {
            return mmio_handler->callback->readm64(addr, mmio_handler->opaque);
        }
        else if (addr >= dram_phy_start && addr < (dram_phy_start + memory_size))
        {
            return ((uint64_t)phy_readm8(addr + 7) << 56) |
                   ((uint64_t)phy_readm8(addr + 6) << 48) |
                   ((uint64_t)phy_readm8(addr + 5) << 40) |
                   ((uint64_t)phy_readm8(addr + 4) << 32) |
                   ((uint64_t)phy_readm8(addr + 3) << 24) |
                   ((uint64_t)phy_readm8(addr + 2) << 16) |
                   ((uint64_t)phy_readm8(addr + 1) << 8) |
                   (uint64_t)phy_readm8(addr);
        }
        else
        {
            if (cpu)
            {
                cpu->get_ras()->dump();
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x emu_pc=%#x\n", __func__, addr, cpu->get_pc());
            }
            else
                fprintf(stderr, "%s(): Memory out of bound: paddr=%#x\n", __func__, addr);
            panic(1);
            return 0;
        }
    }

    inline size_t get_size() const { return memory_size; } /* in bytes */

    inline phy_addr_t get_mmio_phy_base() const { return mmio_phy_base; }
    inline phy_addr_t get_mmio_phy_end_addr() const { return mmio_phy_end_addr; }

private:
    struct mmio_node
    {
        bool write;
        phy_addr_t start_addr;
        phy_addr_t end_addr;
        MMIOCallback *callback;
        void *opaque;
        struct mmio_node *next;
    };

    mmio_node *match_mmio_handler(mmio_node *domain, phy_addr_t addr, bool w);
    void mmio_append_node(mmio_node **doamin,
                          bool write,
                          phy_addr_t start_addr,
                          phy_addr_t end_addr,
                          MMIOCallback *callback,
                          void *opaque);

private:
    CPU *cpu;
    mmio_node *mmio8, *mmio16, *mmio32, *mmio64;
    uint8_t *memory;
    size_t memory_size;
    phy_addr_t dram_phy_start;
    phy_addr_t mmio_phy_base;
    phy_addr_t mmio_phy_end_addr;
};

#endif