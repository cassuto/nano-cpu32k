.PHONY: build generate clean
.PHONY: lint sim build_sim test

GTKWAVE = e:/gtkwave-win32/gtkwave/bin/gtkwave
PYTHON3 = python3

NUM_JOBS = 8
SRC_DIR = rtl
TESTBENCH_DIR = testbench
PDK_RTL_DIR = pdk-lib/rtl
EM_DIR = em
SRCS = $(foreach x,$(SRC_DIR)/core, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/lib, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/general, $(wildcard $(addprefix ${x}/*,.v) ) )
SRCS += $(foreach x,$(SRC_DIR)/fabric, $(wildcard $(addprefix ${x}/*,.v) ) )

# SoC - YSYX
YSYX_SRCS += $(foreach x,$(SRC_DIR)/soc/ysyx, $(wildcard $(addprefix ${x}/*,.v) ) )
YSYX_TOPLEVEL = ysyx_20210479
YSYX_PREFIX = ysyx_20210479_
YSYX_TARGET = build/$(YSYX_TOPLEVEL).v

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

# PDK
PDK_SRCS += $(PDK_RTL_DIR)/S011HD1P_X32Y2D128.v \
			$(PDK_RTL_DIR)/S011HD1P_X32Y2D128_BW.v

# Simulation (Difftest)
SIM_INCS = -I$(SRC_DIR)/core
SIM_DEFS =
SIM_FLAGS = $(SIM_DEFS) $(SIM_INCS) -Wno-UNUSED
CFLAGS = -Wall -Wno-attributes -g -I../em/csrc $(EM_CXXFLAGS)
LDFLAGS = -g $(EM_LDFLAGS)
SIM_FLAGS += +define+IN_VERILATOR_SIM=1+ --exe --trace --assert -LDFLAGS "$(LDFLAGS)" -CFLAGS "$(CFLAGS)" -j $(NUM_JOBS) -Mdir build/ -o emu
SIM_TOPLEVEL = simtop
SIM_SRCS = $(SRCS) $(YSYX_SRCS) $(PDK_SRCS)
SIM_SRCS += $(foreach x,$(EM_DIR)/vsrc, $(wildcard $(addprefix ${x}/*,.v) ) )
SIM_SRCS += $(TESTBENCH_DIR)/simtop.v

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
			$(EM_DIR)/csrc/symtable.cc \
			$(EM_DIR)/csrc/emu.cc \
			$(EM_DIR)/csrc/dpi-c.cc
# Peripherals
SIM_CPPS += $(EM_DIR)/csrc/peripheral/device-tree.cc \
			$(EM_DIR)/csrc/peripheral/pb-uart.cc \
			$(EM_DIR)/csrc/peripheral/flash.cc \
			$(EM_DIR)/csrc/peripheral/virt-uart.cc \
			$(EM_DIR)/csrc/peripheral/axi4.cc \
			$(EM_DIR)/csrc/peripheral/axi4-crossbar.cc

# Lint
LINT_DEFS = +define+SYNTHESIS=1
LINT_INCS = -I$(SRC_DIR)
LINT_FLAGS = $(LINT_DEFS) $(LINT_INCS)

# YSYX Information
MYINFO_FILE = myinfo.txt
ID =$(shell sed '/^ID=/!d;s/.*=//' $(MYINFO_FILE))
NAME =$(shell sed '/^Name=/!d;s/.*=//' $(MYINFO_FILE))

build: $(YSYX_TARGET)

$(YSYX_TARGET): $(SRCS) $(YSYX_SRCS)
	$(PYTHON3) scripts/build.py -d ./ -c $^ -I $(SRC_DIR)/core -t $(YSYX_TOPLEVEL) -p $(YSYX_PREFIX) -o $(YSYX_TARGET)

generate: rtl/general/pmux.v rtl/general/pmux_v.v rtl/general/priority_encoder.v rtl/general/priority_encoder_gs.v

rtl/general/pmux.v rtl/general/pmux_v.v: scripts/gen_pmux.py
	$(PYTHON3) scripts/gen_pmux.py rtl/general/pmux
rtl/general/priority_encoder.v rtl/general/priority_encoder_gs.v: scripts/gen_priority_encoder.py
	$(PYTHON3) scripts/gen_priority_encoder.py rtl/general/priority_encoder

build_sim:  # $(LIB_DRAMSIM3)
	verilator --cc -Wall --top-module $(SIM_TOPLEVEL) $(SIM_FLAGS) --build $(SIM_SRCS) $(SIM_CPPS)
	git add . -A --ignore-errors
	(echo $(NAME) && echo $(ID) && hostnamectl && date) | git commit -F - -q --author='tracer-oscpu2021 <tracer@oscpu.org>' --no-verify --allow-empty  2>&1
	sync

sim: build_sim
	./build/emu --mode=simulate-only -b ./build/vmlinux.bin --dump-wave=./build/dump.vcd
	$(GTKWAVE) ./build/dump.vcd

test: build_sim
	./build/emu --mode=difftest -b ./build/coremark.bin --dump-wave=./build/dump.vcd
	$(GTKWAVE) ./build/dump.vcd

lint:
	-verilator --lint-only -Wall --top-module $(YSYX_TOPLEVEL) $(LINT_FLAGS) $(YSYX_TARGET) $(PDK_SRCS)

$(LIB_DRAMSIM3): $(dir $(LIB_DRAMSIM3)) $(dir $(LIB_DRAMSIM3))/Makefile
	make -C $< -j$(NUM_JOBS) all

$(dir $(LIB_DRAMSIM3)):
	mkdir $@

$(dir $(LIB_DRAMSIM3))/Makefile: $(dir $(LIB_DRAMSIM3))/../CMakeLists.txt
	cd $(dir $(LIB_DRAMSIM3)) && cmake .. -DCOSIM=1

clean:
	-rm ./build/*.o ./build/*.d ./build/*.cpp ./build/*.h ./build/*.v
	-make -C $(dir $(LIB_DRAMSIM3)) clean
	-rm $(dir $(LIB_DRAMSIM3))/Makefile
