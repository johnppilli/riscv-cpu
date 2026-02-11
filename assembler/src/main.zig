const std = @import("std");

// ============================================================================
// INSTRUCTION TABLE
// ============================================================================
// Every RISC-V instruction has a "format" — this tells us how the 32 bits
// are laid out. Your CPU's decoder.sv handles these same formats on the
// hardware side. This is basically the reverse of that decoder.
//
// Format types:
//   R-type: register-register ops   (add, sub, and, or, xor, sll, srl, sra, slt, sltu)
//   I-type: register-immediate ops  (addi, andi, ori, xori, slti, sltiu, slli, srli, srai)
//   IL-type: loads                  (lw) — same encoding as I-type but different opcode
//   S-type: stores                  (sw)
//   B-type: branches                (beq, bne, blt, bge, bltu, bgeu)
//   U-type: upper immediate         (lui, auipc)
//   J-type: jumps                   (jal)
// ============================================================================

const Format = enum {
    R, // register-register: add x3, x1, x2
    I, // immediate:         addi x1, x0, 5
    IL, // load:             lw x1, 0(x2)
    S, // store:             sw x1, 0(x2)
    B, // branch:            beq x1, x2, label
    U, // upper immediate:   lui x1, 0x12345
    J, // jump:              jal x1, label
};

// Each entry describes one instruction: its name, opcode, funct3, funct7, and format.
// These values come directly from the RISC-V spec (and match your decoder.sv).
const InsnInfo = struct {
    name: []const u8,
    opcode: u7,
    funct3: u3,
    funct7: u7,
    format: Format,
};

// This is our lookup table. When we see "add" in the assembly, we search
// this table to find opcode=0x33, funct3=0x0, funct7=0x00, format=R.
const insn_table = [_]InsnInfo{
    // R-type (opcode 0110011 = 0x33)
    .{ .name = "add", .opcode = 0x33, .funct3 = 0x0, .funct7 = 0x00, .format = .R },
    .{ .name = "sub", .opcode = 0x33, .funct3 = 0x0, .funct7 = 0x20, .format = .R },
    .{ .name = "sll", .opcode = 0x33, .funct3 = 0x1, .funct7 = 0x00, .format = .R },
    .{ .name = "slt", .opcode = 0x33, .funct3 = 0x2, .funct7 = 0x00, .format = .R },
    .{ .name = "sltu", .opcode = 0x33, .funct3 = 0x3, .funct7 = 0x00, .format = .R },
    .{ .name = "xor", .opcode = 0x33, .funct3 = 0x4, .funct7 = 0x00, .format = .R },
    .{ .name = "srl", .opcode = 0x33, .funct3 = 0x5, .funct7 = 0x00, .format = .R },
    .{ .name = "sra", .opcode = 0x33, .funct3 = 0x5, .funct7 = 0x20, .format = .R },
    .{ .name = "or", .opcode = 0x33, .funct3 = 0x6, .funct7 = 0x00, .format = .R },
    .{ .name = "and", .opcode = 0x33, .funct3 = 0x7, .funct7 = 0x00, .format = .R },

    // I-type ALU (opcode 0010011 = 0x13)
    .{ .name = "addi", .opcode = 0x13, .funct3 = 0x0, .funct7 = 0x00, .format = .I },
    .{ .name = "slti", .opcode = 0x13, .funct3 = 0x2, .funct7 = 0x00, .format = .I },
    .{ .name = "sltiu", .opcode = 0x13, .funct3 = 0x3, .funct7 = 0x00, .format = .I },
    .{ .name = "xori", .opcode = 0x13, .funct3 = 0x4, .funct7 = 0x00, .format = .I },
    .{ .name = "ori", .opcode = 0x13, .funct3 = 0x6, .funct7 = 0x00, .format = .I },
    .{ .name = "andi", .opcode = 0x13, .funct3 = 0x7, .funct7 = 0x00, .format = .I },
    .{ .name = "slli", .opcode = 0x13, .funct3 = 0x1, .funct7 = 0x00, .format = .I },
    .{ .name = "srli", .opcode = 0x13, .funct3 = 0x5, .funct7 = 0x00, .format = .I },
    .{ .name = "srai", .opcode = 0x13, .funct3 = 0x5, .funct7 = 0x20, .format = .I },

    // Load (opcode 0000011 = 0x03)
    .{ .name = "lw", .opcode = 0x03, .funct3 = 0x2, .funct7 = 0x00, .format = .IL },

    // Store (opcode 0100011 = 0x23)
    .{ .name = "sw", .opcode = 0x23, .funct3 = 0x2, .funct7 = 0x00, .format = .S },

    // Branch (opcode 1100011 = 0x63)
    .{ .name = "beq", .opcode = 0x63, .funct3 = 0x0, .funct7 = 0x00, .format = .B },
    .{ .name = "bne", .opcode = 0x63, .funct3 = 0x1, .funct7 = 0x00, .format = .B },
    .{ .name = "blt", .opcode = 0x63, .funct3 = 0x4, .funct7 = 0x00, .format = .B },
    .{ .name = "bge", .opcode = 0x63, .funct3 = 0x5, .funct7 = 0x00, .format = .B },
    .{ .name = "bltu", .opcode = 0x63, .funct3 = 0x6, .funct7 = 0x00, .format = .B },
    .{ .name = "bgeu", .opcode = 0x63, .funct3 = 0x7, .funct7 = 0x00, .format = .B },

    // Upper immediate
    .{ .name = "lui", .opcode = 0x37, .funct3 = 0x0, .funct7 = 0x00, .format = .U },
    .{ .name = "auipc", .opcode = 0x17, .funct3 = 0x0, .funct7 = 0x00, .format = .U },

    // Jump (opcode 1101111 = 0x6F)
    .{ .name = "jal", .opcode = 0x6F, .funct3 = 0x0, .funct7 = 0x00, .format = .J },

    // Jump register (opcode 1100111 = 0x67) — I-type format
    .{ .name = "jalr", .opcode = 0x67, .funct3 = 0x0, .funct7 = 0x00, .format = .I },
};

// Look up an instruction by name. Returns null if not found.
fn lookupInsn(name: []const u8) ?InsnInfo {
    for (insn_table) |entry| {
        if (std.mem.eql(u8, entry.name, name)) return entry;
    }
    return null;
}

// ============================================================================
// REGISTER PARSER
// ============================================================================
// Converts register names to numbers. RISC-V has 32 registers: x0-x31.
// x0 is hardwired to zero (writes are ignored, reads always return 0).
//
// We also support ABI names like "zero", "ra", "sp", etc. — these are just
// aliases for x0, x1, x2, etc. that make assembly more readable.
// ============================================================================

fn parseRegister(token: []const u8) !u5 {
    // ABI name aliases (commonly used in real RISC-V assembly)
    const abi_names = [_]struct { name: []const u8, reg: u5 }{
        .{ .name = "zero", .reg = 0 },
        .{ .name = "ra", .reg = 1 },
        .{ .name = "sp", .reg = 2 },
        .{ .name = "gp", .reg = 3 },
        .{ .name = "tp", .reg = 4 },
        .{ .name = "t0", .reg = 5 },
        .{ .name = "t1", .reg = 6 },
        .{ .name = "t2", .reg = 7 },
        .{ .name = "s0", .reg = 8 },
        .{ .name = "fp", .reg = 8 }, // fp is an alias for s0
        .{ .name = "s1", .reg = 9 },
        .{ .name = "a0", .reg = 10 },
        .{ .name = "a1", .reg = 11 },
        .{ .name = "a2", .reg = 12 },
        .{ .name = "a3", .reg = 13 },
        .{ .name = "a4", .reg = 14 },
        .{ .name = "a5", .reg = 15 },
        .{ .name = "a6", .reg = 16 },
        .{ .name = "a7", .reg = 17 },
        .{ .name = "s2", .reg = 18 },
        .{ .name = "s3", .reg = 19 },
        .{ .name = "s4", .reg = 20 },
        .{ .name = "s5", .reg = 21 },
        .{ .name = "s6", .reg = 22 },
        .{ .name = "s7", .reg = 23 },
        .{ .name = "s8", .reg = 24 },
        .{ .name = "s9", .reg = 25 },
        .{ .name = "s10", .reg = 26 },
        .{ .name = "s11", .reg = 27 },
        .{ .name = "t3", .reg = 28 },
        .{ .name = "t4", .reg = 29 },
        .{ .name = "t5", .reg = 30 },
        .{ .name = "t6", .reg = 31 },
    };

    // Check ABI names first
    for (abi_names) |entry| {
        if (std.mem.eql(u8, token, entry.name)) return entry.reg;
    }

    // Otherwise expect "x0" through "x31"
    if (token.len >= 2 and token[0] == 'x') {
        return std.fmt.parseInt(u5, token[1..], 10) catch return error.InvalidRegister;
    }

    return error.InvalidRegister;
}

// ============================================================================
// TOKENIZER
// ============================================================================
// Takes a line of assembly like "addi x1, x0, 5  # comment"
// and splits it into tokens: ["addi", "x1", "x0", "5"]
//
// Rules:
//   - Everything after '#' or ';' is a comment (ignored)
//   - Commas and whitespace are delimiters
//   - Parentheses are also delimiters (for load/store syntax like "0(x2)")
// ============================================================================

fn tokenizeLine(line: []const u8, tokens: *[8][]const u8) usize {
    var count: usize = 0;

    // Strip comments — find the first '#' or ';' and ignore everything after
    var effective_line = line;
    for (line, 0..) |ch, i| {
        if (ch == '#' or ch == ';') {
            effective_line = line[0..i];
            break;
        }
    }

    // Split on whitespace, commas, and parentheses
    var i: usize = 0;
    while (i < effective_line.len and count < 8) {
        // Skip delimiters
        while (i < effective_line.len and isDelimiter(effective_line[i])) : (i += 1) {}
        if (i >= effective_line.len) break;

        // Find end of token
        const start = i;
        while (i < effective_line.len and !isDelimiter(effective_line[i])) : (i += 1) {}

        tokens[count] = effective_line[start..i];
        count += 1;
    }

    return count;
}

fn isDelimiter(ch: u8) bool {
    return ch == ' ' or ch == '\t' or ch == ',' or ch == '(' or ch == ')';
}

// ============================================================================
// IMMEDIATE PARSER
// ============================================================================
// Parses an immediate value from a token. Supports:
//   - Decimal: "5", "-1", "42"
//   - Hex: "0xFF", "0x1000"
//   - Labels: "loop" (looked up from the label map)
//
// For branches/jumps, the immediate is a *byte offset* from the current PC.
// ============================================================================

fn parseImmediate(
    token: []const u8,
    labels: *const std.StringHashMap(u32),
    current_pc: u32,
    is_branch_or_jump: bool,
) !i32 {
    // First, try parsing as a number (decimal or hex)
    if (std.fmt.parseInt(i32, token, 0)) |val| {
        return val;
    } else |_| {}

    // If it's not a number, treat it as a label name
    if (labels.get(token)) |label_pc| {
        if (is_branch_or_jump) {
            // Branch/jump offsets are relative to current PC
            // offset = label_address - current_address
            return @as(i32, @intCast(label_pc)) - @as(i32, @intCast(current_pc));
        } else {
            return @intCast(label_pc);
        }
    }

    return error.InvalidImmediate;
}

// ============================================================================
// INSTRUCTION ENCODER
// ============================================================================
// This is the core of the assembler. It takes parsed tokens and an InsnInfo
// and packs them into a 32-bit machine code word.
//
// Each format has a different bit layout. This is essentially the REVERSE
// of what your decoder.sv does — decoder unpacks bits into control signals,
// encoder packs control signals into bits.
// ============================================================================

fn encodeInstruction(
    info: InsnInfo,
    tokens: [8][]const u8,
    token_count: usize,
    labels: *const std.StringHashMap(u32),
    current_pc: u32,
) !u32 {
    return switch (info.format) {
        // R-type: add rd, rs1, rs2
        // Bit layout: [funct7][rs2][rs1][funct3][rd][opcode]
        .R => {
            if (token_count < 4) return error.NotEnoughOperands;
            const rd = try parseRegister(tokens[1]);
            const rs1 = try parseRegister(tokens[2]);
            const rs2 = try parseRegister(tokens[3]);
            return @as(u32, info.funct7) << 25 |
                @as(u32, rs2) << 20 |
                @as(u32, rs1) << 15 |
                @as(u32, info.funct3) << 12 |
                @as(u32, rd) << 7 |
                @as(u32, info.opcode);
        },

        // I-type: addi rd, rs1, imm
        // Bit layout: [imm[11:0]][rs1][funct3][rd][opcode]
        // For shift instructions (slli/srli/srai), the upper 7 bits of
        // the immediate hold funct7 and only bits [4:0] are the shift amount.
        .I => {
            if (token_count < 4) return error.NotEnoughOperands;
            const rd = try parseRegister(tokens[1]);
            const rs1 = try parseRegister(tokens[2]);
            const is_jalr = (info.opcode == 0x67);
            const imm = try parseImmediate(tokens[3], labels, current_pc, is_jalr);
            var imm_u: u32 = @bitCast(imm);

            // For shift instructions, encode funct7 in upper bits
            const is_shift = (info.opcode == 0x13) and
                (info.funct3 == 0x1 or info.funct3 == 0x5);
            if (is_shift) {
                // shamt is bits [4:0], funct7 goes in bits [11:5]
                imm_u = (imm_u & 0x1F) | (@as(u32, info.funct7) << 5);
            }

            return (imm_u & 0xFFF) << 20 |
                @as(u32, rs1) << 15 |
                @as(u32, info.funct3) << 12 |
                @as(u32, rd) << 7 |
                @as(u32, info.opcode);
        },

        // IL-type (load): lw rd, offset(rs1)
        // Same bit layout as I-type, but tokens are ordered differently:
        //   "lw x1, 8(x2)" → tokens: ["lw", "x1", "8", "x2"]
        // The tokenizer splits on '(' and ')' so "8(x2)" becomes "8", "x2"
        .IL => {
            if (token_count < 4) return error.NotEnoughOperands;
            const rd = try parseRegister(tokens[1]);
            const imm = try parseImmediate(tokens[2], labels, current_pc, false);
            const rs1 = try parseRegister(tokens[3]);
            const imm_u: u32 = @bitCast(imm);
            return (imm_u & 0xFFF) << 20 |
                @as(u32, rs1) << 15 |
                @as(u32, info.funct3) << 12 |
                @as(u32, rd) << 7 |
                @as(u32, info.opcode);
        },

        // S-type (store): sw rs2, offset(rs1)
        // Bit layout: [imm[11:5]][rs2][rs1][funct3][imm[4:0]][opcode]
        // The immediate is split across two fields! This is one of the
        // trickier encodings — the hardware needs it split this way so
        // that rs1 and rs2 fields stay in the same bit positions as R-type.
        .S => {
            if (token_count < 4) return error.NotEnoughOperands;
            const rs2 = try parseRegister(tokens[1]);
            const imm = try parseImmediate(tokens[2], labels, current_pc, false);
            const rs1 = try parseRegister(tokens[3]);
            const imm_u: u32 = @bitCast(imm);
            return ((imm_u >> 5) & 0x7F) << 25 |
                @as(u32, rs2) << 20 |
                @as(u32, rs1) << 15 |
                @as(u32, info.funct3) << 12 |
                (imm_u & 0x1F) << 7 |
                @as(u32, info.opcode);
        },

        // B-type (branch): beq rs1, rs2, offset
        // Bit layout: [imm[12|10:5]][rs2][rs1][funct3][imm[4:1|11]][opcode]
        // The immediate is even MORE scrambled than S-type. The bits are
        // arranged this way to keep the sign bit at position 31 (same as
        // other formats) and other bits roughly aligned with S-type.
        // The offset is in multiples of 2 bytes (bit 0 is always 0).
        .B => {
            if (token_count < 4) return error.NotEnoughOperands;
            const rs1 = try parseRegister(tokens[1]);
            const rs2 = try parseRegister(tokens[2]);
            const imm = try parseImmediate(tokens[3], labels, current_pc, true);
            const imm_u: u32 = @bitCast(imm);

            // Extract the scattered immediate bits
            const bit_12 = (imm_u >> 12) & 0x1; // sign bit
            const bits_10_5 = (imm_u >> 5) & 0x3F;
            const bits_4_1 = (imm_u >> 1) & 0xF;
            const bit_11 = (imm_u >> 11) & 0x1;

            return (bit_12 << 31) |
                (bits_10_5 << 25) |
                @as(u32, rs2) << 20 |
                @as(u32, rs1) << 15 |
                @as(u32, info.funct3) << 12 |
                (bits_4_1 << 8) |
                (bit_11 << 7) |
                @as(u32, info.opcode);
        },

        // U-type (upper immediate): lui rd, imm
        // Bit layout: [imm[31:12]][rd][opcode]
        // The immediate occupies the upper 20 bits. Simple!
        .U => {
            if (token_count < 3) return error.NotEnoughOperands;
            const rd = try parseRegister(tokens[1]);
            const imm = try parseImmediate(tokens[2], labels, current_pc, false);
            const imm_u: u32 = @bitCast(imm);
            return (imm_u & 0xFFFFF) << 12 |
                @as(u32, rd) << 7 |
                @as(u32, info.opcode);
        },

        // J-type (jump): jal rd, offset
        // Bit layout: [imm[20|10:1|11|19:12]][rd][opcode]
        // The most scrambled encoding of all. Like B-type on steroids.
        // The offset is in multiples of 2 bytes (bit 0 is always 0).
        .J => {
            if (token_count < 3) return error.NotEnoughOperands;
            const rd = try parseRegister(tokens[1]);
            const imm = try parseImmediate(tokens[2], labels, current_pc, true);
            const imm_u: u32 = @bitCast(imm);

            const bit_20 = (imm_u >> 20) & 0x1;
            const bits_10_1 = (imm_u >> 1) & 0x3FF;
            const bit_11 = (imm_u >> 11) & 0x1;
            const bits_19_12 = (imm_u >> 12) & 0xFF;

            return (bit_20 << 31) |
                (bits_10_1 << 21) |
                (bit_11 << 20) |
                (bits_19_12 << 12) |
                @as(u32, rd) << 7 |
                @as(u32, info.opcode);
        },
    };
}

// ============================================================================
// PSEUDO-INSTRUCTION EXPANSION
// ============================================================================
// RISC-V has "pseudo-instructions" — shorthand that the assembler expands
// into one or more real instructions. For example:
//   "nop"       → "addi x0, x0, 0"
//   "mv x1, x2" → "addi x1, x2, 0"
//   "li x1, 5"  → "addi x1, x0, 5"
//   "j label"   → "jal x0, label"
// These make assembly easier to read and write.
// ============================================================================

fn expandPseudo(tokens: *[8][]const u8, count: usize) usize {
    if (count == 0) return 0;

    if (std.mem.eql(u8, tokens[0], "nop")) {
        tokens[0] = "addi";
        tokens[1] = "x0";
        tokens[2] = "x0";
        tokens[3] = "0";
        return 4;
    }

    if (std.mem.eql(u8, tokens[0], "mv") and count >= 3) {
        // mv rd, rs → addi rd, rs, 0
        const rd = tokens[1];
        const rs = tokens[2];
        tokens[0] = "addi";
        tokens[1] = rd;
        tokens[2] = rs;
        tokens[3] = "0";
        return 4;
    }

    if (std.mem.eql(u8, tokens[0], "li") and count >= 3) {
        // li rd, imm → addi rd, x0, imm (only works for 12-bit immediates)
        const rd = tokens[1];
        const imm = tokens[2];
        tokens[0] = "addi";
        tokens[1] = rd;
        tokens[2] = "x0";
        tokens[3] = imm;
        return 4;
    }

    if (std.mem.eql(u8, tokens[0], "j") and count >= 2) {
        // j label → jal x0, label
        const label = tokens[1];
        tokens[0] = "jal";
        tokens[1] = "x0";
        tokens[2] = label;
        return 3;
    }

    if (std.mem.eql(u8, tokens[0], "ret")) {
        // ret → jalr x0, x1, 0
        tokens[0] = "jalr";
        tokens[1] = "x0";
        tokens[2] = "ra";
        tokens[3] = "0";
        return 4;
    }

    return count;
}

// ============================================================================
// TWO-PASS ASSEMBLER
// ============================================================================
// Pass 1: Scan for labels, record their addresses (PC values)
// Pass 2: Encode each instruction into 32-bit machine code
// ============================================================================

const AssemblerError = error{
    UnknownInstruction,
    NotEnoughOperands,
    InvalidRegister,
    InvalidImmediate,
    OutOfMemory,
};

fn assemble(source: []const u8, allocator: std.mem.Allocator) ![]u32 {
    var labels = std.StringHashMap(u32).init(allocator);
    defer labels.deinit();

    var output = std.ArrayList(u32).init(allocator);

    // ---- PASS 1: Collect labels ----
    // Walk every line. If a line has "label:", record that label's PC.
    // PC increments by 4 for each real instruction (not labels, not blank lines).
    {
        var pc: u32 = 0;
        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            var tokens: [8][]const u8 = undefined;
            var count = tokenizeLine(line, &tokens);
            if (count == 0) continue;

            // Check if the first token is a label (ends with ':')
            if (tokens[0].len > 0 and tokens[0][tokens[0].len - 1] == ':') {
                const label_name = tokens[0][0 .. tokens[0].len - 1];
                try labels.put(label_name, pc);

                // If there's an instruction after the label on the same line,
                // shift tokens left and process it
                if (count > 1) {
                    for (1..count) |j| {
                        tokens[j - 1] = tokens[j];
                    }
                    count -= 1;
                } else {
                    continue; // Label-only line, no instruction
                }
            }

            // This line has an instruction, so advance PC by 4 bytes
            pc += 4;
        }
    }

    // ---- PASS 2: Encode instructions ----
    {
        var pc: u32 = 0;
        var lines = std.mem.splitScalar(u8, source, '\n');
        while (lines.next()) |line| {
            var tokens: [8][]const u8 = undefined;
            var count = tokenizeLine(line, &tokens);
            if (count == 0) continue;

            // Skip label prefix if present
            if (tokens[0].len > 0 and tokens[0][tokens[0].len - 1] == ':') {
                if (count > 1) {
                    for (1..count) |j| {
                        tokens[j - 1] = tokens[j];
                    }
                    count -= 1;
                } else {
                    continue;
                }
            }

            // Expand pseudo-instructions (nop, mv, li, j, ret)
            count = expandPseudo(&tokens, count);

            // Look up the instruction in our table
            const info = lookupInsn(tokens[0]) orelse {
                std.debug.print("error: unknown instruction '{s}' at PC=0x{x:0>8}\n", .{ tokens[0], pc });
                return AssemblerError.UnknownInstruction;
            };

            // Encode it!
            const machine_code = try encodeInstruction(info, tokens, count, &labels, pc);
            try output.append(machine_code);
            pc += 4;
        }
    }

    return output.toOwnedSlice();
}

// ============================================================================
// MAIN — CLI ENTRY POINT
// ============================================================================
// Usage: riscv-asm input.asm [-o output.hex]
//
// Reads the .asm file, assembles it, and writes a .hex file that your
// CPU's instruction_memory.sv can load with $readmemh.
// ============================================================================

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    // Parse command-line arguments
    const args = try std.process.argsAlloc(allocator);
    defer std.process.argsFree(allocator, args);

    if (args.len < 2) {
        std.debug.print("RISC-V RV32I Assembler\n", .{});
        std.debug.print("Usage: riscv-asm <input.asm> [-o output.hex]\n\n", .{});
        std.debug.print("Assembles RISC-V assembly into hex machine code.\n", .{});
        std.debug.print("Output format is compatible with $readmemh (Verilog).\n", .{});
        std.process.exit(1);
    }

    const input_path = args[1];

    // Determine output path: use -o flag if provided, otherwise replace .asm with .hex
    var output_path: []const u8 = undefined;
    var custom_output = false;
    for (args[1..], 0..) |arg, i| {
        if (std.mem.eql(u8, arg, "-o") and i + 2 < args.len) {
            output_path = args[i + 2];
            custom_output = true;
            break;
        }
    }
    if (!custom_output) {
        // Replace .asm extension with .hex
        if (std.mem.endsWith(u8, input_path, ".asm") or std.mem.endsWith(u8, input_path, ".s")) {
            const dot_pos = std.mem.lastIndexOfScalar(u8, input_path, '.') orelse input_path.len;
            const base = input_path[0..dot_pos];
            output_path = try std.fmt.allocPrint(allocator, "{s}.hex", .{base});
        } else {
            output_path = try std.fmt.allocPrint(allocator, "{s}.hex", .{input_path});
        }
    }

    // Read the input file
    const source = std.fs.cwd().readFileAlloc(allocator, input_path, 1024 * 1024) catch |err| {
        std.debug.print("error: could not open '{s}': {}\n", .{ input_path, err });
        std.process.exit(1);
    };
    defer allocator.free(source);

    // Assemble!
    const machine_code = try assemble(source, allocator);
    defer allocator.free(machine_code);

    // Write the output .hex file
    const out_file = try std.fs.cwd().createFile(output_path, .{});
    defer out_file.close();

    // Format each instruction as 8-digit hex and write to file
    for (machine_code) |word| {
        var line_buf: [9]u8 = undefined; // 8 hex chars + newline
        _ = std.fmt.bufPrint(&line_buf, "{x:0>8}\n", .{word}) catch unreachable;
        out_file.writeAll(&line_buf) catch |err| {
            std.debug.print("error: failed to write output: {}\n", .{err});
            std.process.exit(1);
        };
    }

    // Print summary
    std.debug.print("Assembled {d} instructions: {s} -> {s}\n", .{
        machine_code.len,
        input_path,
        output_path,
    });
}

// ============================================================================
// TESTS
// ============================================================================

test "parse register x0-x31" {
    try std.testing.expectEqual(@as(u5, 0), try parseRegister("x0"));
    try std.testing.expectEqual(@as(u5, 1), try parseRegister("x1"));
    try std.testing.expectEqual(@as(u5, 31), try parseRegister("x31"));
}

test "parse register ABI names" {
    try std.testing.expectEqual(@as(u5, 0), try parseRegister("zero"));
    try std.testing.expectEqual(@as(u5, 1), try parseRegister("ra"));
    try std.testing.expectEqual(@as(u5, 2), try parseRegister("sp"));
}

test "tokenize basic instruction" {
    var tokens: [8][]const u8 = undefined;
    const count = tokenizeLine("addi x1, x0, 5  # set x1 to 5", &tokens);
    try std.testing.expectEqual(@as(usize, 4), count);
    try std.testing.expectEqualStrings("addi", tokens[0]);
    try std.testing.expectEqualStrings("x1", tokens[1]);
    try std.testing.expectEqualStrings("x0", tokens[2]);
    try std.testing.expectEqualStrings("5", tokens[3]);
}

test "encode addi x1, x0, 5 = 0x00500093" {
    var labels = std.StringHashMap(u32).init(std.testing.allocator);
    defer labels.deinit();
    const info = lookupInsn("addi").?;
    const tokens = [8][]const u8{ "addi", "x1", "x0", "5", "", "", "", "" };
    const result = try encodeInstruction(info, tokens, 4, &labels, 0);
    try std.testing.expectEqual(@as(u32, 0x00500093), result);
}

test "encode add x3, x1, x2 = 0x002081b3" {
    var labels = std.StringHashMap(u32).init(std.testing.allocator);
    defer labels.deinit();
    const info = lookupInsn("add").?;
    const tokens = [8][]const u8{ "add", "x3", "x1", "x2", "", "", "", "" };
    const result = try encodeInstruction(info, tokens, 4, &labels, 0);
    try std.testing.expectEqual(@as(u32, 0x002081b3), result);
}

test "full assembly of program_single" {
    const source =
        \\addi x1, x0, 5
        \\addi x2, x0, 3
        \\add  x3, x1, x2
        \\nop
        \\nop
        \\nop
        \\nop
        \\nop
    ;
    const result = try assemble(source, std.testing.allocator);
    defer std.testing.allocator.free(result);

    // These are the exact values from your program_single.hex
    try std.testing.expectEqual(@as(u32, 0x00500093), result[0]);
    try std.testing.expectEqual(@as(u32, 0x00300113), result[1]);
    try std.testing.expectEqual(@as(u32, 0x002081b3), result[2]);
    try std.testing.expectEqual(@as(u32, 0x00000013), result[3]); // nop
}
