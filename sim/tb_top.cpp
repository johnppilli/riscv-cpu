// tb_top.cpp - Verilator testbench comparing RTL against reference model

#include <iostream>
#include <iomanip>
#include <cstdint>
#include <cstring>
#include <vector>
#include <fstream>

#include "Vcpu_top.h"
#include "Vcpu_top___024root.h"
#include "verilated.h"
#include "verilated_vcd_c.h"
#include "riscv_ref.h"

#define MEM_SIZE (4 * 1024)  // 4KB memory

class Testbench {
public:
    Vcpu_top* rtl;
    RiscvCpu ref;
    VerilatedVcdC* trace;
    uint64_t sim_time;
    uint8_t* ref_mem;

    // Test counters
    int tests_passed;
    int tests_failed;
    int cycles_run;

    Testbench() {
        rtl = new Vcpu_top;
        trace = nullptr;
        sim_time = 0;
        tests_passed = 0;
        tests_failed = 0;
        cycles_run = 0;

        // Allocate memory for reference model
        ref_mem = new uint8_t[MEM_SIZE];
        memset(ref_mem, 0, MEM_SIZE);

        // Fill with NOPs initially
        for (int i = 0; i < MEM_SIZE; i += 4) {
            ref_mem[i+0] = 0x13;  // NOP = addi x0, x0, 0 = 0x00000013
            ref_mem[i+1] = 0x00;
            ref_mem[i+2] = 0x00;
            ref_mem[i+3] = 0x00;
        }

        // Initialize reference model
        riscv_init(&ref, ref_mem, MEM_SIZE);
    }

    ~Testbench() {
        if (trace) {
            trace->close();
            delete trace;
        }
        delete rtl;
        delete[] ref_mem;
    }

    void openTrace(const char* filename) {
        Verilated::traceEverOn(true);
        trace = new VerilatedVcdC;
        rtl->trace(trace, 99);
        trace->open(filename);
    }

    void tick() {
        // Rising edge
        rtl->clk = 1;
        rtl->eval();
        if (trace) trace->dump(sim_time++);

        // Falling edge
        rtl->clk = 0;
        rtl->eval();
        if (trace) trace->dump(sim_time++);

        cycles_run++;
    }

    void reset() {
        rtl->rst = 1;
        for (int i = 0; i < 5; i++) {
            tick();
        }
        rtl->rst = 0;

        // Manually clear RTL registers (register file doesn't have reset input)
        for (int i = 0; i < 32; i++) {
            rtl->rootp->cpu_top__DOT__regfile__DOT__registers[i] = 0;
        }

        // Clear RTL data memory
        for (int i = 0; i < 1024; i++) {
            rtl->rootp->cpu_top__DOT__dmem__DOT__mem[i] = 0;
        }

        // Reset reference model
        riscv_init(&ref, ref_mem, MEM_SIZE);
    }

    void loadProgram(const std::vector<uint32_t>& program) {
        // Load into reference model memory
        for (size_t i = 0; i < program.size() && i * 4 < MEM_SIZE; i++) {
            uint32_t instr = program[i];
            ref_mem[i * 4 + 0] = (instr >> 0) & 0xFF;
            ref_mem[i * 4 + 1] = (instr >> 8) & 0xFF;
            ref_mem[i * 4 + 2] = (instr >> 16) & 0xFF;
            ref_mem[i * 4 + 3] = (instr >> 24) & 0xFF;
        }

        // Also load into RTL instruction memory
        for (size_t i = 0; i < program.size() && i < 1024; i++) {
            rtl->rootp->cpu_top__DOT__imem__DOT__mem[i] = program[i];
        }
        // Fill rest with NOPs
        for (size_t i = program.size(); i < 1024; i++) {
            rtl->rootp->cpu_top__DOT__imem__DOT__mem[i] = 0x00000013;
        }
    }

    // Get RTL register value
    uint32_t getRtlReg(int reg) {
        if (reg == 0) return 0;
        return rtl->rootp->cpu_top__DOT__regfile__DOT__registers[reg];
    }

    uint32_t getRtlPc() {
        return rtl->rootp->cpu_top__DOT__pc;
    }

    bool compareState() {
        bool match = true;

        // Compare PC
        uint32_t rtl_pc = getRtlPc();
        uint32_t ref_pc = riscv_get_pc(&ref);

        if (rtl_pc != ref_pc) {
            std::cerr << "PC MISMATCH: RTL=0x" << std::hex << rtl_pc
                      << " REF=0x" << ref_pc << std::dec << std::endl;
            match = false;
        }

        // Compare registers
        for (int i = 1; i < 32; i++) {
            uint32_t rtl_val = getRtlReg(i);
            uint32_t ref_val = riscv_get_reg(&ref, i);

            if (rtl_val != ref_val) {
                std::cerr << "REG x" << i << " MISMATCH: RTL=" << rtl_val
                          << " REF=" << ref_val << std::endl;
                match = false;
            }
        }

        return match;
    }

    void stepAndCompare() {
        // Step RTL (one clock cycle)
        tick();

        // Step reference model (one instruction)
        riscv_step(&ref);
    }

    void printState() {
        std::cout << "=== CPU State ===" << std::endl;
        std::cout << "PC: RTL=0x" << std::hex << std::setw(8) << std::setfill('0') << getRtlPc()
                  << " REF=0x" << std::setw(8) << riscv_get_pc(&ref) << std::dec << std::endl;

        std::cout << "Registers (non-zero):" << std::endl;
        for (int i = 1; i < 32; i++) {
            uint32_t rtl_val = getRtlReg(i);
            uint32_t ref_val = riscv_get_reg(&ref, i);
            if (rtl_val != 0 || ref_val != 0) {
                std::cout << "  x" << std::setw(2) << std::setfill(' ') << i
                          << ": RTL=" << std::setw(10) << rtl_val
                          << " REF=" << std::setw(10) << ref_val;
                if (rtl_val != ref_val) std::cout << " MISMATCH!";
                std::cout << std::endl;
            }
        }
    }

    void runTest(const std::string& name, const std::vector<uint32_t>& program, int cycles) {
        std::cout << "\n===== Running Test: " << name << " =====" << std::endl;

        loadProgram(program);
        reset();

        bool all_match = true;
        for (int i = 0; i < cycles; i++) {
            stepAndCompare();

            if (!compareState()) {
                std::cerr << "Mismatch at cycle " << i << std::endl;
                printState();
                all_match = false;
                break;
            }
        }

        if (all_match) {
            std::cout << "PASS: " << name << std::endl;
            tests_passed++;
        } else {
            std::cout << "FAIL: " << name << std::endl;
            tests_failed++;
        }

        printState();
    }
};

int main(int argc, char** argv) {
    Verilated::commandArgs(argc, argv);

    Testbench tb;
    tb.openTrace("sim_trace.vcd");

    std::cout << "========================================" << std::endl;
    std::cout << "RISC-V CPU Verification Testbench" << std::endl;
    std::cout << "RTL vs Reference Model Comparison" << std::endl;
    std::cout << "========================================" << std::endl;

    // Test 1: Simple add
    std::vector<uint32_t> test_add;
    test_add.push_back(0x00500093);  // addi x1, x0, 5
    test_add.push_back(0x00300113);  // addi x2, x0, 3
    test_add.push_back(0x002081b3);  // add  x3, x1, x2
    test_add.push_back(0x00000013);  // nop
    tb.runTest("Simple Add", test_add, 4);

    // Test 2: Subtraction
    std::vector<uint32_t> test_sub;
    test_sub.push_back(0x00A00093);  // addi x1, x0, 10
    test_sub.push_back(0x00300113);  // addi x2, x0, 3
    test_sub.push_back(0x402081b3);  // sub  x3, x1, x2  (x3 = 10 - 3 = 7)
    test_sub.push_back(0x00000013);  // nop
    tb.runTest("Subtraction", test_sub, 4);

    // Test 3: Logical operations
    std::vector<uint32_t> test_logic;
    test_logic.push_back(0x0FF00093);  // addi x1, x0, 255
    test_logic.push_back(0x0F000113);  // addi x2, x0, 240
    test_logic.push_back(0x002071b3);  // and  x3, x1, x2  (x3 = 255 & 240 = 240)
    test_logic.push_back(0x0020E233);  // or   x4, x1, x2  (x4 = 255 | 240 = 255)
    test_logic.push_back(0x0020C2B3);  // xor  x5, x1, x2  (x5 = 255 ^ 240 = 15)
    test_logic.push_back(0x00000013);  // nop
    tb.runTest("Logical Ops", test_logic, 6);

    // Test 4: Immediate operations
    std::vector<uint32_t> test_imm;
    test_imm.push_back(0x01400093);  // addi x1, x0, 20
    test_imm.push_back(0x00A0F113);  // andi x2, x1, 10  (x2 = 20 & 10 = 0)
    test_imm.push_back(0x00F0E193);  // ori  x3, x1, 15  (x3 = 20 | 15 = 31)
    test_imm.push_back(0x00000013);  // nop
    tb.runTest("Immediate Ops", test_imm, 4);

    // Test 5: Shifts
    std::vector<uint32_t> test_shift;
    test_shift.push_back(0x00800093);  // addi x1, x0, 8
    test_shift.push_back(0x00209113);  // slli x2, x1, 2   (x2 = 8 << 2 = 32)
    test_shift.push_back(0x0020D193);  // srli x3, x1, 2   (x3 = 8 >> 2 = 2)
    test_shift.push_back(0x00000013);  // nop
    tb.runTest("Shifts", test_shift, 4);

    // Summary
    std::cout << "\n========================================" << std::endl;
    std::cout << "Test Summary" << std::endl;
    std::cout << "========================================" << std::endl;
    std::cout << "Tests Passed: " << tb.tests_passed << std::endl;
    std::cout << "Tests Failed: " << tb.tests_failed << std::endl;
    std::cout << "Total Cycles: " << tb.cycles_run << std::endl;

    if (tb.tests_failed == 0) {
        std::cout << "\n*** ALL TESTS PASSED ***" << std::endl;
        return 0;
    } else {
        std::cout << "\n*** SOME TESTS FAILED ***" << std::endl;
        return 1;
    }
}
