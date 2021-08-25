.PHONY: lint sim build clean

NUM_JOBS := 8
SRC_DIR := rtl
LIB_DIR := rtl/lib
TESTBENCH_DIR := testbench
EM_DIR := em
SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,${LIB_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

# Emulator
EM_CXXFLAGS :=
EM_CXXFLAGS :=
EM_LDFLAGS :=

# DRAMsim3
DRAMSIM3_HOME = em/third-party/DRAMsim3
LIB_DRAMSIM3 = $(DRAMSIM3_HOME)/build/libdramsim3.a
EM_CXXFLAGS += -I../$(DRAMSIM3_HOME)/src
EM_CXXFLAGS += -DWITH_DRAMSIM3 -DDRAMSIM3_CONFIG=\\\"$(DRAMSIM3_HOME)/configs/XiangShan.ini\\\" -DDRAMSIM3_OUTDIR=\\\"$(BUILD_DIR)\\\"
EM_LDFLAGS  += -L../$(LIB_DRAMSIM3)

INCS = -I$(SRC_DIR)
DEFS = +define+SYNTHESIS=1
FLAGS = $(DEFS) $(INCS) -Wno-UNUSED
CFLAGS = -Wall -g -I../em $(EM_CXXFLAGS)
LDFLAGS = -g $(EM_LDFLAGS)

# Simulation
SIM_TOPLEVEL := simtop
SIM_FLAGS := +define+IN_VERILATOR_SIM=1+ --exe --trace --assert -CFLAGS "$(CFLAGS)" -LDFLAGS "$(LDFLAGS)" -j $(NUM_JOBS) -Mdir build/ -o emu
SIM_SRCS := $(SRCS) \
			$(TESTBENCH_DIR)/simtop.v
SIM_CPPS := $(EM_DIR)/main.cc \
			$(EM_DIR)/cpu.cc \
			$(EM_DIR)/cache.cc \
			$(EM_DIR)/memory.cc \
			$(EM_DIR)/mmu.cc \
			$(EM_DIR)/msr.cc \
			$(EM_DIR)/tsc.cc \
			$(EM_DIR)/irqc.cc \
			$(EM_DIR)/pc-queue.cc \
			$(EM_DIR)/peripheral/device-tree.cc \
			$(EM_DIR)/peripheral/pb-uart.cc \
			$(EM_DIR)/peripheral/virt-uart.cc

# Lint
LINT_TOPLEVEL := ncpu64k
LINT_SRCS := $(SRCS)

# YSYX Information
MYINFO_FILE := myinfo.txt
ID :=$(shell sed '/^ID=/!d;s/.*=//' $(MYINFO_FILE))
NAME :=$(shell sed '/^Name=/!d;s/.*=//' $(MYINFO_FILE))

build: $(LIB_DRAMSIM3)
	verilator --cc -Wall --top-module $(SIM_TOPLEVEL) $(FLAGS) $(SIM_FLAGS) --build $(SIM_SRCS) $(SIM_CPPS)
	git add . -A --ignore-errors
	(echo $(NAME) && echo $(ID) && hostnamectl && date) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty  2>&1
	sync

sim: build
	cd ./build && ./emu

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
