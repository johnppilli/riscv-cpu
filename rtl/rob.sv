// rob.sv - Reorder Buffer
// Circular queue that maintains program order for in-order commit
// Tracks instruction status: dispatched → completed → committed

module rob #(
    parameter ROB_SIZE     = 16,
    parameter ROB_IDX_BITS = 4,    // log2(16)
    parameter PHYS_REG_BITS = 6
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,     // Clear all entries (misprediction)

    // Allocate: new instruction enters the ROB (during dispatch)
    input  logic        alloc_en,
    input  logic [4:0]  alloc_rd,                    // Architectural dest reg
    input  logic [PHYS_REG_BITS-1:0] alloc_phys_rd,  // Physical dest reg
    input  logic [PHYS_REG_BITS-1:0] alloc_old_phys, // Old physical mapping (to free)
    input  logic [31:0] alloc_pc,
    output logic [ROB_IDX_BITS-1:0]  alloc_idx,      // Assigned ROB index
    output logic        alloc_ready,                  // ROB has space

    // Complete: mark instruction as done (from execution unit)
    input  logic        complete_en,
    input  logic [ROB_IDX_BITS-1:0] complete_idx,
    input  logic [31:0] complete_result,

    // Commit: retire from head (in program order)
    output logic        commit_valid,                 // Head is ready to commit
    output logic [4:0]  commit_rd,
    output logic [PHYS_REG_BITS-1:0] commit_phys_rd,
    output logic [PHYS_REG_BITS-1:0] commit_old_phys, // Register to free
    output logic [31:0] commit_result,
    input  logic        commit_ack                    // Acknowledge commit
);

    // ROB entry fields (separate arrays for Icarus compatibility)
    logic        valid      [0:ROB_SIZE-1];
    logic        done       [0:ROB_SIZE-1];
    logic [4:0]  rd         [0:ROB_SIZE-1];
    logic [PHYS_REG_BITS-1:0] phys_rd   [0:ROB_SIZE-1];
    logic [PHYS_REG_BITS-1:0] old_phys  [0:ROB_SIZE-1];
    logic [31:0] result     [0:ROB_SIZE-1];
    logic [31:0] pc         [0:ROB_SIZE-1];

    // Head and tail pointers
    logic [ROB_IDX_BITS-1:0] head;
    logic [ROB_IDX_BITS-1:0] tail;
    logic [ROB_IDX_BITS:0]   count;

    // Outputs
    assign alloc_idx   = tail;
    assign alloc_ready = (count < ROB_SIZE);

    assign commit_valid    = (count > 0) && valid[head] && done[head];
    assign commit_rd       = rd[head];
    assign commit_phys_rd  = phys_rd[head];
    assign commit_old_phys = old_phys[head];
    assign commit_result   = result[head];

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            head  <= 0;
            tail  <= 0;
            count <= 0;
            begin : rst_loop
                integer i;
                for (i = 0; i < ROB_SIZE; i++) begin
                    valid[i]    <= 1'b0;
                    done[i]     <= 1'b0;
                    rd[i]       <= 5'd0;
                    phys_rd[i]  <= 0;
                    old_phys[i] <= 0;
                    result[i]   <= 32'd0;
                    pc[i]       <= 32'd0;
                end
            end
        end else begin
            // Allocate new entry at tail
            if (alloc_en && alloc_ready) begin
                valid[tail]    <= 1'b1;
                done[tail]     <= 1'b0;
                rd[tail]       <= alloc_rd;
                phys_rd[tail]  <= alloc_phys_rd;
                old_phys[tail] <= alloc_old_phys;
                pc[tail]       <= alloc_pc;
                tail           <= tail + 1;
            end

            // Mark instruction as complete
            if (complete_en) begin
                done[complete_idx]   <= 1'b1;
                result[complete_idx] <= complete_result;
            end

            // Commit from head
            if (commit_ack && commit_valid) begin
                valid[head] <= 1'b0;
                done[head]  <= 1'b0;
                head        <= head + 1;
            end

            // Update count
            count <= count
                     + (alloc_en && alloc_ready ? 1 : 0)
                     - (commit_ack && commit_valid ? 1 : 0);
        end
    end

endmodule
