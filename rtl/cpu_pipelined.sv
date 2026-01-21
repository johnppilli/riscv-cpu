// cpu_pipelined.sv - 5-stage pipelined RISC-V CPU
//
// Stages: IF (Fetch) -> ID (Decode) -> EX (Execute) -> MEM (Memory) -> WB (Writeback)
//
// Note: This is a basic pipeline without hazard detection/forwarding yet.
//       NOPs or careful instruction ordering needed to avoid hazards.

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
    logic [31:0] ex_alu_operand_b;
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

    // WB stage signals (from MEM/WB register)
    logic [31:0] wb_pc_plus4;
    logic [31:0] wb_alu_result;
    logic [31:0] wb_read_data;
    logic [4:0]  wb_rd;
    logic        wb_reg_write;
    logic        wb_mem_to_reg;
    logic        wb_jump;
    logic [31:0] wb_write_data;

    // Control signals
    logic        pipeline_flush;
    logic        pipeline_stall;

    // For now, no hazard detection - no stalls or flushes
    assign pipeline_stall = 1'b0;
    assign pipeline_flush = 1'b0;


    // ============================================================
    // IF Stage: Instruction Fetch
    // ============================================================

    assign if_pc_plus4 = if_pc + 32'd4;

    // For now, simple PC logic (no branch handling from MEM stage yet)
    // Branch resolution happens in MEM stage in this design
    assign if_pc_next = (mem_take_branch) ? mem_alu_result : if_pc_plus4;

    // Program Counter
    program_counter pc_inst (
        .clk     (clk),
        .rst     (rst),
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

    pipe_if_id if_id_reg (
        .clk            (clk),
        .rst            (rst),
        .flush          (mem_take_branch),  // Flush on branch taken
        .stall          (pipeline_stall),
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

    pipe_id_ex id_ex_reg (
        .clk            (clk),
        .rst            (rst),
        .flush          (mem_take_branch),  // Flush on branch taken
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
    // EX Stage: Execute
    // ============================================================

    assign ex_pc_plus4 = ex_pc + 32'd4;
    assign ex_branch_target = ex_pc + ex_imm;
    assign ex_alu_operand_b = ex_alu_src ? ex_imm : ex_read_data2;

    // ALU
    alu alu_inst (
        .a      (ex_read_data1),
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
        .ex_read_data2  (ex_read_data2),
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
