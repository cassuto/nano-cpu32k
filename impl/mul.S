#include "simplify.inc"

/**
 * Integer Multiply (unsigned). Time O(logN)
 * @param[in] op1 = v0
 * @param[in] op2 = v1
 * @return op1 * op2
 */

/*
 * Pseudo code:
 * if (v0==0) return 0;
 * v2 = v0;
 * do {
 *  v0 = v2 & 1;
 * 	if (v0) {
 * 		rv += v1;
 * 	}
 * 	v2 >>= 1;
 * 	v1 <<= 1;
 * } while(v2);
 *
 * Clobber registers:
 *   [in]	v0 v1
 *   [out]	rv
 *   [mod]	v0 v1 v2
 */

ENTRY(mul)
	mov rv,0x0
	
	cmp v0,eq,rv
	mov v2,v0
	bt 	3f	# v0==0
1:
	and v0,v2,0x1
	cmp	v0,eq,r0
	lsr v2,v2,0x1
	bt 2f	# v0==0
	add rv,rv,v1
2:
	lsl v1,v1,0x1
	cmp v2,eq,r0
	bf 	1b
3:
	jmp r0,lnk

.size mul,.-mul
