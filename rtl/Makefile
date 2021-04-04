.PHONY: lint

SRC_DIR := \
	ncpu32k \
	ncpu32k/cache \
	ncpu32k/mmu \
	ncpu32k/cells \
	pb_fb_arbiter \
	pb_fb_bootrom \
	pb_fb_DRAM_ctrl \
	pb_fb_L2_cache \
	pb_fb_router

SRCS := $(foreach x,${SRC_DIR}, $(wildcard $(addprefix ${x}/*,.v) ) )

INCS = +incdir+./ncpu32k/

DEFS = +define+IN_SIM=1

lint:
	verilator --lint-only -Wall $(DEFS) $(INCS) $(SRCS)

