// cpu_pipelined_tb.sv - Testbench for pipelined CPU

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
        $display("  RISC-V Pipelined CPU Testbench");
        $display("===========================================");
        $display("");

        // Reset the CPU
        rst = 1;
        #25;
        rst = 0;

        // Run for enough cycles
        // Pipeline needs more cycles: 4 cycles to fill + instruction cycles
        // Test program has NOPs to avoid hazards
        $display("Cycle | PC       | IF Instr | ID Instr | x1   | x2   | x3");
        $display("------+----------+----------+----------+------+------+------");

        repeat (25) begin
            @(posedge clk);
            #1;  // Small delay to let signals settle
            $display("%5d | %h | %h | %h | %4d | %4d | %4d",
                     $time/10,
                     cpu.if_pc,
                     cpu.if_instruction,
                     cpu.id_instruction,
                     cpu.regfile.registers[1],
                     cpu.regfile.registers[2],
                     cpu.regfile.registers[3]);
        end

        $display("");
        $display("===========================================");
        $display("  Final Register Values");
        $display("===========================================");
        $display("x1 = %0d", cpu.regfile.registers[1]);
        $display("x2 = %0d", cpu.regfile.registers[2]);
        $display("x3 = %0d", cpu.regfile.registers[3]);

        // For pipelined CPU with NOPs between instructions:
        // addi x1, x0, 5  -> x1 = 5
        // nop (x3)
        // nop
        // nop
        // addi x2, x0, 3  -> x2 = 3
        // nop
        // nop
        // nop
        // add x3, x1, x2  -> x3 = 8

        if (cpu.regfile.registers[1] == 5 &&
            cpu.regfile.registers[2] == 3 &&
            cpu.regfile.registers[3] == 8) begin
            $display("");
            $display("*** PASS ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
            $display("Expected: x1=5, x2=3, x3=8");
        end

        $display("");
        $finish;
    end

endmodule
