// instruction_memory.sv - Holds the program instructions

module instruction_memory #(
    parameter MEM_SIZE = 1024  // Size in words (4KB)
) (
    input  logic [31:0] addr,
    output logic [31:0] instruction
);

    // Memory array
    logic [31:0] mem [0:MEM_SIZE-1];

    // Initialize to NOPs
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            mem[i] = 32'h00000013;  // NOP (addi x0, x0, 0)
        end
        // Load program from file if it exists
        $readmemh("program.hex", mem);
    end

    // Word-aligned read (address is byte address, divide by 4)
    assign instruction = mem[addr[31:2]];

endmodule
