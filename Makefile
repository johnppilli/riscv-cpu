# Makefile for RISC-V CPU simulation

# Simulator (using Icarus Verilog - free and open source)
IVERILOG = iverilog
VVP = vvp

# Source files
RTL_DIR = rtl
TB_DIR = tb

RTL_FILES = $(RTL_DIR)/alu.sv \
            $(RTL_DIR)/register_file.sv \
            $(RTL_DIR)/program_counter.sv \
            $(RTL_DIR)/decoder.sv \
            $(RTL_DIR)/instruction_memory.sv \
            $(RTL_DIR)/data_memory.sv \
            $(RTL_DIR)/cpu_top.sv

TB_FILES = $(TB_DIR)/cpu_tb.sv

# Output
SIM_OUT = cpu_sim

# Default target
all: sim

# Compile
compile: $(RTL_FILES) $(TB_FILES)
	$(IVERILOG) -g2012 -o $(SIM_OUT) $(TB_FILES) $(RTL_FILES)

# Run simulation
sim: compile
	$(VVP) $(SIM_OUT)

# View waveforms (requires GTKWave)
wave: sim
	gtkwave cpu_tb.vcd &

# Clean
clean:
	rm -f $(SIM_OUT) *.vcd

.PHONY: all compile sim wave clean
