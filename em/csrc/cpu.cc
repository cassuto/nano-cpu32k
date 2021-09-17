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

#include "isa.hh"
#include "cpu.hh"
#include "memory.hh"
#include "cache.hh"
#include "pc-queue.hh"
#include "ras.hh"
#include "symtable.hh"

#include "emu.hh"

CPU::CPU(int dmmu_tlb_count_, int immu_tlb_count_,
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
         phy_addr_t vect_EINT_)
    : msr(immu_tlb_count_, dmmu_tlb_count_),
      dmmu_tlb_count(dmmu_tlb_count_),
      immu_tlb_count(immu_tlb_count_),
      dmmu_tlb_count_log2(int(std::log2(dmmu_tlb_count_))),
      immu_tlb_count_log2(int(std::log2(immu_tlb_count_))),
      dmmu_enable_uncached_seg(dmmu_enable_uncached_seg_),
      immu_enable_uncached_seg(immu_enable_uncached_seg_),
      enable_icache(enable_icache_),
      enable_dcache(enable_dcache_),
      icache_p_ways(icache_p_ways_),
      icache_p_sets(icache_p_sets_),
      icache_p_line(icache_p_line_),
      dcache_p_ways(dcache_p_ways_),
      dcache_p_sets(dcache_p_sets_),
      dcache_p_line(dcache_p_line_),
      IRQ_TSC(IRQ_TSC_),
      pc_queue(new PCQueue()),
      symtable(new Symtable()),
      ras(new RAS(symtable)),
      vect_EINSN(vect_EINSN_),
      vect_EIRQ(vect_EIRQ_),
      vect_ESYSCALL(vect_ESYSCALL_),
      vect_EIPF(vect_EIPF_),
      vect_EDPF(vect_EDPF_),
      vect_EITM(vect_EITM_),
      vect_EDTM(vect_EDTM_),
      vect_EALGIN(vect_EALGIN_),
      vect_EINT(vect_EINT_),
      enable_dbg(true)
{
    mem = new Memory(this, memory_size_, dram_phy_base_, mmio_phy_base_, mmio_phy_end_addr_);
    icache = new Cache(mem, enable_icache, icache_p_ways, icache_p_sets, icache_p_line);
    dcache = new Cache(mem, enable_dcache, dcache_p_ways, dcache_p_sets, dcache_p_line);
}

CPU::~CPU()
{
    delete dcache;
    delete icache;
    delete mem;
    delete ras;
    delete symtable;
    delete pc_queue;
}

void CPU::set_reg(uint16_t addr, cpu_word_t val)
{
    if (addr >= 32)
    {
        fprintf(stderr, "set_reg() invalid register index at PC=%#x\n", pc);
        panic(1);
    }
    if (addr)
    {
        regfile.r[addr] = val;
    }
}

cpu_word_t
CPU::get_reg(uint16_t addr)
{
    if (addr >= 32)
    {
        fprintf(stderr, "cpu_get_reg() invalid register index at PC=%#x, index=%#x\n", pc, addr);
        panic(1);
    }
    if (addr)
        return regfile.r[addr];
    else
        return 0;
}

void CPU::reset(vm_addr_t reset_vect)
{
    pc = reset_vect;
    std::memset(&regfile.r, 0, sizeof(regfile.r));

    /* Init MSR */
    msr.PSR.RM = 1;
}

static inline vm_signed_addr_t
rel25_sig_ext(uint32_t rel25)
{
    return (((int32_t)(rel25 << INSN_LEN_SHIFT) ^ 0x4000000) - 0x4000000);
}

static inline vm_signed_addr_t
rel15_sig_ext(uint16_t rel15)
{
    return (((int32_t)(rel15 << INSN_LEN_SHIFT) ^ 0x10000) - 0x10000);
}

vm_addr_t
CPU::step(vm_addr_t pc)
{
    uint16_t opcode;
    uint16_t rs1;
    uint16_t rs2;
    uint16_t rd;
    uint32_t uimm17;
    uint16_t uimm15;
    int16_t simm15;
    uint16_t rel15;
    uint32_t rel25;

    vm_addr_t pc_nxt;
    phy_addr_t insn_pa;
    bool insn_uncached;
    insn_t insn;

    tsc_clk(1);

    /* response asynchronous interrupts */
    if (irqc_handle_irqs() == -EM_IRQ)
    {
        pc_nxt = raise_exception(pc, vect_EIRQ, 0, 0);
        goto handle_exception;
    }

    switch (immu_translate_vma(pc, &insn_pa, &insn_uncached))
    {
    case -EM_PAGE_FAULT:
        pc_nxt = raise_exception(pc, vect_EIPF, pc, 0);
        goto handle_exception;

    case -EM_TLB_MISS:
        pc_nxt = raise_exception(pc, vect_EITM, pc, 0);
        goto handle_exception;
    }

    /* Access ICache */
    if (insn_uncached)
        insn = (insn_t)mem->phy_readm32(insn_pa);
    else
        insn = (insn_t)icache->phy_readm32(insn_pa);
    pc_queue->push(pc, insn);
    pc_nxt = pc + INSN_LEN;

    /* decode and execute */
    opcode = insn & INS32_MASK_OPCODE;
    rs1 = INS32_GET_BITS(insn, RS1);
    rs2 = INS32_GET_BITS(insn, RS2);
    rd = INS32_GET_BITS(insn, RD);
    uimm17 = INS32_GET_BITS(insn, IMM17);
    uimm15 = INS32_GET_BITS(insn, IMM15);
    simm15 = (((int16_t)uimm15) ^ 0x4000) - 0x4000; /* sign extend */
    rel15 = INS32_GET_BITS(insn, REL15);
    rel25 = INS32_GET_BITS(insn, REL25);

    switch (opcode)
    {
    case INS32_OP_AND:
        set_reg(rd, get_reg(rs1) & get_reg(rs2));
        break;
    case INS32_OP_AND_I:
        set_reg(rd, get_reg(rs1) & uimm15);
        break;

    case INS32_OP_OR:
        set_reg(rd, get_reg(rs1) | get_reg(rs2));
        break;
    case INS32_OP_OR_I:
        set_reg(rd, get_reg(rs1) | uimm15);
        break;

    case INS32_OP_XOR:
        set_reg(rd, get_reg(rs1) ^ get_reg(rs2));
        break;
    case INS32_OP_XOR_I:
        set_reg(rd, get_reg(rs1) ^ simm15);
        break;

    case INS32_OP_LSL:
        set_reg(rd, get_reg(rs1) << get_reg(rs2));
        break;
    case INS32_OP_LSL_I:
        set_reg(rd, get_reg(rs1) << uimm15);
        break;

    case INS32_OP_LSR:
        set_reg(rd, (cpu_unsigned_word_t)get_reg(rs1) >> get_reg(rs2));
        break;
    case INS32_OP_LSR_I:
        set_reg(rd, (cpu_unsigned_word_t)get_reg(rs1) >> uimm15);
        break;

    case INS32_OP_ADD:
        set_reg(rd, get_reg(rs1) + get_reg(rs2));
        break;
    case INS32_OP_ADD_I:
        set_reg(rd, get_reg(rs1) + (cpu_word_t)simm15);
        break;

    case INS32_OP_SUB:
        set_reg(rd, get_reg(rs1) - get_reg(rs2));
        break;

    case INS32_OP_JMP:
    {
        vm_addr_t lnkpc = pc + INSN_LEN;
        set_reg(rd, lnkpc); /* link the returning address */
        pc_nxt = get_reg(rs1);
        if (rs1 == ADDR_RLNK)
            ras->pop();
        if (rd == ADDR_RLNK)
            ras->push(pc, pc_nxt);
        goto flush_pc;
    }

    case INS32_OP_JMP_I:
    {
        pc_nxt = pc + rel25_sig_ext(rel25);
        goto flush_pc;
    }
    case INS32_OP_JMP_I_LNK:
    {
        vm_addr_t lnkpc = pc + INSN_LEN;
        set_reg(ADDR_RLNK, lnkpc); /* link the returning address */
        pc_nxt = pc + rel25_sig_ext(rel25);
        ras->push(pc, pc_nxt);
        goto flush_pc;
    }

    case INS32_OP_BEQ:
    case INS32_OP_BNE:
    case INS32_OP_BGT:
    case INS32_OP_BGTU:
    case INS32_OP_BLE:
    case INS32_OP_BLEU:
    {
        char cc = 0;
        switch (opcode)
        {
        case INS32_OP_BEQ:
            cc = (get_reg(rs1) == get_reg(rd));
            break;
        case INS32_OP_BNE:
            cc = (get_reg(rs1) != get_reg(rd));
            break;
        case INS32_OP_BGT:
            cc = (get_reg(rs1) > get_reg(rd));
            break;
        case INS32_OP_BGTU:
            cc = ((cpu_unsigned_word_t)get_reg(rs1) > (cpu_unsigned_word_t)get_reg(rd));
            break;
        case INS32_OP_BLE:
            cc = (get_reg(rs1) <= get_reg(rd));
            break;
        case INS32_OP_BLEU:
            cc = ((cpu_unsigned_word_t)get_reg(rs1) <= (cpu_unsigned_word_t)get_reg(rd));
            break;
        }
        if (cc)
        {
            pc_nxt = pc + rel15_sig_ext(rel15);
            goto flush_pc;
        }
        break;
    }

    case INS32_OP_LDWU:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        if (check_vma_align(va, 2) < 0)
        {
            pc_nxt = raise_exception(pc, vect_EALGIN, va, 0);
            goto handle_exception;
        }
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 0))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        cpu_unsigned_word_t readout;
        if (uncached)
            readout = mem->phy_readm32(pa);
        else
            readout = dcache->phy_readm32(pa);
        set_reg(rd, readout);
        if (pc==0xc0383768){
printf("pc=%#x va=%#x pa=%#x val=%#x\n", pc, va,pa, readout);
        }
    }
    break;

    case INS32_OP_STW:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        if (check_vma_align(va, 2) < 0)
        {
            pc_nxt = raise_exception(pc, vect_EALGIN, va, 0);
            goto handle_exception;
        }
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 1))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        if (uncached)
            mem->phy_writem32(pa, (uint32_t)get_reg(rd));
        else
            dcache->phy_writem32(pa, (uint32_t)get_reg(rd));
        if (pa==0x80375dbc){
            extern Emu *emu;
            printf("stw [%lu] %#x va=%#x val=%#x\n", emu->get_cycle(), pc, va, (uint32_t)get_reg(rd));
        }
    }
    break;

    case INS32_OP_LDHU:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        if (check_vma_align(va, 1) < 0)
        {
            pc_nxt = raise_exception(pc, vect_EALGIN, va, 0);
            goto handle_exception;
        }
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 0))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        cpu_unsigned_word_t readout;
        if (uncached)
            readout = (cpu_unsigned_word_t)mem->phy_readm16(pa);
        else
            readout = (cpu_unsigned_word_t)dcache->phy_readm16(pa);
        set_reg(rd, readout);
        if(pc==0xc0002178){
            printf("ldhu %#x va=%#x pa=%#x val=%#x\n", pc, va, pa, readout);
        }
    }
    break;
    case INS32_OP_LDH:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        if (check_vma_align(va, 1) < 0)
        {
            pc_nxt = raise_exception(pc, vect_EALGIN, va, 0);
            goto handle_exception;
        }
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 0))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        cpu_word_t readout;
        if (uncached)
            readout = (((cpu_word_t)mem->phy_readm16(pa)) ^ 0x8000) - 0x8000; /* sign ext */
        else
            readout = (((cpu_word_t)dcache->phy_readm16(pa)) ^ 0x8000) - 0x8000; /* sign ext */
        set_reg(rd, readout);
    }
    break;
    case INS32_OP_STH:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        if (check_vma_align(va, 1) < 0)
        {
            pc_nxt = raise_exception(pc, vect_EALGIN, va, 0);
            goto handle_exception;
        }
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 1))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        if (uncached)
            mem->phy_writem16(pa, (uint16_t)get_reg(rd));
        else
            dcache->phy_writem16(pa, (uint16_t)get_reg(rd));
    }
    break;

    case INS32_OP_LDBU:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 0))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        cpu_unsigned_word_t readout;
        if (uncached)
            readout = (cpu_unsigned_word_t)mem->phy_readm8(pa);
        else
            readout = (cpu_unsigned_word_t)dcache->phy_readm8(pa);
        set_reg(rd, readout);
    }
    break;
    case INS32_OP_LDB:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 0))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        cpu_word_t readout;
        if (uncached)
            readout = (((cpu_word_t)mem->phy_readm8(pa)) ^ 0x80) - 0x80l; /* sign ext */
        else
            readout = (((cpu_word_t)dcache->phy_readm8(pa)) ^ 0x80) - 0x80l; /* sign ext */
        set_reg(rd, readout);
    }
    break;

    case INS32_OP_STB:
    {
        vm_addr_t va = get_reg(rs1) + (cpu_word_t)simm15;
        phy_addr_t pa = 0;
        bool uncached = false;
        switch (dmmu_translate_vma(va, &pa, &uncached, 1))
        {
        case -EM_PAGE_FAULT:
            pc_nxt = raise_exception(pc, vect_EDPF, va, 0);
            goto handle_exception;
        case -EM_TLB_MISS:
            pc_nxt = raise_exception(pc, vect_EDTM, va, 0);
            goto handle_exception;
        }
        if (uncached)
            mem->phy_writem8(pa, (uint8_t)get_reg(rd));
        else
            dcache->phy_writem8(pa, (uint8_t)get_reg(rd));
        if (pc==0x8000468c){
            printf("ldb %#x va=%#x w=%#x\n",pc,va, (uint8_t)get_reg(rd));
        }
    }
    break;

    case INS32_OP_BARR:
        break;

    case INS32_OP_SYSCALL:
        pc_nxt = raise_exception(pc, vect_ESYSCALL, 0, /*syscall*/ 1);
        goto handle_exception;

    case INS32_OP_RET:
        /* restore PSR and PC */
        msr.PSR = msr.EPSR;
        pc_nxt = msr.EPC;
        goto flush_pc;

    case INS32_OP_WMSR:
        wmsr(get_reg(rs1) | uimm15, get_reg(rd));
        break;
    case INS32_OP_RMSR:
        set_reg(rd, rmsr(get_reg(rs1) | uimm15));
        break;

    case INS32_OP_ASR:
        set_reg(rd, get_reg(rs1) >> get_reg(rs2));
        break;
    case INS32_OP_ASR_I:
        set_reg(rd, get_reg(rs1) >> uimm15);
        break;

    case INS32_OP_MUL:
        set_reg(rd, get_reg(rs1) * get_reg(rs2));
        break;

    case INS32_OP_DIV:
        set_reg(rd, get_reg(rs1) / get_reg(rs2));
        break;
    case INS32_OP_DIVU:
        set_reg(rd, (cpu_unsigned_word_t)get_reg(rs1) / (cpu_unsigned_word_t)get_reg(rs2));
        break;

    case INS32_OP_MOD:
        set_reg(rd, get_reg(rs1) % get_reg(rs2));
        break;
    case INS32_OP_MODU:
        set_reg(rd, (cpu_unsigned_word_t)get_reg(rs1) % (cpu_unsigned_word_t)get_reg(rs2));
        break;

    case INS32_OP_MHI:
        set_reg(rd, (cpu_unsigned_word_t)uimm17 << 15);
        break;

    default:
        if (opcode != INS32_OP_LDWA && opcode != INS32_OP_STWA)
        {
            fprintf(stderr, "EINSN: opcode = %#x at pc %#x\n", opcode, pc);
        }
        pc_nxt = raise_exception(pc, vect_EINSN, pc, 0);
        goto handle_exception;
    }

    goto fetch_next;
handle_exception:
fetch_next:
flush_pc:
    /* The only-one exit point */
    return pc_nxt;
}

void CPU::run_step()
{
    vm_addr_t npc = step(pc);
    //printf("pc = %#x, npc=%#x\n", pc, npc);
    pc = npc;
}

/**
 * @brief Raise an exception to handle for CPU.
 * @param [in] vector Target exception vector.
 * @param [in] lsa Target LSA virtual address.
 * @param [in] is_syscall Indicates if it is a syscall.
 */
vm_addr_t
CPU::raise_exception(vm_addr_t pc, vm_addr_t vector, vm_addr_t lsa, bool is_syscall)
{
    msr.EPC = pc + (is_syscall ? INSN_LEN : 0);
    msr.ELSA = lsa;
    /* save old PSR */
    msr.EPSR = msr.PSR;
    /* set up new PSR for exception */
    msr.PSR.RM = 1;
    msr.PSR.IMME = 0;
    msr.PSR.DMME = 0;
    msr.PSR.IRE = 0;
    /* transfer to exception handler */
    return vector;
}

int CPU::check_vma_align(vm_addr_t va, int size)
{
    if (va & ((1 << size) - 1))
    {
        fprintf(stderr, "EALIGN: pc=%x va=%x\n", pc, va);
        exit(1);
        return -EM_ALIGN_FAULT;
    }
    return 0;
}
