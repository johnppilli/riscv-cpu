// cpu_top.sv - Top module that connects all CPU components

module cpu_top (
    input  logic clk,
    input  logic rst
);

    // Internal wires
    logic [31:0] pc, pc_next, pc_plus4;
    logic [31:0] instruction;
    logic [31:0] read_data1, read_data2;
    logic [31:0] alu_result;
    logic [31:0] imm;
    logic [31:0] alu_operand_b;
    logic [31:0] write_back_data;
    logic [31:0] mem_read_data;
    logic        alu_zero;

    // Control signals
    logic [4:0]  rs1, rs2, rd;
    logic [3:0]  alu_op;
    logic        alu_src;
    logic        reg_write;
    logic        mem_read, mem_write;
    logic        mem_to_reg;
    logic        branch, jump;

    // Branch/jump logic
    logic        take_branch;
    logic [31:0] branch_target;

    // PC + 4 (next sequential instruction)
    assign pc_plus4 = pc + 32'd4;

    // Branch target calculation
    assign branch_target = pc + imm;

    // Branch decision (for BEQ - branch if equal, i.e., if subtraction result is zero)
    assign take_branch = (branch && alu_zero) || jump;

    // Next PC selection
    assign pc_next = take_branch ? branch_target : pc_plus4;

    // ALU operand B selection (register or immediate)
    assign alu_operand_b = alu_src ? imm : read_data2;

    // Write-back data selection (ALU result or memory data)
    // For JAL/JALR, write PC+4 to rd (return address)
    assign write_back_data = jump ? pc_plus4 : (mem_to_reg ? mem_read_data : alu_result);

    // =========== Module Instantiations ===========

    // Program Counter
    program_counter pc_inst (
        .clk     (clk),
        .rst     (rst),
        .pc_next (pc_next),
        .pc      (pc)
    );

    // Instruction Memory
    instruction_memory imem (
        .addr        (pc),
        .instruction (instruction)
    );

    // Decoder
    decoder decoder_inst (
        .instruction (instruction),
        .rs1         (rs1),
        .rs2         (rs2),
        .rd          (rd),
        .imm         (imm),
        .alu_op      (alu_op),
        .alu_src     (alu_src),
        .reg_write   (reg_write),
        .mem_read    (mem_read),
        .mem_write   (mem_write),
        .mem_to_reg  (mem_to_reg),
        .branch      (branch),
        .jump        (jump)
    );

    // Register File
    register_file regfile (
        .clk        (clk),
        .we         (reg_write),
        .rs1        (rs1),
        .rs2        (rs2),
        .rd         (rd),
        .write_data (write_back_data),
        .read_data1 (read_data1),
        .read_data2 (read_data2)
    );

    // ALU
    alu alu_inst (
        .a      (read_data1),
        .b      (alu_operand_b),
        .alu_op (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // Data Memory
    data_memory dmem (
        .clk        (clk),
        .mem_read   (mem_read),
        .mem_write  (mem_write),
        .addr       (alu_result),
        .write_data (read_data2),
        .read_data  (mem_read_data)
    );

endmodule
