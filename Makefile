.PHONY: lint lint_testbench

SRC_DIR := \
	rtl/core \
	rtl/core/cache \
	rtl/core/mmu \
	rtl/core/bpu \
	rtl/core/fu \
	rtl/core/debug \
	rtl/cells \
	rtl/pb \
	sopc/rtl
SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

TESTBENCH_SRC_DIR := \
	testbench
TESTBENCH_SRCS := \
	$(SRCS) \
	$(foreach x,${TESTBENCH_SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

TOPLEVEL := soc_toplevel
WARNS = -Wno-EOFNEWLINE -Wno-PINCONNECTEMPTY -Wno-UNUSED
INCS = +incdir+rtl/core/
DEFS = +define+IN_SIM=1+SYNTHESIS=1+IN_LINT=1
FLAGS := --top-module $(TOPLEVEL) $(DEFS) $(INCS) $(WARNS)

lint:
	@echo "==========================================================="
	@echo "Warning: $(WARNS)"
	@echo "==========================================================="
	-verilator --lint-only -Wall $(FLAGS) $(SRCS)

TESTBENCH_INCS = +incdir+rtl/core/ +incdir+testbench +incdir+testbench/model-SPI-FLASH
TESTBENCH_DEFS = +define+IN_SIM=1+IN_LINT=1
TESTBENCH_FLAGS := $(TESTBENCH_DEFS) $(TESTBENCH_INCS) $(WARNS) -Wno-MULTITOP

lint_testbench:
	@echo "==========================================================="
	@echo "Lint Testbench"
	@echo "==========================================================="
	verilator --lint-only -Wall $(TESTBENCH_FLAGS) $(TESTBENCH_SRCS)
