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

/* test SE */
_reset:
add r0,r0,r0

bf _123
add r2,r0,444 # 2
_123:
add r2,r0,555 # 3

add r2,r2,1 # 4
add r2,r2,1 # 5
add r2,r2,1 # 6


#jmp lnk, _l1 # 7
_l1:
jmp lnk, _reset # 8
add r3,r0,333
/*end*/


/* test stall */
add r3, r3, 240
add r2, r2, 4
stw 4(r2), r3
stw 8(r2), r2
ldwu r4, 4(r2)
ldwu r5, 8(r2)
/* end */



_halt:
jmp lnk,_halt


/* test continuous jumping */
_reset:
bf _r1 				# 1
add r3,r0,123 		# 2
_r1:
bt _r2 				# 3
add r3,r0,321		# 4
_r2:
add r3,r0,44 		# 5

/* cc=0 */
/* predicate not_taken */
bt _e				# 6
bf _r3				# 7
add r3,r0,4			# 8
_r3:
add r3,r0,5			# 9
_e:
add r3,r0,6 		#10

/* end */

/* test stall */
_reset:
add r8,r8, 2
_loop:
add r3, r3, 240
add r2, r2, 4
stw 4(r2), r3
stw 8(r2), r2
ldwu r4, 4(r2)
ldwu r5, 8(r2)
#add r0,r0,r0
#add r0,r0,r0
#add r0,r0,r0
#add r0,r0,r0

jmp lnk,_loop
/* end */


/* test mhi */
mhi r2,hi(1000016383)
or r2,r2,lo(1000016383)
/* end */

/* test load/store */
add r1, r0, -12
stb 4(r0), r1
ldwu r2, 4(r0)
sth 4(r0), r1
ldwu r2, 4(r0)
stw 4(r0), r1
ldwu r2, 4(r0)

sth 4(r0), r1
ldwu r2, 4(r0)
stb 4(r0), r1
ldwu r2, 4(r0)
/* end */



ldwu r5, 4(r2) # 7
ldwu r6, 8(r2) # 8
ldwu r7, 4(r2) # 9
ldwu r8, 8(r2) # 10

.org 0x300
add r2, r2, 1
add r3, r3, 1
add r4, r0, 5
/*add r2, r1, -1
sub r3, r1, r2
sub r4, r2, r3
add r5, r4, r2*/
/*add r2,r2,1
add r3,r2,1
add r4,r2,1
add r5,r2,1*/
jmp lnk,_reset
# bf _reset
# jmp r0, r4
add r8,r8,1
add r8,r8,1 # 5
add r8,r8,1
add r8,r8,1
