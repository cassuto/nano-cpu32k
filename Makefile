.PHONY: lint sim build clean

NUM_JOBS := 8
SRC_DIR := rtl
LIB_DIR := rtl/lib
TESTBENCH_DIR := testbench
EM_DIR := em
SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,${LIB_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )
INCS = -I$(SRC_DIR)
DEFS = +define+SYNTHESIS=1
FLAGS := $(DEFS) $(INCS) -Wno-UNUSED
CFLAGS := -Wall

# Simulation
SIM_TOPLEVEL := simtop
SIM_FLAGS := +define+IN_VERILATOR_SIM=1+ --exe --trace --assert -CFLAGS "$(CFLAGS)" -j $(NUM_JOBS) -Mdir build/ -o emu
SIM_SRCS := $(SRCS) \
			$(TESTBENCH_DIR)/simtop.v
SIM_CPPS := $(EM_DIR)/main.cc \
			$(EM_DIR)/cpu.cc \
			$(EM_DIR)/cache.cc \
			$(EM_DIR)/memory.cc \
			$(EM_DIR)/mmu.cc \
			$(EM_DIR)/msr.cc \
			$(EM_DIR)/tsc.cc \
			$(EM_DIR)/irqc.cc

# Lint
LINT_TOPLEVEL := ncpu64k
LINT_SRCS := $(SRCS)

# YSYX Information
MYINFO_FILE := myinfo.txt
ID :=$(shell sed '/^ID=/!d;s/.*=//' $(MYINFO_FILE))
NAME :=$(shell sed '/^Name=/!d;s/.*=//' $(MYINFO_FILE))

build:
	verilator --cc -Wall --top-module $(SIM_TOPLEVEL) $(FLAGS) $(SIM_FLAGS) --build $(SIM_SRCS) $(SIM_CPPS)
	git add . -A --ignore-errors
	(echo $(NAME) && echo $(ID) && hostnamectl && date) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty  2>&1
	sync

sim: build
	cd ./build && ./emu

lint:
	-verilator --lint-only -Wall --top-module $(LINT_TOPLEVEL) $(FLAGS) $(LINT_SRCS)

clean:
	-rm ./build/*.o ./build/*.d ./build/*.cpp ./build/*.h