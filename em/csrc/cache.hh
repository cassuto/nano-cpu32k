#ifndef CACHE_H_
#define CACHE_H_

#include "common.hh"

class Memory;
class Cache {
public:
    Cache(Memory *mem_, bool enabled, int p_ways, int p_sets, int p_line);
    ~Cache();
    void access(phy_addr_t pa, bool store, int *hit_way, int *hit_entry);
    void phy_writem8(phy_addr_t addr, uint8_t val);
    void phy_writem16(phy_addr_t addr, uint16_t val);
    void phy_writem32(phy_addr_t addr, uint32_t val);

    uint8_t phy_readm8(phy_addr_t addr);
    uint16_t phy_readm16(phy_addr_t addr);
    uint32_t phy_readm32(phy_addr_t addr);

    void flush(phy_addr_t addr);
    void invalidate(phy_addr_t addr);
    void dump(char prefix);

private:
    bool enabled;
    int m_P_WAYS, m_P_SETS, m_P_LINE;

    bool **cache_v;
    bool **cache_dirty;
    int **cache_lru;
    phy_addr_t **cache_addr;

    bool *match;
    bool *sfree;

    uint8_t ***lines;

    uint64_t freq_hit, freq_miss, freq_miss_writeback;

    Memory *mem;
    phy_addr_t m_block_offset_mask;
};

#endif // CACHE_H_
