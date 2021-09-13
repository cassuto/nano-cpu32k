.PHONY: lint sim build clean

GTKWAVE = e:/gtkwave-win32/gtkwave/bin/gtkwave

NUM_JOBS = 8
SRC_DIR = rtl
TESTBENCH_DIR = testbench
EM_DIR = em
SRCS = $(foreach x,$(SRC_DIR), $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/lib, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/general, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/fabric, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/port, $(wildcard $(addprefix ${x}/*,.v) ) )

# Emulator
EM_CXXFLAGS =
EM_CXXFLAGS =
EM_LDFLAGS =

# DRAMsim3
DRAMSIM3_HOME = em/csrc/third-party/DRAMsim3
LIB_DRAMSIM3 = $(DRAMSIM3_HOME)/build/libdramsim3.a
EM_CXXFLAGS += -I../$(DRAMSIM3_HOME)/src
EM_CXXFLAGS += -DWITH_DRAMSIM3 -DDRAMSIM3_CONFIG=\\\"$(DRAMSIM3_HOME)/configs/XiangShan.ini\\\" -DDRAMSIM3_OUTDIR=\\\"$(BUILD_DIR)\\\"
EM_LDFLAGS  += ../$(LIB_DRAMSIM3)

INCS = -I$(SRC_DIR)
DEFS = +define+SYNTHESIS=1
FLAGS = $(DEFS) $(INCS) -Wno-UNUSED
CFLAGS = -Wall -g -I../em/csrc $(EM_CXXFLAGS)
LDFLAGS = -g $(EM_LDFLAGS)

# Simulation (Difftest)
SIM_TOPLEVEL = simtop
SIM_FLAGS = +define+IN_VERILATOR_SIM=1+ --exe --trace --assert -LDFLAGS "$(LDFLAGS)" -CFLAGS "$(CFLAGS)" -j $(NUM_JOBS) -Mdir build/ -o emu
SIM_SRCS = $(SRCS) \
			$(TESTBENCH_DIR)/simtop.v
SIM_SRCS += $(foreach x,$(EM_DIR)/vsrc, $(wildcard $(addprefix ${x}/*,.v) ) )

# CPU Model
SIM_CPPS = $(EM_DIR)/csrc/main.cc \
			$(EM_DIR)/csrc/cpu.cc \
			$(EM_DIR)/csrc/cache.cc \
			$(EM_DIR)/csrc/memory.cc \
			$(EM_DIR)/csrc/mmu.cc \
			$(EM_DIR)/csrc/msr.cc \
			$(EM_DIR)/csrc/tsc.cc \
			$(EM_DIR)/csrc/irqc.cc \
			$(EM_DIR)/csrc/pc-queue.cc \
			$(EM_DIR)/csrc/ras.cc \
			$(EM_DIR)/csrc/emu.cc \
			$(EM_DIR)/csrc/dpi-c.cc
# Peripherals
SIM_CPPS += $(EM_DIR)/csrc/peripheral/device-tree.cc \
			$(EM_DIR)/csrc/peripheral/pb-uart.cc \
			$(EM_DIR)/csrc/peripheral/virt-uart.cc
# Third-party lib
SIM_CPPS += $(EM_DIR)/csrc/third-party/axi4.cc \
			$(EM_DIR)/csrc/third-party/dram-axi4-model.cc

# Lint
LINT_TOPLEVEL = ysyx_20210479
LINT_SRCS = $(SRCS)

# YSYX Information
MYINFO_FILE = myinfo.txt
ID =$(shell sed '/^ID=/!d;s/.*=//' $(MYINFO_FILE))
NAME =$(shell sed '/^Name=/!d;s/.*=//' $(MYINFO_FILE))

build: # $(LIB_DRAMSIM3)
	verilator --cc -Wall --top-module $(SIM_TOPLEVEL) $(FLAGS) $(SIM_FLAGS) --build $(SIM_SRCS) $(SIM_CPPS)
	git add . -A --ignore-errors
	(echo $(NAME) && echo $(ID) && hostnamectl && date) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty  2>&1
	sync

sim: build
	./build/emu --mode=simulate-only -b ./build/vmlinux.bin --dump-wave=./build/dump.vcd
	$(GTKWAVE) ./build/dump.vcd

test: build
	./build/emu --mode=difftest -b ./build/coremark.bin --dump-wave=./build/dump.vcd
	$(GTKWAVE) ./build/dump.vcd

lint:
	-verilator --lint-only -Wall --top-module $(LINT_TOPLEVEL) $(FLAGS) $(LINT_SRCS)

$(LIB_DRAMSIM3): $(dir $(LIB_DRAMSIM3)) $(dir $(LIB_DRAMSIM3))/Makefile
	make -C $< -j$(NUM_JOBS) all

$(dir $(LIB_DRAMSIM3)):
	mkdir $@

$(dir $(LIB_DRAMSIM3))/Makefile: $(dir $(LIB_DRAMSIM3))/../CMakeLists.txt
	cd $(dir $(LIB_DRAMSIM3)) && cmake .. -DCOSIM=1

clean:
	-rm ./build/*.o ./build/*.d ./build/*.cpp ./build/*.h
	-make -C $(dir $(LIB_DRAMSIM3)) clean
	-rm $(dir $(LIB_DRAMSIM3))/Makefile
