// riscv_ref.h - C header for Zig reference model

#ifndef RISCV_REF_H
#define RISCV_REF_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

typedef struct {
    uint32_t pc;
    uint32_t regs[32];
    uint8_t* mem;
    uint32_t mem_size;
    bool halted;
} RiscvCpu;

void riscv_init(RiscvCpu* cpu, uint8_t* mem, uint32_t mem_size);
void riscv_step(RiscvCpu* cpu);
uint32_t riscv_get_pc(RiscvCpu* cpu);
uint32_t riscv_get_reg(RiscvCpu* cpu, uint32_t reg);
void riscv_set_reg(RiscvCpu* cpu, uint32_t reg, uint32_t value);
void riscv_load_program(RiscvCpu* cpu, const uint8_t* program, uint32_t size);
bool riscv_is_halted(RiscvCpu* cpu);

#ifdef __cplusplus
}
#endif

#endif // RISCV_REF_H
