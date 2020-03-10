/* test emu insn */
# EINSN
.org 0x4
jmp r0, _emu_insn

.org 0x100
_emu_insn:
	add r16,r16,233
	#jmp r0, _emu_insn
	ret
	
_reset:
	ldwa r1, 0(r0)
	add r2,r2,1
/* end */