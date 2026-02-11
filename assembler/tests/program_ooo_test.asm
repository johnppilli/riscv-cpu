# program_ooo_test.asm — Tests out-of-order execution
# Independent instructions that can be executed in any order
addi x1, x0, 5      # x1 = 5
addi x2, x0, 3      # x2 = 3     (independent of x1)
add  x3, x1, x2     # x3 = 8     (depends on x1, x2)
addi x4, x0, 10     # x4 = 10    (independent)
add  x5, x3, x4     # x5 = 18    (depends on x3, x4)
nop
nop
nop
