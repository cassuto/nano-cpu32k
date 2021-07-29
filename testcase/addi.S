.org 0x0

addi x1, x0, 123
addi x2, x1, 4
addi x3, x2, 4
addi x4, x3, 4
addi x5, x4, 4
addi x6, x5, 4
addi x7, x6, 4
addi x8, x7, 4
addi x31, x8, 4

lui x31, 0x80010

#
# test jal and jalr
#
jal x31, l1
addi x2, x0, 0xba
l1:
addi x1, x0, 0x123

li x30, 0x80  # = address(l2) - 8
sll x30, x30, 24
ori x30, x30, 0x40

jalr x31, 8(x30)
addi x2, x0, 0xba
l2:
addi x2, x0, 0x456

#
# test bcc
#
lui x1, 0x80000
lui x2, 0x70000
beq x1,x2, bad
li x3, 0x123
bne x1,x2,ok1
jal x31, bad
ok1:
blt x1,x2, ok2
jal bad
ok2:
bge x1,x2, bad
li x3, 0x123
bltu x1,x2, ok3
jal bad
ok3:
li x3, 0x123
bgeu x1,x2, ok4
jal bad
ok4:
li x3, 0x123
bad:
li x3, 0xba

#
# test memory
#
li x30, 0x80
sll x30, x30, 24 # x30=0x80000000
li x7, 0xF0
sll x7, x7, 16
add x6, x30, x7 # x6=0x80f00000

li x5, 0x10
sb x5, 4(x6)
lb x29, 4(x6)

