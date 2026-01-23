// rat.sv - Register Alias Table
// Maps architectural registers (x0-x31) to physical registers
// Maintains speculative and committed mappings

module rat #(
    parameter PHYS_REG_BITS = 6
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,   // Restore speculative RAT from committed RAT

    // Lookup: read current mapping for source registers
    input  logic [4:0]  rs1,
    input  logic [4:0]  rs2,
    output logic [PHYS_REG_BITS-1:0] phys_rs1,
    output logic [PHYS_REG_BITS-1:0] phys_rs2,

    // Rename: update mapping for destination register
    input  logic        rename_en,
    input  logic [4:0]  rename_rd,
    input  logic [PHYS_REG_BITS-1:0] rename_phys_rd,  // New physical reg
    output logic [PHYS_REG_BITS-1:0] rename_old_phys,  // Old mapping (for freeing on commit)

    // Commit: update committed RAT
    input  logic        commit_en,
    input  logic [4:0]  commit_rd,
    input  logic [PHYS_REG_BITS-1:0] commit_phys_rd
);

    // Speculative RAT (updated during rename)
    logic [PHYS_REG_BITS-1:0] spec_rat [0:31];

    // Committed RAT (updated during commit, used for recovery)
    logic [PHYS_REG_BITS-1:0] comm_rat [0:31];

    // Combinational lookup (with bypass for same-cycle rename)
    assign phys_rs1 = (rs1 == 5'd0) ? {PHYS_REG_BITS{1'b0}} :
                      (rename_en && rename_rd == rs1 && rename_rd != 5'd0) ? rename_phys_rd :
                      spec_rat[rs1];

    assign phys_rs2 = (rs2 == 5'd0) ? {PHYS_REG_BITS{1'b0}} :
                      (rename_en && rename_rd == rs2 && rename_rd != 5'd0) ? rename_phys_rd :
                      spec_rat[rs2];

    // Old physical register for the destination (will be freed on commit)
    assign rename_old_phys = spec_rat[rename_rd];

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initial mapping: arch reg i → phys reg i
            integer i;
            for (i = 0; i < 32; i++) begin
                spec_rat[i] <= i[PHYS_REG_BITS-1:0];
                comm_rat[i] <= i[PHYS_REG_BITS-1:0];
            end
        end else if (flush) begin
            // Restore speculative from committed
            integer i;
            for (i = 0; i < 32; i++) begin
                spec_rat[i] <= comm_rat[i];
            end
        end else begin
            // Update speculative RAT on rename
            if (rename_en && rename_rd != 5'd0) begin
                spec_rat[rename_rd] <= rename_phys_rd;
            end

            // Update committed RAT on commit
            if (commit_en && commit_rd != 5'd0) begin
                comm_rat[commit_rd] <= commit_phys_rd;
            end
        end
    end

endmodule
