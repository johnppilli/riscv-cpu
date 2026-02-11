# program_pipelined.asm — Tests basic pipeline operation
# NOPs inserted between instructions to avoid data hazards
# (the pipeline takes multiple cycles to complete each instruction)
addi x1, x0, 5      # x1 = 5
nop
nop
nop
addi x2, x0, 3      # x2 = 3
nop
nop
nop
add  x3, x1, x2     # x3 = x1 + x2 = 8
nop
