#ifndef MEMORY_H_
#define MEMORY_H_

#include "common.hh"

typedef void (*pfn_writem8)(phy_addr_t addr, uint8_t val, void *opaque);
typedef void (*pfn_writem16)(phy_addr_t addr, uint16_t val, void *opaque);
typedef void (*pfn_writem32)(phy_addr_t addr, uint32_t val, void *opaque);
typedef uint8_t (*pfn_readm8)(phy_addr_t addr, void *opaque);
typedef uint16_t (*pfn_readm16)(phy_addr_t addr, void *opaque);
typedef uint32_t (*pfn_readm32)(phy_addr_t addr, void *opaque);

class Memory
{
public:
    Memory(size_t memory_size_, phy_addr_t mmio_phy_base_);
    ~Memory();
    int load_address_fp(FILE *fp, phy_addr_t baseaddr);

    void mmio_register_writem8(phy_addr_t start_addr, phy_addr_t end_addr, pfn_writem8 callback, void *opaque);
    void mmio_register_writem16(phy_addr_t start_addr, phy_addr_t end_addr, pfn_writem16 callback, void *opaque);
    void mmio_register_writem32(phy_addr_t start_addr, phy_addr_t end_addr, pfn_writem32 callback, void *opaque);
    void mmio_register_readm8(phy_addr_t start_addr, phy_addr_t end_addr, pfn_readm8 callback, void *opaque);
    void mmio_register_readm16(phy_addr_t start_addr, phy_addr_t end_addr, pfn_readm16 callback, void *opaque);
    void mmio_register_readm32(phy_addr_t start_addr, phy_addr_t end_addr, pfn_readm32 callback, void *opaque);

    void phy_writem8(phy_addr_t addr, uint8_t val);
    void phy_writem16(phy_addr_t addr, uint16_t val);
    void phy_writem32(phy_addr_t addr, uint32_t val);

    uint8_t phy_readm8(phy_addr_t addr);
    uint16_t phy_readm16(phy_addr_t addr);
    uint32_t phy_readm32(phy_addr_t addr);

private:
    struct mmio_node
    {
        bool write;
        phy_addr_t start_addr;
        phy_addr_t end_addr;
        void *callback;
        void *opaque;
        struct mmio_node *next;
    };

    mmio_node *match_mmio_handler(mmio_node *domain, phy_addr_t addr, bool w);
    void mmio_append_node(mmio_node **doamin,
                          bool write,
                          phy_addr_t start_addr,
                          phy_addr_t end_addr,
                          void *callback,
                          void *opaque);

private:
    mmio_node *mmio8, *mmio16, *mmio32;
    uint8_t *memory;
    size_t memory_size;
    phy_addr_t mmio_phy_base;
};

#endif