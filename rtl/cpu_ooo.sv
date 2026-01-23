// cpu_ooo.sv - Out-of-Order RISC-V CPU
// Implements: Fetch → Decode/Rename/Dispatch → Issue → Execute → Complete → Commit
// Features: Register renaming, ROB, Issue Queue, in-order commit

module cpu_ooo (
    input  logic clk,
    input  logic rst
);

    // Parameters
    localparam PHYS_REG_BITS = 6;
    localparam NUM_PHYS_REGS = 64;
    localparam ROB_IDX_BITS  = 4;
    localparam ROB_SIZE      = 16;

    // ========================================================================
    // Ready Table - tracks which physical registers have valid values
    // ========================================================================
    logic [NUM_PHYS_REGS-1:0] ready_table;

    // ========================================================================
    // FETCH STAGE
    // ========================================================================
    logic [31:0] pc;
    logic [31:0] pc_next;
    logic [31:0] fetch_instruction;
    logic        fetch_valid;
    logic        frontend_stall;

    // Simple instruction memory (reuse existing module)
    instruction_memory imem (
        .addr        (pc),
        .instruction (fetch_instruction)
    );

    // PC logic
    assign pc_next = frontend_stall ? pc : pc + 4;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            pc <= 32'd0;
            fetch_valid <= 1'b0;
        end else begin
            pc <= pc_next;
            fetch_valid <= !frontend_stall && !rst;
        end
    end

    // ========================================================================
    // FETCH/DECODE Pipeline Register
    // ========================================================================
    logic [31:0] fd_pc;
    logic [31:0] fd_instruction;
    logic        fd_valid;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            fd_pc          <= 32'd0;
            fd_instruction <= 32'h00000013; // NOP
            fd_valid       <= 1'b0;
        end else if (!frontend_stall) begin
            fd_pc          <= pc;
            fd_instruction <= fetch_instruction;
            fd_valid       <= 1'b1;
        end
    end

    // ========================================================================
    // DECODE STAGE
    // ========================================================================
    logic [3:0]  dec_alu_op;
    logic        dec_alu_src;
    logic        dec_reg_write;
    logic [31:0] dec_imm;
    logic [4:0]  dec_rs1, dec_rs2, dec_rd;
    logic        dec_is_nop;

    // Extract fields from instruction
    assign dec_rs1 = fd_instruction[19:15];
    assign dec_rs2 = fd_instruction[24:20];
    assign dec_rd  = fd_instruction[11:7];

    // Decode logic (R-type and I-type ALU only for now)
    always_comb begin
        dec_alu_op    = 4'd0;   // ADD
        dec_alu_src   = 1'b0;   // Register
        dec_reg_write = 1'b0;
        dec_imm       = 32'd0;
        dec_is_nop    = 1'b0;

        case (fd_instruction[6:0])
            7'b0110011: begin // R-type
                dec_reg_write = 1'b1;
                dec_alu_src   = 1'b0;
                case (fd_instruction[14:12])
                    3'b000: dec_alu_op = fd_instruction[30] ? 4'd1 : 4'd0; // SUB/ADD
                    3'b001: dec_alu_op = 4'd7;  // SLL
                    3'b010: dec_alu_op = 4'd5;  // SLT
                    3'b011: dec_alu_op = 4'd6;  // SLTU
                    3'b100: dec_alu_op = 4'd4;  // XOR
                    3'b101: dec_alu_op = fd_instruction[30] ? 4'd9 : 4'd8; // SRA/SRL
                    3'b110: dec_alu_op = 4'd3;  // OR
                    3'b111: dec_alu_op = 4'd2;  // AND
                endcase
            end

            7'b0010011: begin // I-type ALU
                dec_reg_write = 1'b1;
                dec_alu_src   = 1'b1;
                dec_imm       = {{20{fd_instruction[31]}}, fd_instruction[31:20]};
                case (fd_instruction[14:12])
                    3'b000: dec_alu_op = 4'd0;  // ADDI
                    3'b001: dec_alu_op = 4'd7;  // SLLI
                    3'b010: dec_alu_op = 4'd5;  // SLTI
                    3'b011: dec_alu_op = 4'd6;  // SLTIU
                    3'b100: dec_alu_op = 4'd4;  // XORI
                    3'b101: dec_alu_op = fd_instruction[30] ? 4'd9 : 4'd8; // SRAI/SRLI
                    3'b110: dec_alu_op = 4'd3;  // ORI
                    3'b111: dec_alu_op = 4'd2;  // ANDI
                endcase
            end

            default: begin
                dec_is_nop = 1'b1; // Treat unknown as NOP
            end
        endcase

        // NOP instruction (ADDI x0, x0, 0)
        if (fd_instruction == 32'h00000013)
            dec_is_nop = 1'b1;
    end

    // ========================================================================
    // RENAME STAGE (same cycle as decode)
    // ========================================================================
    logic [PHYS_REG_BITS-1:0] rename_phys_rs1;
    logic [PHYS_REG_BITS-1:0] rename_phys_rs2;
    logic [PHYS_REG_BITS-1:0] rename_phys_rd;
    logic [PHYS_REG_BITS-1:0] rename_old_phys;
    logic                     rename_en;
    logic                     alloc_valid;

    // Should we rename this instruction?
    assign rename_en = fd_valid && dec_reg_write && !dec_is_nop &&
                       dec_rd != 5'd0 && alloc_valid && rob_alloc_ready && iq_dispatch_ready;

    // Free list allocation
    logic [PHYS_REG_BITS-1:0] fl_alloc_reg;

    free_list #(
        .NUM_PHYS_REGS(NUM_PHYS_REGS),
        .PHYS_REG_BITS(PHYS_REG_BITS)
    ) fl (
        .clk        (clk),
        .rst        (rst),
        .alloc_en   (rename_en),
        .alloc_reg  (fl_alloc_reg),
        .alloc_valid(alloc_valid),
        .free_en    (commit_free_en),
        .free_reg   (commit_free_reg)
    );

    assign rename_phys_rd = fl_alloc_reg;

    // RAT lookup and update
    rat #(.PHYS_REG_BITS(PHYS_REG_BITS)) rat_inst (
        .clk            (clk),
        .rst            (rst),
        .flush          (1'b0),  // No branch misprediction handling yet
        .rs1            (dec_rs1),
        .rs2            (dec_rs2),
        .phys_rs1       (rename_phys_rs1),
        .phys_rs2       (rename_phys_rs2),
        .rename_en      (rename_en),
        .rename_rd      (dec_rd),
        .rename_phys_rd (rename_phys_rd),
        .rename_old_phys(rename_old_phys),
        .commit_en      (commit_rat_en),
        .commit_rd      (commit_rat_rd),
        .commit_phys_rd (commit_rat_phys)
    );

    // Source readiness from ready table
    logic src1_ready, src2_ready;
    assign src1_ready = (dec_rs1 == 5'd0) || ready_table[rename_phys_rs1];
    assign src2_ready = (dec_rs2 == 5'd0) || ready_table[rename_phys_rs2];

    // Frontend stalls if resources unavailable
    assign frontend_stall = fd_valid && dec_reg_write && !dec_is_nop && dec_rd != 5'd0 &&
                           (!alloc_valid || !rob_alloc_ready || !iq_dispatch_ready);

    // ========================================================================
    // DISPATCH - Insert into ROB and Issue Queue
    // ========================================================================
    logic        rob_alloc_ready;
    logic [ROB_IDX_BITS-1:0] rob_alloc_idx;

    // ROB allocation
    logic        rob_complete_en;
    logic [ROB_IDX_BITS-1:0] rob_complete_idx;
    logic [31:0] rob_complete_result;
    logic        commit_valid;
    logic [4:0]  commit_rd_out;
    logic [PHYS_REG_BITS-1:0] commit_phys_rd_out;
    logic [PHYS_REG_BITS-1:0] commit_old_phys_out;
    logic [31:0] commit_result_out;
    logic        commit_ack;

    rob #(
        .ROB_SIZE(ROB_SIZE),
        .ROB_IDX_BITS(ROB_IDX_BITS),
        .PHYS_REG_BITS(PHYS_REG_BITS)
    ) rob_inst (
        .clk            (clk),
        .rst            (rst),
        .flush          (1'b0),
        .alloc_en       (rename_en),
        .alloc_rd       (dec_rd),
        .alloc_phys_rd  (rename_phys_rd),
        .alloc_old_phys (rename_old_phys),
        .alloc_pc       (fd_pc),
        .alloc_idx      (rob_alloc_idx),
        .alloc_ready    (rob_alloc_ready),
        .complete_en    (rob_complete_en),
        .complete_idx   (rob_complete_idx),
        .complete_result(rob_complete_result),
        .commit_valid   (commit_valid),
        .commit_rd      (commit_rd_out),
        .commit_phys_rd (commit_phys_rd_out),
        .commit_old_phys(commit_old_phys_out),
        .commit_result  (commit_result_out),
        .commit_ack     (commit_ack)
    );

    // Issue Queue dispatch
    logic iq_dispatch_ready;

    // Issue queue outputs
    logic        iq_issue_valid;
    logic [3:0]  iq_issue_alu_op;
    logic        iq_issue_alu_src;
    logic [31:0] iq_issue_imm;
    logic [PHYS_REG_BITS-1:0] iq_issue_phys_rs1;
    logic [PHYS_REG_BITS-1:0] iq_issue_phys_rs2;
    logic [PHYS_REG_BITS-1:0] iq_issue_phys_rd;
    logic [ROB_IDX_BITS-1:0]  iq_issue_rob_idx;
    logic        iq_issue_ack;

    // Wakeup signal (from execute/complete stage)
    logic        wakeup_en;
    logic [PHYS_REG_BITS-1:0] wakeup_phys_rd;

    issue_queue #(
        .IQ_SIZE(8),
        .IQ_IDX_BITS(3),
        .PHYS_REG_BITS(PHYS_REG_BITS),
        .ROB_IDX_BITS(ROB_IDX_BITS)
    ) iq (
        .clk               (clk),
        .rst               (rst),
        .flush             (1'b0),
        .dispatch_en       (rename_en),
        .dispatch_alu_op   (dec_alu_op),
        .dispatch_alu_src  (dec_alu_src),
        .dispatch_imm      (dec_imm),
        .dispatch_phys_rs1 (rename_phys_rs1),
        .dispatch_phys_rs2 (rename_phys_rs2),
        .dispatch_phys_rd  (rename_phys_rd),
        .dispatch_src1_ready(src1_ready),
        .dispatch_src2_ready(src2_ready),
        .dispatch_rob_idx  (rob_alloc_idx),
        .dispatch_ready    (iq_dispatch_ready),
        .wakeup_en         (wakeup_en),
        .wakeup_phys_rd    (wakeup_phys_rd),
        .issue_valid       (iq_issue_valid),
        .issue_alu_op      (iq_issue_alu_op),
        .issue_alu_src     (iq_issue_alu_src),
        .issue_imm         (iq_issue_imm),
        .issue_phys_rs1    (iq_issue_phys_rs1),
        .issue_phys_rs2    (iq_issue_phys_rs2),
        .issue_phys_rd     (iq_issue_phys_rd),
        .issue_rob_idx     (iq_issue_rob_idx),
        .issue_ack         (iq_issue_ack)
    );

    // ========================================================================
    // ISSUE STAGE - Read physical register file
    // ========================================================================
    logic [31:0] issue_rs1_data, issue_rs2_data;

    // Issue when IQ has a ready instruction
    assign iq_issue_ack = iq_issue_valid; // Always accept (single-cycle execute)

    // Physical register file
    logic        prf_write_en;
    logic [PHYS_REG_BITS-1:0] prf_write_addr;
    logic [31:0] prf_write_data;

    physical_regfile #(
        .NUM_PHYS_REGS(NUM_PHYS_REGS),
        .PHYS_REG_BITS(PHYS_REG_BITS)
    ) prf (
        .clk        (clk),
        .rst        (rst),
        .read_addr1 (iq_issue_phys_rs1),
        .read_data1 (issue_rs1_data),
        .read_addr2 (iq_issue_phys_rs2),
        .read_data2 (issue_rs2_data),
        .write_en   (prf_write_en),
        .write_addr (prf_write_addr),
        .write_data (prf_write_data)
    );

    // ========================================================================
    // EXECUTE STAGE
    // ========================================================================
    logic [31:0] alu_operand_b;
    logic [31:0] alu_result;

    assign alu_operand_b = iq_issue_alu_src ? iq_issue_imm : issue_rs2_data;

    // ALU instance
    alu alu_inst (
        .a       (issue_rs1_data),
        .b       (alu_operand_b),
        .alu_op  (iq_issue_alu_op),
        .result  (alu_result),
        .zero    ()  // Not used in OoO for now
    );

    // ========================================================================
    // COMPLETE STAGE - Write result, wake up dependents
    // Pipeline register between execute and complete
    // ========================================================================
    logic        ex_valid_r;
    logic [PHYS_REG_BITS-1:0] ex_phys_rd_r;
    logic [ROB_IDX_BITS-1:0]  ex_rob_idx_r;
    logic [31:0] ex_result_r;

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            ex_valid_r   <= 1'b0;
            ex_phys_rd_r <= 0;
            ex_rob_idx_r <= 0;
            ex_result_r  <= 32'd0;
        end else begin
            ex_valid_r   <= iq_issue_valid;
            ex_phys_rd_r <= iq_issue_phys_rd;
            ex_rob_idx_r <= iq_issue_rob_idx;
            ex_result_r  <= alu_result;
        end
    end

    // Write to physical regfile
    assign prf_write_en   = ex_valid_r && (ex_phys_rd_r != 0);
    assign prf_write_addr = ex_phys_rd_r;
    assign prf_write_data = ex_result_r;

    // Complete: mark ROB entry done
    assign rob_complete_en     = ex_valid_r;
    assign rob_complete_idx    = ex_rob_idx_r;
    assign rob_complete_result = ex_result_r;

    // Wake-up: broadcast to issue queue
    assign wakeup_en      = ex_valid_r && (ex_phys_rd_r != 0);
    assign wakeup_phys_rd = ex_phys_rd_r;

    // ========================================================================
    // READY TABLE - Track which physical registers have valid values
    // ========================================================================
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            // Initially, registers 0-31 are ready (architectural state)
            ready_table <= {32'b0, 32'hFFFFFFFF};  // [31:0] ready, [63:32] not ready
        end else begin
            // Clear ready bit when a new physical reg is allocated (rename)
            if (rename_en && rename_phys_rd != 0) begin
                ready_table[rename_phys_rd] <= 1'b0;
            end

            // Set ready bit when result is written (complete)
            if (ex_valid_r && ex_phys_rd_r != 0) begin
                ready_table[ex_phys_rd_r] <= 1'b1;
            end
        end
    end

    // ========================================================================
    // COMMIT STAGE - Retire from ROB head in program order
    // ========================================================================
    logic        commit_free_en;
    logic [PHYS_REG_BITS-1:0] commit_free_reg;
    logic        commit_rat_en;
    logic [4:0]  commit_rat_rd;
    logic [PHYS_REG_BITS-1:0] commit_rat_phys;

    // Auto-commit when head is ready
    assign commit_ack = commit_valid;

    // Free the old physical register
    assign commit_free_en  = commit_valid && (commit_old_phys_out != 0) &&
                             (commit_rd_out != 5'd0);
    assign commit_free_reg = commit_old_phys_out;

    // Update committed RAT
    assign commit_rat_en   = commit_valid && (commit_rd_out != 5'd0);
    assign commit_rat_rd   = commit_rd_out;
    assign commit_rat_phys = commit_phys_rd_out;

endmodule
