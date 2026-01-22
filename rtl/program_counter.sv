// program_counter.sv - Tracks current instruction address

module program_counter (
    input  logic        clk,
    input  logic        rst,          // Reset
    input  logic        stall,        // Stall signal (hold PC when high)
    input  logic [31:0] pc_next,      // Next PC value
    output logic [31:0] pc            // Current PC value
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'd0;  // Start at address 0 on reset
        end else if (!stall) begin
            pc <= pc_next;  // Only update PC if not stalling
        end
        // If stall, keep current PC
    end

endmodule
