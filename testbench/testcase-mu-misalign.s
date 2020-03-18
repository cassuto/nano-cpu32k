
/* test load/store unalign */
.org 0x24
jmp r0, _align

.org 0x100
_reset:
	mhi r1,hi(0x12345678)
	or r1,r1,lo(0x12345678)
	stw 4(r0), r1
	ldwu r2, 3(r0)
	add r3,r3,1
	wmsr ((5<<9)+1)(r0), r2
	ldwu r2, 4(r0)
	add r3,r3,1
	wmsr ((5<<9)+1)(r0), r2
	
_halt:
	jmp r0, _halt
	
	/* clobber r1 */
_align:
	add r1,r0,123
	wmsr ((5<<9)+1)(r0), r1
	rmsr r1, (0+(1<<3))(r0) # EPC
	add r1,r1,4
	wmsr (0+(1<<3))(r0), r1 # EPC
	ret
/* end */
