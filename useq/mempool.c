#include "common.h"
#include "mempool.h"

#define MAX_POOL_SIZE 4*_MB

static uint32_t static_pool[MAX_POOL_SIZE];
static int pool_ptr;

/**
 * Allocate a block from memory, ensuring that returning address
 * is 32-bit aligned.
 */
void *mpool_alloc(size_t size)
{
    size=(size+3)>>2; /* calc 4bytes index */
    if(!size || pool_ptr + size >= MAX_POOL_SIZE) {
        return NULL;
    }
    void *ptr = &static_pool[pool_ptr];
    pool_ptr += size;
    return ptr;
}
