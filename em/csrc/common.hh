#ifndef COMMON_H_
#define COMMON_H_

#include <cstdint>
#include <cstdio>
#include <cstring>
#include <cstdlib>
#include <cmath>
#include <cassert>
#include <string>

typedef int32_t cpu_word_t;
typedef uint32_t cpu_unsigned_word_t;
typedef uint32_t vm_addr_t;
typedef uint32_t vm_signed_addr_t;
typedef uint32_t phy_addr_t;
typedef uint32_t phy_signed_addr_t;
typedef uint32_t insn_t;
typedef uint16_t msr_index_t;

class Cache;
class CPU;
class Memory;
class DeviceTree;
class PCQueue;
class DRAM;
class RAS;
class Symtable;

#define EM_SUCCEEDED 0
#define EM_FAULT 1
#define EM_NO_MEMORY 2
#define EM_TLB_MISS 3
#define EM_PAGE_FAULT 4
#define EM_IRQ 5
#define EM_ALIGN_FAULT 6

#define CHUNK_SIZE 8192

extern void panic(int code);

#ifndef MIN
#define MIN(x,y) ((x)<(y) ? (x) : (y)) /* Look out please! */
#endif

//#define CHECK_MEMORY_BOUND
#undef CHECK_MEMORY_BOUND

#endif // COMMON_H_
