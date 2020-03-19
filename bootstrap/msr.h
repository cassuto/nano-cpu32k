#ifndef MSR_H_
#define MST_H_

#define MAX_MSR_BANK_BITS 9
#define MSR_BANK_DBGR (5 << MAX_MSR_BANK_BITS)

#define MSR_DBGR_NUMPORT (MSR_BANK_DBGR + (1<<0))
#define MSR_DBGR_MSGPORT (MSR_BANK_DBGR + (1<<1))

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
