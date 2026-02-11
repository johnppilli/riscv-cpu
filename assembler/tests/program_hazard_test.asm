# program_hazard_test.asm — Tests data hazard detection and forwarding
# Instructions have back-to-back data dependencies:
#   x2 depends on x1, x3 depends on x1+x2, x4 depends on x2+x3
addi x1, x0, 5      # x1 = 5
addi x2, x1, 3      # x2 = x1 + 3 = 8   (data hazard: x1 just written)
add  x3, x1, x2     # x3 = x1 + x2 = 13 (data hazard: x2 just written)
add  x4, x3, x1     # x4 = x3 + x1 = 18 (data hazard: x3 just written)
nop
nop
nop
nop
nop
