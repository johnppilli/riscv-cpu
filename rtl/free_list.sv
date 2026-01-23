// free_list.sv - Free list for physical register allocation
// Circular FIFO tracking available physical registers

module free_list #(
    parameter NUM_PHYS_REGS = 64,
    parameter PHYS_REG_BITS = 6
) (
    input  logic        clk,
    input  logic        rst,

    // Allocate: pop a free register (during rename)
    input  logic                     alloc_en,
    output logic [PHYS_REG_BITS-1:0] alloc_reg,
    output logic                     alloc_valid,  // 0 if list is empty

    // Free: push a register back (during commit)
    input  logic                     free_en,
    input  logic [PHYS_REG_BITS-1:0] free_reg
);

    // Circular buffer storage
    // We have 64 physical regs, first 32 are initially mapped to arch regs
    // So free list starts with regs 32-63
    localparam FIFO_SIZE = NUM_PHYS_REGS;

    logic [PHYS_REG_BITS-1:0] fifo [0:FIFO_SIZE-1];
    logic [PHYS_REG_BITS:0]   head;  // Extra bit for full/empty detection
    logic [PHYS_REG_BITS:0]   tail;
    logic [PHYS_REG_BITS:0]   count;

    // Output the register at the head
    assign alloc_reg   = fifo[head[PHYS_REG_BITS-1:0]];
    assign alloc_valid = (count > 0);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initialize: physical regs 32-63 are free
            // (0-31 are initially mapped 1:1 to architectural regs)
            integer i;
            for (i = 0; i < NUM_PHYS_REGS - 32; i++) begin
                fifo[i] <= i[PHYS_REG_BITS-1:0] + 6'd32;
            end
            head  <= 0;
            tail  <= NUM_PHYS_REGS - 32;  // 32 entries initially
            count <= NUM_PHYS_REGS - 32;
        end else begin
            // Allocate (pop from head)
            if (alloc_en && alloc_valid) begin
                head <= head + 1;
                count <= count - (free_en ? 0 : 1);
            end

            // Free (push to tail)
            if (free_en) begin
                fifo[tail[PHYS_REG_BITS-1:0]] <= free_reg;
                tail <= tail + 1;
                if (!(alloc_en && alloc_valid)) begin
                    count <= count + 1;
                end
            end
        end
    end

endmodule
