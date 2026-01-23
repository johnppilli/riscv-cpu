// cpu_ooo_tb.sv - Testbench for Out-of-Order CPU

module cpu_ooo_tb;

    logic clk;
    logic rst;

    // Instantiate the OoO CPU
    cpu_ooo cpu (
        .clk (clk),
        .rst (rst)
    );

    // Clock generation: 10ns period
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Test sequence
    initial begin
        $dumpfile("cpu_ooo_tb.vcd");
        $dumpvars(0, cpu_ooo_tb);

        $display("===========================================");
        $display("  RISC-V Out-of-Order CPU Test");
        $display("===========================================");
        $display("");
        $display("Test program:");
        $display("  ADDI x1, x0, 5     // x1 = 5");
        $display("  ADDI x2, x0, 3     // x2 = 3  (independent)");
        $display("  ADD  x3, x1, x2    // x3 = 8  (depends on x1, x2)");
        $display("  ADDI x4, x0, 10    // x4 = 10 (independent, can execute OoO)");
        $display("  ADD  x5, x3, x4    // x5 = 18 (depends on x3, x4)");
        $display("");

        // Reset
        rst = 1;
        #25;
        rst = 0;

        // Run for enough cycles
        repeat (30) @(posedge clk);

        // Display pipeline state each cycle
        $display("Cycle | Rename | Issue | Complete | Commit | x1  | x2  | x3  | x4  | x5");
        $display("------+--------+-------+----------+--------+-----+-----+-----+-----+-----");

        repeat (30) begin
            @(posedge clk);
            #1;
            $display("%5d |    %b   |   %b   |    %b     |    %b   | %3d | %3d | %3d | %3d | %3d",
                     $time/10,
                     cpu.rename_en,
                     cpu.iq_issue_valid,
                     cpu.ex_valid_r,
                     cpu.commit_valid,
                     cpu.prf.regs[cpu.rat_inst.comm_rat[1]],
                     cpu.prf.regs[cpu.rat_inst.comm_rat[2]],
                     cpu.prf.regs[cpu.rat_inst.comm_rat[3]],
                     cpu.prf.regs[cpu.rat_inst.comm_rat[4]],
                     cpu.prf.regs[cpu.rat_inst.comm_rat[5]]);
        end

        $display("");
        $display("===========================================");
        $display("  Final Register Values (committed)");
        $display("===========================================");

        // Read committed values through committed RAT
        $display("x1 = %0d (expected: 5)",  cpu.prf.regs[cpu.rat_inst.comm_rat[1]]);
        $display("x2 = %0d (expected: 3)",  cpu.prf.regs[cpu.rat_inst.comm_rat[2]]);
        $display("x3 = %0d (expected: 8)",  cpu.prf.regs[cpu.rat_inst.comm_rat[3]]);
        $display("x4 = %0d (expected: 10)", cpu.prf.regs[cpu.rat_inst.comm_rat[4]]);
        $display("x5 = %0d (expected: 18)", cpu.prf.regs[cpu.rat_inst.comm_rat[5]]);

        if (cpu.prf.regs[cpu.rat_inst.comm_rat[1]] == 5 &&
            cpu.prf.regs[cpu.rat_inst.comm_rat[2]] == 3 &&
            cpu.prf.regs[cpu.rat_inst.comm_rat[3]] == 8 &&
            cpu.prf.regs[cpu.rat_inst.comm_rat[4]] == 10 &&
            cpu.prf.regs[cpu.rat_inst.comm_rat[5]] == 18) begin
            $display("");
            $display("*** PASS - Out-of-order execution works! ***");
        end else begin
            $display("");
            $display("*** FAIL ***");
        end

        $display("");
        $finish;
    end

endmodule
