// cache.sv - Direct-mapped cache (used for both I-cache and D-cache)
//
// How a cache works:
// - Instead of always going to slow main memory, keep copies of
//   recently used data in a small, fast storage (the cache)
// - When we need data, check the cache first:
//   - HIT: Data is here! Return it immediately (1 cycle)
//   - MISS: Data isn't here. Fetch from main memory (multiple cycles)
//
// Structure:
// - Direct-mapped: each address maps to exactly one cache line
// - Each line: [valid][tag][data block]
// - Address breakdown: [tag | index | offset]
//
// Parameters:
//   CACHE_SIZE_BYTES = total cache size
//   LINE_SIZE_BYTES  = bytes per cache line (block size)

module cache #(
    parameter CACHE_SIZE_BYTES = 256,       // 256 bytes total cache
    parameter LINE_SIZE_BYTES  = 16,        // 16 bytes per line (4 words)
    parameter ADDR_WIDTH       = 32
)(
    input  logic                  clk,
    input  logic                  rst,

    // CPU interface
    input  logic [ADDR_WIDTH-1:0] cpu_addr,      // Address from CPU
    input  logic [31:0]           cpu_write_data, // Data to write (for stores)
    input  logic                  cpu_read_en,    // CPU wants to read
    input  logic                  cpu_write_en,   // CPU wants to write
    output logic [31:0]           cpu_read_data,  // Data returned to CPU
    output logic                  cpu_stall,      // Stall CPU (cache miss)

    // Memory interface (for cache misses)
    output logic [ADDR_WIDTH-1:0] mem_addr,       // Address to main memory
    output logic                  mem_read_en,    // Read from main memory
    output logic                  mem_write_en,   // Write to main memory
    output logic [31:0]           mem_write_data, // Data to write to memory
    input  logic [31:0]           mem_read_data,  // Data from main memory
    input  logic                  mem_ready       // Memory operation complete
);

    // Cache geometry calculations
    localparam NUM_LINES    = CACHE_SIZE_BYTES / LINE_SIZE_BYTES;  // 16 lines
    localparam WORDS_PER_LINE = LINE_SIZE_BYTES / 4;              // 4 words per line
    localparam OFFSET_BITS  = $clog2(LINE_SIZE_BYTES);            // 4 bits (byte offset)
    localparam INDEX_BITS   = $clog2(NUM_LINES);                  // 4 bits
    localparam TAG_BITS     = ADDR_WIDTH - INDEX_BITS - OFFSET_BITS; // 24 bits
    localparam WORD_OFFSET_BITS = $clog2(WORDS_PER_LINE);         // 2 bits

    // Cache storage
    logic                          valid [0:NUM_LINES-1];
    logic [TAG_BITS-1:0]           tags  [0:NUM_LINES-1];
    logic [31:0]                   data  [0:NUM_LINES-1][0:WORDS_PER_LINE-1];

    // Address breakdown
    logic [TAG_BITS-1:0]           addr_tag;
    logic [INDEX_BITS-1:0]         addr_index;
    logic [WORD_OFFSET_BITS-1:0]   addr_word_offset;

    assign addr_tag         = cpu_addr[ADDR_WIDTH-1 -: TAG_BITS];
    assign addr_index       = cpu_addr[OFFSET_BITS +: INDEX_BITS];
    assign addr_word_offset = cpu_addr[2 +: WORD_OFFSET_BITS];

    // Cache hit detection
    logic cache_hit;
    assign cache_hit = valid[addr_index] && (tags[addr_index] == addr_tag);

    // State machine for handling cache misses
    typedef enum logic [1:0] {
        IDLE,           // Normal operation
        FETCH,          // Fetching a line from memory
        WRITE_THROUGH   // Writing data to memory
    } state_t;

    state_t state, next_state;
    logic [$clog2(WORDS_PER_LINE)-1:0] fetch_word_count;
    logic [ADDR_WIDTH-1:0] fetch_addr;

    // Read data output (from cache on hit)
    assign cpu_read_data = data[addr_index][addr_word_offset];

    // Stall CPU when we have a miss and need to fetch
    assign cpu_stall = (cpu_read_en || cpu_write_en) && !cache_hit && (state == IDLE) ||
                       (state == FETCH);

    // Memory interface signals
    always_comb begin
        mem_addr = fetch_addr;
        mem_read_en = (state == FETCH);
        mem_write_en = (state == WRITE_THROUGH);
        mem_write_data = cpu_write_data;
    end

    // Initialize cache
    initial begin
        for (int i = 0; i < NUM_LINES; i++) begin
            valid[i] = 1'b0;
            tags[i] = '0;
            for (int j = 0; j < WORDS_PER_LINE; j++) begin
                data[i][j] = 32'd0;
            end
        end
    end

    // State machine
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            state <= IDLE;
            fetch_word_count <= '0;
            fetch_addr <= '0;
        end else begin
            case (state)
                IDLE: begin
                    if ((cpu_read_en || cpu_write_en) && !cache_hit) begin
                        // Cache miss - start fetching the line
                        state <= FETCH;
                        fetch_word_count <= '0;
                        // Align address to line boundary
                        fetch_addr <= {cpu_addr[ADDR_WIDTH-1:OFFSET_BITS], {OFFSET_BITS{1'b0}}};
                    end else if (cpu_write_en && cache_hit) begin
                        // Write hit - update cache (write-through)
                        data[addr_index][addr_word_offset] <= cpu_write_data;
                        // Also write to memory
                        state <= WRITE_THROUGH;
                        fetch_addr <= cpu_addr;
                    end
                end

                FETCH: begin
                    if (mem_ready) begin
                        // Store the word from memory into cache
                        data[addr_index][fetch_word_count] <= mem_read_data;

                        if (fetch_word_count == WORDS_PER_LINE - 1) begin
                            // Done fetching entire line
                            valid[addr_index] <= 1'b1;
                            tags[addr_index] <= addr_tag;
                            state <= IDLE;
                        end else begin
                            fetch_word_count <= fetch_word_count + 1;
                            fetch_addr <= fetch_addr + 4;
                        end
                    end
                end

                WRITE_THROUGH: begin
                    if (mem_ready) begin
                        state <= IDLE;
                    end
                end

                default: state <= IDLE;
            endcase
        end
    end

endmodule
