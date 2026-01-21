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
RTL_FILES = $(RTL_DIR)/alu.sv \
            $(RTL_DIR)/register_file.sv \
            $(RTL_DIR)/program_counter.sv \
            $(RTL_DIR)/decoder.sv \
            $(RTL_DIR)/instruction_memory.sv \
            $(RTL_DIR)/data_memory.sv \
            $(RTL_DIR)/cpu_top.sv

TB_FILES = $(TB_DIR)/cpu_tb.sv

# ============ Icarus Verilog (simple simulation) ============
SIM_OUT = cpu_sim

.PHONY: all sim wave clean verilate verify ref

all: sim

compile: $(RTL_FILES) $(TB_FILES)
	$(IVERILOG) -g2012 -o $(SIM_OUT) $(TB_FILES) $(RTL_FILES)

sim: compile
	$(VVP) $(SIM_OUT)

wave: sim
	gtkwave cpu_tb.vcd &

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
		$(RTL_FILES) \
		$(SIM_DIR)/tb_top.cpp \
		-o ../cpu_verilator

verify: verilate
	./cpu_verilator

# ============ Clean ============
clean:
	rm -f $(SIM_OUT) *.vcd cpu_verilator
	rm -rf $(OBJ_DIR)
	rm -rf $(REF_DIR)/zig-out $(REF_DIR)/.zig-cache

# ============ Help ============
help:
	@echo "RISC-V CPU Makefile"
	@echo ""
	@echo "Targets:"
	@echo "  sim      - Run simple simulation (Icarus Verilog)"
	@echo "  wave     - Open waveform viewer"
	@echo "  ref      - Build Zig reference model"
	@echo "  verilate - Compile with Verilator"
	@echo "  verify   - Run RTL vs reference model verification"
	@echo "  clean    - Remove generated files"
