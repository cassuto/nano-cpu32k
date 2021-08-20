.PHONY: lint sim build

NUM_JOBS := 8
SRC_DIR := rtl
TESTBENCH_DIR := testbench
EM_DIR := em
SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )
INCS = -I$(SRC_DIR)
DEFS = +define+SYNTHESIS=1
FLAGS := $(DEFS) $(INCS) -Wno-UNUSED


# Simulation
SIM_TOPLEVEL := simtop
SIM_FLAGS := +define+IN_VERILATOR_SIM=1+ --exe --trace --assert -CFLAGS "-Wall" -j $(NUM_JOBS) -Mdir build/ -o emu
SIM_SRCS := $(SRCS) \
			$(TESTBENCH_DIR)/simtop.v
SIM_CPPS := $(EM_DIR)/main.cc

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
