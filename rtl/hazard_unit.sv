// hazard_unit.sv - Detects hazards that require stalling
//
// Load-Use Hazard:
//   LOAD x1, 0(x2)    <- This is in EX stage, loading into x1
//   ADD  x3, x1, x4   <- This is in ID stage, needs x1
//
// Problem: The LOAD won't have x1's value until after MEM stage.
//          Forwarding can't help because the data doesn't exist yet!
//
// Solution: STALL the pipeline for 1 cycle. Insert a "bubble" (NOP).
//           After stalling, the LOAD will be in MEM stage and we can forward.

module hazard_unit (
    // Source registers being decoded in ID stage
    input  logic [4:0] id_rs1,
    input  logic [4:0] id_rs2,

    // What's happening in EX stage
    input  logic [4:0] ex_rd,        // Destination register
    input  logic       ex_mem_read,  // Is it a LOAD instruction?

    // Stall control outputs
    output logic       stall_if,     // Freeze IF stage (don't fetch new instruction)
    output logic       stall_id,     // Freeze ID stage (don't decode new instruction)
    output logic       flush_ex      // Insert bubble in EX (turn into NOP)
);

    logic load_use_hazard;

    // Detect load-use hazard
    // Hazard exists when:
    //   1. EX stage has a LOAD instruction (ex_mem_read is high)
    //   2. The LOAD's destination matches a source in ID stage
    //   3. The destination isn't x0 (writing to x0 does nothing)
    always_comb begin
        load_use_hazard = ex_mem_read &&
                          (ex_rd != 5'd0) &&
                          ((ex_rd == id_rs1) || (ex_rd == id_rs2));
    end

    // When we detect a hazard:
    // - Stall IF: Don't fetch the next instruction (keep current PC)
    // - Stall ID: Don't let the instruction move to EX yet
    // - Flush EX: Insert a NOP/bubble so EX doesn't execute garbage
    assign stall_if = load_use_hazard;
    assign stall_id = load_use_hazard;
    assign flush_ex = load_use_hazard;

endmodule
