# program_branch_test.asm — Tests branch prediction
# Counts down from 3 to 0 in a loop, then sets x2 = 42
addi x1, x0, 3      # x1 = 3 (loop counter)
loop:
    addi x1, x1, -1 # x1 = x1 - 1
    bne  x1, x0, loop  # if x1 != 0, jump back to loop
addi x2, x0, 42     # x2 = 42 (reached after loop ends)
nop
nop
nop
nop
