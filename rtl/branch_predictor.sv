// branch_predictor.sv - 2-bit saturating counter branch predictor
//
// How it works:
// - Each branch gets a 2-bit counter that tracks its history
// - Counter values: 00 = strongly not taken
//                   01 = weakly not taken
//                   10 = weakly taken
//                   11 = strongly taken
// - Predict taken if counter >= 2 (top bit is 1)
// - Update counter based on actual outcome
//
// This is called "saturating" because it doesn't wrap around:
// - 11 + 1 stays at 11 (not 00)
// - 00 - 1 stays at 00 (not 11)

module branch_predictor #(
    parameter INDEX_BITS = 6  // 2^6 = 64 entries in the table
)(
    input  logic        clk,
    input  logic        rst,

    // Prediction interface (IF stage)
    input  logic [31:0] pc_if,           // PC to predict for
    output logic        predict_taken,   // Prediction: 1=taken, 0=not taken

    // Update interface (when branch resolves in MEM/WB stage)
    input  logic        update_en,       // Update the predictor
    input  logic [31:0] update_pc,       // PC of the branch being updated
    input  logic        actual_taken     // What actually happened
);

    // Pattern History Table (PHT) - array of 2-bit counters
    logic [1:0] pht [0:(1 << INDEX_BITS)-1];

    // Index into the table using lower bits of PC
    // We skip the bottom 2 bits since instructions are 4-byte aligned
    logic [INDEX_BITS-1:0] predict_index;
    logic [INDEX_BITS-1:0] update_index;

    assign predict_index = pc_if[INDEX_BITS+1:2];
    assign update_index = update_pc[INDEX_BITS+1:2];

    // Prediction: taken if counter >= 2 (i.e., top bit is 1)
    assign predict_taken = pht[predict_index][1];

    // Initialize all counters to weakly taken (10)
    initial begin
        for (int i = 0; i < (1 << INDEX_BITS); i++) begin
            pht[i] = 2'b10;  // Start with "weakly taken"
        end
    end

    // Update logic
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Reset all counters to weakly taken
            for (int i = 0; i < (1 << INDEX_BITS); i++) begin
                pht[i] <= 2'b10;
            end
        end else if (update_en) begin
            // Update the counter based on actual outcome
            if (actual_taken) begin
                // Branch was taken - increment counter (saturate at 11)
                if (pht[update_index] != 2'b11) begin
                    pht[update_index] <= pht[update_index] + 1;
                end
            end else begin
                // Branch was not taken - decrement counter (saturate at 00)
                if (pht[update_index] != 2'b00) begin
                    pht[update_index] <= pht[update_index] - 1;
                end
            end
        end
    end

endmodule
