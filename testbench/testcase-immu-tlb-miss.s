
/* test IMMU */
# EIPF
.org 0x00000014
	jmp r0, i_page_fault
# EITM
.org 0x0000001c
	jmp r0, boot_itlb_miss_handler

.org 0x100
boot_itlb_miss_handler:
	stw	   0x1000(r0),r3
	stw	   0x1004(r0),v0
	stw	   0x1008(r0),v1
	stw	   0x100c(r0),v2
	stw	   0x1010(r0),v3

	rmsr v1,(1<<4)(r0)		/* v1 = LSA */

	and v3,r0,r0

	lsr	 v0,v1,13
	rmsr v3, (1<<9)(r0) /* MSR_IMMID */
	and	v3, v3, 0x7 /* MSR_IMMID_STLB */
	lsr	v3, v3, 0 /* MSR_IMMID_STLB_SHIFT */
	or	v2, r0, 0x1
	lsl	v2, v2, v3	/* v2 = size of DMMU TLB entries */
	add	v3, v2, -1	/* v3 = TLE_OFFSET_MASK */
	and	r3, v0, v3	/* r3 = TLB entry offset */

	/* generate TLBL entry */
	or	  v3,v3,v1
	or	 v3,v3,~(0xffffe000)
	
	mhi v2,hi(0xffffe001) /* set V bit */
	or v2,v2,lo(0xffffe001)
	
	and	  v2,v2,v3
	wmsr ((1<<9)+0x100)(r3), v2	/* reload ITLBL */

	/* reload ITLB with no translation for user-space(LSA <= 0x00c00000) 
	 */
	mhi v3,hi(0x00c00000)
	or v3,v3,lo(0x00c00000)
	cmp v1,gtu,v3
	and	   v0,v1,v1	/* v0 = LSA */
	bf	   1f
	sub v0,v1,v3 /* v0 = PA(V1) */
1:
	/* generate TLBH entry */
	or	 v0,v0,~(0xffffe000)
	mhi v2,hi(0xffffe014) /* _PAGE_A | _PAGE_RX */
	or v2,v2,lo(0xffffe014)
	and	  v2,v2,v0
	wmsr ((1<<9)+0x180)(r3), v2 /* reload ITLBH */

	ldwu   v3,0x1010(r0)
	ldwu   v2,0x100c(r0)
	ldwu   v1,0x1008(r0)
	ldwu   v0,0x1004(r0)
	ldwu   r3,0x1000(r0)

	ret
	
i_page_fault:
	add r2,r2,2
	jmp lnk, i_page_fault
	
.org 0x1000
	.space 128
	
.org 0x00002000
	_1:
	add r1,r1,1
	add r2,r2,2
	add r3,r3,3
	add r4,r4,4
	jmp lnk,_1

_reset:
	rmsr r1,1(r0)
	or r1,r1,(1<<6)
	# xor r1,r1,(1<<4)
	wmsr 1(r0), r1
	
	mhi r1, hi(0x00c02000)
	or r1,r1,lo(0x00c02000)
	jmp lnk, r1
	add r7,r7,1
	add r8,r8,2
	add r9,r9,3
	add r10,r10,4
/* end */
