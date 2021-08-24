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
#include "cache.hh"

template <typename T>
static inline T **create_2d(size_t d1, size_t d2)
{
    T **ret = new T *[d1];
    for (size_t i = 0; i < d1; ++i)
    {
        ret[i] = new T[d2];
    }
    return ret;
}

Cache::Cache(Memory *mem_, bool enabled, int p_ways, int p_sets, int p_line)
    : enabled(enabled),
      m_P_WAYS(p_ways),
      m_P_SETS(p_sets),
      m_P_LINE(p_line),
      freq_hit(0),
      freq_miss(0),
      freq_miss_writeback(0),
      mem(mem_),
      m_block_offset_mask((1U << m_P_LINE) - 1)
{
    cache_v = create_2d<bool>((1L << m_P_WAYS), (1L << m_P_SETS));
    cache_dirty = create_2d<bool>((1L << m_P_SETS), (1L << m_P_WAYS));
    cache_lru = create_2d<int>((1L << m_P_WAYS), (1L << m_P_SETS));
    cache_addr = create_2d<phy_addr_t>((1L << m_P_WAYS), (1L << m_P_SETS));
    match = new bool[(1L << m_P_WAYS)];
    sfree = new bool[(1L << m_P_WAYS)];

    lines = new uint8_t **[(1L << m_P_WAYS)];

    for (int k = 0; k < (1L << m_P_WAYS); ++k)
    {
        lines[k] = new uint8_t *[(1L << m_P_SETS)];
        for (int j = 0; j < (1L << m_P_SETS); ++j)
        {
            cache_v[k][j] = 0;
            cache_dirty[k][j] = 0;
            cache_lru[k][j] = k;
            cache_addr[k][j] = 0;
            lines[k][j] = new uint8_t[(1L << m_P_LINE)];
        }
    }
}

Cache::~Cache()
{
    delete[] match;
    delete[] sfree;
    for (int k = 0; k < (1L << m_P_WAYS); ++k)
    {
        for (int j = 0; j < (1L << m_P_SETS); ++j)
        {
            delete[] lines[k][j];
        }
        delete[] lines[k];
    }
    delete[] lines;
}

void Cache::access(phy_addr_t pa, bool store, int *hit_way, int *hit_entry)
{
    if (!enabled)
        return;

    int entry_idx = (pa >> m_P_LINE) & ((1 << m_P_SETS) - 1);
    phy_addr_t maddr = pa >> (m_P_LINE + m_P_SETS);

    char hit = 0;
    char dirty = 0;
    int lru_thresh = 0;
    int free_way_idx = -1;

    for (int i = 0; i < (1L << m_P_WAYS); i++)
    {
        match[i] = cache_v[i][entry_idx] && (cache_addr[i][entry_idx] == maddr);
        sfree[i] = cache_lru[i][entry_idx] == 0;

        if (match[i])
        {
            hit = 1;
        }
        if (sfree[i])
        {
            free_way_idx = i;
        }
        if (sfree[i] & cache_dirty[entry_idx][i])
        {
            dirty = 1;
        }
    }

    if (!hit) /* miss */
    {
        assert(free_way_idx >= 0);
        ++freq_miss;

        if (dirty)
        {
            /* Writeback*/
            ++freq_miss_writeback;

            phy_addr_t line_size = (1U << m_P_LINE);
            phy_addr_t line_paddr = (cache_addr[free_way_idx][entry_idx] << (m_P_LINE + m_P_SETS));
            for (phy_addr_t offset = 0; offset < line_size; offset++)
            {
                mem->phy_writem8(line_paddr + offset, lines[free_way_idx][entry_idx][offset]);
            }
        }

        /* Replace */
        cache_v[free_way_idx][entry_idx] = 1;
        cache_addr[free_way_idx][entry_idx] = maddr;
        hit = 1;

        /* Refill */
        {
            phy_addr_t line_size = (1U << m_P_LINE);
            phy_addr_t line_paddr = (maddr << (m_P_LINE + m_P_SETS));
            for (phy_addr_t offset = 0; offset < line_size; offset++)
            {
                lines[free_way_idx][entry_idx][offset] = mem->phy_readm8(line_paddr + offset);
                printf("%02x ", lines[free_way_idx][entry_idx][offset]);
            }
        }
    }
    else
    {
        /* cache hit */
        ++freq_hit;
    }

    for (int i = 0; i < (1L << m_P_WAYS); i++)
    {
        match[i] = cache_v[i][entry_idx] && (cache_addr[i][entry_idx] == maddr);
        lru_thresh |= match[i] ? cache_lru[i][entry_idx] : 0;
    }

    *hit_way = -1;

    for (int i = 0; i < (1L << m_P_WAYS); i++)
    {
        if (hit)
        {
            /* Update LRU priority */
            cache_lru[i][entry_idx] = match[i] ? (1 << m_P_WAYS) - 1 : (cache_lru[i][entry_idx] - (cache_lru[i][entry_idx] > lru_thresh)) & ((1 << m_P_WAYS) - 1);
            /* Mark dirty when written */
            if (match[i])
            {
                cache_dirty[entry_idx][i] |= store;
            }
        }
        else if (sfree[i])
        {
            /* Mark clean when entry is freed */
            cache_dirty[entry_idx][i] = 0;
        }

        if (match[i])
            *hit_way = i;
    }
    *hit_entry = entry_idx;
    assert(*hit_way != -1);
}

void Cache::phy_writem8(phy_addr_t addr, uint8_t val)
{
    if (enabled)
    {
        int way, entry;
        access(addr, true, &way, &entry);
        lines[way][entry][addr & m_block_offset_mask] = val;
    }
    else
    {
        mem->phy_writem8(addr, val);
    }
}

void Cache::phy_writem16(phy_addr_t addr, uint16_t val)
{
    if (enabled)
    {
        int way, entry;
        assert((addr & 0x1) == 0);
        access(addr, true, &way, &entry);
        lines[way][entry][addr & m_block_offset_mask] = val;
        lines[way][entry][(addr+1) & m_block_offset_mask] = (val>>8);
    }
    else
    {
        mem->phy_writem16(addr, val);
    }
}

void Cache::phy_writem32(phy_addr_t addr, uint32_t val)
{
    if (enabled)
    {
        int way, entry;
        assert((addr & 0x3) == 0);
        access(addr, true, &way, &entry);
        lines[way][entry][addr & m_block_offset_mask] = val;
        lines[way][entry][(addr+1) & m_block_offset_mask] = (val>>8);
        lines[way][entry][(addr+2) & m_block_offset_mask] = (val>>16);
        lines[way][entry][(addr+3) & m_block_offset_mask] = (val>>24);
    }
    else
    {
        mem->phy_writem32(addr, val);
    }
}

uint8_t Cache::phy_readm8(phy_addr_t addr)
{
    if (enabled)
    {
        int way, entry;
        access(addr, false, &way, &entry);
        return lines[way][entry][addr & m_block_offset_mask];
    }
    else
    {
        return mem->phy_readm8(addr);
    }
}

uint16_t Cache::phy_readm16(phy_addr_t addr)
{
    if (enabled)
    {
        int way, entry;
        assert((addr & 0x1) == 0);
        access(addr, false, &way, &entry);
        return lines[way][entry][addr & m_block_offset_mask] |
                (uint16_t(lines[way][entry+1][addr & m_block_offset_mask])<<8);
    }
    else
    {
        return mem->phy_readm16(addr);
    }
}

uint32_t Cache::phy_readm32(phy_addr_t addr)
{
    if (enabled)
    {
        int way, entry;
        assert((addr & 0x3) == 0);
        access(addr, false, &way, &entry);
        return lines[way][entry][addr & m_block_offset_mask] |
                (uint32_t(lines[way][entry+1][addr & m_block_offset_mask])<<8) |
                (uint32_t(lines[way][entry+2][addr & m_block_offset_mask])<<16) |
                (uint32_t(lines[way][entry+3][addr & m_block_offset_mask])<<24);
    }
    else
    {
        return mem->phy_readm32(addr);
    }
}

void Cache::flush(phy_addr_t pa)
{
    if (!enabled)
        return;

    int entry_idx = (pa >> m_P_LINE) & ((1 << m_P_SETS) - 1);
    phy_addr_t maddr = pa >> (m_P_LINE + m_P_SETS);

    for (int i = 0; i < (1L << m_P_WAYS); i++)
    {
        if (cache_v[i][entry_idx] && cache_addr[i][entry_idx]==maddr) { /* hit */
            if (cache_dirty[entry_idx][i])
            {
                /* write back */
                phy_addr_t line_size = (1U << m_P_LINE);
                phy_addr_t line_paddr = (cache_addr[i][entry_idx] << (m_P_LINE + m_P_SETS));
                for (phy_addr_t offset = 0; offset < line_size; offset++)
                {
                    mem->phy_writem8(line_paddr + offset, lines[i][entry_idx][offset]);
                }

                cache_dirty[entry_idx][i] = 0;
            }
        }
    }
}

void Cache::invalidate(phy_addr_t pa)
{
    if (!enabled)
        return;
    int entry_idx = (pa >> m_P_LINE) & ((1 << m_P_SETS) - 1);
    for (int i = 0; i < (1L << m_P_WAYS); i++)
    {
        cache_v[i][entry_idx] = 0;
    }
}

void Cache::dump(char prefix)
{
    printf("%cCache dump:", prefix);
    printf("\tHit: %lu\n", freq_hit);
    printf("\tMiss: %lu\n", freq_miss);
    printf("\t\tWriteback: %lu\n", freq_miss_writeback);
    printf("\tP(h) = %f%%\n", (float)freq_hit / (freq_hit + freq_miss) * 100);
}
