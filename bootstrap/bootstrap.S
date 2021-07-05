/* Init code */

.extern bootstrap_entry

/* Bootrom entry */
.org 0x0
.proc _start
.global _start
.type	_start, @function
_start:
	/* Set up stack */
	/* Stack in DRAM */
	mhi sp, hi(0x01fffffc)
   or sp, sp, lo(0x01fffffc)
	
	/* Return address of entry */
	mhi lnk, hi(hlt)
	or lnk, lnk, lo(hlt)
	
	/* Relative jmp */
	jmp r0, bootstrap_entry

.size	_start, .-_start
.align	4

.proc halt
.global hlt
.type	hlt, @function
hlt:
	jmp r0,hlt
.align	4


