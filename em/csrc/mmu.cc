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

#include "cpu.hh"

#define VPN_SHIFT 13
#define PPN_SHIFT 13

/**
 * Translate virtual address to physical address.
 * @param [in] va Target Virtual Address
 * @param [out] pa Indicate where to store the physical address.
 * @param [in] store_insn Indicate if the insn is a store.
 * @retval -EM_TLB_MISS   Exception of TLB MISS
 * @retval -EM_PAGE_FAULT Exception of Page Fault. 
 * @retval >= 0              No exception.
 */
int CPU::dmmu_translate_vma(vm_addr_t va, phy_addr_t *pa, bool *uncached, bool store_insn)
{
    int ret = 0;
    *uncached = false;
    if (msr.PSR.DMME)
    {
        vm_addr_t vpn = va >> VPN_SHIFT;
        int offset = vpn & (dmmu_tlb_count - 1);
        if (msr.DTLBL[offset].V && msr.DTLBL[offset].VPN == vpn)
        {
            if (msr.PSR.RM)
            {
                if ((store_insn && !msr.DTLBH[offset].RW) ||
                    (!store_insn && !msr.DTLBH[offset].RR))
                {
                    ret = -EM_PAGE_FAULT;
                    goto out;
                }
            }
            else
            {
                if ((store_insn && !msr.DTLBH[offset].UW) ||
                    (!store_insn && !msr.DTLBH[offset].UR))
                {
                    ret = -EM_PAGE_FAULT;
                    goto out;
                }
            }
            *pa = (msr.DTLBH[offset].PPN << PPN_SHIFT) | (va & ((1 << PPN_SHIFT) - 1));
            /* If DMMU is disabled, UNC bit in page entry is not functioned.
             * Uncached segment is always functioned as long as physical addr is valid
             * and is within 0x80000000~0x8FFFFFFF
             */
            if (dmmu_enable_uncached_seg)
                /* Without any exception */
                *uncached = (msr.DTLBH[offset].NC) || !((msr.DTLBH[offset].PPN >> (32 - PPN_SHIFT - 1))&0x1);
            else
                *uncached = (msr.DTLBH[offset].NC);
        }
        else
        {
            ret = -EM_TLB_MISS;
        }
    }
    else
    {
        /* no translation */
        *pa = va;
        if (dmmu_enable_uncached_seg)
            *uncached = !(va >> (32 - 1));
    }
out:
    /* dcache disabled */
    if (!msr.PSR.DCE)
        *uncached = true;
    return ret;
}

/**
 * Translate virtual address to physical address.
 * @param [in] va Target Virtual Address
 * @param [out] pa Indicate where to store the physical address.
 * @retval -EM_TLB_MISS   Exception of TLB MISS
 * @retval -EM_PAGE_FAULT Exception of Page Fault. 
 * @retval >= 0              No exception.
 */
int CPU::immu_translate_vma(vm_addr_t va, phy_addr_t *pa, bool *uncached)
{
    int ret = 0;
    *uncached = false;
    if (msr.PSR.IMME)
    {
        vm_addr_t vpn = va >> VPN_SHIFT;
        int offset = vpn & (immu_tlb_count - 1);
        if (msr.ITLBL[offset].V && msr.ITLBL[offset].VPN == vpn)
        {
            if ((msr.PSR.RM && !msr.ITLBH[offset].RX) ||
                (!msr.PSR.RM && !msr.ITLBH[offset].UX))
            {
                ret = -EM_PAGE_FAULT;
                goto out;
            }
            *pa = (msr.ITLBH[offset].PPN << PPN_SHIFT) | (va & ((1 << PPN_SHIFT) - 1));
            if (immu_enable_uncached_seg)
                /* Without any exception */
                *uncached = (msr.ITLBH[offset].NC) || !((msr.ITLBH[offset].PPN >> (32 - PPN_SHIFT - 1))&0x1);
            else
                *uncached = (msr.ITLBH[offset].NC);
        }
        else
        {
            ret = -EM_TLB_MISS;
        }
    }
    else
    {
        /* no translation */
        *pa = va;
        if (immu_enable_uncached_seg)
            *uncached = !(va >> (32 - 1));
    }
out:
    /* icache disabled */
    if (!msr.PSR.ICE)
        *uncached = true;
    return ret;
}
