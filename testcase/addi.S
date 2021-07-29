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

# test jal and jalr
jal x31, l1
addi x2, x0, 0xba
l1:
addi x1, x0, 0x123
li x30, 0x3c  # = address(l2) - 4
jalr x31, 4(x30)
addi x2, x0, 0xba
l2:
addi x2, x0, 0x456

