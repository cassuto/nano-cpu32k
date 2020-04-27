
/* test DMMU */
# EDTM
.org 0x20
	stw 0xc(r0), r1
	jmp r0, _d_tlb_miss
	
_d_tlb_miss:
	add r4,r4,1
	rmsr r1,(1<<2)(r0)
	xor r1,r1,(1<<7)
	wmsr (1<<2)(r0), r1
	ret
	
_reset:
	or r12,r0,123
	stw 0xc(r0), r12
	xor r12,r12,r12
	
	rmsr r1,1(r0)
	or r1,r1,(1<<7)
	# xor r1,r1,(1<<4)
	wmsr 1(r0), r1
	
	ldwu r2, 0xc(r0)
	add r3,r3,2
/* end */
