# RISC-V CPU

RV32I processor in SystemVerilog. Built it up from a simple single-cycle design to a full out-of-order execution engine.

## What's in here

**Single-cycle** (`rtl/cpu_top.sv`) - one instruction per cycle, nothing fancy

**Pipelined** (`rtl/cpu_pipelined.sv`) - 5-stage pipeline with:
- Data forwarding and hazard detection
- 2-bit branch predictor + BTB
- I-cache and D-cache (direct-mapped, write-through)

**Out-of-order** (`rtl/cpu_ooo.sv`) - the fun stuff:
- Register renaming (RAT + free list)
- 64 physical registers
- 8-entry issue queue with wakeup logic
- 16-entry reorder buffer

## Running it

```bash
make sim       # single-cycle
make sim-pipe  # pipelined
make sim-ooo   # out-of-order

make wave-ooo  # view waveforms (needs GTKWave)
```

## Project layout

```
rtl/       - all the SystemVerilog
tb/        - testbenches
programs/  - test programs (hex)
ref/       - Zig reference model for verification
```

## How I built it

Started with single-cycle to get the basics working, then added pipeline stages, then forwarding/hazards, then branch prediction and caches, and finally ripped it apart to do out-of-order. Each step built on the last.

Testbenches run programs and check register values against expected results.
