// forwarding_unit.sv - Detects when to forward data to avoid stalls
//
// Forwarding happens when:
// - An instruction in EX stage needs a register value
// - That register is being written by an instruction in MEM or WB stage
//
// Instead of waiting, we "forward" the result directly.

module forwarding_unit (
    // Source registers in EX stage (what we're reading)
    input  logic [4:0] ex_rs1,
    input  logic [4:0] ex_rs2,

    // Destination register in MEM stage (what MEM is writing)
    input  logic [4:0] mem_rd,
    input  logic       mem_reg_write,

    // Destination register in WB stage (what WB is writing)
    input  logic [4:0] wb_rd,
    input  logic       wb_reg_write,

    // Forwarding control outputs
    // 00 = no forwarding (use register file value)
    // 01 = forward from WB stage
    // 10 = forward from MEM stage
    output logic [1:0] forward_a,   // For rs1 / operand A
    output logic [1:0] forward_b    // For rs2 / operand B
);

    // Forwarding logic for operand A (rs1)
    always_comb begin
        // Default: no forwarding
        forward_a = 2'b00;

        // Check MEM stage first (most recent result has priority)
        // Forward from MEM if:
        //   - MEM stage is writing to a register (mem_reg_write)
        //   - Destination isn't x0 (can't write to x0)
        //   - Destination matches what EX needs (mem_rd == ex_rs1)
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1)) begin
            forward_a = 2'b10;  // Forward from MEM
        end
        // Otherwise check WB stage (older result)
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1)) begin
            forward_a = 2'b01;  // Forward from WB
        end
    end

    // Forwarding logic for operand B (rs2)
    always_comb begin
        // Default: no forwarding
        forward_b = 2'b00;

        // Check MEM stage first (most recent result has priority)
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2)) begin
            forward_b = 2'b10;  // Forward from MEM
        end
        // Otherwise check WB stage
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2)) begin
            forward_b = 2'b01;  // Forward from WB
        end
    end

endmodule
