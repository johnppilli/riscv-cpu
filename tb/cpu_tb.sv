// cpu_tb.sv - Testbench for the CPU

module cpu_tb;

    // Clock and reset
    logic clk;
    logic rst;

    // Instantiate the CPU
    cpu_top cpu (
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
        $dumpfile("cpu_tb.vcd");
        $dumpvars(0, cpu_tb);

        // Initialize
        $display("=== RISC-V CPU Testbench ===");
        $display("");

        // Reset the CPU
        rst = 1;
        #20;
        rst = 0;

        // Run for enough cycles to execute the test program
        // Our simple test has 3 instructions, but let's run more to be safe
        repeat (20) begin
            @(posedge clk);
            $display("PC=%h | Instr=%h | x1=%0d | x2=%0d | x3=%0d",
                     cpu.pc,
                     cpu.instruction,
                     cpu.regfile.registers[1],
                     cpu.regfile.registers[2],
                     cpu.regfile.registers[3]);
        end

        $display("");
        $display("=== Test Results ===");
        $display("x1 = %0d (expected: 5)", cpu.regfile.registers[1]);
        $display("x2 = %0d (expected: 3)", cpu.regfile.registers[2]);
        $display("x3 = %0d (expected: 8)", cpu.regfile.registers[3]);

        // Check results
        if (cpu.regfile.registers[1] == 5 &&
            cpu.regfile.registers[2] == 3 &&
            cpu.regfile.registers[3] == 8) begin
            $display("");
            $display("*** PASS ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
        end

        $display("");
        $finish;
    end

endmodule
