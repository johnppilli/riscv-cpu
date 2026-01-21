// riscv_ref.zig - RISC-V RV32I Reference Model
// A software implementation of the RISC-V ISA for verification

const std = @import("std");

// CPU State
pub const RiscvCpu = extern struct {
    pc: u32,
    regs: [32]u32,
    mem: [*]u8,
    mem_size: u32,
    halted: bool,
};

// Opcode definitions
const OP_LUI: u7 = 0b0110111;
const OP_AUIPC: u7 = 0b0010111;
const OP_JAL: u7 = 0b1101111;
const OP_JALR: u7 = 0b1100111;
const OP_BRANCH: u7 = 0b1100011;
const OP_LOAD: u7 = 0b0000011;
const OP_STORE: u7 = 0b0100011;
const OP_OPIMM: u7 = 0b0010011;
const OP_OP: u7 = 0b0110011;

// Sign extend helper
fn signExtend(value: u32, comptime num_bits: u6) i32 {
    const shift: u5 = @intCast(32 - num_bits);
    return @as(i32, @bitCast(value << shift)) >> shift;
}

// Extract bits helper
fn bits(instr: u32, hi: u5, lo: u5) u32 {
    const mask = (@as(u32, 1) << (hi - lo + 1)) - 1;
    return (instr >> lo) & mask;
}

// Decode immediate based on instruction type
fn decodeImmI(instr: u32) i32 {
    return signExtend(bits(instr, 31, 20), 12);
}

fn decodeImmS(instr: u32) i32 {
    const imm = (bits(instr, 31, 25) << 5) | bits(instr, 11, 7);
    return signExtend(imm, 12);
}

fn decodeImmB(instr: u32) i32 {
    const imm = (bits(instr, 31, 31) << 12) |
        (bits(instr, 7, 7) << 11) |
        (bits(instr, 30, 25) << 5) |
        (bits(instr, 11, 8) << 1);
    return signExtend(imm, 13);
}

fn decodeImmU(instr: u32) i32 {
    return @bitCast(instr & 0xFFFFF000);
}

fn decodeImmJ(instr: u32) i32 {
    const imm = (bits(instr, 31, 31) << 20) |
        (bits(instr, 19, 12) << 12) |
        (bits(instr, 20, 20) << 11) |
        (bits(instr, 30, 21) << 1);
    return signExtend(imm, 21);
}

// Memory access functions
fn readWord(cpu: *RiscvCpu, addr: u32) u32 {
    if (addr + 3 >= cpu.mem_size) return 0;
    const ptr: *align(1) const u32 = @ptrCast(cpu.mem + addr);
    return ptr.*;
}

fn writeWord(cpu: *RiscvCpu, addr: u32, value: u32) void {
    if (addr + 3 >= cpu.mem_size) return;
    const ptr: *align(1) u32 = @ptrCast(cpu.mem + addr);
    ptr.* = value;
}

// Execute one instruction
fn executeInstr(cpu: *RiscvCpu, instr: u32) void {
    const opcode: u7 = @truncate(bits(instr, 6, 0));
    const rd: u5 = @truncate(bits(instr, 11, 7));
    const funct3: u3 = @truncate(bits(instr, 14, 12));
    const rs1: u5 = @truncate(bits(instr, 19, 15));
    const rs2: u5 = @truncate(bits(instr, 24, 20));
    const funct7: u7 = @truncate(bits(instr, 31, 25));

    // Read register values (x0 is always 0)
    const rs1_val: u32 = if (rs1 == 0) 0 else cpu.regs[rs1];
    const rs2_val: u32 = if (rs2 == 0) 0 else cpu.regs[rs2];
    const rs1_signed: i32 = @bitCast(rs1_val);
    const rs2_signed: i32 = @bitCast(rs2_val);

    var next_pc: u32 = cpu.pc + 4;
    var rd_val: ?u32 = null;

    switch (opcode) {
        OP_LUI => {
            rd_val = @bitCast(decodeImmU(instr));
        },

        OP_AUIPC => {
            rd_val = @bitCast(@as(i32, @bitCast(cpu.pc)) +% decodeImmU(instr));
        },

        OP_JAL => {
            rd_val = cpu.pc + 4;
            next_pc = @bitCast(@as(i32, @bitCast(cpu.pc)) +% decodeImmJ(instr));
        },

        OP_JALR => {
            rd_val = cpu.pc + 4;
            next_pc = @bitCast((rs1_signed +% decodeImmI(instr)) & ~@as(i32, 1));
        },

        OP_BRANCH => {
            const imm = decodeImmB(instr);
            const take_branch = switch (funct3) {
                0b000 => rs1_val == rs2_val, // BEQ
                0b001 => rs1_val != rs2_val, // BNE
                0b100 => rs1_signed < rs2_signed, // BLT
                0b101 => rs1_signed >= rs2_signed, // BGE
                0b110 => rs1_val < rs2_val, // BLTU
                0b111 => rs1_val >= rs2_val, // BGEU
                else => false,
            };
            if (take_branch) {
                next_pc = @bitCast(@as(i32, @bitCast(cpu.pc)) +% imm);
            }
        },

        OP_LOAD => {
            const addr: u32 = @bitCast(rs1_signed +% decodeImmI(instr));
            rd_val = switch (funct3) {
                0b010 => readWord(cpu, addr), // LW
                else => readWord(cpu, addr), // Simplified: treat all as LW
            };
        },

        OP_STORE => {
            const addr: u32 = @bitCast(rs1_signed +% decodeImmS(instr));
            switch (funct3) {
                0b010 => writeWord(cpu, addr, rs2_val), // SW
                else => writeWord(cpu, addr, rs2_val), // Simplified
            }
        },

        OP_OPIMM => {
            const imm = decodeImmI(instr);
            const imm_u: u32 = @bitCast(imm);
            const shamt: u5 = @truncate(imm_u);

            rd_val = switch (funct3) {
                0b000 => @bitCast(rs1_signed +% imm), // ADDI
                0b010 => if (rs1_signed < imm) @as(u32, 1) else @as(u32, 0), // SLTI
                0b011 => if (rs1_val < imm_u) @as(u32, 1) else @as(u32, 0), // SLTIU
                0b100 => rs1_val ^ imm_u, // XORI
                0b110 => rs1_val | imm_u, // ORI
                0b111 => rs1_val & imm_u, // ANDI
                0b001 => rs1_val << shamt, // SLLI
                0b101 => if (funct7 & 0x20 != 0)
                    @bitCast(rs1_signed >> shamt) // SRAI
                else
                    rs1_val >> shamt, // SRLI
            };
        },

        OP_OP => {
            const shamt: u5 = @truncate(rs2_val);

            rd_val = switch (funct3) {
                0b000 => if (funct7 & 0x20 != 0)
                    @bitCast(rs1_signed -% rs2_signed) // SUB
                else
                    @bitCast(rs1_signed +% rs2_signed), // ADD
                0b001 => rs1_val << shamt, // SLL
                0b010 => if (rs1_signed < rs2_signed) @as(u32, 1) else @as(u32, 0), // SLT
                0b011 => if (rs1_val < rs2_val) @as(u32, 1) else @as(u32, 0), // SLTU
                0b100 => rs1_val ^ rs2_val, // XOR
                0b101 => if (funct7 & 0x20 != 0)
                    @bitCast(rs1_signed >> shamt) // SRA
                else
                    rs1_val >> shamt, // SRL
                0b110 => rs1_val | rs2_val, // OR
                0b111 => rs1_val & rs2_val, // AND
            };
        },

        else => {
            // Unknown opcode - halt
            cpu.halted = true;
        },
    }

    // Write to rd (if not x0)
    if (rd_val) |val| {
        if (rd != 0) {
            cpu.regs[rd] = val;
        }
    }

    cpu.pc = next_pc;
}

// ============ C API ============

export fn riscv_init(cpu: *RiscvCpu, mem: [*]u8, mem_size: u32) void {
    cpu.pc = 0;
    cpu.mem = mem;
    cpu.mem_size = mem_size;
    cpu.halted = false;
    for (&cpu.regs) |*r| {
        r.* = 0;
    }
}

export fn riscv_step(cpu: *RiscvCpu) void {
    if (cpu.halted) return;
    const instr = readWord(cpu, cpu.pc);
    executeInstr(cpu, instr);
}

export fn riscv_get_pc(cpu: *RiscvCpu) u32 {
    return cpu.pc;
}

export fn riscv_get_reg(cpu: *RiscvCpu, reg: u32) u32 {
    if (reg >= 32) return 0;
    return cpu.regs[reg];
}

export fn riscv_set_reg(cpu: *RiscvCpu, reg: u32, value: u32) void {
    if (reg > 0 and reg < 32) {
        cpu.regs[reg] = value;
    }
}

export fn riscv_load_program(cpu: *RiscvCpu, program: [*]const u8, size: u32) void {
    var i: u32 = 0;
    while (i < size and i < cpu.mem_size) : (i += 1) {
        cpu.mem[i] = program[i];
    }
}

export fn riscv_is_halted(cpu: *RiscvCpu) bool {
    return cpu.halted;
}
