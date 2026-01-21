// program_counter.sv - Tracks current instruction address

module program_counter (
    input  logic        clk,
    input  logic        rst,          // Reset
    input  logic [31:0] pc_next,      // Next PC value
    output logic [31:0] pc            // Current PC value
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'd0;  // Start at address 0 on reset
        end else begin
            pc <= pc_next;
        end
    end

endmodule
