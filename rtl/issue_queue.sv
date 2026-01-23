// issue_queue.sv - Issue Queue (Reservation Stations)
// Holds instructions waiting for operands, issues when ready
// Implements wake-up (mark sources ready) and select (pick ready instruction)

module issue_queue #(
    parameter IQ_SIZE       = 8,
    parameter IQ_IDX_BITS   = 3,
    parameter PHYS_REG_BITS = 6,
    parameter ROB_IDX_BITS  = 4
) (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    // Dispatch: insert a new instruction
    input  logic        dispatch_en,
    input  logic [3:0]  dispatch_alu_op,
    input  logic        dispatch_alu_src,     // 0=reg, 1=imm
    input  logic [31:0] dispatch_imm,
    input  logic [PHYS_REG_BITS-1:0] dispatch_phys_rs1,
    input  logic [PHYS_REG_BITS-1:0] dispatch_phys_rs2,
    input  logic [PHYS_REG_BITS-1:0] dispatch_phys_rd,
    input  logic        dispatch_src1_ready,  // Source 1 already in regfile
    input  logic        dispatch_src2_ready,  // Source 2 already in regfile
    input  logic [ROB_IDX_BITS-1:0] dispatch_rob_idx,
    output logic        dispatch_ready,       // Queue has space

    // Wake-up: broadcast completing instruction's phys_rd
    input  logic        wakeup_en,
    input  logic [PHYS_REG_BITS-1:0] wakeup_phys_rd,

    // Issue: output the selected ready instruction
    output logic        issue_valid,
    output logic [3:0]  issue_alu_op,
    output logic        issue_alu_src,
    output logic [31:0] issue_imm,
    output logic [PHYS_REG_BITS-1:0] issue_phys_rs1,
    output logic [PHYS_REG_BITS-1:0] issue_phys_rs2,
    output logic [PHYS_REG_BITS-1:0] issue_phys_rd,
    output logic [ROB_IDX_BITS-1:0]  issue_rob_idx,
    input  logic        issue_ack              // Execution unit accepted
);

    // Entry fields
    logic        valid     [0:IQ_SIZE-1];
    logic [3:0]  alu_op    [0:IQ_SIZE-1];
    logic        alu_src   [0:IQ_SIZE-1];
    logic [31:0] imm       [0:IQ_SIZE-1];
    logic [PHYS_REG_BITS-1:0] phys_rs1 [0:IQ_SIZE-1];
    logic [PHYS_REG_BITS-1:0] phys_rs2 [0:IQ_SIZE-1];
    logic [PHYS_REG_BITS-1:0] phys_rd  [0:IQ_SIZE-1];
    logic        src1_rdy  [0:IQ_SIZE-1];
    logic        src2_rdy  [0:IQ_SIZE-1];
    logic [ROB_IDX_BITS-1:0] rob_idx [0:IQ_SIZE-1];

    // Count entries
    logic [IQ_IDX_BITS:0] count;
    assign dispatch_ready = (count < IQ_SIZE);

    // Find a free slot for dispatch
    logic [IQ_IDX_BITS-1:0] free_slot;
    logic free_found;
    always_comb begin
        free_slot = 0;
        free_found = 1'b0;
        begin : find_free
            integer i;
            for (i = 0; i < IQ_SIZE; i++) begin
                if (!valid[i] && !free_found) begin
                    free_slot = i[IQ_IDX_BITS-1:0];
                    free_found = 1'b1;
                end
            end
        end
    end

    // Select oldest ready instruction to issue
    // "Ready" means both sources are ready (or alu_src=1 means src2 is imm)
    logic [IQ_IDX_BITS-1:0] issue_slot;
    logic issue_found;
    always_comb begin
        issue_slot = 0;
        issue_found = 1'b0;
        issue_valid = 1'b0;
        issue_alu_op = 4'd0;
        issue_alu_src = 1'b0;
        issue_imm = 32'd0;
        issue_phys_rs1 = 0;
        issue_phys_rs2 = 0;
        issue_phys_rd = 0;
        issue_rob_idx = 0;

        begin : find_ready
            integer i;
            for (i = 0; i < IQ_SIZE; i++) begin
                if (valid[i] && !issue_found) begin
                    // Check if ready: src1 must be ready, src2 must be ready OR using immediate
                    if (src1_rdy[i] && (src2_rdy[i] || alu_src[i])) begin
                        issue_slot = i[IQ_IDX_BITS-1:0];
                        issue_found = 1'b1;
                        issue_valid = 1'b1;
                        issue_alu_op = alu_op[i];
                        issue_alu_src = alu_src[i];
                        issue_imm = imm[i];
                        issue_phys_rs1 = phys_rs1[i];
                        issue_phys_rs2 = phys_rs2[i];
                        issue_phys_rd = phys_rd[i];
                        issue_rob_idx = rob_idx[i];
                    end
                end
            end
        end
    end

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            count <= 0;
            begin : rst_loop
                integer i;
                for (i = 0; i < IQ_SIZE; i++) begin
                    valid[i]    <= 1'b0;
                    src1_rdy[i] <= 1'b0;
                    src2_rdy[i] <= 1'b0;
                    alu_op[i]   <= 4'd0;
                    alu_src[i]  <= 1'b0;
                    imm[i]      <= 32'd0;
                    phys_rs1[i] <= 0;
                    phys_rs2[i] <= 0;
                    phys_rd[i]  <= 0;
                    rob_idx[i]  <= 0;
                end
            end
        end else begin
            // Wake-up: mark sources ready when their producer completes
            if (wakeup_en) begin
                begin : wakeup_loop
                    integer i;
                    for (i = 0; i < IQ_SIZE; i++) begin
                        if (valid[i]) begin
                            if (phys_rs1[i] == wakeup_phys_rd && wakeup_phys_rd != 0)
                                src1_rdy[i] <= 1'b1;
                            if (phys_rs2[i] == wakeup_phys_rd && wakeup_phys_rd != 0)
                                src2_rdy[i] <= 1'b1;
                        end
                    end
                end
            end

            // Issue: remove the issued instruction
            if (issue_valid && issue_ack) begin
                valid[issue_slot] <= 1'b0;
                count <= count - (dispatch_en && dispatch_ready ? 0 : 1);
            end else if (dispatch_en && dispatch_ready) begin
                count <= count + 1;
            end

            // Dispatch: insert new instruction
            if (dispatch_en && dispatch_ready) begin
                valid[free_slot]     <= 1'b1;
                alu_op[free_slot]    <= dispatch_alu_op;
                alu_src[free_slot]   <= dispatch_alu_src;
                imm[free_slot]       <= dispatch_imm;
                phys_rs1[free_slot]  <= dispatch_phys_rs1;
                phys_rs2[free_slot]  <= dispatch_phys_rs2;
                phys_rd[free_slot]   <= dispatch_phys_rd;
                rob_idx[free_slot]   <= dispatch_rob_idx;

                // Check if sources are already ready (or being woken up this cycle)
                src1_rdy[free_slot]  <= dispatch_src1_ready ||
                                        (wakeup_en && dispatch_phys_rs1 == wakeup_phys_rd && wakeup_phys_rd != 0);
                src2_rdy[free_slot]  <= dispatch_src2_ready ||
                                        (wakeup_en && dispatch_phys_rs2 == wakeup_phys_rd && wakeup_phys_rd != 0);
            end
        end
    end

endmodule
