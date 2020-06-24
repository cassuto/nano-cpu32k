/* test irq */
.org 0x0
jmp r0, _reset

# EIRQ
.org 0x00000008
	jmp r0, irq_handler

.org 0x100

irq_handler:
	add r1,r1,999
	jmp r0, irq_handler
	
_reset:
	# IRE
	rmsr r1,1(r0)
	or r1,r1,(1<<5)
	wmsr 1(r0), r1
	
	# IMR
	rmsr r1,((6<<9)+1)(r0)
	xor r1,r1,r1
	wmsr ((6<<9)+1)(r0), r1

	
_loop:
	add r2,r2,1
	jmp r0, _loop
/* end */
