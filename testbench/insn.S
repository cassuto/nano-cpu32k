.org 0x0
jmp r0, _reset


/* test syscall */
.org 0xc
ldwu r1, 3(r0)
cmp r0,eq,r0
add r1,r0,432
ret
add r2,r0,2
add r2,r0,3

.org 0x100

_reset:
syscall 0xc
add r2,r0,1
/* end */