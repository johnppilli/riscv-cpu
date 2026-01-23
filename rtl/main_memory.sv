// main_memory.sv - Simulated main memory with latency
//
// This simulates real main memory which is SLOW compared to cache.
// Takes LATENCY cycles to respond to a read/write request.
// This is why caches are important - they avoid this slow access.

module main_memory #(
    parameter MEM_SIZE_WORDS = 4096,   // 16KB of memory
    parameter LATENCY = 4              // 4 cycles to respond
)(
    input  logic        clk,
    input  logic        rst,

    // Memory interface
    input  logic [31:0] addr,          // Address
    input  logic        read_en,       // Read request
    input  logic        write_en,      // Write request
    input  logic [31:0] write_data,    // Data to write
    output logic [31:0] read_data,     // Data read
    output logic        ready          // Response ready
);

    // Memory storage
    logic [31:0] mem [0:MEM_SIZE_WORDS-1];

    // Latency counter
    logic [$clog2(LATENCY):0] counter;
    logic active;

    // Word-aligned address
    logic [31:0] word_addr;
    assign word_addr = addr >> 2;

    // Load program from hex file (same as instruction_memory)
    initial begin
        for (int i = 0; i < MEM_SIZE_WORDS; i++) begin
            mem[i] = 32'd0;
        end
        $readmemh("program.hex", mem);
    end

    // Latency simulation
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            counter <= '0;
            active <= 1'b0;
            ready <= 1'b0;
            read_data <= 32'd0;
        end else begin
            ready <= 1'b0;  // Default: not ready

            if (!active && (read_en || write_en)) begin
                // New request - start counting
                active <= 1'b1;
                counter <= '0;
            end else if (active) begin
                if (counter == LATENCY - 1) begin
                    // Done waiting - respond
                    ready <= 1'b1;
                    active <= 1'b0;
                    counter <= '0;

                    if (read_en) begin
                        read_data <= (word_addr < MEM_SIZE_WORDS) ? mem[word_addr] : 32'd0;
                    end
                    if (write_en) begin
                        if (word_addr < MEM_SIZE_WORDS) begin
                            mem[word_addr] <= write_data;
                        end
                    end
                end else begin
                    counter <= counter + 1;
                end
            end
        end
    end

endmodule
