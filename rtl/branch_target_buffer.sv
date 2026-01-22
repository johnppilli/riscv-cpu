// branch_target_buffer.sv - Stores branch target addresses
//
// The BTB remembers where each branch instruction jumps to.
// When we predict "taken", we need to know WHERE to jump.
//
// Structure:
// - Indexed by PC (like a cache)
// - Each entry stores: valid bit, tag (upper PC bits), target address
// - On a hit: we know the target address
// - On a miss: we don't know where to jump (assume not taken)

module branch_target_buffer #(
    parameter INDEX_BITS = 6,  // 2^6 = 64 entries
    parameter TAG_BITS = 24   // Upper bits of PC for matching
)(
    input  logic        clk,
    input  logic        rst,

    // Lookup interface (IF stage)
    input  logic [31:0] pc_if,           // PC to look up
    output logic        btb_hit,         // Found in BTB
    output logic [31:0] btb_target,      // Target address if hit

    // Update interface (when branch executes)
    input  logic        update_en,       // Update the BTB
    input  logic [31:0] update_pc,       // PC of the branch
    input  logic [31:0] update_target,   // Where the branch goes
    input  logic        update_is_branch // Is this actually a branch instruction?
);

    localparam NUM_ENTRIES = (1 << INDEX_BITS);

    // BTB storage - separate arrays instead of struct
    logic                valid  [0:NUM_ENTRIES-1];
    logic [TAG_BITS-1:0] tags   [0:NUM_ENTRIES-1];
    logic [31:0]         targets[0:NUM_ENTRIES-1];

    // Index and tag extraction
    // Skip bottom 2 bits (instructions are 4-byte aligned)
    logic [INDEX_BITS-1:0] lookup_index;
    logic [TAG_BITS-1:0]   lookup_tag;
    logic [INDEX_BITS-1:0] update_index;
    logic [TAG_BITS-1:0]   update_tag;

    assign lookup_index = pc_if[INDEX_BITS+1:2];
    assign lookup_tag = pc_if[INDEX_BITS+TAG_BITS+1:INDEX_BITS+2];
    assign update_index = update_pc[INDEX_BITS+1:2];
    assign update_tag = update_pc[INDEX_BITS+TAG_BITS+1:INDEX_BITS+2];

    // Lookup logic (combinational)
    assign btb_hit = valid[lookup_index] && (tags[lookup_index] == lookup_tag);
    assign btb_target = targets[lookup_index];

    // Initialize BTB to empty
    initial begin
        for (int i = 0; i < NUM_ENTRIES; i++) begin
            valid[i] = 1'b0;
            tags[i] = '0;
            targets[i] = 32'd0;
        end
    end

    // Update logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            for (int i = 0; i < NUM_ENTRIES; i++) begin
                valid[i] <= 1'b0;
                tags[i] <= '0;
                targets[i] <= 32'd0;
            end
        end else if (update_en && update_is_branch) begin
            // Store/update the branch target
            valid[update_index] <= 1'b1;
            tags[update_index] <= update_tag;
            targets[update_index] <= update_target;
        end
    end

endmodule
