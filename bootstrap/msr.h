#ifndef MSR_H_
#define MST_H_

#define MAX_MSR_BANK_BITS 9
#define MSR_BANK_ICA	(3 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DCA	(4 << MAX_MSR_BANK_BITS)
#define MSR_BANK_DBGR (5 << MAX_MSR_BANK_BITS)

/*********************************************************************
* MSR bank - DBG
**********************************************************************/

#define MSR_DBGR_NUMPORT (MSR_BANK_DBGR + (1<<0))
#define MSR_DBGR_MSGPORT (MSR_BANK_DBGR + (1<<1))


/*********************************************************************
* MSR bank - ICA
**********************************************************************/

/* MSR.ICID */
#define MSR_ICID	(MSR_BANK_ICA + (1<<0))
#define MSR_ICID_SS_SHIFT	0
#define MSR_ICID_SS	0xf
#define MSR_ICID_SL_SHIFT 4
#define MSR_ICID_SL	(1 << MSR_ICID_SL_SHIFT)
#define MSR_ICID_SW_SHIFT 8
#define MSR_ICID_SW	(1 << MSR_ICID_SW_SHIFT)
#define MSR_ICINV	(MSR_BANK_ICA + (1<<1))


/*********************************************************************
* MSR bank - DCA
**********************************************************************/

/* MSR.DCID */
#define MSR_DCID	(MSR_BANK_DCA + (1<<0))
#define MSR_DCID_SS_SHIFT	0
#define MSR_DCID_SS	0xf
#define MSR_DCID_SL_SHIFT	4
#define MSR_DCID_SL	(1 << MSR_DCID_SL_SHIFT)
#define MSR_DCID_SW_SHIFT	8
#define MSR_DCID_SW	(1 << MSR_DCID_SW_SHIFT)
#define MSR_DCINV	(MSR_BANK_DCA + (1<<1))
#define MSR_DCFLS	(MSR_BANK_DCA + (1<<2))


#define wmsr(_index, _val) __asm__ __volatile__ (		\
	"wmsr %0(r0),%1"					\
	: : "K" (_index), "r" (_val))

static inline unsigned long rmsr(unsigned long index)
{
	unsigned long ret;
	__asm__ __volatile__ ("rmsr %0,%1(r0)" : "=r" (ret) : "K" (index));
	return ret;
}

#endif // MST_H_
