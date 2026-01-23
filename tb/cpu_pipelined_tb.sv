// cpu_pipelined_tb.sv - Testbench for pipelined CPU with caches

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

        $display("===========================================");
        $display("  RISC-V Pipelined CPU - Cache Test");
        $display("===========================================");
        $display("");
        $display("Test program (back-to-back with forwarding):");
        $display("  ADDI x1, x0, 5     // x1 = 5");
        $display("  ADDI x2, x1, 3     // x2 = 8");
        $display("  ADD  x3, x1, x2    // x3 = 13");
        $display("  ADD  x4, x3, x1    // x4 = 18");
        $display("");
        $display("With caches, initial misses add latency.");
        $display("");

        // Reset the CPU
        rst = 1;
        #25;
        rst = 0;

        // Run for enough cycles (cache misses add latency)
        // Each cache miss takes ~4 cycles to fetch from memory
        // Plus filling 4 words per line
        repeat (100) begin
            @(posedge clk);
        end

        // Show some status
        $display("Cycle | ICache Stall | DCache Stall | x1   | x2   | x3   | x4");
        $display("------+--------------+--------------+------+------+------+------");

        repeat (50) begin
            @(posedge clk);
            #1;
            $display("%5d |      %b       |      %b       | %4d | %4d | %4d | %4d",
                     $time/10,
                     cpu.icache_stall,
                     cpu.dcache_stall,
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

        if (cpu.regfile.registers[1] == 5 &&
            cpu.regfile.registers[2] == 8 &&
            cpu.regfile.registers[3] == 13 &&
            cpu.regfile.registers[4] == 18) begin
            $display("");
            $display("*** PASS - Caches work correctly! ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
        end

        $display("");
        $finish;
    end

endmodule
