# ERST
.org 0x0
	jmp r0, _reset
	
.org 0x100
_reset:
	or r2, r0, 0x200
# Prefetch icache line
	jmp lnk, r2
	
# Generate codes
	mhi r1,hi(0x00c8020b)
	or r1,r1,lo(0x00c8020b)
	stw 0(r2), r1
	add r2,r2,4
	
	mhi r1,hi(0x00021084)
	or r1,r1,lo(0x00021084)
	stw 0(r2), r1
	add r2,r2,4
	
	mhi r1,hi(0x0002108b)
	or r1,r1,lo(0x0002108b)
	stw 0(r2), r1
	add r2,r2,4
	
	mhi r1,hi(0xfffe4092)
	or r1,r1,lo(0xfffe4092)
	stw 0(r2), r1
	add r2,r2,4
	
	mhi r1,hi(0x00021084)
	or r1,r1,lo(0x00021084)
	stw 0(r2), r1
	add r2,r2,4
	
	mhi r1,hi(0xfffffd8e)
	or r1,r1,lo(0xfffffd8e)
	stw 0(r2), r1
	add r2,r2,4
	
	or r2, r0, 0x200
	
# Flush d-cache
	wmsr ((4 << 9) + (1<<2))(r0),r2  # MSR_DCFLS
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
# Invalidate i-cache
	wmsr ((3 << 9) + (1<<1))(r0),r2 # MSR_ICINV
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	nop
	
# Goto generated code
	jmp r0, r2

.org 0x200
	nop
	nop
	nop
	nop
	jmp r0, lnk
	
	


#
# Codes to be generated
#_test:
#	add r4,r0,100
#	xor r1,r1,r1
#_add:
#	add r1,r1,1
#	bcc r4,gt,r1,_add
#	xor r1,r1,r1
#	jmp r0,_test
#
#00000200 <_test>:
# 200:   0b 02 c8 00     add r4,r0,100
# 204:   84 10 02 00     xor r1,r1,r1
#
#00000208 <_add>:
# 208:   8b 10 02 00     add r1,r1,1
# 20c:   92 40 fe ff     bcc r4,gt,r1, <_add>
# 210:   84 10 02 00     xor r1,r1,r1
# 214:   8e fd ff ff     jmp r0,214 <_test>
#