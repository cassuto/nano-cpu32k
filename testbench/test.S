
/* test syscall with imme PSR */
.org 0x0c
jmp r0, _syscall

.org 0x14
add r8,r8,1
add r9,r8,1
add r10,r8,1
wmsr (1<<2)(r0), r0
ret

.org 0x100

_syscall:
	rmsr r1, 1(r0)
	ldwu r1, 3(r0) # 3
	cmp r0,eq,r0   # 4
	add r1,r1,432  # 5
	ret            # 6
	add r2,r2,2
	add r2,r2,3

_reset:
rmsr r1, 1(r0)
or r1,r1,(1<<6)  # 4
wmsr 1(r0), r1   # 8
add r2,r2,2      # c
add r3,r3,3      # 10
add r4,r4,4
add r5,r5,5
add r6,r6,6

stw 3(r0), r2
syscall 0
rmsr r1, 1(r0)
add r7,r7,1
/* end */

/* test syscall */
.org 0xc
ldwu r1, 3(r0) # 3
cmp r0,eq,r0   # 4
add r1,r0,432  # 5
ret            # 6
add r2,r0,2
add r2,r0,3

.org 0x100
_reset:
syscall 0xc # 64
add r2,r0,1 # 65
/* end */

/* test syscall with imme PSR */
.org 0xc
rmsr r1, 1(r0)
# ldwu r1, 3(r0) # 3
cmp r0,eq,r0   # 4
add r1,r1,432  # 5
ret            # 6
add r2,r2,2
add r2,r2,3

.org 0x100

_reset:
add r1,r0,(1<<6) # 4
wmsr 1(r0), r1   # 8
add r2,r2,2      # c
add r3,r3,3      # 10
add r4,r4,4
add r5,r5,5
add r6,r6,6

syscall 0
rmsr r1, 1(r0)
add r7,r7,1
/* end */

/* test rmsr and wmsr */
_reset:
rmsr r1, 1(r0) # PSR
add r1,r0,18
wmsr 1(r0), r1
rmsr r2, 2(r0) # CPUID
/* end */


/* test non delay slot */
_reset:
add r0,r0,1
add r1,r1,2
add r2,r2,3
add r3,r3,4

jmp lnk, _reset # 4
add r4,r0,123   # 5
add r4,r0,456   # 6
add r4,r0,789   # 7
add r4,r0,102   # 8
add r4,r0,103   # 9
add r4,r0,104   # 10
add r4,r0,105   # 11
/* end */

.org 0x100
/* test SE */
_reset:
add r0,r0,r0

bf _123
add r2,r0,444 # 2
add r2,r0,445
add r2,r0,446
add r2,r0,447
add r2,r0,448
add r2,r0,449
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
_reset:
add r8,r8, 2
_loop:
add r3, r3, 240
add r2, r2, 4
stw 4(r2), r3
stw 8(r2), r2
ldwu r4, 4(r2)
add r6,r6,1
add r6,r6,2
ldwu r5, 8(r2)
#add r0,r0,r0
#add r0,r0,r0
#add r0,r0,r0
#add r0,r0,r0

jmp lnk,_loop
/* end */



_halt:
jmp lnk,_halt


.org 0x100
/* test continuous jumping */
_reset:
bf _r1 				# 1
add r3,r3,123 		# 2
_r1:
bt _r2 				# 3
add r3,r3,321		# 4
_r2:
add r5,r5,44 		# 5

/* cc=0 */
/* predicate not_taken */
bt _e				# 6
bf _r3				# 7
add r3,r3,4			# 8
_r3:
add r4,r4,5			# 9
_e:
add r6,r6,6 		#10

/* end */



/* test mhi */
mhi r2,hi(1000016383)
or r2,r2,lo(1000016383)
/* end */

/* test load/store */
_reset:
mhi r1, hi(0xabcdef12)
or r1,r1,lo(0xabcdef12)
add r2,r0,123
ldwu r2, 4(r0)
stb 4(r0), r1
ldwu r2, 4(r0)
stb 5(r0), r1
ldwu r2, 4(r0)
stb 6(r0), r1
ldwu r2, 4(r0)
stb 7(r0), r1
ldwu r2, 4(r0)

ldbu r2, 4(r0)
sth 4(r0), r1
ldwu r2, 4(r0)
stw 4(r0), r1
ldwu r2, 4(r0)
ldbu r2, 4(r0)
ldbu r2, 5(r0)
ldbu r2, 6(r0)
ldbu r2, 7(r0)

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
