#include "misc/common.h"
#include "misc/err.h"
#include "useq.h"
#include "list.h"
#include "mempool.h"
#include "translate.h"

#define TRANSLATE_CODE_BLKS_MAXSIZE         1*_KB
#define TRANSLATE_CODE_BLKS_COUNT           1024
#define TRANSLATE_CODE_BLKS_HASH_COUNT      6379   /* be better a prime number */
#define TRANSLATE_CODE_BUF_SIZE             2*_MB

struct useq_block
{
    struct list blk; /* node of list */
    phy_addr_t pc; /* start PC */
    uint8_t *entry; /* entry of code buffer */
};

struct useq_data
{
    /** Hash-table structured translate blocks. */
    struct list blk_hash[TRANSLATE_CODE_BLKS_HASH_COUNT];
    struct useq_block *blk_pool;
    int blk_count;
    /** Translate code buffer. */
    uint8_t *buf_base;
    uint8_t *buf_ptr;
    uint8_t *buf_upbound;
};

static struct useq_data useq;

static void cache_flush()
{
    for(int i=0;i<TRANSLATE_CODE_BLKS_HASH_COUNT; ++i) {
        list_init(&useq.blk_hash[i]);
    }
    useq.blk_count = 0;
    useq.buf_current = useq.buf_base;
    useq.buf_upbound = useq.buf_base + TRANSLATE_CODE_BUF_SIZE;
}

int useq_init()
{
    if(!useq.blk_pool = (struct useq_block *)mpool_alloc(TRANSLATE_CODE_BLKS_MAXSIZE*TRANSLATE_CODE_BLKS_COUNT)) {
        return -ERR_MPOOL_ALLOC;
    }
    if(!useq.buf_base = (uint8_t *)mpool_alloc(TRANSLATE_CODE_BUF_SIZE)) {
        return -ERR_MPOOL_ALLOC;
    }
    
    cache_flush();
}

static struct useq_block *blk_alloc()
{
    if(useq.blk_count >= TRANSLATE_CODE_BLKS_COUNT) {
        return NULL;
    }
    return &useq.blk_pool[useq.blk_count++];
}

static inline phy_addr_t blk_hash_pc(phy_addr_t pc) {
#ifdef TARGET_ARCH_MIPS
    return (pc>>2) % TRANSLATE_CODE_BLKS_HASH_COUNT; /* MIPS insn are 32-bit aligned */
#endif
}

static struct useq_block *useq_translate(phy_addr_t pc)
{
    struct useq_block *blk = blk_alloc();
    if(!blk) {
        cache_flush();
    }
    blk = blk_alloc();
    n_assert(blk);
    
    blk->entry = useq.buf_ptr;
#ifdef TARGET_ARCH_MIPS
    translate_mips(&blk->entry, pc);
#endif
    return blk;
}

/**
 * Acquire a translate block by PC.
 * If not found in cache, then translate target PC and return the block generated.
 * @param pc target code address.
 * @return block.
 */
static struct useq_block *blk_find_gen(phy_addr_t pc)
{
    int key = blk_hash_pc(pc);
    list_iterate(&useq.blk_hash[key], prev, cur) {
        struct useq_block *blk = list_entry(cur, struct useq_block, blk);
        if (blk->pc == pc)
            return blk;
    }
    /* Not found, translate target code to generate a block. */
    struct useq_block *blk = useq_translate(pc);
    list_add(&useq.blk_hash[key], &blk->blk);
    return blk;
}
