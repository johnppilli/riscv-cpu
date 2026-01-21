// data_memory.sv - Memory for load/store operations

module data_memory #(
    parameter MEM_SIZE = 1024  // Size in words (4KB)
) (
    input  logic        clk,
    input  logic        mem_read,     // Read enable
    input  logic        mem_write,    // Write enable
    input  logic [31:0] addr,         // Byte address
    input  logic [31:0] write_data,   // Data to write
    output logic [31:0] read_data     // Data read
);

    // Memory array
    logic [31:0] mem [0:MEM_SIZE-1];

    // Initialize to zero
    initial begin
        for (int i = 0; i < MEM_SIZE; i++) begin
            mem[i] = 32'd0;
        end
    end

    // Read (combinational)
    assign read_data = mem_read ? mem[addr[31:2]] : 32'd0;

    // Write (sequential)
    always_ff @(posedge clk) begin
        if (mem_write) begin
            mem[addr[31:2]] <= write_data;
        end
    end

endmodule
