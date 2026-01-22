// cpu_pipelined_tb.sv - Testbench for pipelined CPU with hazard handling

module cpu_pipelined_tb;

    // Clock and reset
    logic clk;
    logic rst;

    // Instantiate the pipelined CPU
    cpu_pipelined cpu (
        .clk (clk),
        .rst (rst)
    );

    // Clock generation: 10ns period (100MHz)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        // Setup waveform dump
        $dumpfile("cpu_pipelined_tb.vcd");
        $dumpvars(0, cpu_pipelined_tb);

        // Initialize
        $display("===========================================");
        $display("  RISC-V Pipelined CPU - Hazard Test");
        $display("===========================================");
        $display("");
        $display("Test program (back-to-back dependent instructions):");
        $display("  ADDI x1, x0, 5   // x1 = 5");
        $display("  ADDI x2, x1, 3   // x2 = x1 + 3 = 8 (needs forwarding!)");
        $display("  ADD  x3, x1, x2  // x3 = x1 + x2 = 13 (needs forwarding!)");
        $display("  ADD  x4, x3, x1  // x4 = x3 + x1 = 18 (needs forwarding!)");
        $display("");

        // Reset the CPU
        rst = 1;
        #25;
        rst = 0;

        // Run for enough cycles
        $display("Cycle | PC       | Stall | FwdA | FwdB | x1   | x2   | x3   | x4");
        $display("------+----------+-------+------+------+------+------+------+------");

        repeat (20) begin
            @(posedge clk);
            #1;  // Small delay to let signals settle
            $display("%5d | %h |   %b   |  %b   |  %b   | %4d | %4d | %4d | %4d",
                     $time/10,
                     cpu.if_pc,
                     cpu.stall_if,
                     cpu.forward_a,
                     cpu.forward_b,
                     cpu.regfile.registers[1],
                     cpu.regfile.registers[2],
                     cpu.regfile.registers[3],
                     cpu.regfile.registers[4]);
        end

        $display("");
        $display("===========================================");
        $display("  Final Register Values");
        $display("===========================================");
        $display("x1 = %0d (expected: 5)", cpu.regfile.registers[1]);
        $display("x2 = %0d (expected: 8)", cpu.regfile.registers[2]);
        $display("x3 = %0d (expected: 13)", cpu.regfile.registers[3]);
        $display("x4 = %0d (expected: 18)", cpu.regfile.registers[4]);

        // Verify results
        // With hazard handling:
        // ADDI x1, x0, 5  -> x1 = 5
        // ADDI x2, x1, 3  -> x2 = 5 + 3 = 8 (forwarded from MEM or WB)
        // ADD  x3, x1, x2 -> x3 = 5 + 8 = 13 (forwarded)
        // ADD  x4, x3, x1 -> x4 = 13 + 5 = 18 (forwarded)

        if (cpu.regfile.registers[1] == 5 &&
            cpu.regfile.registers[2] == 8 &&
            cpu.regfile.registers[3] == 13 &&
            cpu.regfile.registers[4] == 18) begin
            $display("");
            $display("*** PASS - Hazard handling works! ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
            $display("Hazard forwarding did not produce correct values.");
        end

        $display("");
        $finish;
    end

endmodule
