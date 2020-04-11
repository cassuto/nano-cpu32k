#ifndef NCPU32K_MSR_H_
#define NCPU32K_MSR_H_

#define MAX_MSR_BANK_BITS 9 /* (1 << MAX_MSR_BANK_BITS) = 512 */

/* MSR banks  */
#define MSR_BANK_PS		(0 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DBG	(5 << MAX_MSR_BANK_BITS)
#define MSR_BANK_TSC	(7 << MAX_MSR_BANK_BITS)


/*********************************************************************
* MSR bank - PS
**********************************************************************/

/* MSR.PSR R/W */
#define MSR_PSR	(MSR_BANK_PS + (1<<0))
#define MSR_PSR_CC_SHIFT	0
#define MSR_PSR_CC		(1 << MSR_PSR_CC_SHIFT)
#define MSR_PSR_CY_SHIFT	1
#define MSR_PSR_CY		(1 << MSR_PSR_CY_SHIFT)
#define MSR_PSR_OV_SHIFT	2
#define MSR_PSR_OV		(1 << MSR_PSR_OV_SHIFT)
#define MSR_PSR_OE_SHIFT	3
#define MSR_PSR_OE		(1 << MSR_PSR_OE_SHIFT)
#define MSR_PSR_RM_SHIFT	4
#define MSR_PSR_RM		(1 << MSR_PSR_RM_SHIFT)
#define MSR_PSR_IRE_SHIFT	5
#define MSR_PSR_IRE		(1 << MSR_PSR_IRE_SHIFT)
#define MSR_PSR_IMME_SHIFT	6
#define MSR_PSR_IMME	(1 << MSR_PSR_IMME_SHIFT)
#define MSR_PSR_DMME_SHIFT	7
#define MSR_PSR_DMME	(1 << MSR_PSR_DMME_SHIFT)
#define MSR_PSR_ICAE_SHIFT	8
#define MSR_PSR_ICAE	(1 << MSR_PSR_ICAE_SHIFT)
#define MSR_PSR_DCAE_SHIFT	9
#define MSR_PSR_DCAE	(1 << MSR_PSR_DCAE_SHIFT)

/* MSR.CPUID R */
#define MSR_CPUID	(MSR_BANK_PS + (1<<1))
#define MSR_CPUID_VER_SHIFT	0
#define MSR_CPUID_VER	0x000000ff
#define MSR_CPUID_REV_SHIFT	8
#define MSR_CPUID_REV	0x0003ff00
#define MSR_CPUID_FIMM_SHIFT 18
#define MSR_CPUID_FIMM	(1 << MSR_CPUID_FIMM_SHIFT)
#define MSR_CPUID_FDMM_SHIFT 19
#define MSR_CPUID_FDMM	(1 << MSR_CPUID_FDMM_SHIFT)
#define MSR_CPUID_FICA_SHIFT 20
#define MSR_CPUID_FICA	(1 << MSR_CPUID_FICA_SHIFT)
#define MSR_CPUID_FDCA_SHIFT 21
#define MSR_CPUID_FDCA	(1 << MSR_CPUID_FDCA_SHIFT)
#define MSR_CPUID_FDBG_SHIFT 22
#define MSR_CPUID_FDBG	(1 << MSR_CPUID_FDBG_SHIFT)
#define MSR_CPUID_FFPU_SHIFT 23
#define MSR_CPUID_FFPU  (1 << MSR_CPUID_FFPU_SHIFT)
#define MSR_CPUID_FIRQC_SHIFT 24
#define MSR_CPUID_FIRQC	(1 << MSR_CPUID_FIRQC_SHIFT)
#define MSR_CPUID_FTSC_SHIFT 25
#define MSR_CPUID_FTSC  (1 << MSR_CPUID_FTSC_SHIFT)


/* MSR.EPSR R/W */
#define MSR_EPSR	(MSR_BANK_PS + (1<<2))

/* MSR.EPC R/W */
#define MSR_EPC	(MSR_BANK_PS + (1<<3))

/* MSR.ELSA R/W */
#define MSR_ELSA	(MSR_BANK_PS + (1<<4))

/* MSR.COREID R */
#define MSR_COREID	(MSR_BANK_PS + (1<<5))


/*********************************************************************
* MSR bank - DBG
**********************************************************************/

/* MSR.DBGR */
#define MSR_DBGR_NUMPORT (MSR_BANK_DBG + (1<<0))
#define MSR_DBGR_MSGPORT (MSR_BANK_DBG + (1<<1))

/*********************************************************************
* MSR bank - TSC
**********************************************************************/

/* MSR.TSR R/W */
#define MSR_TSR	(MSR_BANK_TSC + (1<<0))

/* MSR.TCR R/W */
#define MSR_TCR	(MSR_BANK_TSC + (1<<1))
#define MSR_TCR_CNT_SHIFT 0
#define MSR_TCR_CNT	0x0fffffff
#define MSR_TCR_EN_SHIFT 28
#define MSR_TCR_EN	(1 << MSR_TCR_EN_SHIFT)
#define MSR_TCR_I_SHIFT 29
#define MSR_TCR_I	(1 << MSR_TCR_I_SHIFT)
#define MSR_TCR_P_SHIFT 30
#define MSR_TCR_P	(1 << MSR_TCR_P_SHIFT)

/*********************************************************************
* Wrapper of WMSR.RMSR
**********************************************************************/

#define wmsr(_index, _val) __asm__ __volatile__ (		\
	"wmsr %0(r0),%1"					\
	: : "K" (_index), "r" (_val))
#define wmsr_reg(_index, _off, _val) __asm__ __volatile__ (	\
	"wmsr %2(%0),%1"					\
	: : "r" (_off), "r" (_val), "K" (_index))

static inline unsigned long rmsr(unsigned long index)
{
	unsigned long ret;
	__asm__ __volatile__ ("rmsr %0,%1(r0)" : "=r" (ret) : "K" (index));
	return ret;
}

static inline unsigned long rmsr_reg(unsigned long index, unsigned long offset)
{
	unsigned long ret;
	__asm__ __volatile__ ("rmsr %0,%2(%1)" : "=r" (ret)
						 : "r" (offset), "K" (index));
	return ret;
}

#endif /* NCPU32K_MSR_H_ */
