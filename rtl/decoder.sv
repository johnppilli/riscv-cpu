// decoder.sv - Parses instruction bits and generates control signals

module decoder (
    input  logic [31:0] instruction,

    // Register addresses
    output logic [4:0]  rs1,
    output logic [4:0]  rs2,
    output logic [4:0]  rd,

    // Immediate value (sign-extended)
    output logic [31:0] imm,

    // Control signals
    output logic [3:0]  alu_op,
    output logic        alu_src,      // 0 = rs2, 1 = immediate
    output logic        reg_write,    // Write to register file
    output logic        mem_read,     // Read from data memory
    output logic        mem_write,    // Write to data memory
    output logic        mem_to_reg,   // 0 = ALU result, 1 = memory data
    output logic        branch,       // Branch instruction
    output logic [2:0]  branch_type,  // Branch condition (funct3)
    output logic        jump          // Jump instruction (JAL/JALR)
);

    // Extract fields from instruction
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;

    assign opcode = instruction[6:0];
    assign rd     = instruction[11:7];
    assign funct3 = instruction[14:12];
    assign rs1    = instruction[19:15];
    assign rs2    = instruction[24:20];
    assign funct7 = instruction[31:25];

    // Opcode definitions
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_OPIMM  = 7'b0010011;  // I-type ALU (addi, etc.)
    localparam OP_OP     = 7'b0110011;  // R-type ALU (add, sub, etc.)

    // ALU operation codes (match alu.sv)
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;
    localparam ALU_SLTU = 4'b0110;
    localparam ALU_SLL  = 4'b0111;
    localparam ALU_SRL  = 4'b1000;
    localparam ALU_SRA  = 4'b1001;

    // Immediate generation
    always_comb begin
        case (opcode)
            OP_OPIMM, OP_LOAD, OP_JALR: begin
                // I-type immediate
                imm = {{20{instruction[31]}}, instruction[31:20]};
            end
            OP_STORE: begin
                // S-type immediate
                imm = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end
            OP_BRANCH: begin
                // B-type immediate
                imm = {{20{instruction[31]}}, instruction[7], instruction[30:25], instruction[11:8], 1'b0};
            end
            OP_LUI, OP_AUIPC: begin
                // U-type immediate
                imm = {instruction[31:12], 12'd0};
            end
            OP_JAL: begin
                // J-type immediate
                imm = {{12{instruction[31]}}, instruction[19:12], instruction[20], instruction[30:21], 1'b0};
            end
            default: begin
                imm = 32'd0;
            end
        endcase
    end

    // Control signal generation
    always_comb begin
        // Defaults
        alu_op      = ALU_ADD;
        alu_src     = 1'b0;
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        mem_to_reg  = 1'b0;
        branch      = 1'b0;
        branch_type = 3'b000;
        jump        = 1'b0;

        case (opcode)
            OP_OP: begin  // R-type (add, sub, and, or, etc.)
                reg_write = 1'b1;
                alu_src   = 1'b0;  // Use rs2
                case (funct3)
                    3'b000: alu_op = (funct7[5]) ? ALU_SUB : ALU_ADD;
                    3'b001: alu_op = ALU_SLL;
                    3'b010: alu_op = ALU_SLT;
                    3'b011: alu_op = ALU_SLTU;
                    3'b100: alu_op = ALU_XOR;
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;
                    3'b110: alu_op = ALU_OR;
                    3'b111: alu_op = ALU_AND;
                endcase
            end

            OP_OPIMM: begin  // I-type ALU (addi, andi, etc.)
                reg_write = 1'b1;
                alu_src   = 1'b1;  // Use immediate
                case (funct3)
                    3'b000: alu_op = ALU_ADD;  // addi
                    3'b001: alu_op = ALU_SLL;  // slli
                    3'b010: alu_op = ALU_SLT;  // slti
                    3'b011: alu_op = ALU_SLTU; // sltiu
                    3'b100: alu_op = ALU_XOR;  // xori
                    3'b101: alu_op = (funct7[5]) ? ALU_SRA : ALU_SRL;  // srai/srli
                    3'b110: alu_op = ALU_OR;   // ori
                    3'b111: alu_op = ALU_AND;  // andi
                endcase
            end

            OP_LOAD: begin  // lw, lb, lh, etc.
                reg_write  = 1'b1;
                alu_src    = 1'b1;  // Use immediate for address calc
                alu_op     = ALU_ADD;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
            end

            OP_STORE: begin  // sw, sb, sh, etc.
                alu_src   = 1'b1;  // Use immediate for address calc
                alu_op    = ALU_ADD;
                mem_write = 1'b1;
            end

            OP_BRANCH: begin  // beq, bne, blt, etc.
                branch      = 1'b1;
                branch_type = funct3;  // 000=BEQ, 001=BNE, 100=BLT, 101=BGE, 110=BLTU, 111=BGEU
                alu_op      = ALU_SUB; // For comparison
            end

            OP_JAL: begin
                reg_write = 1'b1;
                jump      = 1'b1;
            end

            OP_JALR: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
                jump      = 1'b1;
            end

            OP_LUI: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;  // Pass through (add 0)
            end

            OP_AUIPC: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = ALU_ADD;
            end
        endcase
    end

endmodule
