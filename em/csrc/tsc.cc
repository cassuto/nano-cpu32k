
#include "cpu.hh"
#include "isa.hh"

#define CNT_MASK (MSR_TCR_CNT >> MSR_TCR_CNT_SHIFT)

/**
 * Emulate a clk edge of TSC.
 * @retval >= 0 If not any exception.
 */
void CPU::tsc_clk()
{
    if (msr.TCR.EN)
    {
        if (msr.TCR.I && (msr.TSR & CNT_MASK) == msr.TCR.CNT)
        {
            msr.TCR.P = 1;
            tsc_update_tcr();
        }
        ++msr.TSR;
        if (msr.TSR == 0)
        {
            fprintf(stderr, "TSR overflow.\n");
        }
    }
}

/**
 * @brief Called when TCR is updated.
 */
void CPU::tsc_update_tcr()
{
    irqc_set_interrupt(IRQ_TSC, msr.TCR.P && msr.TCR.I);
}
