.PHONY: lint lint_testbench

SRC_DIR := \
	rtl/ncpu32k \
	rtl/ncpu32k/cache \
	rtl/ncpu32k/mmu \
	rtl/ncpu32k/cells \
	rtl/pb_fb_arbiter \
	rtl/pb_fb_bootrom \
	rtl/pb_fb_DRAM_ctrl \
	rtl/pb_fb_L2_cache \
	rtl/pb_fb_router \
	sopc/rtl
SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

TESTBENCH_SRC_DIR := \
	testbench
TESTBENCH_SRCS := \
	$(SRCS) \
	$(foreach x,${TESTBENCH_SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

TOPLEVEL := soc_toplevel
WARNS = -Wno-EOFNEWLINE -Wno-PINCONNECTEMPTY -Wno-UNUSED
INCS = +incdir+rtl/ncpu32k/
DEFS = +define+IN_SIM=1+SYNTHESIS=1+IN_LINT=1
FLAGS := --top-module $(TOPLEVEL) $(DEFS) $(INCS) $(WARNS)

lint:
	@echo "==========================================================="
	@echo "Warning: $(WARNS)"
	@echo "==========================================================="
	-verilator --lint-only -Wall $(FLAGS) $(SRCS)

TESTBENCH_INCS = +incdir+rtl/ncpu32k/ +incdir+testbench +incdir+testbench/model-SPI-FLASH
TESTBENCH_DEFS = +define+IN_SIM=1+IN_LINT=1
TESTBENCH_FLAGS := $(TESTBENCH_DEFS) $(TESTBENCH_INCS) $(WARNS) -Wno-MULTITOP

lint_testbench:
	@echo "==========================================================="
	@echo "Lint Testbench"
	@echo "==========================================================="
	verilator --lint-only -Wall $(TESTBENCH_FLAGS) $(TESTBENCH_SRCS)
