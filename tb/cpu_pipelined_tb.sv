// cpu_pipelined_tb.sv - Testbench for pipelined CPU with branch prediction

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
        $display("  RISC-V Pipelined CPU - Branch Test");
        $display("===========================================");
        $display("");
        $display("Test program (loop with branch):");
        $display("  ADDI x1, x0, 3      // x1 = 3 (counter)");
        $display("  loop:");
        $display("    ADDI x1, x1, -1   // x1--");
        $display("    BNE x1, x0, loop  // if x1 != 0, loop");
        $display("  ADDI x2, x0, 42     // x2 = 42 (done marker)");
        $display("");
        $display("Expected: Loop runs 3 times, then x1=0, x2=42");
        $display("");

        // Reset the CPU
        rst = 1;
        #25;
        rst = 0;

        // Run for enough cycles
        $display("Cycle | PC       | Predict | Mispred | x1   | x2");
        $display("------+----------+---------+---------+------+------");

        repeat (40) begin
            @(posedge clk);
            #1;
            $display("%5d | %h |    %b    |    %b    | %4d | %4d",
                     $time/10,
                     cpu.if_pc,
                     cpu.if_predict_taken,
                     cpu.mem_mispredicted,
                     cpu.regfile.registers[1],
                     cpu.regfile.registers[2]);
        end

        $display("");
        $display("===========================================");
        $display("  Final Register Values");
        $display("===========================================");
        $display("x1 = %0d (expected: 0)", cpu.regfile.registers[1]);
        $display("x2 = %0d (expected: 42)", cpu.regfile.registers[2]);

        // Verify results
        if (cpu.regfile.registers[1] == 0 &&
            cpu.regfile.registers[2] == 42) begin
            $display("");
            $display("*** PASS - Branch prediction works! ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
        end

        $display("");
        $finish;
    end

endmodule
