// register_file.sv - 32 registers (x0-x31)

module register_file (
    input  logic        clk,
    input  logic        we,           // Write enable
    input  logic [4:0]  rs1,          // Read register 1 address
    input  logic [4:0]  rs2,          // Read register 2 address
    input  logic [4:0]  rd,           // Write register address
    input  logic [31:0] write_data,   // Data to write
    output logic [31:0] read_data1,   // Data from rs1
    output logic [31:0] read_data2    // Data from rs2
);

    // 32 registers, each 32 bits
    logic [31:0] registers [0:31];

    // Initialize all registers to 0
    initial begin
        for (int i = 0; i < 32; i++) begin
            registers[i] = 32'd0;
        end
    end

    // Read ports (combinational) with internal forwarding
    // x0 is hardwired to zero in RISC-V
    // Internal forwarding: if we're writing and reading the same register
    // in the same cycle, return the write value (not the stale value)
    assign read_data1 = (rs1 == 5'd0) ? 32'd0 :
                        (we && rd == rs1 && rd != 5'd0) ? write_data :
                        registers[rs1];
    assign read_data2 = (rs2 == 5'd0) ? 32'd0 :
                        (we && rd == rs2 && rd != 5'd0) ? write_data :
                        registers[rs2];

    // Write port (sequential, on clock edge)
    always_ff @(posedge clk) begin
        if (we && rd != 5'd0) begin  // Can't write to x0
            registers[rd] <= write_data;
        end
    end

endmodule
