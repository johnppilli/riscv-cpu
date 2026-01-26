# RISC-V CPU

An RV32I RISC-V processor implemented in SystemVerilog, built incrementally from single-cycle to pipelined to out-of-order execution.

## Features

### Three CPU Implementations

**1. Single-Cycle CPU** (`rtl/cpu_top.sv`)
- Basic RV32I implementation where each instruction completes in one cycle
- Good for understanding the fundamentals

**2. 5-Stage Pipelined CPU** (`rtl/cpu_pipelined.sv`)
- Classic IF → ID → EX → MEM → WB pipeline
- Data forwarding unit (EX-to-EX and MEM-to-EX paths)
- Hazard detection with pipeline stalling for load-use hazards
- 2-bit saturating counter branch predictor (64 entries) with BTB
- Separate instruction and data caches (direct-mapped, write-through)

**3. Out-of-Order CPU** (`rtl/cpu_ooo.sv`)
- Full out-of-order execution with in-order commit
- Register renaming with speculative and committed RAT
- 64-entry physical register file
- 8-entry issue queue with wakeup/select logic
- 16-entry reorder buffer for precise exceptions
- Free list for physical register allocation
- Ready table to track operand availability

## Supported Instructions

| Type | Instructions |
|------|--------------|
| R-type | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` |
| I-type | `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai`, `lw`, `jalr` |
| S-type | `sw` |
| B-type | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` |
| U-type | `lui`, `auipc` |
| J-type | `jal` |

## Project Structure

```
riscv-cpu/
├── rtl/                        # All RTL source files
│   ├── cpu_top.sv              # Single-cycle CPU
│   ├── cpu_pipelined.sv        # Pipelined CPU
│   ├── cpu_ooo.sv              # Out-of-order CPU
│   ├── alu.sv                  # ALU (shared)
│   ├── decoder.sv              # Instruction decoder
│   ├── register_file.sv        # Architectural register file
│   ├── physical_regfile.sv     # Physical register file (OoO)
│   ├── forwarding_unit.sv      # Data forwarding
│   ├── hazard_unit.sv          # Hazard detection
│   ├── branch_predictor.sv     # 2-bit saturating counter
│   ├── branch_target_buffer.sv # BTB for branch targets
│   ├── cache.sv                # Direct-mapped cache
│   ├── rat.sv                  # Register alias table
│   ├── rob.sv                  # Reorder buffer
│   ├── issue_queue.sv          # Issue queue with wakeup
│   └── free_list.sv            # Physical register free list
├── tb/                         # Testbenches
│   ├── cpu_tb.sv               # Single-cycle testbench
│   ├── cpu_pipelined_tb.sv     # Pipelined testbench
│   └── cpu_ooo_tb.sv           # OoO testbench
├── programs/                   # Test programs (hex)
├── ref/                        # Zig reference model
├── sim/                        # Verilator testbench
├── docs/                       # Documentation
└── Makefile
```

## Running Simulations

Requires [Icarus Verilog](http://iverilog.icarus.com/).

```bash
# Single-cycle CPU
make sim

# Pipelined CPU
make sim-pipe

# Out-of-order CPU
make sim-ooo

# View waveforms (requires GTKWave)
make wave       # single-cycle
make wave-pipe  # pipelined
make wave-ooo   # out-of-order

# Clean build artifacts
make clean
```

## Example Output

### Single-Cycle
```
=== RISC-V CPU Testbench ===
PC=00000000 | Instr=00500093 | x1=5 | x2=0 | x3=0
PC=00000004 | Instr=00300113 | x1=5 | x2=3 | x3=0
PC=00000008 | Instr=002081b3 | x1=5 | x2=3 | x3=8
*** PASS ***
```

### Out-of-Order
```
=== Out-of-Order RISC-V CPU Testbench ===
Running OoO test program...
Cycle 50: Checking committed register state
x1=5, x2=3, x3=8, x4=10, x5=18
*** PASS - Out-of-order execution works! ***
```

## Architecture Diagrams

### Single-Cycle
```
┌──────────┐    ┌──────────┐    ┌──────────┐
│    PC    │───▶│  I-Mem   │───▶│ Decoder  │
└──────────┘    └──────────┘    └──────────┘
                                     │
                    ┌────────────────┘
                    ▼
               ┌──────────┐
               │ Register │
               │   File   │
               └──────────┘
                    │
                    ▼
               ┌──────────┐    ┌──────────┐
               │   ALU    │───▶│  D-Mem   │
               └──────────┘    └──────────┘
```

### 5-Stage Pipeline
```
┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐   ┌───────┐
│  IF   │──▶│  ID   │──▶│  EX   │──▶│  MEM  │──▶│  WB   │
└───────┘   └───────┘   └───────┘   └───────┘   └───────┘
    │           │           │           │
    ▼           │           │           │
┌───────┐       │      ┌────┴────┐      │
│Branch │       │      │Forwarding      │
│Predict│       │      │  Unit   │◀─────┘
└───────┘       │      └─────────┘
                │           ▲
                ▼           │
           ┌─────────┐      │
           │ Hazard  │──────┘
           │  Unit   │ (stalls)
           └─────────┘
```

### Out-of-Order Pipeline
```
┌───────┐   ┌────────────────┐   ┌─────────┐   ┌─────────┐   ┌────────┐
│ Fetch │──▶│ Decode/Rename/ │──▶│  Issue  │──▶│ Execute │──▶│ Commit │
│       │   │    Dispatch    │   │  Queue  │   │  (ALU)  │   │ (ROB)  │
└───────┘   └────────────────┘   └─────────┘   └─────────┘   └────────┘
                   │                  ▲              │            │
                   ▼                  │              ▼            ▼
              ┌─────────┐        ┌────┴────┐   ┌─────────┐   ┌─────────┐
              │   RAT   │        │ Wakeup  │◀──│Broadcast│   │ Arch RF │
              │(rename) │        │ Logic   │   │ Result  │   │ Update  │
              └─────────┘        └─────────┘   └─────────┘   └─────────┘
                   │
              ┌────┴────┐
              │  Free   │
              │  List   │
              └─────────┘
```

## Verification

The CPU is verified using self-checking testbenches that run RISC-V programs and compare register state against expected values.

There's also a Verilator-based verification flow that compares the RTL against a Zig reference model:

```bash
# Build reference model and run verification
make verify
```

## Development History

This project was built incrementally:

1. **Single-cycle CPU** - Basic fetch-decode-execute in one cycle
2. **5-stage pipeline** - Added pipeline registers between stages
3. **Hazard handling** - Data forwarding and stall logic
4. **Branch prediction** - 2-bit predictor with BTB
5. **Caching** - Separate I-cache and D-cache
6. **Out-of-order execution** - Register renaming, issue queue, ROB

## License

MIT
