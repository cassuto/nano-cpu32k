# ERST
.org 0x0
	jmp r0, _reset
	
.org 0x100
_reset:
	add r1,r0,0x123
	add r2,r0,0x456
	add r3,r1,r2
	add r4,r0,0x24
	add r5,r0,0x25
	add r6,r0,0x26
	add r7,r4,r5
	add r8,r2,r3
	add r9,r1,r2
	add r10,r3,r4
	add r11,r5,r6
	
;
; r1 = 0x123
; r2 = 0x456
; r3 = 0x579
; r4 = 0x24
; r5 = 0x25
; r6 = 0x26
; r7 = 0x49
; r8 = 0x9cf
; r10 = 0x59d
; r11 = 0x4b
;
