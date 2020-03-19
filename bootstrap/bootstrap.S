/* Init code */

.extern bootstrap_entry

/* Bootrom entry */
.org 0x0
.proc _start
.global _start
.type	_start, @function
_start:
	/* Set up stack */
	or sp, r0, lo(0x020000)
	mhi sp, hi(0x020000)
	
	/* Return address of entry */
	mhi lnk, hi(hlt)
	or lnk, lnk, lo(hlt)

	jmp r0, bootstrap_entry

.size	_start, .-_start
.align	4

.proc halt
.global hlt
.type	hlt, @function
hlt:
	jmp r0,hlt
.align	4


