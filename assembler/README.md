# RISC-V RV32I Assembler

A two-pass assembler for the RISC-V RV32I base integer instruction set, written in Zig. Converts human-readable assembly into hex machine code compatible with Verilog's `$readmemh` for direct use with the CPU simulations.

## Usage

```bash
cd assembler

# Assemble a file (outputs .hex by default)
zig build run -- program.asm

# Specify output path
zig build run -- program.asm -o output.hex

# Run tests
zig build test
```

## Example

Input (`program.asm`):
```asm
# Count down from 3 to 0
addi x1, x0, 3
loop:
    addi x1, x1, -1
    bne  x1, x0, loop
addi x2, x0, 42     # done
```

Output (`program.hex`):
```
00300093
fff08093
fe009ee3
02a00113
```

This hex file can be loaded directly by the CPU's instruction memory using `$readmemh("program.hex", mem)`.

## Supported Instructions

### RV32I Base Integer Instructions

| Type | Instructions |
|------|-------------|
| R-type (register-register) | `add`, `sub`, `sll`, `slt`, `sltu`, `xor`, `srl`, `sra`, `or`, `and` |
| I-type (immediate) | `addi`, `slti`, `sltiu`, `xori`, `ori`, `andi`, `slli`, `srli`, `srai` |
| Load | `lw` |
| Store | `sw` |
| Branch | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| Upper immediate | `lui`, `auipc` |
| Jump | `jal`, `jalr` |

### Pseudo-instructions

| Pseudo | Expands to |
|--------|-----------|
| `nop` | `addi x0, x0, 0` |
| `mv rd, rs` | `addi rd, rs, 0` |
| `li rd, imm` | `addi rd, x0, imm` |
| `j label` | `jal x0, label` |
| `ret` | `jalr x0, ra, 0` |

### Register Names

Supports both numeric (`x0`-`x31`) and ABI names (`zero`, `ra`, `sp`, `t0`, `a0`, `s0`, etc.).

## How It Works

The assembler runs in two passes:

1. **Pass 1 — Label collection**: Scans every line for labels (e.g., `loop:`), records the byte address each label corresponds to.
2. **Pass 2 — Encoding**: For each instruction, tokenizes the line, looks up the instruction format, and packs the opcode, registers, and immediates into a 32-bit word following the RISC-V encoding spec.

This is essentially the **reverse of the CPU's decoder** — the decoder unpacks bits into control signals, the assembler packs control signals into bits.

## Building

Requires [Zig](https://ziglang.org/) (tested with 0.15.0-dev).

```bash
cd assembler
zig build
```

The built binary will be at `zig-out/bin/riscv-asm`.
