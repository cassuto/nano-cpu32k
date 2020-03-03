#ifndef COMMON_H_
#define COMMON_H_

#include <stdlib.h>

#define offsetof(TYPE, MEMBER) ((size_t) &((TYPE *)0)->MEMBER)

#define container_of(ptr, type, member) ({          \
    const typeof( ((type *)0)->member ) *__mptr = (ptr);    \
    (type *)( (char *)__mptr - offsetof(type,member) );})

#define algin_to(x, a) ((uintptr_t)((x) + (a) - 1) & -(a))

#define n_assert(x) do{ (void)(x); }while(0);

#define _KB 1024L
#define _MB _KB*1024L
#define _GB _MB*1024L

typedef uint32_t phy_addr_t;

/*
 * Configuration
 */
#define TARGET_ARCH_MIPS

#endif /* COMMON_H_ */
