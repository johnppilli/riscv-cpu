// pipeline_regs.sv - Pipeline registers between stages
// IF/ID, ID/EX, EX/MEM, MEM/WB

// ============================================================
// IF/ID Pipeline Register
// Holds: instruction, PC
// ============================================================
module pipe_if_id (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,          // Clear on branch misprediction
    input  logic        stall,          // Hold values (for hazards)

    // Inputs from IF stage
    input  logic [31:0] if_pc,
    input  logic [31:0] if_instruction,

    // Outputs to ID stage
    output logic [31:0] id_pc,
    output logic [31:0] id_instruction
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            id_pc          <= 32'd0;
            id_instruction <= 32'h00000013;  // NOP
        end else if (!stall) begin
            id_pc          <= if_pc;
            id_instruction <= if_instruction;
        end
        // If stall, keep current values
    end

endmodule


// ============================================================
// ID/EX Pipeline Register
// Holds: control signals, register data, immediate, addresses
// ============================================================
module pipe_id_ex (
    input  logic        clk,
    input  logic        rst,
    input  logic        flush,

    // Inputs from ID stage
    input  logic [31:0] id_pc,
    input  logic [31:0] id_read_data1,
    input  logic [31:0] id_read_data2,
    input  logic [31:0] id_imm,
    input  logic [4:0]  id_rs1,
    input  logic [4:0]  id_rs2,
    input  logic [4:0]  id_rd,

    // Control signals from ID stage
    input  logic [3:0]  id_alu_op,
    input  logic        id_alu_src,
    input  logic        id_reg_write,
    input  logic        id_mem_read,
    input  logic        id_mem_write,
    input  logic        id_mem_to_reg,
    input  logic        id_branch,
    input  logic        id_jump,

    // Outputs to EX stage
    output logic [31:0] ex_pc,
    output logic [31:0] ex_read_data1,
    output logic [31:0] ex_read_data2,
    output logic [31:0] ex_imm,
    output logic [4:0]  ex_rs1,
    output logic [4:0]  ex_rs2,
    output logic [4:0]  ex_rd,

    // Control signals to EX stage
    output logic [3:0]  ex_alu_op,
    output logic        ex_alu_src,
    output logic        ex_reg_write,
    output logic        ex_mem_read,
    output logic        ex_mem_write,
    output logic        ex_mem_to_reg,
    output logic        ex_branch,
    output logic        ex_jump
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst || flush) begin
            ex_pc          <= 32'd0;
            ex_read_data1  <= 32'd0;
            ex_read_data2  <= 32'd0;
            ex_imm         <= 32'd0;
            ex_rs1         <= 5'd0;
            ex_rs2         <= 5'd0;
            ex_rd          <= 5'd0;
            ex_alu_op      <= 4'd0;
            ex_alu_src     <= 1'b0;
            ex_reg_write   <= 1'b0;
            ex_mem_read    <= 1'b0;
            ex_mem_write   <= 1'b0;
            ex_mem_to_reg  <= 1'b0;
            ex_branch      <= 1'b0;
            ex_jump        <= 1'b0;
        end else begin
            ex_pc          <= id_pc;
            ex_read_data1  <= id_read_data1;
            ex_read_data2  <= id_read_data2;
            ex_imm         <= id_imm;
            ex_rs1         <= id_rs1;
            ex_rs2         <= id_rs2;
            ex_rd          <= id_rd;
            ex_alu_op      <= id_alu_op;
            ex_alu_src     <= id_alu_src;
            ex_reg_write   <= id_reg_write;
            ex_mem_read    <= id_mem_read;
            ex_mem_write   <= id_mem_write;
            ex_mem_to_reg  <= id_mem_to_reg;
            ex_branch      <= id_branch;
            ex_jump        <= id_jump;
        end
    end

endmodule


// ============================================================
// EX/MEM Pipeline Register
// Holds: ALU result, data for store, control signals
// ============================================================
module pipe_ex_mem (
    input  logic        clk,
    input  logic        rst,

    // Inputs from EX stage
    input  logic [31:0] ex_pc_plus4,
    input  logic [31:0] ex_alu_result,
    input  logic [31:0] ex_read_data2,
    input  logic [4:0]  ex_rd,
    input  logic        ex_zero,

    // Control signals from EX stage
    input  logic        ex_reg_write,
    input  logic        ex_mem_read,
    input  logic        ex_mem_write,
    input  logic        ex_mem_to_reg,
    input  logic        ex_branch,
    input  logic        ex_jump,

    // Outputs to MEM stage
    output logic [31:0] mem_pc_plus4,
    output logic [31:0] mem_alu_result,
    output logic [31:0] mem_read_data2,
    output logic [4:0]  mem_rd,
    output logic        mem_zero,

    // Control signals to MEM stage
    output logic        mem_reg_write,
    output logic        mem_mem_read,
    output logic        mem_mem_write,
    output logic        mem_mem_to_reg,
    output logic        mem_branch,
    output logic        mem_jump
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            mem_pc_plus4    <= 32'd0;
            mem_alu_result  <= 32'd0;
            mem_read_data2  <= 32'd0;
            mem_rd          <= 5'd0;
            mem_zero        <= 1'b0;
            mem_reg_write   <= 1'b0;
            mem_mem_read    <= 1'b0;
            mem_mem_write   <= 1'b0;
            mem_mem_to_reg  <= 1'b0;
            mem_branch      <= 1'b0;
            mem_jump        <= 1'b0;
        end else begin
            mem_pc_plus4    <= ex_pc_plus4;
            mem_alu_result  <= ex_alu_result;
            mem_read_data2  <= ex_read_data2;
            mem_rd          <= ex_rd;
            mem_zero        <= ex_zero;
            mem_reg_write   <= ex_reg_write;
            mem_mem_read    <= ex_mem_read;
            mem_mem_write   <= ex_mem_write;
            mem_mem_to_reg  <= ex_mem_to_reg;
            mem_branch      <= ex_branch;
            mem_jump        <= ex_jump;
        end
    end

endmodule


// ============================================================
// MEM/WB Pipeline Register
// Holds: data to write back, control signals
// ============================================================
module pipe_mem_wb (
    input  logic        clk,
    input  logic        rst,

    // Inputs from MEM stage
    input  logic [31:0] mem_pc_plus4,
    input  logic [31:0] mem_alu_result,
    input  logic [31:0] mem_read_data,
    input  logic [4:0]  mem_rd,

    // Control signals from MEM stage
    input  logic        mem_reg_write,
    input  logic        mem_mem_to_reg,
    input  logic        mem_jump,

    // Outputs to WB stage
    output logic [31:0] wb_pc_plus4,
    output logic [31:0] wb_alu_result,
    output logic [31:0] wb_read_data,
    output logic [4:0]  wb_rd,

    // Control signals to WB stage
    output logic        wb_reg_write,
    output logic        wb_mem_to_reg,
    output logic        wb_jump
);

    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            wb_pc_plus4    <= 32'd0;
            wb_alu_result  <= 32'd0;
            wb_read_data   <= 32'd0;
            wb_rd          <= 5'd0;
            wb_reg_write   <= 1'b0;
            wb_mem_to_reg  <= 1'b0;
            wb_jump        <= 1'b0;
        end else begin
            wb_pc_plus4    <= mem_pc_plus4;
            wb_alu_result  <= mem_alu_result;
            wb_read_data   <= mem_read_data;
            wb_rd          <= mem_rd;
            wb_reg_write   <= mem_reg_write;
            wb_mem_to_reg  <= mem_mem_to_reg;
            wb_jump        <= mem_jump;
        end
    end

endmodule
