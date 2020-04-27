
/* test TSC */
# EIRQ
.org 0x8
	jmp r0, irq_handler

.org 0x1000
	.space 128

irq_handler:
	stw   0x1010(r0), r1
	stw   0x100c(r0), r2
	
	mhi r2,hi(1<<30) # P
	or r2,r2,lo(1<<30)
	
	rmsr r1, ((7<<9)+(1<<1))(r0) # TCR
	xor r1,r1,r2
	wmsr ((7<<9)+(1<<1))(r0), r1
	
	wmsr ((7<<9)+(1<<0))(r0), r0 # TSR
	
	add r4,r4,1
	
	ldwu   r1,0x1010(r0)
	ldwu   r2,0x100c(r0)
	ret

_reset:
	/* Config TSC */
	mhi r1, hi(50 | (1<<28)|(1<<29)) # EN | I
	or r1,r1, lo(50 | (1<<28)|(1<<29))
	wmsr ((7<<9)+(1<<1))(r0), r1 # TCR
	
	/* Config IRQC */
	wmsr ((6<<9)+1)(r0), r0 # IMR
	
	/* Enable IRQ Exception */
	rmsr r1,1(r0)
	or r1,r1,(1<<5) # IRE
	wmsr 1(r0), r1
	
_halt:
	add r3,r3,1
	jmp r0,_halt
/* end */
