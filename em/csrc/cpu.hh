#ifndef CPU_H_
#define CPU_H_

#include "common.hh"

struct regfile_s
{
    cpu_word_t r[32];
};

struct psr_s
{
    char CY;
    char OV;
    char OE;
    char RM;
    char IRE;
    char IMME;
    char DMME;
    char ICAE;
    char DCAE;
};
/* ITLB */
struct itlbl_s
{
    char V;
    vm_addr_t VPN;
};
struct itlbh_s
{
    char P;
    char D;
    char A;
    char UX;
    char RX;
    char NC;
    char S;
    vm_addr_t PPN;
};
/* DTLB */
struct dtlbl_s
{
    char V;
    vm_addr_t VPN;
};
struct dtlbh_s
{
    char P;
    char D;
    char A;
    char UW;
    char UR;
    char RW;
    char RR;
    char NC;
    char S;
    vm_addr_t PPN;
};

struct tcr_s
{
    uint32_t CNT;
    char EN;
    char I;
    char P;
};

class msr_s
{
public:
    msr_s(uint32_t immu_tlb_count, uint32_t dmmu_tlb_count)
        : ITLBL(new itlbl_s[immu_tlb_count]),
          ITLBH(new itlbh_s[immu_tlb_count]),
          DTLBL(new dtlbl_s[dmmu_tlb_count]),
          DTLBH(new dtlbh_s[dmmu_tlb_count])
    {
        PSR.CY =
            PSR.OV =
                PSR.OE =
                    PSR.RM =
                        PSR.IRE =
                            PSR.IMME =
                                PSR.DMME =
                                    PSR.ICAE =
                                        PSR.DCAE = 0;
        TSR = 0;
        IMR = 0;
        IRR = 0;
    }
    struct psr_s PSR;
    struct psr_s EPSR;
    vm_addr_t EPC;
    vm_addr_t ELSA;
    struct itlbl_s *ITLBL;
    struct itlbh_s *ITLBH;
    struct dtlbl_s *DTLBL;
    struct dtlbh_s *DTLBH;
    cpu_unsigned_word_t TSR;
    struct tcr_s TCR;
    cpu_unsigned_word_t IMR;
    cpu_unsigned_word_t IRR;
    cpu_word_t SR[4];
};

class CPU
{
public:
    CPU(int dmmu_tlb_count_, int immu_tlb_count_,
        bool dmmu_enable_uncached_seg_,
        bool immu_enable_uncached_seg_,
        bool enable_icache_, bool enable_dcache_,
        int icache_p_ways_, int icache_p_sets_, int icache_p_line_,
        int dcache_p_ways_, int dcache_p_sets_, int dcache_p_line_,
        size_t memory_size_, phy_addr_t dram_phy_base_, phy_addr_t mmio_phy_base_, phy_addr_t mmio_phy_end_addr_,
        int IRQ_TSC_,
        phy_addr_t vect_EINSN_,
        phy_addr_t vect_EIRQ_,
        phy_addr_t vect_ESYSCALL_,
        phy_addr_t vect_EIPF_,
        phy_addr_t vect_EDPF_,
        phy_addr_t vect_EITM_,
        phy_addr_t vect_EDTM_,
        phy_addr_t vect_EALGIN_,
        phy_addr_t vect_EINT_);
    ~CPU();

    void reset(vm_addr_t reset_vect);
    vm_addr_t step(vm_addr_t pc);
    void run_step();

    void set_reg(uint16_t addr, cpu_word_t val);
    cpu_word_t get_reg(uint16_t addr);

    inline PCQueue *get_pc_queue() { return pc_queue; }
    inline RAS *get_ras() { return ras; }
    inline Symtable *get_symtable() { return symtable; }

    /* irqc.cc */
    void irqc_set_interrupt(int channel, char raise);
    int irqc_is_masked(int channel);
    int irqc_handle_irqs();

    inline Memory *memory() { return mem; }
    inline vm_addr_t get_pc() { return pc; }
    inline void set_pc(vm_addr_t npc) { pc = npc; }

    void init_msr(bool support_dbg);

private:
    vm_addr_t raise_exception(vm_addr_t pc, vm_addr_t vector, vm_addr_t lsa, bool is_syscall);
    int check_vma_align(vm_addr_t va, int size);

    /* mmu.cc */
    int dmmu_translate_vma(vm_addr_t va, phy_addr_t *pa, bool *uncached, bool store_insn);
    int immu_translate_vma(vm_addr_t va, phy_addr_t *pa, bool *uncached);

    /* msr.cc */
    void wmsr(msr_index_t index, cpu_word_t v);
    cpu_word_t rmsr(msr_index_t index);
    void warn_illegal_access_reg(const char *reg);

    /* tsc.cc */
    void tsc_clk(int delta);
    void tsc_update_tcr();

private:
    vm_addr_t pc;
    msr_s msr;
    struct regfile_s regfile;
    int dmmu_tlb_count, immu_tlb_count;
    int dmmu_tlb_count_log2, immu_tlb_count_log2;
    bool dmmu_enable_uncached_seg;
    bool immu_enable_uncached_seg;
    bool enable_icache, enable_dcache;
    int icache_p_ways, icache_p_sets, icache_p_line;
    int dcache_p_ways, dcache_p_sets, dcache_p_line;
    Memory *mem;
    Cache *icache, *dcache;
    int IRQ_TSC;
    PCQueue *pc_queue;
    Symtable *symtable;
    RAS *ras;
    phy_addr_t vect_EINSN;
    phy_addr_t vect_EIRQ;
    phy_addr_t vect_ESYSCALL;
    phy_addr_t vect_EIPF;
    phy_addr_t vect_EDPF;
    phy_addr_t vect_EITM;
    phy_addr_t vect_EDTM;
    phy_addr_t vect_EALGIN;
    phy_addr_t vect_EINT;
    bool enable_dbg;
};

#endif // CPU_H_
