#ifndef MEMORY_H_
#define MEMORY_H_

#include "common.hh"

class MMIOCallback
{
public:
    MMIOCallback() {}
    virtual ~MMIOCallback() {}
    virtual void writem8(phy_addr_t addr, uint8_t val, void *opaque) {}
    virtual void writem16(phy_addr_t addr, uint16_t val, void *opaque) {}
    virtual void writem32(phy_addr_t addr, uint32_t val, void *opaque) {}
    virtual uint8_t readm8(phy_addr_t addr, void *opaque) { return 0; }
    virtual uint16_t readm16(phy_addr_t addr, void *opaque) { return 0; }
    virtual uint32_t readm32(phy_addr_t addr, void *opaque) { return 0; }
};

class Memory
{
public:
    Memory(size_t memory_size_, phy_addr_t mmio_phy_base_);
    ~Memory();
    int load_address_fp(FILE *fp, phy_addr_t baseaddr);

    void mmio_register_writem8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_writem16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_writem32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm8(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm16(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);
    void mmio_register_readm32(phy_addr_t start_addr, phy_addr_t end_addr, MMIOCallback *callback, void *opaque);

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
        else
        {
#ifdef CHECK_MEMORY_BOUND
            if (addr < memory_size)
                memory[addr] = val;
            else
            {
                fprintf(stderr, "Memory out of bound. paddr=%#x\n", addr);
                panic(1);
            }
#else
            memory[addr] = val;
#endif
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
        else
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
        else
        {
            phy_writem8(addr, uint8_t(val & 0xff));
            phy_writem8(addr + 1, uint8_t((val >> 8) & 0xff));
            phy_writem8(addr + 2, uint8_t((val >> 16) & 0xff));
            phy_writem8(addr + 3, uint8_t(val >> 24));
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
        else
        {
#ifdef CHECK_MEMORY_BOUND
            if (addr >= memory_size)
            {
                fprintf(stderr, "Memory out of bound: paddr=%#x\n", addr);
                panic(1);
            }
#endif
            return memory[addr];
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
        else
            return ((uint16_t)phy_readm8(addr + 1) << 8) | (uint16_t)phy_readm8(addr);
    }

    inline uint32_t
    phy_readm32(phy_addr_t addr)
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

    inline uint64_t
    dram_readm64(uint64_t idx)
    {
        /* FIXME: support big-endian host machines */
        return *(((uint64_t *)memory)+idx);
    }
    inline void
    dram_writem64(uint64_t idx, uint64_t val)
    {
        /* FIXME: support big-endian host machines */
        *(((uint64_t *)memory)+idx) = val;
    }

    inline size_t get_size() const { return memory_size; } /* in bytes */

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
    mmio_node *mmio8, *mmio16, *mmio32;
    uint8_t *memory;
    size_t memory_size;
    phy_addr_t mmio_phy_base;
};

#endif