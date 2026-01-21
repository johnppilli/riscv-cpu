# RISC-V CPU

A single-cycle RISC-V RV32I processor implemented in SystemVerilog.

## Overview

This is a from-scratch implementation of a RISC-V CPU that executes the RV32I base integer instruction set. Currently implemented as a single-cycle design, with plans to evolve into a pipelined out-of-order processor.

## Architecture

```
┌──────────┐    ┌──────────┐    ┌──────────┐
│    PC    │───▶│  I-Mem   │───▶│ Decoder  │
└──────────┘    └──────────┘    └──────────┘
      ▲                              │
      │              ┌───────────────┘
      │              ▼
      │         ┌──────────┐
      │         │ Register │
      │         │   File   │
      │         └──────────┘
      │              │
      │              ▼
      │         ┌──────────┐
      └─────────│   ALU    │
                └──────────┘
                     │
                     ▼
                ┌──────────┐
                │  D-Mem   │
                └──────────┘
```

## Supported Instructions

| Type | Instructions |
|------|--------------|
| R-type | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` |
| I-type | `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai`, `lw`, `jalr` |
| S-type | `sw` |
| B-type | `beq` |
| U-type | `lui`, `auipc` |
| J-type | `jal` |

## Project Structure

```
riscv-cpu/
├── rtl/                    # RTL design files
│   ├── alu.sv              # Arithmetic Logic Unit
│   ├── register_file.sv    # 32x32-bit register file
│   ├── program_counter.sv  # Program counter
│   ├── decoder.sv          # Instruction decoder
│   ├── instruction_memory.sv
│   ├── data_memory.sv
│   └── cpu_top.sv          # Top-level module
├── ref/                    # Reference model (Zig)
│   ├── riscv_ref.zig       # RISC-V software emulator
│   └── build.zig           # Zig build configuration
├── sim/                    # Verilator testbench
│   ├── tb_top.cpp          # C++ testbench
│   └── riscv_ref.h         # C header for Zig library
├── tb/                     # Icarus Verilog testbench
│   └── cpu_tb.sv
├── tests/                  # Test programs
│   └── simple_add.s
├── program.hex             # Test program in hex
└── Makefile
```

## Running the Simulation

Requires [Icarus Verilog](http://iverilog.icarus.com/).

```bash
# Run simulation
make sim

# View waveforms (requires GTKWave)
make wave

# Clean build artifacts
make clean
```

## Example Output

```
=== RISC-V CPU Testbench ===

PC=00000000 | Instr=00500093 | x1=5 | x2=0 | x3=0
PC=00000004 | Instr=00300113 | x1=5 | x2=3 | x3=0
PC=00000008 | Instr=002081b3 | x1=5 | x2=3 | x3=8

=== Test Results ===
x1 = 5 (expected: 5)
x2 = 3 (expected: 3)
x3 = 8 (expected: 8)

*** PASS ***
```

## Verification

The RTL is verified against a reference model using Verilator.

**Reference Model**: A RISC-V instruction set emulator written in Zig (`ref/riscv_ref.zig`)

**Verification Flow**:
1. Verilator compiles SystemVerilog RTL to C++
2. C++ testbench runs both RTL and reference model
3. After each instruction, PC and all 32 registers are compared
4. Any mismatch is flagged as a failure

```bash
# Run verification (requires Verilator and Zig)
make verify
```

```
========================================
RISC-V CPU Verification Testbench
RTL vs Reference Model Comparison
========================================

===== Running Test: Simple Add =====
PASS: Simple Add

===== Running Test: Subtraction =====
PASS: Subtraction

===== Running Test: Logical Ops =====
PASS: Logical Ops

===== Running Test: Immediate Ops =====
PASS: Immediate Ops

===== Running Test: Shifts =====
PASS: Shifts

========================================
Test Summary
========================================
Tests Passed: 5
Tests Failed: 0

*** ALL TESTS PASSED ***
```

## Roadmap

- [x] Single-cycle CPU
- [x] Verilator verification with Zig reference model
- [ ] 5-stage pipeline
- [ ] Hazard detection and forwarding
- [ ] Branch prediction
- [ ] Instruction and data caches
- [ ] Out-of-order execution (ROB, register renaming, issue queue)
