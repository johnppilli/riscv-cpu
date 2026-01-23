// physical_regfile.sv - Physical Register File for OoO CPU
// 64 physical registers (more than 32 architectural to allow renaming)

module physical_regfile #(
    parameter NUM_PHYS_REGS = 64,
    parameter PHYS_REG_BITS = 6    // log2(64)
) (
    input  logic        clk,
    input  logic        rst,

    // Read port 1
    input  logic [PHYS_REG_BITS-1:0] read_addr1,
    output logic [31:0]              read_data1,

    // Read port 2
    input  logic [PHYS_REG_BITS-1:0] read_addr2,
    output logic [31:0]              read_data2,

    // Write port (from completing instructions)
    input  logic                     write_en,
    input  logic [PHYS_REG_BITS-1:0] write_addr,
    input  logic [31:0]              write_data
);

    // Physical register storage
    logic [31:0] regs [0:NUM_PHYS_REGS-1];

    // Combinational reads with write-through
    assign read_data1 = (read_addr1 == 0) ? 32'd0 :
                        (write_en && write_addr == read_addr1) ? write_data :
                        regs[read_addr1];

    assign read_data2 = (read_addr2 == 0) ? 32'd0 :
                        (write_en && write_addr == read_addr2) ? write_data :
                        regs[read_addr2];

    // Synchronous write
    always_ff @(posedge clk or posedge rst) begin
        if (rst) begin
            integer i;
            for (i = 0; i < NUM_PHYS_REGS; i++) begin
                regs[i] <= 32'd0;
            end
        end else if (write_en && write_addr != 0) begin
            regs[write_addr] <= write_data;
        end
    end

endmodule
