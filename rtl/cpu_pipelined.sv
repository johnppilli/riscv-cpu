// cpu_pipelined.sv - 5-stage pipelined RISC-V CPU with hazard handling and branch prediction
//
// Stages: IF (Fetch) -> ID (Decode) -> EX (Execute) -> MEM (Memory) -> WB (Writeback)
//
// Features:
//   - Forwarding Unit: Passes results from MEM/WB directly to EX when needed
//   - Hazard Detection: Stalls pipeline for load-use hazards
//   - Branch Prediction: 2-bit predictor with BTB to reduce branch penalties

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
    logic        if_predict_taken;
    logic [31:0] if_predict_target;
    logic        if_btb_hit;

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
    logic [2:0]  id_branch_type;
    logic        id_jump;
    logic        id_predict_taken;
    logic [31:0] id_predict_target;

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
    logic [2:0]  ex_branch_type;
    logic        ex_jump;
    logic        ex_predict_taken;
    logic [31:0] ex_predict_target;
    logic [31:0] ex_alu_operand_a;
    logic [31:0] ex_alu_operand_b;
    logic [31:0] ex_alu_operand_b_fwd;
    logic [31:0] ex_alu_result;
    logic        ex_alu_zero;
    logic [31:0] ex_branch_target;

    // MEM stage signals (from EX/MEM register)
    logic [31:0] mem_pc;
    logic [31:0] mem_pc_plus4;
    logic [31:0] mem_alu_result;
    logic [31:0] mem_read_data2;
    logic [4:0]  mem_rd;
    logic        mem_zero;
    logic [31:0] mem_branch_target;
    logic        mem_predict_taken;
    logic        mem_reg_write;
    logic        mem_mem_read;
    logic        mem_mem_write;
    logic        mem_mem_to_reg;
    logic        mem_branch;
    logic [2:0]  mem_branch_type;
    logic        mem_jump;
    logic [31:0] mem_data_read;
    logic        mem_actual_taken;
    logic        mem_mispredicted;
    logic [31:0] mem_correct_pc;
    logic [31:0] mem_write_back_data;

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
    logic        flush_if_id;
    logic        flush_id_ex;

    // Cache signals
    logic        icache_stall;
    logic        dcache_stall;
    logic        cache_stall;       // Global stall from cache misses
    logic [31:0] imem_addr;
    logic        imem_read_en;
    logic [31:0] imem_read_data;
    logic        imem_ready;
    logic [31:0] dmem_addr;
    logic        dmem_read_en;
    logic        dmem_write_en;
    logic [31:0] dmem_write_data;
    logic [31:0] dmem_read_data;
    logic        dmem_ready;

    // Forwarding control signals
    logic [1:0]  forward_a;
    logic [1:0]  forward_b;


    // ============================================================
    // Branch Predictor
    // ============================================================

    branch_predictor bp_inst (
        .clk           (clk),
        .rst           (rst),
        .pc_if         (if_pc),
        .predict_taken (if_predict_taken),
        .update_en     (mem_branch || mem_jump),
        .update_pc     (mem_pc),
        .actual_taken  (mem_actual_taken)
    );


    // ============================================================
    // Branch Target Buffer
    // ============================================================

    branch_target_buffer btb_inst (
        .clk             (clk),
        .rst             (rst),
        .pc_if           (if_pc),
        .btb_hit         (if_btb_hit),
        .btb_target      (if_predict_target),
        .update_en       (mem_branch || mem_jump),
        .update_pc       (mem_pc),
        .update_target   (mem_branch_target),
        .update_is_branch(mem_branch || mem_jump)
    );


    // ============================================================
    // Cache Stall Logic
    // ============================================================

    // Cache miss freezes the entire pipeline
    assign cache_stall = icache_stall || dcache_stall;


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
    // IF Stage: Instruction Fetch with Branch Prediction
    // ============================================================

    assign if_pc_plus4 = if_pc + 32'd4;

    // PC selection logic:
    // 1. If mispredicted in MEM stage, use correct PC
    // 2. If predicted taken and BTB hit, use predicted target
    // 3. Otherwise, use PC + 4
    always_comb begin
        if (mem_mispredicted) begin
            if_pc_next = mem_correct_pc;
        end else if (if_predict_taken && if_btb_hit && !stall_if) begin
            if_pc_next = if_predict_target;
        end else begin
            if_pc_next = if_pc_plus4;
        end
    end

    // Program Counter (with stall support - hazard OR cache stall)
    program_counter pc_inst (
        .clk     (clk),
        .rst     (rst),
        .stall   (stall_if || cache_stall),
        .pc_next (if_pc_next),
        .pc      (if_pc)
    );

    // Instruction Cache
    cache #(
        .CACHE_SIZE_BYTES(256),
        .LINE_SIZE_BYTES(16)
    ) icache (
        .clk            (clk),
        .rst            (rst),
        .cpu_addr       (if_pc),
        .cpu_write_data (32'd0),
        .cpu_read_en    (1'b1),         // Always reading instructions
        .cpu_write_en   (1'b0),         // Never write to I-cache from CPU
        .cpu_read_data  (if_instruction),
        .cpu_stall      (icache_stall),
        .mem_addr       (imem_addr),
        .mem_read_en    (imem_read_en),
        .mem_write_en   (),             // Not used for I-cache
        .mem_write_data (),
        .mem_read_data  (imem_read_data),
        .mem_ready      (imem_ready)
    );

    // Instruction Main Memory (slow)
    main_memory #(
        .MEM_SIZE_WORDS(4096),
        .LATENCY(4)
    ) imem (
        .clk        (clk),
        .rst        (rst),
        .addr       (imem_addr),
        .read_en    (imem_read_en),
        .write_en   (1'b0),
        .write_data (32'd0),
        .read_data  (imem_read_data),
        .ready      (imem_ready)
    );


    // ============================================================
    // IF/ID Pipeline Register
    // ============================================================

    // Flush IF/ID on misprediction
    assign flush_if_id = mem_mispredicted;

    pipe_if_id if_id_reg (
        .clk               (clk),
        .rst               (rst),
        .flush             (flush_if_id),
        .stall             (stall_id || cache_stall),
        .if_pc             (if_pc),
        .if_instruction    (if_instruction),
        .if_predict_taken  (if_predict_taken && if_btb_hit),
        .if_predict_target (if_predict_target),
        .id_pc             (id_pc),
        .id_instruction    (id_instruction),
        .id_predict_taken  (id_predict_taken),
        .id_predict_target (id_predict_target)
    );


    // ============================================================
    // ID Stage: Instruction Decode
    // ============================================================

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
        .branch_type (id_branch_type),
        .jump        (id_jump)
    );

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

    // Flush ID/EX on misprediction or load-use hazard
    assign flush_id_ex = mem_mispredicted || flush_ex;

    pipe_id_ex id_ex_reg (
        .clk               (clk),
        .rst               (rst),
        .flush             (flush_id_ex),
        .stall             (cache_stall),
        .id_pc             (id_pc),
        .id_read_data1     (id_read_data1),
        .id_read_data2     (id_read_data2),
        .id_imm            (id_imm),
        .id_rs1            (id_rs1),
        .id_rs2            (id_rs2),
        .id_rd             (id_rd),
        .id_predict_taken  (id_predict_taken),
        .id_predict_target (id_predict_target),
        .id_alu_op         (id_alu_op),
        .id_alu_src        (id_alu_src),
        .id_reg_write      (id_reg_write),
        .id_mem_read       (id_mem_read),
        .id_mem_write      (id_mem_write),
        .id_mem_to_reg     (id_mem_to_reg),
        .id_branch         (id_branch),
        .id_branch_type    (id_branch_type),
        .id_jump           (id_jump),
        .ex_pc             (ex_pc),
        .ex_read_data1     (ex_read_data1),
        .ex_read_data2     (ex_read_data2),
        .ex_imm            (ex_imm),
        .ex_rs1            (ex_rs1),
        .ex_rs2            (ex_rs2),
        .ex_rd             (ex_rd),
        .ex_predict_taken  (ex_predict_taken),
        .ex_predict_target (ex_predict_target),
        .ex_alu_op         (ex_alu_op),
        .ex_alu_src        (ex_alu_src),
        .ex_reg_write      (ex_reg_write),
        .ex_mem_read       (ex_mem_read),
        .ex_mem_write      (ex_mem_write),
        .ex_mem_to_reg     (ex_mem_to_reg),
        .ex_branch         (ex_branch),
        .ex_branch_type    (ex_branch_type),
        .ex_jump           (ex_jump)
    );


    // ============================================================
    // EX Stage: Execute (with forwarding muxes)
    // ============================================================

    assign ex_pc_plus4 = ex_pc + 32'd4;
    assign ex_branch_target = ex_pc + ex_imm;
    assign mem_write_back_data = mem_alu_result;

    // Forwarding mux for operand A (rs1)
    always_comb begin
        case (forward_a)
            2'b00:   ex_alu_operand_a = ex_read_data1;
            2'b01:   ex_alu_operand_a = wb_write_data;
            2'b10:   ex_alu_operand_a = mem_write_back_data;
            default: ex_alu_operand_a = ex_read_data1;
        endcase
    end

    // Forwarding mux for operand B (rs2)
    always_comb begin
        case (forward_b)
            2'b00:   ex_alu_operand_b_fwd = ex_read_data2;
            2'b01:   ex_alu_operand_b_fwd = wb_write_data;
            2'b10:   ex_alu_operand_b_fwd = mem_write_back_data;
            default: ex_alu_operand_b_fwd = ex_read_data2;
        endcase
    end

    assign ex_alu_operand_b = ex_alu_src ? ex_imm : ex_alu_operand_b_fwd;

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
        .clk              (clk),
        .rst              (rst),
        .flush            (mem_mispredicted),  // Flush on branch misprediction
        .stall            (cache_stall),
        .ex_pc            (ex_pc),
        .ex_pc_plus4      (ex_pc_plus4),
        .ex_alu_result    (ex_alu_result),
        .ex_read_data2    (ex_alu_operand_b_fwd),
        .ex_rd            (ex_rd),
        .ex_zero          (ex_alu_zero),
        .ex_branch_target (ex_branch_target),
        .ex_predict_taken (ex_predict_taken),
        .ex_reg_write     (ex_reg_write),
        .ex_mem_read      (ex_mem_read),
        .ex_mem_write     (ex_mem_write),
        .ex_mem_to_reg    (ex_mem_to_reg),
        .ex_branch        (ex_branch),
        .ex_branch_type   (ex_branch_type),
        .ex_jump          (ex_jump),
        .mem_pc           (mem_pc),
        .mem_pc_plus4     (mem_pc_plus4),
        .mem_alu_result   (mem_alu_result),
        .mem_read_data2   (mem_read_data2),
        .mem_rd           (mem_rd),
        .mem_zero         (mem_zero),
        .mem_branch_target(mem_branch_target),
        .mem_predict_taken(mem_predict_taken),
        .mem_reg_write    (mem_reg_write),
        .mem_mem_read     (mem_mem_read),
        .mem_mem_write    (mem_mem_write),
        .mem_mem_to_reg   (mem_mem_to_reg),
        .mem_branch       (mem_branch),
        .mem_branch_type  (mem_branch_type),
        .mem_jump         (mem_jump)
    );


    // ============================================================
    // MEM Stage: Memory Access + Branch Resolution
    // ============================================================

    // Actual branch decision (resolved here)
    // Branch types: 000=BEQ, 001=BNE, 100=BLT, 101=BGE, 110=BLTU, 111=BGEU
    logic mem_branch_condition;
    always_comb begin
        case (mem_branch_type)
            3'b000:  mem_branch_condition = mem_zero;           // BEQ: branch if equal
            3'b001:  mem_branch_condition = !mem_zero;          // BNE: branch if not equal
            3'b100:  mem_branch_condition = mem_alu_result[31]; // BLT: branch if less than (signed)
            3'b101:  mem_branch_condition = !mem_alu_result[31] || mem_zero; // BGE: branch if >= (signed)
            3'b110:  mem_branch_condition = !mem_zero && !mem_alu_result[31]; // BLTU: unsigned (simplified)
            3'b111:  mem_branch_condition = mem_zero || mem_alu_result[31];   // BGEU: unsigned (simplified)
            default: mem_branch_condition = 1'b0;
        endcase
    end
    assign mem_actual_taken = (mem_branch && mem_branch_condition) || mem_jump;

    // Misprediction detection
    // Mispredicted if: prediction != actual outcome
    assign mem_mispredicted = (mem_branch || mem_jump) &&
                              (mem_predict_taken != mem_actual_taken);

    // Correct PC to fetch from after misprediction
    // If we should have taken but didn't predict taken: go to branch target
    // If we predicted taken but shouldn't have: go to PC + 4
    assign mem_correct_pc = mem_actual_taken ? mem_branch_target : mem_pc_plus4;

    // Data Cache
    cache #(
        .CACHE_SIZE_BYTES(256),
        .LINE_SIZE_BYTES(16)
    ) dcache (
        .clk            (clk),
        .rst            (rst),
        .cpu_addr       (mem_alu_result),
        .cpu_write_data (mem_read_data2),
        .cpu_read_en    (mem_mem_read),
        .cpu_write_en   (mem_mem_write),
        .cpu_read_data  (mem_data_read),
        .cpu_stall      (dcache_stall),
        .mem_addr       (dmem_addr),
        .mem_read_en    (dmem_read_en),
        .mem_write_en   (dmem_write_en),
        .mem_write_data (dmem_write_data),
        .mem_read_data  (dmem_read_data),
        .mem_ready      (dmem_ready)
    );

    // Data Main Memory (slow)
    main_memory #(
        .MEM_SIZE_WORDS(4096),
        .LATENCY(4)
    ) dmem (
        .clk        (clk),
        .rst        (rst),
        .addr       (dmem_addr),
        .read_en    (dmem_read_en),
        .write_en   (dmem_write_en),
        .write_data (dmem_write_data),
        .read_data  (dmem_read_data),
        .ready      (dmem_ready)
    );


    // ============================================================
    // MEM/WB Pipeline Register
    // ============================================================

    pipe_mem_wb mem_wb_reg (
        .clk            (clk),
        .rst            (rst),
        .stall          (cache_stall),
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

    assign wb_write_data = wb_jump ? wb_pc_plus4 :
                           (wb_mem_to_reg ? wb_read_data : wb_alu_result);

endmodule
