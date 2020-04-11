/* Init code */

.extern coremark_main

/* Bootrom entry */
.org 0x0
.proc _start
.global _start
.type	_start, @function
_start:
	/* Set up stack */
	mhi sp, hi(0x01000000)
	or sp, sp, lo(0x01000000)
	
	/* Return address of entry */
	mhi lnk, hi(hlt)
	or lnk, lnk, lo(hlt)
	
	/* startup TSC */
	mhi v1, hi(0 | (1<<28)) # EN
	or v1,v1, lo(0| (1<<28))
	wmsr ((7<<9)+(1<<1))(r0), v1 # TCR
	
	xor v1,v1,v1
	
	/* Relative jmp */
	jmp r0, coremark_main

.size	_start, .-_start
.align	4

.proc halt
.global hlt
.type	hlt, @function
hlt:
	jmp r0,hlt
.align	4


