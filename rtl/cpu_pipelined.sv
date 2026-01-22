// cpu_pipelined.sv - 5-stage pipelined RISC-V CPU with hazard handling
//
// Stages: IF (Fetch) -> ID (Decode) -> EX (Execute) -> MEM (Memory) -> WB (Writeback)
//
// This version includes:
//   - Forwarding Unit: Passes results from MEM/WB directly to EX when needed
//   - Hazard Detection: Stalls pipeline for load-use hazards

module cpu_pipelined (
    input  logic clk,
    input  logic rst
);

    // ============================================================
    // Wire declarations for each stage
    // ============================================================

    // IF stage signals
    logic [31:0] if_pc;
    logic [31:0] if_pc_next;
    logic [31:0] if_pc_plus4;
    logic [31:0] if_instruction;

    // ID stage signals (from IF/ID register)
    logic [31:0] id_pc;
    logic [31:0] id_instruction;
    logic [31:0] id_read_data1;
    logic [31:0] id_read_data2;
    logic [31:0] id_imm;
    logic [4:0]  id_rs1, id_rs2, id_rd;
    logic [3:0]  id_alu_op;
    logic        id_alu_src;
    logic        id_reg_write;
    logic        id_mem_read;
    logic        id_mem_write;
    logic        id_mem_to_reg;
    logic        id_branch;
    logic        id_jump;

    // EX stage signals (from ID/EX register)
    logic [31:0] ex_pc;
    logic [31:0] ex_pc_plus4;
    logic [31:0] ex_read_data1;
    logic [31:0] ex_read_data2;
    logic [31:0] ex_imm;
    logic [4:0]  ex_rs1, ex_rs2, ex_rd;
    logic [3:0]  ex_alu_op;
    logic        ex_alu_src;
    logic        ex_reg_write;
    logic        ex_mem_read;
    logic        ex_mem_write;
    logic        ex_mem_to_reg;
    logic        ex_branch;
    logic        ex_jump;
    logic [31:0] ex_alu_operand_a;    // After forwarding mux
    logic [31:0] ex_alu_operand_b;    // After forwarding mux
    logic [31:0] ex_alu_operand_b_fwd; // Forwarded rs2 value (before alu_src mux)
    logic [31:0] ex_alu_result;
    logic        ex_alu_zero;
    logic [31:0] ex_branch_target;

    // MEM stage signals (from EX/MEM register)
    logic [31:0] mem_pc_plus4;
    logic [31:0] mem_alu_result;
    logic [31:0] mem_read_data2;
    logic [4:0]  mem_rd;
    logic        mem_zero;
    logic        mem_reg_write;
    logic        mem_mem_read;
    logic        mem_mem_write;
    logic        mem_mem_to_reg;
    logic        mem_branch;
    logic        mem_jump;
    logic [31:0] mem_data_read;
    logic        mem_take_branch;
    logic [31:0] mem_write_back_data;  // Data to forward from MEM stage

    // WB stage signals (from MEM/WB register)
    logic [31:0] wb_pc_plus4;
    logic [31:0] wb_alu_result;
    logic [31:0] wb_read_data;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic        wb_mem_to_reg;
    logic        wb_jump;
    logic [31:0] wb_write_data;

    // Hazard control signals
    logic        stall_if;
    logic        stall_id;
    logic        flush_ex;
    logic        flush_if_id;  // For branch taken

    // Forwarding control signals
    logic [1:0]  forward_a;
    logic [1:0]  forward_b;


    // ============================================================
    // Hazard Detection Unit
    // ============================================================

    hazard_unit hazard_inst (
        .id_rs1      (id_rs1),
        .id_rs2      (id_rs2),
        .ex_rd       (ex_rd),
        .ex_mem_read (ex_mem_read),
        .stall_if    (stall_if),
        .stall_id    (stall_id),
        .flush_ex    (flush_ex)
    );


    // ============================================================
    // Forwarding Unit
    // ============================================================

    forwarding_unit fwd_inst (
        .ex_rs1        (ex_rs1),
        .ex_rs2        (ex_rs2),
        .mem_rd        (mem_rd),
        .mem_reg_write (mem_reg_write),
        .wb_rd         (wb_rd),
        .wb_reg_write  (wb_reg_write),
        .forward_a     (forward_a),
        .forward_b     (forward_b)
    );


    // ============================================================
    // IF Stage: Instruction Fetch
    // ============================================================

    assign if_pc_plus4 = if_pc + 32'd4;

    // PC logic - stall or update based on hazards and branches
    assign if_pc_next = (mem_take_branch) ? mem_alu_result : if_pc_plus4;

    // Program Counter (with stall support)
    program_counter pc_inst (
        .clk     (clk),
        .rst     (rst),
        .stall   (stall_if),       // Hold PC when stalling
        .pc_next (if_pc_next),
        .pc      (if_pc)
    );

    // Instruction Memory
    instruction_memory imem (
        .addr        (if_pc),
        .instruction (if_instruction)
    );


    // ============================================================
    // IF/ID Pipeline Register
    // ============================================================

    // Flush IF/ID on branch taken
    assign flush_if_id = mem_take_branch;

    pipe_if_id if_id_reg (
        .clk            (clk),
        .rst            (rst),
        .flush          (flush_if_id),
        .stall          (stall_id),      // Stall on load-use hazard
        .if_pc          (if_pc),
        .if_instruction (if_instruction),
        .id_pc          (id_pc),
        .id_instruction (id_instruction)
    );


    // ============================================================
    // ID Stage: Instruction Decode
    // ============================================================

    // Decoder
    decoder decoder_inst (
        .instruction (id_instruction),
        .rs1         (id_rs1),
        .rs2         (id_rs2),
        .rd          (id_rd),
        .imm         (id_imm),
        .alu_op      (id_alu_op),
        .alu_src     (id_alu_src),
        .reg_write   (id_reg_write),
        .mem_read    (id_mem_read),
        .mem_write   (id_mem_write),
        .mem_to_reg  (id_mem_to_reg),
        .branch      (id_branch),
        .jump        (id_jump)
    );

    // Register File
    // Note: Write happens from WB stage
    register_file regfile (
        .clk        (clk),
        .we         (wb_reg_write),
        .rs1        (id_rs1),
        .rs2        (id_rs2),
        .rd         (wb_rd),
        .write_data (wb_write_data),
        .read_data1 (id_read_data1),
        .read_data2 (id_read_data2)
    );


    // ============================================================
    // ID/EX Pipeline Register
    // ============================================================

    // Flush ID/EX on branch taken OR when we detect a load-use hazard
    pipe_id_ex id_ex_reg (
        .clk            (clk),
        .rst            (rst),
        .flush          (mem_take_branch || flush_ex),  // Flush creates a bubble
        .id_pc          (id_pc),
        .id_read_data1  (id_read_data1),
        .id_read_data2  (id_read_data2),
        .id_imm         (id_imm),
        .id_rs1         (id_rs1),
        .id_rs2         (id_rs2),
        .id_rd          (id_rd),
        .id_alu_op      (id_alu_op),
        .id_alu_src     (id_alu_src),
        .id_reg_write   (id_reg_write),
        .id_mem_read    (id_mem_read),
        .id_mem_write   (id_mem_write),
        .id_mem_to_reg  (id_mem_to_reg),
        .id_branch      (id_branch),
        .id_jump        (id_jump),
        .ex_pc          (ex_pc),
        .ex_read_data1  (ex_read_data1),
        .ex_read_data2  (ex_read_data2),
        .ex_imm         (ex_imm),
        .ex_rs1         (ex_rs1),
        .ex_rs2         (ex_rs2),
        .ex_rd          (ex_rd),
        .ex_alu_op      (ex_alu_op),
        .ex_alu_src     (ex_alu_src),
        .ex_reg_write   (ex_reg_write),
        .ex_mem_read    (ex_mem_read),
        .ex_mem_write   (ex_mem_write),
        .ex_mem_to_reg  (ex_mem_to_reg),
        .ex_branch      (ex_branch),
        .ex_jump        (ex_jump)
    );


    // ============================================================
    // EX Stage: Execute (with forwarding muxes)
    // ============================================================

    assign ex_pc_plus4 = ex_pc + 32'd4;
    assign ex_branch_target = ex_pc + ex_imm;

    // What MEM stage will write back (for forwarding)
    // This is the ALU result (or branch target for branches)
    assign mem_write_back_data = mem_alu_result;

    // Forwarding mux for operand A (rs1)
    // forward_a: 00 = register file, 01 = WB, 10 = MEM
    always_comb begin
        case (forward_a)
            2'b00:   ex_alu_operand_a = ex_read_data1;     // Normal: from register file
            2'b01:   ex_alu_operand_a = wb_write_data;     // Forward from WB stage
            2'b10:   ex_alu_operand_a = mem_write_back_data; // Forward from MEM stage
            default: ex_alu_operand_a = ex_read_data1;
        endcase
    end

    // Forwarding mux for operand B (rs2)
    // First select forwarded value, then decide if we use immediate instead
    always_comb begin
        case (forward_b)
            2'b00:   ex_alu_operand_b_fwd = ex_read_data2;     // Normal: from register file
            2'b01:   ex_alu_operand_b_fwd = wb_write_data;     // Forward from WB stage
            2'b10:   ex_alu_operand_b_fwd = mem_write_back_data; // Forward from MEM stage
            default: ex_alu_operand_b_fwd = ex_read_data2;
        endcase
    end

    // Final operand B: use immediate for I-type, otherwise use (possibly forwarded) rs2
    assign ex_alu_operand_b = ex_alu_src ? ex_imm : ex_alu_operand_b_fwd;

    // ALU
    alu alu_inst (
        .a      (ex_alu_operand_a),
        .b      (ex_alu_operand_b),
        .alu_op (ex_alu_op),
        .result (ex_alu_result),
        .zero   (ex_alu_zero)
    );


    // ============================================================
    // EX/MEM Pipeline Register
    // ============================================================

    pipe_ex_mem ex_mem_reg (
        .clk            (clk),
        .rst            (rst),
        .ex_pc_plus4    (ex_pc_plus4),
        .ex_alu_result  (ex_branch ? ex_branch_target : ex_alu_result),
        .ex_read_data2  (ex_alu_operand_b_fwd),  // Use forwarded value for stores
        .ex_rd          (ex_rd),
        .ex_zero        (ex_alu_zero),
        .ex_reg_write   (ex_reg_write),
        .ex_mem_read    (ex_mem_read),
        .ex_mem_write   (ex_mem_write),
        .ex_mem_to_reg  (ex_mem_to_reg),
        .ex_branch      (ex_branch),
        .ex_jump        (ex_jump),
        .mem_pc_plus4   (mem_pc_plus4),
        .mem_alu_result (mem_alu_result),
        .mem_read_data2 (mem_read_data2),
        .mem_rd         (mem_rd),
        .mem_zero       (mem_zero),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_read   (mem_mem_read),
        .mem_mem_write  (mem_mem_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_branch     (mem_branch),
        .mem_jump       (mem_jump)
    );


    // ============================================================
    // MEM Stage: Memory Access
    // ============================================================

    // Branch decision
    assign mem_take_branch = (mem_branch && mem_zero) || mem_jump;

    // Data Memory
    data_memory dmem (
        .clk        (clk),
        .mem_read   (mem_mem_read),
        .mem_write  (mem_mem_write),
        .addr       (mem_alu_result),
        .write_data (mem_read_data2),
        .read_data  (mem_data_read)
    );


    // ============================================================
    // MEM/WB Pipeline Register
    // ============================================================

    pipe_mem_wb mem_wb_reg (
        .clk            (clk),
        .rst            (rst),
        .mem_pc_plus4   (mem_pc_plus4),
        .mem_alu_result (mem_alu_result),
        .mem_read_data  (mem_data_read),
        .mem_rd         (mem_rd),
        .mem_reg_write  (mem_reg_write),
        .mem_mem_to_reg (mem_mem_to_reg),
        .mem_jump       (mem_jump),
        .wb_pc_plus4    (wb_pc_plus4),
        .wb_alu_result  (wb_alu_result),
        .wb_read_data   (wb_read_data),
        .wb_rd          (wb_rd),
        .wb_reg_write   (wb_reg_write),
        .wb_mem_to_reg  (wb_mem_to_reg),
        .wb_jump        (wb_jump)
    );


    // ============================================================
    // WB Stage: Write Back
    // ============================================================

    // Select what to write back to register file
    assign wb_write_data = wb_jump ? wb_pc_plus4 :
                           (wb_mem_to_reg ? wb_read_data : wb_alu_result);

endmodule
