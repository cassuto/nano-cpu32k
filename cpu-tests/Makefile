ARCH ?= riscv64-nemu
.PHONY: all run clean latest $(ALL)

AM_HOME = $(realpath .)/abstract-machine

ALL = $(basename $(notdir $(shell find tests/. -name "*.c")))

all: $(addprefix Makefile., $(ALL))
	@echo "" $(ALL)

$(ALL): %: Makefile.%

Makefile.%: tests/%.c latest
	@/bin/echo -e "NAME = $*\nSRCS = $<\ninclude ${AM_HOME}/Makefile" > $@
	-@make -s -f $@ ARCH=$(ARCH) $(MAKECMDGOALS) AM_HOME=$(AM_HOME)
	-@rm -f Makefile.$*

# cancel rules included by $(AM_HOME)/Makefile.check
image: ;
default $(MAKECMDGOALS): all ;

clean:
	rm -rf Makefile.* build/ $(AM_HOME)/am/build $(AM_HOME)/klib/build

latest:
