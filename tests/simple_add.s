# simple_add.s - First test program
# Expected result: x3 = 8

addi x1, x0, 5      # x1 = 0 + 5 = 5
addi x2, x0, 3      # x2 = 0 + 3 = 3
add  x3, x1, x2     # x3 = x1 + x2 = 5 + 3 = 8
