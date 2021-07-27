// --xuezhen--
//b001_cpu-test.cpp
#include <verilated.h>          
#include <verilated_vcd_c.h>    
#include <iostream>
#include <fstream>
#include "Vb001_cpu.h"

using namespace std;
typedef uint64_t word_t;
typedef uint32_t paddr_t;

static Vb001_cpu* top;
static VerilatedVcdC* tfp;
static vluint64_t main_time = 0;
static const vluint64_t sim_time = 1000;

// inst.bin
// inst 0: 1 + zero = reg1 1+0=1
// inst 1: 2 + zero = reg1 2+0=2
// inst 2: 1 + reg1 = reg1 1+2=3

#define IMAGE_START 0x100000
#define PMEM_BASE 0x80000000
#define PMEM_SIZE (128 * 1024 * 1024)
static uint8_t pmem[PMEM_SIZE];
static inline void* guest_to_host(paddr_t addr) { return &pmem[addr]; }

static void read_inst(const char *filename)
{
	FILE *fp = fopen(filename, "rb");
	if( fp == NULL ) {
			printf( "Can not open this file!\n" );
			exit(1);
	}
	
	fseek(fp, 0, SEEK_END);
	size_t size = ftell(fp);
	fseek(fp, 0, SEEK_SET);
	size = fread(guest_to_host(IMAGE_START), size, 1, fp);
	fclose(fp);
}

static inline bool in_pmem(paddr_t addr) {
  return (PMEM_BASE <= addr) && (addr <= PMEM_BASE + PMEM_SIZE - 1);
}

static inline word_t pmem_read(paddr_t addr, int len) {
  void *p = &pmem[addr - PMEM_BASE];
  switch (len) {
    case 1: return *(uint8_t  *)p;
    case 2: return *(uint16_t *)p;
    case 4: return *(uint32_t *)p;
#ifdef ISA64
    case 8: return *(uint64_t *)p;
#endif
    default: assert(0);
  }
}

static inline void pmem_write(paddr_t addr, word_t data, int len) {
  void *p = &pmem[addr - PMEM_BASE];
  switch (len) {
    case 1: *(uint8_t  *)p = data; return;
    case 2: *(uint16_t *)p = data; return;
    case 4: *(uint32_t *)p = data; return;
#ifdef ISA64
    case 8: *(uint64_t *)p = data; return;
#endif
    default: assert(0);
  }
}

/* Memory accessing interfaces */
void* fetch_mmio_map(paddr_t addr) {
	printf("Failed to call fetch_mmio_map\n");
	exit(1);
}

word_t map_read(paddr_t addr, int len, void *map)
{
	return 0;
}
void map_write(paddr_t addr, word_t data, int len, void *map)
{
}

inline word_t paddr_read(paddr_t addr, int len) {
	if (in_pmem(addr)) return pmem_read(addr, len);
	else return map_read(addr, len, fetch_mmio_map(addr));
}

inline void paddr_write(paddr_t addr, word_t data, int len) {
	if (in_pmem(addr)) pmem_write(addr, data, len);
	else map_write(addr, data, len, fetch_mmio_map(addr));
}

static void check_bus(void)
{
	if (top->ready) {
		if (top->bus_read_en) {
			top->bus_read_data = (uint64_t)paddr_read(top->bus_addr, top->bus_size);
		}
		else if (top->bus_write_en) {
			paddr_write(top->bus_addr, top->bus_write_data, top->bus_size);
		}
		top->valid = 1;
	}
	else {
		top->valid = 0;
	}
}

static uint64_t wave_time = 1;
static void clock_one_cycle(void)
{
	top->clock = 1;
	// top->inst = (top->inst_ena == 1) ? mem[(top->inst_addr) >> 2] : 0;
	top->eval();
	tfp->dump(wave_time++);
	check_bus();
	top->eval();
	tfp->dump(wave_time++);
	check_bus();
	top->eval();
	// check_bus();
	tfp->dump(wave_time++);

	top->clock = 0;
	top->eval();
	tfp->dump(wave_time++);
}

int main(int argc, char **argv)
{
	const char *filename = argv[1] != NULL ? (const char *)argv[1] : "../inst.bin";\
	cout << filename << endl;
	read_inst(filename);

	// initialization
	Verilated::commandArgs(argc, argv);
	Verilated::traceEverOn(true);

	top = new Vb001_cpu;
	tfp = new VerilatedVcdC;

	top->trace(tfp, 99);
	tfp->open("top.vcd");

	top->reset = 1;
	top->clock = 0;
	top->eval();
	tfp->dump(wave_time++);

	top->reset = 0;
	top->eval();
	tfp->dump(wave_time++);

	
	while( !Verilated::gotFinish() && wave_time < sim_time )
	{
		clock_one_cycle();
	}
		
	// clean
	tfp->close();
	delete top;
	delete tfp;
	exit(0);
	return 0;
}
