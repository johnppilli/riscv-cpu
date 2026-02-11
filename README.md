# RISC-V CPU

RV32I processor in SystemVerilog, built up from a simple single-cycle design to a full out-of-order execution engine.

## Architecture

Three implementations, each building on the last:

### Single-Cycle

One instruction per clock cycle. Simple datapath, no pipelining.

```
                ┌─────────┐    ┌─────────┐    ┌─────┐    ┌──────────┐
  PC ──────────►│  Instr  │───►│ Decoder │───►│ ALU │───►│ Register │
                │  Memory │    │         │    │     │    │   File   │
                └─────────┘    └─────────┘    └─────┘    └──────────┘
                                                │              │
                                          ┌─────▼──────┐       │
                                          │    Data    │───────┘
                                          │   Memory   │
                                          └────────────┘
```

### 5-Stage Pipeline

Classic RISC pipeline with hazard handling and branch prediction.

```
  ┌────┐    ┌────┐    ┌────┐    ┌────┐    ┌────┐
  │ IF │───►│ ID │───►│ EX │───►│MEM │───►│ WB │
  └────┘    └────┘    └────┘    └────┘    └────┘
    │                   ▲  │                 │
    │         ┌─────────┘  └─────────┐       │
    │         │  Forwarding Unit     │       │
    │         └──────────────────────┼───────┘
    │                                │
  ┌─┴──────────┐              ┌─────┴──────┐
  │  Branch    │              │   Hazard   │
  │ Predictor  │              │    Unit    │
  │  + BTB     │              └────────────┘
  └────────────┘
  ┌────────┐  ┌────────┐
  │ I-Cache│  │ D-Cache│
  └────────┘  └────────┘
```

Features:
- Data forwarding to avoid pipeline stalls
- Hazard detection for load-use dependencies
- 2-bit dynamic branch predictor with branch target buffer
- Direct-mapped write-through instruction and data caches

### Out-of-Order Execution

Instructions execute as soon as their operands are ready, regardless of program order.

```
  Fetch ──► Decode ──► Rename ──► Dispatch ──► Issue ──► Execute ──► Commit
                         │                       │                     │
                    ┌────┴────┐            ┌─────┴─────┐         ┌────┴────┐
                    │   RAT   │            │  Issue    │         │  ROB    │
                    │64 phys  │            │  Queue    │         │16-entry │
                    │registers│            │  8-entry  │         │in-order │
                    │+free list│           │  +wakeup  │         │ commit  │
                    └─────────┘            └───────────┘         └─────────┘
```

Features:
- Register renaming via Register Allocation Table (RAT) + free list
- 64 physical registers (mapped from 32 architectural)
- 8-entry issue queue with wakeup logic for dependency tracking
- 16-entry reorder buffer for in-order commitment

## Supported Instructions (RV32I)

| Type | Instructions | Example |
|------|-------------|---------|
| R-type | `add`, `sub`, `and`, `or`, `xor`, `sll`, `srl`, `sra`, `slt`, `sltu` | `add x3, x1, x2` |
| I-type | `addi`, `andi`, `ori`, `xori`, `slti`, `sltiu`, `slli`, `srli`, `srai` | `addi x1, x0, 5` |
| Load | `lw` | `lw x1, 0(x2)` |
| Store | `sw` | `sw x1, 0(x2)` |
| Branch | `beq`, `bne`, `blt`, `bge`, `bltu`, `bgeu` | `beq x1, x2, label` |
| Upper | `lui`, `auipc` | `lui x1, 0x12345` |
| Jump | `jal`, `jalr` | `jal x1, label` |

## Running

```bash
# Single-cycle
make sim

# Pipelined
make sim-pipe

# Out-of-order
make sim-ooo

# View waveforms (needs GTKWave)
make wave-ooo

# Run RTL vs Zig reference model verification
make verify
```

## Project Layout

```
rtl/        SystemVerilog source (21 modules)
tb/         Testbenches
programs/   Test programs (.hex machine code)
ref/        Zig reference model for dual-model verification
sim/        Verilator C++ testbench
```

## Tools

- [Icarus Verilog](http://iverilog.icarus.com/) — simulation
- [Verilator](https://www.veripool.org/verilator/) — verification
- [GTKWave](http://gtkwave.sourceforge.net/) — waveform viewer
- [Zig](https://ziglang.org/) — reference model

## Related

- [riscv-assembler](https://github.com/johnppilli/riscv-assembler) — Assembler I built for this CPU. Takes `.asm` files and outputs `.hex` files that the instruction memory loads via `$readmemh`.

## How I Built It

Started with single-cycle to get the basics working, then added pipeline stages, then forwarding/hazards, then branch prediction and caches, and finally ripped it apart to do out-of-order. Each step built on the last.

Verification uses dual-model comparison: the RTL runs a program, a Zig reference model runs the same program, and the testbench compares register state cycle-by-cycle.
