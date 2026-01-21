// alu.sv - Arithmetic Logic Unit

module alu (
    input  logic [31:0] a,          // First operand
    input  logic [31:0] b,          // Second operand
    input  logic [3:0]  alu_op,     // Operation to perform
    output logic [31:0] result,     // Result
    output logic        zero        // 1 if result is zero (for branches)
);

    // ALU operation codes
    localparam ALU_ADD  = 4'b0000;
    localparam ALU_SUB  = 4'b0001;
    localparam ALU_AND  = 4'b0010;
    localparam ALU_OR   = 4'b0011;
    localparam ALU_XOR  = 4'b0100;
    localparam ALU_SLT  = 4'b0101;  // Set less than (signed)
    localparam ALU_SLTU = 4'b0110;  // Set less than (unsigned)
    localparam ALU_SLL  = 4'b0111;  // Shift left logical
    localparam ALU_SRL  = 4'b1000;  // Shift right logical
    localparam ALU_SRA  = 4'b1001;  // Shift right arithmetic

    always_comb begin
        case (alu_op)
            ALU_ADD:  result = a + b;
            ALU_SUB:  result = a - b;
            ALU_AND:  result = a & b;
            ALU_OR:   result = a | b;
            ALU_XOR:  result = a ^ b;
            ALU_SLT:  result = ($signed(a) < $signed(b)) ? 32'd1 : 32'd0;
            ALU_SLTU: result = (a < b) ? 32'd1 : 32'd0;
            ALU_SLL:  result = a << b[4:0];
            ALU_SRL:  result = a >> b[4:0];
            ALU_SRA:  result = $signed(a) >>> b[4:0];
            default:  result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule
