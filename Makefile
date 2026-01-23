# Makefile for RISC-V CPU simulation and verification

# ============ Tools ============
IVERILOG = iverilog
VVP = vvp
VERILATOR = verilator
ZIG = zig

# ============ Directories ============
RTL_DIR = rtl
TB_DIR = tb
SIM_DIR = sim
REF_DIR = ref
OBJ_DIR = obj_dir

# ============ Source Files ============
RTL_COMMON = $(RTL_DIR)/alu.sv \
             $(RTL_DIR)/register_file.sv \
             $(RTL_DIR)/program_counter.sv \
             $(RTL_DIR)/decoder.sv \
             $(RTL_DIR)/instruction_memory.sv \
             $(RTL_DIR)/data_memory.sv

RTL_SINGLE = $(RTL_COMMON) $(RTL_DIR)/cpu_top.sv

RTL_PIPELINED = $(RTL_DIR)/alu.sv \
                $(RTL_DIR)/register_file.sv \
                $(RTL_DIR)/program_counter.sv \
                $(RTL_DIR)/decoder.sv \
                $(RTL_DIR)/cache.sv \
                $(RTL_DIR)/main_memory.sv \
                $(RTL_DIR)/pipeline_regs.sv \
                $(RTL_DIR)/forwarding_unit.sv \
                $(RTL_DIR)/hazard_unit.sv \
                $(RTL_DIR)/branch_predictor.sv \
                $(RTL_DIR)/branch_target_buffer.sv \
                $(RTL_DIR)/cpu_pipelined.sv

RTL_OOO = $(RTL_DIR)/alu.sv \
            $(RTL_DIR)/instruction_memory.sv \
            $(RTL_DIR)/physical_regfile.sv \
            $(RTL_DIR)/free_list.sv \
            $(RTL_DIR)/rat.sv \
            $(RTL_DIR)/rob.sv \
            $(RTL_DIR)/issue_queue.sv \
            $(RTL_DIR)/cpu_ooo.sv

TB_SINGLE = $(TB_DIR)/cpu_tb.sv
TB_PIPELINED = $(TB_DIR)/cpu_pipelined_tb.sv
TB_OOO = $(TB_DIR)/cpu_ooo_tb.sv

# ============ Icarus Verilog (single-cycle) ============
SIM_OUT = cpu_sim
SIM_PIPELINED_OUT = cpu_pipelined_sim
SIM_OOO_OUT = cpu_ooo_sim

.PHONY: all sim sim-pipe sim-ooo wave wave-pipe wave-ooo clean verilate verify ref help

all: sim

# Single-cycle simulation
compile: $(RTL_SINGLE) $(TB_SINGLE)
	$(IVERILOG) -g2012 -o $(SIM_OUT) $(TB_SINGLE) $(RTL_SINGLE)

sim: compile
	cp program_single.hex program.hex
	$(VVP) $(SIM_OUT)

wave: sim
	gtkwave cpu_tb.vcd &

# Pipelined simulation
compile-pipe: $(RTL_PIPELINED) $(TB_PIPELINED)
	$(IVERILOG) -g2012 -o $(SIM_PIPELINED_OUT) $(TB_PIPELINED) $(RTL_PIPELINED)

sim-pipe: compile-pipe
	cp program_hazard_test.hex program.hex
	$(VVP) $(SIM_PIPELINED_OUT)

wave-pipe: sim-pipe
	gtkwave cpu_pipelined_tb.vcd &

# Out-of-Order simulation
compile-ooo: $(RTL_OOO) $(TB_OOO)
	$(IVERILOG) -g2012 -o $(SIM_OOO_OUT) $(TB_OOO) $(RTL_OOO)

sim-ooo: compile-ooo
	cp program_ooo_test.hex program.hex
	$(VVP) $(SIM_OOO_OUT)

wave-ooo: sim-ooo
	gtkwave cpu_ooo_tb.vcd &

# ============ Zig Reference Model ============
REF_LIB = $(REF_DIR)/zig-out/lib/libriscv_ref.a

ref:
	cd $(REF_DIR) && $(ZIG) build -Doptimize=ReleaseFast

# ============ Verilator (verification) ============
VERILATOR_FLAGS = --cc --exe --build \
                  --trace \
                  --public \
                  -Wno-fatal \
                  --top-module cpu_top \
                  -CFLAGS "-I../$(SIM_DIR) -I../$(REF_DIR)" \
                  -LDFLAGS "-L../$(REF_DIR)/zig-out/lib -lriscv_ref"

verilate: ref
	$(VERILATOR) $(VERILATOR_FLAGS) \
		$(RTL_SINGLE) \
		$(SIM_DIR)/tb_top.cpp \
		-o ../cpu_verilator

verify: verilate
	./cpu_verilator

# ============ Clean ============
clean:
	rm -f $(SIM_OUT) $(SIM_PIPELINED_OUT) $(SIM_OOO_OUT) *.vcd cpu_verilator
	rm -rf $(OBJ_DIR)
	rm -rf $(REF_DIR)/zig-out $(REF_DIR)/.zig-cache

# ============ Help ============
help:
	@echo "RISC-V CPU Makefile"
	@echo ""
	@echo "Single-cycle CPU:"
	@echo "  sim        - Run single-cycle simulation"
	@echo "  wave       - View single-cycle waveforms"
	@echo ""
	@echo "Pipelined CPU:"
	@echo "  sim-pipe   - Run pipelined simulation"
	@echo "  wave-pipe  - View pipelined waveforms"
	@echo ""
	@echo "Out-of-Order CPU:"
	@echo "  sim-ooo    - Run OoO simulation"
	@echo "  wave-ooo   - View OoO waveforms"
	@echo ""
	@echo "Verification:"
	@echo "  ref        - Build Zig reference model"
	@echo "  verilate   - Compile with Verilator"
	@echo "  verify     - Run RTL vs reference model verification"
	@echo ""
	@echo "  clean      - Remove generated files"
