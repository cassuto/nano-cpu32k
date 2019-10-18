.org 0x0
jmp r8, _l
add r1, r0, 123
.org 0x10
_l:
jmp r8,_start
add r1, r0, 456

.org 0x100
_start:
jmp r0, r8
add r1, r0, 123
add r3, r0, -1
sub r4, r1, r2
sub r5, r1, r2
add r6, r0, r1
jmp r1,_start