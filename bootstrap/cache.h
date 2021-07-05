#ifndef CACHE_H_
#define CACHE_H_

#include "msr.h"

static inline void sync_dcache_icache(void *paddr) {
   wmsr(MSR_DCFLS, (unsigned int)paddr);
   wmsr(MSR_ICINV, (unsigned int)paddr);
}

#endif // CACHE_H_
